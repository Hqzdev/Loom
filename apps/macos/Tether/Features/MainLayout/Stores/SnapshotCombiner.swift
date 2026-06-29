import Core
import Foundation

extension TraceStore {
    /// Combines proxy and local agent snapshots into one ordered multi-agent timeline.
    func combinedSnapshot(
        proxySnapshot: TraceSnapshot?,
        codexSnapshot: TraceSnapshot?
    ) -> TraceSnapshot? {
        guard let proxySnapshot,
              let codexSnapshot,
              !proxySnapshot.nodes.isEmpty,
              !codexSnapshot.nodes.isEmpty
        else {
            return nil
        }

        let orderedNodes = (proxySnapshot.nodes + codexSnapshot.nodes)
            .sorted { lhs, rhs in
                if lhs.timestamp == rhs.timestamp {
                    return lhs.agentName < rhs.agentName
                }

                return lhs.timestamp < rhs.timestamp
            }
        let maxLatency = max(orderedNodes.map(\.latencyMs).max() ?? 0, 1)
        let nodes = orderedNodes.enumerated().map { index, node in
            node.withLayout(
                depth: index,
                barPercent: max(0.06, min(Double(node.latencyMs) / Double(maxLatency), 1.0))
            )
        }

        return TraceSnapshot(nodes: nodes, staleNodeIds: proxySnapshot.staleNodeIds + codexSnapshot.staleNodeIds)
    }

    /// Builds the sidebar summary for combined multi-agent snapshots.
    func agentSummary(for nodes: [AgentNode]) -> String {
        let agents = orderedAgentNames(from: nodes)
        guard !agents.isEmpty else {
            return "Watching multiple agents"
        }

        return "Watching \(agents.joined(separator: " + "))"
    }

    /// Orders preferred agent names before any unknown local observer names.
    func orderedAgentNames(from nodes: [AgentNode]) -> [String] {
        let names = Set(nodes.map(\.agentName))
        let preferredOrder = ["Local Agent", "Claude Code"]
        let preferredNames = preferredOrder.filter(names.contains)
        let remainingNames = names
            .subtracting(preferredNames)
            .sorted()

        return preferredNames + remainingNames
    }
}

private extension AgentNode {
    /// Returns a copy with layout-only fields replaced for the combined timeline.
    func withLayout(depth: Int, barPercent: Double) -> AgentNode {
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
            traceId: traceId,
            parentSpanId: parentSpanId,
            toolUseIds: toolUseIds,
            contextInputs: contextInputs,
            inputHash: inputHash,
            outputHash: outputHash,
            stale: stale,
            isReplay: isReplay,
            replaySourceId: replaySourceId,
            replayProvider: replayProvider,
            status: status,
            prompt: prompt,
            response: response,
            error: error
        )
    }
}
