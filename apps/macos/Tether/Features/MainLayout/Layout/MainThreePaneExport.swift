import Core
import Foundation

extension MainThreePaneLayoutView {
    /// Builds CSV rows with a stable header matching exported trace fields.
    func csvRows(for snapshot: TraceSnapshot) -> [[String]] {
        var rows = [
            [
                "node_id",
                "agent",
                "provider",
                "step",
                "timestamp",
                "model",
                "status",
                "latency_ms",
                "cost",
                "tokens_in",
                "tokens_out",
                "input_hash",
                "output_hash",
                "stale",
                "context_sources",
                "withheld",
                "request_id",
                "prompt",
                "response"
            ]
        ]

        for node in snapshot.nodes {
            rows.append([
                node.id,
                node.agentName,
                node.provider,
                node.stepName,
                node.timestamp,
                node.model,
                node.status.rawValue,
                "\(node.latencyMs)",
                node.cost,
                "\(node.tokensIn)",
                "\(node.tokensOut)",
                node.inputHash,
                node.outputHash,
                node.stale ? "true" : "false",
                "\(node.contextInputs.sources.count)",
                node.contextInputs.withheld.joined(separator: ";"),
                node.requestId,
                node.prompt.user,
                node.response.text
            ])
        }

        return rows
    }

    /// Builds the metadata text block copied from the inspector.
    func metadataClipboardText(for node: AgentNode) -> String {
        """
        id: \(node.id)
        agent: \(node.agentName)
        provider: \(node.provider)
        model: \(node.model)
        requestId: \(node.requestId)
        status: \(node.status.label)
        latency: \(node.latency)
        cost: \(node.cost)
        inputHash: \(node.inputHash)
        outputHash: \(node.outputHash)
        stale: \(node.stale)
        tokensIn: \(node.tokensIn)
        tokensOut: \(node.tokensOut)
        cacheStatus: \(node.cacheStatus)
        """
    }
}
