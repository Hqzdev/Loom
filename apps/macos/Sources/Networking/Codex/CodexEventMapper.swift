import Core
import Foundation

extension CodexLogObserver {
    nonisolated static func makeNodes(
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
                    promptUser: event.promptUser,
                    toolSummaries: pendingToolSummaries,
                    errorMessage: nil
                )
                pendingOutputText = ""
                pendingToolSummaries = []

            case "response.output_text.done":
                appendText(event.outputText, active: &active, pendingOutputText: &pendingOutputText)

            case "response.output_item.done":
                handleOutputItem(event, active: &active, pendingOutputText: &pendingOutputText, pendingToolSummaries: &pendingToolSummaries)

            case "response.completed":
                let draft = completedDraft(from: event, active: active, thread: thread, pendingOutputText: pendingOutputText, pendingToolSummaries: pendingToolSummaries)
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

        let maxLatency = max(responses.map(\.latencyMs).max() ?? 0, 1)

        return responses.enumerated().map { index, draft in
            makeNode(from: draft, index: index, maxLatency: maxLatency, thread: thread)
        }
    }

    nonisolated static func makeNode(
        from draft: CodexResponseDraft,
        index: Int,
        maxLatency: Int,
        thread: CodexThreadRow
    ) -> AgentNode {
        let latencyMs = draft.latencyMs
        let responseText = responseText(for: draft)
        let error = errorPayload(for: draft)
        let responseTitle = truncate(firstLine(responseText).trimmingCharacters(in: .whitespacesAndNewlines), limit: 54)
        let promptUser = draft.promptUser?.trimmingCharacters(in: .whitespacesAndNewlines)

        return AgentNode(
            id: draft.id,
            agentName: "Codex",
            depth: index,
            stepName: draft.status == .running ? "Codex response streaming" : responseTitle,
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
            traceId: thread.id,
            status: draft.status,
            prompt: AgentPrompt(
                system: "Observed from ~/.codex local logs. No proxy configuration is required for Terminal Codex runs.",
                user: promptUser?.isEmpty == false ? promptUser ?? "" : "No turn request was recorded for this local log event."
            ),
            response: AgentResponse(language: .text, text: responseText),
            error: error
        )
    }
}
