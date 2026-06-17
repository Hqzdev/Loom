import Core
import Foundation

extension CodexLogObserver {
    /// Loads the latest Codex thread and converts its response events into a trace snapshot.
    nonisolated static func loadSnapshot(afterLogId baselineLogId: Int?) throws -> TraceSnapshot? {
        guard CodexDatabase.allDatabasesExist else {
            return nil
        }

        guard let thread = try latestThread(from: CodexDatabase.statePath) else {
            return nil
        }

        let events = try responseEvents(for: thread.id, from: CodexDatabase.logsPath, afterLogId: baselineLogId)
        let nodes = makeNodes(from: events, thread: thread)

        return TraceSnapshot(nodes: nodes)
    }

    /// Returns a compact user-facing title for a Codex thread.
    nonisolated static func title(for thread: CodexThreadRow) -> String {
        let source = thread.title ?? thread.preview ?? thread.firstUserMessage ?? "Codex Terminal Run"
        return truncate(firstLine(source), limit: 86)
    }

    /// Returns the prompt text shown in the inspector for a Codex thread.
    nonisolated static func promptText(for thread: CodexThreadRow) -> String {
        let prompt = thread.preview ?? thread.firstUserMessage ?? thread.title ?? "Terminal Codex run"
        return truncate(prompt.trimmingCharacters(in: .whitespacesAndNewlines), limit: 4_000)
    }
}
