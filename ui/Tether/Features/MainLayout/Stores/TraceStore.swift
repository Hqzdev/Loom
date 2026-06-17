import Combine
import Core
import Networking
import SwiftUI
import UI

/// Main-actor state owner for the trace graph. It polls the single live trace
/// stream and combines proxy captures with local Codex observations.
@MainActor
final class TraceStore: ObservableObject {
    /// Calls captured in the current live trace stream.
    @Published var nodes: [AgentNode] = []

    @Published var proxyStatus: ProxyConnectionStatus = .connecting

    let client: TraceAPIClient
    let codexObserver: CodexLogObserver
    var pollingTask: Task<Void, Never>?
    var codexBaselineLogId: Int?
    var graphInteractionActive = false
    var refreshAfterInteraction = false
    var deferredSnapshot: TraceSnapshot?
    var nodeDetails: [AgentNode.ID: AgentNode] = [:]
    var loadingNodeDetailIds: Set<AgentNode.ID> = []

    /// Creates a store backed by the local proxy client and Codex log observer.
    init(
        client: TraceAPIClient? = nil,
        codexObserver: CodexLogObserver = CodexLogObserver()
    ) {
        self.client = client ?? TraceAPIClient()
        self.codexObserver = codexObserver
    }

    /// Starts the periodic refresh loop if it is not already running.
    func startPolling() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                if self.graphInteractionActive {
                    self.refreshAfterInteraction = true
                    do {
                        try await Task.sleep(for: .milliseconds(180))
                    } catch {
                        break
                    }
                    continue
                }

                await refresh()

                do {
                    try await Task.sleep(for: .seconds(1.2))
                } catch {
                    break
                }
            }
        }
    }

    /// Stops the periodic refresh loop.
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Refreshes the combined live proxy + Codex stream.
    func refresh() async {
        guard !graphInteractionActive else {
            refreshAfterInteraction = true
            return
        }

        await refreshLive()
    }

    /// Polls the live view, combining the proxy trace stream with local Codex events.
    private func refreshLive() async {
        async let codexResult = loadCodexSnapshot()
        let proxyResult = await loadProxySnapshot()
        let codex = await codexResult
        guard !shouldDeferRefreshResult() else { return }

        let proxySnapshot = try? proxyResult.get()
        let codexSnapshot = try? codex.get()
        let proxyError: Error? = {
            if case .failure(let error) = proxyResult { return error }
            return nil
        }()

        if let combinedSnapshot = combinedSnapshot(
            proxySnapshot: proxySnapshot,
            codexSnapshot: codexSnapshot
        ) {
            apply(snapshot: combinedSnapshot)
            proxyStatus = .observingAgents(agentSummary(for: combinedSnapshot.nodes))
            return
        }

        if let proxySnapshot, !proxySnapshot.nodes.isEmpty {
            apply(snapshot: proxySnapshot)
            proxyStatus = .online
            return
        }

        if let codexSnapshot, !codexSnapshot.nodes.isEmpty {
            apply(snapshot: codexSnapshot)
            proxyStatus = .observingCodex("Watching Terminal Codex automatically")
            return
        }

        if let proxySnapshot {
            apply(snapshot: proxySnapshot)
            proxyStatus = .online
            return
        }

        if let codexSnapshot {
            apply(snapshot: codexSnapshot)
            proxyStatus = .observingCodex("Open Terminal and run codex")
            return
        }

        proxyStatus = .offline(proxyError?.localizedDescription ?? "Start the proxy or run codex in Terminal")
    }

    /// Applies a snapshot to the currently visible graph.
    func apply(snapshot: TraceSnapshot) {
        guard !graphInteractionActive else {
            deferredSnapshot = snapshot
            return
        }

        commit(snapshot: snapshot)
    }

    /// Marks graph gestures so refreshes do not invalidate SwiftUI during drag or pan.
    func setGraphInteractionActive(_ isActive: Bool) {
        guard graphInteractionActive != isActive else { return }

        graphInteractionActive = isActive

        guard !isActive else { return }

        flushDeferredTraceUpdates()

        if refreshAfterInteraction {
            refreshAfterInteraction = false
            Task { [weak self] in
                await self?.refresh()
            }
        }
    }

    /// Applies buffered updates once the current graph gesture ends.
    func flushDeferredTraceUpdates() {
        if let snapshot = deferredSnapshot {
            deferredSnapshot = nil
            commit(snapshot: snapshot)
        }
    }

    /// Commits a snapshot. Only writes when visible state changes.
    func commit(snapshot: TraceSnapshot) {
        let liveCluster = snapshot.nodes.map(hydrated(_:))

        guard nodes != liveCluster else {
            return
        }

        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            nodes = liveCluster
        }
    }

    /// Attaches any lazily loaded inspector payload to a graph summary node.
    private func hydrated(_ node: AgentNode) -> AgentNode {
        guard let detail = nodeDetails[node.id] else { return node }
        return node.hydrated(with: detail)
    }

    /// Drops buffered live updates after an explicit clear or trace reset.
    func resetDeferredTraceUpdates() {
        deferredSnapshot = nil
        refreshAfterInteraction = false
        nodeDetails = [:]
        loadingNodeDetailIds = []
    }

    /// Returns true when an in-flight refresh should yield to active graph input.
    func shouldDeferRefreshResult() -> Bool {
        guard graphInteractionActive else { return false }

        refreshAfterInteraction = true
        return true
    }

    /// Lazily hydrates prompt/response/error payloads for the selected proxy node.
    func loadNodeDetailIfNeeded(_ nodeId: AgentNode.ID) async {
        guard let node = nodes.first(where: { $0.id == nodeId }),
              node.needsDetailPayload,
              nodeDetails[nodeId] == nil,
              !loadingNodeDetailIds.contains(nodeId)
        else {
            return
        }

        loadingNodeDetailIds.insert(nodeId)
        defer {
            loadingNodeDetailIds.remove(nodeId)
        }

        do {
            let detail = try await client.traceNodeDetail(nodeId: nodeId)
            nodeDetails[nodeId] = detail
            hydrateVisibleNode(nodeId, with: detail)
        } catch {
            // Local Codex nodes and stale proxy selections may not have proxy-side details.
        }
    }

    /// Replaces a node in whichever cluster currently holds it with its hydrated form.
    private func hydrateVisibleNode(_ nodeId: AgentNode.ID, with detail: AgentNode) {
        if let index = nodes.firstIndex(where: { $0.id == nodeId }) {
            let hydratedNode = nodes[index].hydrated(with: detail)
            if nodes[index] != hydratedNode {
                nodes[index] = hydratedNode
            }
        }

    }

    /// Hydrates every currently visible summary node before full-fidelity export.
    func loadVisibleNodeDetailsIfNeeded() async {
        let nodeIds = nodes
            .filter(\.needsDetailPayload)
            .map(\.id)

        for nodeId in nodeIds {
            await loadNodeDetailIfNeeded(nodeId)
        }
    }
}

