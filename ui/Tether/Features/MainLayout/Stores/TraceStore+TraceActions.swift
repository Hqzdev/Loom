import Core
import Foundation
import Networking

extension TraceStore {
    /// Clears every proxy trace and hides already-observed Codex events.
    func clearTrace() {
        Task {
            await clearAllTraces()
        }
    }

    /// Requests a manual refresh from menu commands.
    func reload() {
        Task {
            await refresh()
        }
    }

    /// Loads a proxy trace snapshot without throwing through async-let boundaries.
    func loadProxySnapshot() async -> Result<TraceSnapshot, Error> {
        do {
            return .success(try await client.currentTraceSummary())
        } catch {
            return .failure(error)
        }
    }

    /// Loads the local Codex snapshot without failing the proxy refresh path.
    func loadCodexSnapshot() async -> Result<TraceSnapshot?, Error> {
        do {
            return .success(try await codexObserver.currentSnapshot(afterLogId: codexBaselineLogId))
        } catch {
            return .failure(error)
        }
    }

    /// Clears proxy traces and hides previously observed Codex events until new
    /// activity arrives.
    func clearAllTraces() async {
        codexBaselineLogId = try? await codexObserver.latestResponseEventId()
        resetDeferredTraceUpdates()
        nodes = []

        do {
            try await client.clearTrace()
            proxyStatus = .online
            await refresh()
        } catch {
            proxyStatus = .observingCodex("Open Terminal and run codex")
        }
    }
}
