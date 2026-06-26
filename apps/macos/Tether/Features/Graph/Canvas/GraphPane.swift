import Core
import SwiftUI
import UI

struct GraphPane: View {
    private let nodeSize = CGSize(width: 336, height: 136)
    private let depthSpacing: CGFloat = 380
    private let zoomRange: ClosedRange<CGFloat> = 0.5...1.8

    let nodes: [AgentNode]
    let historyCount: Int
    let selectedNode: AgentNode?
    let totalLatencyMs: Int
    let focusRequest: Int
    let onSelect: (AgentNode) -> Void
    let onCopyFailureAnalysisPrompt: () -> Void
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
        nodes.isEmpty ? "Waiting for calls" : "Live trace"
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
                onCopyFailureAnalysisPrompt: onCopyFailureAnalysisPrompt,
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
                focusRequest: focusRequest,
                onSelect: onSelect,
                onZoom: { value, animated in setZoom(value, animated: animated) },
                onInteractionChanged: onInteractionChanged,
                palette: palette
            )
            .overlay(alignment: .bottomTrailing) {
                if !nodes.isEmpty {
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

    private func formatLatency(_ milliseconds: Int) -> String {
        if milliseconds >= 1000 {
            return String(format: "%.2fs", Double(milliseconds) / 1000.0)
        }

        return "\(milliseconds)ms"
    }

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
