import Core
import SwiftUI
import UI

/// Center pane that renders the draggable trace graph and its summary metrics.
struct GraphPane: View {
    private let nodeSize = CGSize(width: 320, height: 112)
    private let depthSpacing: CGFloat = 380
    private let zoomRange: ClosedRange<CGFloat> = 0.5...1.8

    let nodes: [AgentNode]
    /// Leading history nodes within `nodes`; the rest are the live cluster.
    let historyCount: Int
    let selectedNode: AgentNode?
    let totalLatencyMs: Int
    let onSelect: (AgentNode) -> Void
    let onInteractionChanged: (Bool) -> Void
    let palette: AgentTracePalette

    @StateObject private var nodePositionStore = GraphNodePositionStore()
    @State private var nodeSizes: [AgentNode.ID: CGSize] = [:]
    @State private var zoomScale: CGFloat = 1

    private var statusText: String {
        guard !nodes.isEmpty else { return "IDLE" }
        if nodes.contains(where: { $0.status == .running }) { return "LIVE" }
        return nodes.contains(where: { $0.status == .error }) ? "FAILED" : "OK"
    }

    private var statusColor: Color {
        statusText == "FAILED" ? palette.pink : statusText == "LIVE" ? palette.amber : statusText == "OK" ? palette.green : palette.textTertiary
    }

    private var agentCountText: String {
        "\(Set(nodes.map(\.agentName)).count)"
    }

    private var headerContext: String {
        let nodeTitle = selectedNode?.stepName ?? "Waiting for calls"
        return "Live trace · \(nodeTitle)"
    }

    var body: some View {
        VStack(spacing: 0) {
            GraphPaneHeader(
                context: headerContext,
                title: selectedNode?.stepName ?? "Trace timeline",
                totalLatency: formatLatency(totalLatencyMs),
                stepCount: nodes.count,
                agentCount: agentCountText,
                statusText: statusText,
                statusColor: statusColor,
                palette: palette
            )

            GraphViewport(
                nodes: nodes,
                historyCount: historyCount,
                selectedNode: selectedNode,
                nodeSize: nodeSize,
                depthSpacing: depthSpacing,
                positionStore: nodePositionStore,
                nodeSizes: $nodeSizes,
                zoomScale: zoomScale,
                onSelect: onSelect,
                onZoom: { value, animated in setZoom(value, animated: animated) },
                onInteractionChanged: onInteractionChanged,
                palette: palette
            )
            .overlay(alignment: .bottomTrailing) {
                ZoomControls(
                    zoomScale: $zoomScale,
                    zoomRange: zoomRange,
                    onReset: { setZoom(1) },
                    palette: palette
                )
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
        .background(palette.window.opacity(0.48))
        .onChange(of: nodes.map(\.id)) { _, ids in
            nodePositionStore.prune(validNodeIds: Set(ids))
            nodeSizes = nodeSizes.filter { ids.contains($0.key) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceResetGraphLayout)) { _ in
            withAnimation(.smooth(duration: 0.2)) {
                nodePositionStore.reset()
                nodeSizes = [:]
            }
            setZoom(1)
        }
    }

    /// Formats latency for the graph header metric.
    private func formatLatency(_ milliseconds: Int) -> String {
        if milliseconds >= 1000 {
            return String(format: "%.2fs", Double(milliseconds) / 1000.0)
        }

        return "\(milliseconds)ms"
    }

    /// Updates graph zoom while clamping it to the supported range.
    private func setZoom(_ value: CGFloat, animated: Bool = true) {
        let clampedValue = min(max(value, zoomRange.lowerBound), zoomRange.upperBound)

        if animated {
            withAnimation(.smooth(duration: 0.16)) {
                zoomScale = clampedValue
            }
        } else {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                zoomScale = clampedValue
            }
        }
    }
}
