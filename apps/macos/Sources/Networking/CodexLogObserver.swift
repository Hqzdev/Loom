import Core
import Foundation

/// Reads local terminal agent logs and exposes them as Tether trace snapshots.
public actor CodexLogObserver {
    /// Creates an observer for the current user's local log databases.
    public init() {}

    /// Returns the latest local trace snapshot, optionally ignoring events before a watermark.
    public func currentSnapshot(afterLogId baselineLogId: Int? = nil) async throws -> TraceSnapshot? {
        try await Task.detached(priority: .utility) {
            try Self.loadSnapshot(afterLogId: baselineLogId)
        }.value
    }

    /// Returns the latest response log id so clears can hide already-seen local events.
    public func latestResponseEventId() async throws -> Int? {
        try await Task.detached(priority: .utility) {
            guard CodexDatabase.logsExist else {
                return nil
            }

            return try Self.latestResponseLogId(from: CodexDatabase.logsPath)
        }.value
    }
}
