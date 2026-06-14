import Core
import Foundation

public actor CodexLogObserver {
    public init() {}

    public func currentSnapshot(afterLogId baselineLogId: Int? = nil) async throws -> TraceSnapshot? {
        try await Task.detached(priority: .utility) {
            try Self.loadSnapshot(afterLogId: baselineLogId)
        }.value
    }

    public func latestResponseEventId() async throws -> Int? {
        try await Task.detached(priority: .utility) {
            let codexDirectory = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".codex", isDirectory: true)
            let logsPath = codexDirectory.appendingPathComponent("logs_2.sqlite").path

            guard FileManager.default.fileExists(atPath: logsPath) else {
                return nil
            }

            return try Self.latestResponseEventId(from: logsPath)
        }.value
    }

    nonisolated private static func loadSnapshot(afterLogId baselineLogId: Int?) throws -> TraceSnapshot? {
        let codexDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
        let statePath = codexDirectory.appendingPathComponent("state_5.sqlite").path
        let logsPath = codexDirectory.appendingPathComponent("logs_2.sqlite").path

        guard FileManager.default.fileExists(atPath: statePath),
              FileManager.default.fileExists(atPath: logsPath)
        else {
            return nil
        }

        guard let thread = try latestThread(from: statePath) else {
            return nil
        }

        let events = try responseEvents(for: thread.id, from: logsPath, afterLogId: baselineLogId)
        let nodes = makeNodes(from: events, thread: thread)
        let session = TraceSession(
            id: thread.id,
            title: title(for: thread),
            trigger: "Terminal Codex",
            startedAt: formatClock(seconds: thread.createdAt ?? thread.updatedAt ?? 0)
        )

        return TraceSnapshot(session: session, nodes: nodes)
    }

    nonisolated private static func latestThread(from databasePath: String) throws -> CodexThreadRow? {
        let query = """
        SELECT
            id,
            NULLIF(title, '') AS title,
            NULLIF(first_user_message, '') AS first_user_message,
            NULLIF(preview, '') AS preview,
            NULLIF(model, '') AS model,
            NULLIF(model_provider, '') AS model_provider,
            NULLIF(source, '') AS source,
            created_at,
            updated_at
        FROM threads
        WHERE archived = 0
        ORDER BY updated_at_ms DESC, updated_at DESC
        LIMIT 1;
        """

        return try runSQLiteJSON(databasePath: databasePath, query: query, as: [CodexThreadRow].self).first
    }

    nonisolated private static func responseEvents(
        for threadId: String,
        from databasePath: String,
        afterLogId baselineLogId: Int?
    ) throws -> [CodexResponseEventRow] {
        let baselineClause = baselineLogId.map { "AND id > \($0)" } ?? ""
        let query = """
        WITH raw_events AS (
            SELECT
                id,
                ts,
                substr(
                    feedback_log_body,
                    instr(feedback_log_body, 'websocket event: ') + length('websocket event: ')
                ) AS body
            FROM logs
            WHERE thread_id = \(sqlQuote(threadId))
              \(baselineClause)
              AND feedback_log_body LIKE '%websocket event: {"type":"response.%'
              AND json_valid(substr(
                    feedback_log_body,
                    instr(feedback_log_body, 'websocket event: ') + length('websocket event: ')
              ))
            ORDER BY id DESC
            LIMIT 1000
        ),
        parsed_events AS (
            SELECT
                id,
                ts,
                json_extract(body, '$.type') AS event_type,
                json_extract(body, '$.response.id') AS response_id,
                json_extract(body, '$.response.model') AS model,
                json_extract(body, '$.response.status') AS response_status,
                json_extract(body, '$.response.created_at') AS response_created_at,
                json_extract(body, '$.response.completed_at') AS response_completed_at,
                json_extract(body, '$.response.usage.input_tokens') AS input_tokens,
                json_extract(body, '$.response.usage.output_tokens') AS output_tokens,
                json_extract(body, '$.response.error.message') AS error_message,
                json_extract(body, '$.text') AS output_text,
                json_extract(body, '$.item.type') AS item_type,
                json_extract(body, '$.item.id') AS item_id,
                json_extract(body, '$.item.name') AS item_name,
                json_extract(body, '$.item.arguments') AS item_arguments,
                json_extract(body, '$.item.content[0].text') AS item_text
            FROM raw_events
        )
        SELECT *
        FROM parsed_events
        WHERE event_type IN (
            'response.created',
            'response.output_text.done',
            'response.output_item.done',
            'response.completed'
        )
        ORDER BY id ASC;
        """

        return try runSQLiteJSON(databasePath: databasePath, query: query, as: [CodexResponseEventRow].self)
    }

    nonisolated private static func latestResponseEventId(from databasePath: String) throws -> Int? {
        let query = """
        SELECT id
        FROM logs
        WHERE feedback_log_body LIKE '%websocket event: {"type":"response.%'
        ORDER BY id DESC
        LIMIT 1;
        """

        return try runSQLiteJSON(databasePath: databasePath, query: query, as: [CodexLogWatermarkRow].self).first?.id
    }

    nonisolated private static func makeNodes(
        from events: [CodexResponseEventRow],
        thread: CodexThreadRow
    ) -> [AgentNode] {
        var responses: [CodexResponseDraft] = []
        var active: CodexResponseDraft?
        var pendingOutputText = ""
        var pendingToolSummaries: [String] = []

        for event in events {
            switch event.eventType {
            case "response.created":
                if let active {
                    responses.append(active)
                }

                active = CodexResponseDraft(
                    id: event.responseId ?? "codex-\(event.id)",
                    startedAt: event.responseCreatedAt ?? event.ts,
                    completedAt: nil,
                    model: event.model ?? thread.model ?? "codex",
                    status: .running,
                    tokensIn: 0,
                    tokensOut: 0,
                    outputText: pendingOutputText,
                    toolSummaries: pendingToolSummaries,
                    errorMessage: nil
                )
                pendingOutputText = ""
                pendingToolSummaries = []

            case "response.output_text.done":
                if let text = event.outputText, !text.isEmpty {
                    if var draft = active {
                        draft.outputText = appendBlock(text, to: draft.outputText)
                        active = draft
                    } else {
                        pendingOutputText = appendBlock(text, to: pendingOutputText)
                    }
                }

            case "response.output_item.done":
                if event.itemType == "function_call" || event.itemType == "custom_tool_call" {
                    let name = event.itemName ?? "tool"
                    let arguments = event.itemArguments.map { truncate($0, limit: 420) } ?? ""
                    let summary = arguments.isEmpty ? "Tool call: \(name)" : "Tool call: \(name)\n\(arguments)"
                    if var draft = active {
                        draft.toolSummaries.append(summary)
                        active = draft
                    } else {
                        pendingToolSummaries.append(summary)
                    }
                } else if event.itemType == "message", let text = event.itemText, !text.isEmpty {
                    if var draft = active {
                        if draft.outputText.isEmpty {
                            draft.outputText = appendBlock(text, to: draft.outputText)
                        }
                        active = draft
                    } else if pendingOutputText.isEmpty {
                        pendingOutputText = appendBlock(text, to: pendingOutputText)
                    }
                }

            case "response.completed":
                var draft = active ?? CodexResponseDraft(
                    id: event.responseId ?? "codex-\(event.id)",
                    startedAt: event.responseCreatedAt ?? event.ts,
                    completedAt: nil,
                    model: event.model ?? thread.model ?? "codex",
                    status: .success,
                    tokensIn: 0,
                    tokensOut: 0,
                    outputText: pendingOutputText,
                    toolSummaries: pendingToolSummaries,
                    errorMessage: nil
                )

                draft.id = event.responseId ?? draft.id
                draft.completedAt = event.responseCompletedAt ?? event.ts
                draft.model = event.model ?? draft.model
                draft.tokensIn = event.inputTokens ?? draft.tokensIn
                draft.tokensOut = event.outputTokens ?? draft.tokensOut
                draft.errorMessage = event.errorMessage
                draft.status = event.responseStatus == "completed" ? .success : .error
                responses.append(draft)
                active = nil
                pendingOutputText = ""
                pendingToolSummaries = []

            default:
                continue
            }
        }

        if let active {
            responses.append(active)
        }

        let visibleResponses = Array(responses.suffix(12))
        let maxLatency = max(visibleResponses.map(\.latencyMs).max() ?? 0, 1)

        return visibleResponses.enumerated().map { index, draft in
            makeNode(
                from: draft,
                index: index,
                maxLatency: maxLatency,
                thread: thread
            )
        }
    }

    nonisolated private static func makeNode(
        from draft: CodexResponseDraft,
        index: Int,
        maxLatency: Int,
        thread: CodexThreadRow
    ) -> AgentNode {
        let latencyMs = draft.latencyMs
        let responseText: String
        if !draft.outputText.isEmpty {
            responseText = draft.outputText
        } else if !draft.toolSummaries.isEmpty {
            responseText = draft.toolSummaries.joined(separator: "\n\n")
        } else if draft.status == .running {
            responseText = "Codex response is streaming from Terminal."
        } else if let errorMessage = draft.errorMessage, !errorMessage.isEmpty {
            responseText = errorMessage
        } else {
            responseText = "Codex response completed. Full output text was not present in the local event window."
        }

        let error = draft.status == .error
            ? AgentError(
                code: "codex.response",
                message: "Codex response failed",
                detail: draft.errorMessage ?? "The local Codex log marked this response as failed."
            )
            : nil

        return AgentNode(
            id: draft.id,
            agentName: "Codex",
            depth: index,
            stepName: draft.status == .running ? "Codex response streaming" : "Codex response \(index + 1)",
            timestamp: formatClock(seconds: draft.startedAt),
            model: draft.model,
            cost: "$0.0000",
            latency: draft.status == .running ? "live" : formatLatency(milliseconds: latencyMs),
            latencyMs: latencyMs,
            barPercent: Double(latencyMs) / Double(maxLatency),
            tokensIn: draft.tokensIn,
            tokensOut: draft.tokensOut,
            requestId: shortId(draft.id),
            cacheStatus: "codex-log",
            temperature: nil,
            status: draft.status,
            prompt: AgentPrompt(
                system: "Observed from ~/.codex local logs. No proxy configuration is required for Terminal Codex sessions.",
                user: promptText(for: thread)
            ),
            response: AgentResponse(language: .text, text: responseText),
            error: error
        )
    }

    nonisolated private static func runSQLiteJSON<Row: Decodable>(
        databasePath: String,
        query: String,
        as _: [Row].Type
    ) throws -> [Row] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-readonly", "-json", databasePath, query]

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = error.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8) ?? "sqlite3 exited with status \(process.terminationStatus)"
            throw CodexLogObserverError.sqlite(message)
        }

        guard !outputData.isEmpty else { return [] }
        return try JSONDecoder().decode([Row].self, from: outputData)
    }

    nonisolated private static func title(for thread: CodexThreadRow) -> String {
        let source = thread.title ?? thread.preview ?? thread.firstUserMessage ?? "Codex Terminal Session"
        return truncate(firstLine(source), limit: 86)
    }

    nonisolated private static func promptText(for thread: CodexThreadRow) -> String {
        let prompt = thread.preview ?? thread.firstUserMessage ?? thread.title ?? "Terminal Codex session"
        return truncate(prompt.trimmingCharacters(in: .whitespacesAndNewlines), limit: 4_000)
    }

    nonisolated private static func appendBlock(_ block: String, to text: String) -> String {
        guard !text.isEmpty else { return block }
        return "\(text)\n\n\(block)"
    }

    nonisolated private static func firstLine(_ value: String) -> String {
        value
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? value
    }

    nonisolated private static func truncate(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return "\(value.prefix(limit - 1))..."
    }

    nonisolated private static func shortId(_ value: String) -> String {
        if let suffix = value.split(separator: "_").last {
            return String(suffix.prefix(12))
        }

        return String(value.prefix(12))
    }

    nonisolated private static func formatLatency(milliseconds: Int) -> String {
        if milliseconds >= 1000 {
            return String(format: "%.2fs", Double(milliseconds) / 1000.0)
        }

        return "\(milliseconds)ms"
    }

    nonisolated private static func formatClock(seconds: Int) -> String {
        guard seconds > 0 else { return "--:--:--" }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(seconds)))
    }

    nonisolated private static func sqlQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "''"))'"
    }
}

