import Core
import Foundation
import Networking

extension TraceStore {
    /// Clears every proxy trace and hides already-observed local agent events.
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

    /// Loads the local agent snapshot without failing the proxy refresh path.
    func loadCodexSnapshot() async -> Result<TraceSnapshot?, Error> {
        do {
            return .success(try await codexObserver.currentSnapshot(afterLogId: codexBaselineLogId))
        } catch {
            return .failure(error)
        }
    }

    /// Replays the stored request for `node` through CometAPI using `model`.
    func replayWithModel(_ node: AgentNode, _ model: String) async throws -> ReplayResult {
        try await CometAPIClient.replayWithModel(traceId: node.id, model: model)
    }

    /// Clears proxy traces and hides previously observed local agent events until new
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
            proxyStatus = .observingCodex("Open Terminal and run an agent command")
        }
    }
}