extension AgentNode {
    /// Summary payloads intentionally omit inspector-only text fields.
    var needsDetailPayload: Bool {
        cacheStatus != "codex-log"
            && prompt.system.isEmpty
            && prompt.user.isEmpty
            && response.text.isEmpty
    }

    /// Preserves fresh graph summary fields while attaching inspector payloads.
    func hydrated(with detail: AgentNode) -> AgentNode {
        AgentNode(
            id: id,
            agentName: agentName,
            depth: depth,
            stepName: stepName,
            timestamp: timestamp,
            provider: provider,
            model: model,
            cost: cost,
            latency: latency,
            latencyMs: latencyMs,
            barPercent: barPercent,
            tokensIn: tokensIn,
            tokensOut: tokensOut,
            requestId: requestId,
            cacheStatus: cacheStatus,
            temperature: temperature,
            traceId: detail.traceId.isEmpty ? traceId : detail.traceId,
            parentSpanId: detail.parentSpanId ?? parentSpanId,
            toolUseIds: detail.toolUseIds.isEmpty ? toolUseIds : detail.toolUseIds,
            contextInputs: detail.contextInputs.sources.isEmpty && detail.contextInputs.withheld.isEmpty ? contextInputs : detail.contextInputs,
            inputHash: detail.inputHash.isEmpty ? inputHash : detail.inputHash,
            outputHash: detail.outputHash.isEmpty ? outputHash : detail.outputHash,
            stale: stale || detail.stale,
            status: status,
            prompt: detail.prompt,
            response: detail.response,
            error: detail.error
        )
    }
}