private nonisolated enum CodexLogObserverError: LocalizedError {
    case sqlite(String)

    var errorDescription: String? {
        switch self {
        case .sqlite(let message):
            return "Codex log query failed: \(message)"
        }
    }
}

private nonisolated struct CodexThreadRow: Decodable {
    let id: String
    let title: String?
    let firstUserMessage: String?
    let preview: String?
    let model: String?
    let modelProvider: String?
    let source: String?
    let createdAt: Int?
    let updatedAt: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case firstUserMessage = "first_user_message"
        case preview
        case model
        case modelProvider = "model_provider"
        case source
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private nonisolated struct CodexResponseEventRow: Decodable {
    let id: Int
    let ts: Int
    let eventType: String?
    let responseId: String?
    let model: String?
    let responseStatus: String?
    let responseCreatedAt: Int?
    let responseCompletedAt: Int?
    let inputTokens: Int?
    let outputTokens: Int?
    let errorMessage: String?
    let outputText: String?
    let itemType: String?
    let itemId: String?
    let itemName: String?
    let itemArguments: String?
    let itemText: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case ts
        case eventType = "event_type"
        case responseId = "response_id"
        case model
        case responseStatus = "response_status"
        case responseCreatedAt = "response_created_at"
        case responseCompletedAt = "response_completed_at"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case errorMessage = "error_message"
        case outputText = "output_text"
        case itemType = "item_type"
        case itemId = "item_id"
        case itemName = "item_name"
        case itemArguments = "item_arguments"
        case itemText = "item_text"
    }
}

private nonisolated struct CodexLogWatermarkRow: Decodable {
    let id: Int
}

private nonisolated struct CodexResponseDraft {
    var id: String
    var startedAt: Int
    var completedAt: Int?
    var model: String
    var status: NodeStatus
    var tokensIn: Int
    var tokensOut: Int
    var outputText: String
    var toolSummaries: [String]
    var errorMessage: String?

    var latencyMs: Int {
        guard let completedAt else { return 0 }
        return max(0, completedAt - startedAt) * 1_000
    }
}
