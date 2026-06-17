import Core
import Foundation

extension CodexLogObserver {
    /// Folds Codex response events into graph nodes for the visible timeline.
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

        // Surface every observed Codex response, not just the most recent ones.
        let maxLatency = max(responses.map(\.latencyMs).max() ?? 0, 1)

        return responses.enumerated().map { index, draft in
            makeNode(from: draft, index: index, maxLatency: maxLatency, thread: thread)
        }
    }

    /// Builds the final graph node from a folded Codex response draft.
    nonisolated static func makeNode(
        from draft: CodexResponseDraft,
        index: Int,
        maxLatency: Int,
        thread: CodexThreadRow
    ) -> AgentNode {
        let latencyMs = draft.latencyMs
        let responseText = responseText(for: draft)
        let error = errorPayload(for: draft)

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
                system: "Observed from ~/.codex local logs. No proxy configuration is required for Terminal Codex runs.",
                user: promptText(for: thread)
            ),
            response: AgentResponse(language: .text, text: responseText),
            error: error
        )
    }
}
