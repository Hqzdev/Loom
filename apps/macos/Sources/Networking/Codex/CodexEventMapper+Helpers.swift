import Core
import Foundation

extension CodexLogObserver {
    /// Appends streamed output text to either the active response or pending prelude.
    nonisolated static func appendText(
        _ text: String?,
        active: inout CodexResponseDraft?,
        pendingOutputText: inout String
    ) {
        guard let text, !text.isEmpty else { return }

        if var draft = active {
            draft.outputText = appendBlock(text, to: draft.outputText)
            active = draft
        } else {
            pendingOutputText = appendBlock(text, to: pendingOutputText)
        }
    }

    /// Routes output item events into tool summaries or message text.
    nonisolated static func handleOutputItem(
        _ event: CodexResponseEventRow,
        active: inout CodexResponseDraft?,
        pendingOutputText: inout String,
        pendingToolSummaries: inout [String]
    ) {
        if event.itemType == "function_call" || event.itemType == "custom_tool_call" {
            appendToolSummary(event, active: &active, pendingToolSummaries: &pendingToolSummaries)
        } else if event.itemType == "message", let text = event.itemText, !text.isEmpty {
            appendMessageText(text, active: &active, pendingOutputText: &pendingOutputText)
        }
    }

    /// Produces the terminal draft when Codex emits a completion event.
    nonisolated static func completedDraft(
        from event: CodexResponseEventRow,
        active: CodexResponseDraft?,
        thread: CodexThreadRow,
        pendingOutputText: String,
        pendingToolSummaries: [String]
    ) -> CodexResponseDraft {
        var draft = active ?? CodexResponseDraft(
            id: event.responseId ?? "codex-\(event.id)",
            startedAt: event.responseCreatedAt ?? event.ts,
            completedAt: nil,
            model: event.model ?? thread.model ?? "codex",
            status: .success,
            tokensIn: 0,
            tokensOut: 0,
            outputText: pendingOutputText.isEmpty ? event.outputText ?? "" : pendingOutputText,
            promptUser: event.promptUser,
            toolSummaries: pendingToolSummaries,
            errorMessage: nil
        )

        draft.id = event.responseId ?? draft.id
        draft.completedAt = event.responseCompletedAt ?? event.ts
        draft.model = event.model ?? draft.model
        draft.tokensIn = event.inputTokens ?? draft.tokensIn
        draft.tokensOut = event.outputTokens ?? draft.tokensOut
        draft.errorMessage = event.errorMessage
        draft.promptUser = event.promptUser ?? draft.promptUser
        draft.status = event.responseStatus == "completed" ? .success : .error
        return draft
    }

    /// Returns response text with sensible fallbacks for sparse local log windows.
    nonisolated static func responseText(for draft: CodexResponseDraft) -> String {
        if !draft.outputText.isEmpty {
            return draft.outputText
        }

        if !draft.toolSummaries.isEmpty {
            return draft.toolSummaries.joined(separator: "\n\n")
        }

        if draft.status == .running {
            return "Codex response is streaming from Terminal."
        }

        if let errorMessage = draft.errorMessage, !errorMessage.isEmpty {
            return errorMessage
        }

        return "Codex response completed. Full output text was not present in the local event window."
    }

    /// Builds an error payload for failed Codex responses.
    nonisolated static func errorPayload(for draft: CodexResponseDraft) -> AgentError? {
        guard draft.status == .error else { return nil }

        return AgentError(
            code: "codex.response",
            message: "Codex response failed",
            detail: draft.errorMessage ?? "The local Codex log marked this response as failed."
        )
    }

    /// Adds a tool call summary to the active response or pending summaries.
    private nonisolated static func appendToolSummary(
        _ event: CodexResponseEventRow,
        active: inout CodexResponseDraft?,
        pendingToolSummaries: inout [String]
    ) {
        let name = event.itemName ?? "tool"
        let arguments = event.itemArguments.map { truncate($0, limit: 420) } ?? ""
        let summary = arguments.isEmpty ? "Tool call: \(name)" : "Tool call: \(name)\n\(arguments)"

        if var draft = active {
            draft.toolSummaries.append(summary)
            active = draft
        } else {
            pendingToolSummaries.append(summary)
        }
    }

    /// Adds assistant message text only when it fills an otherwise empty response body.
    private nonisolated static func appendMessageText(
        _ text: String,
        active: inout CodexResponseDraft?,
        pendingOutputText: inout String
    ) {
        if var draft = active {
            if draft.outputText.isEmpty {
                draft.outputText = appendBlock(text, to: draft.outputText)
            }
            active = draft
        } else if pendingOutputText.isEmpty {
            pendingOutputText = appendBlock(text, to: pendingOutputText)
        }
    }
}
