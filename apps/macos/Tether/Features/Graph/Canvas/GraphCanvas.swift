import Core
import SwiftUI
import UI

struct GraphCanvas: View {
    private let verticalNodeSpacing: CGFloat = 156
    private let nodeBoundaryInset: CGFloat = 240
    private let historyOpacity: CGFloat = 0.7

    let nodes: [AgentNode]
    let historyCount: Int
    let selectedNode: AgentNode?
    let nodeSize: CGSize
    let contentSize: CGSize
    let positionStore: GraphNodePositionStore
    let nodeSizes: [AgentNode.ID: CGSize]
    let activeDragNodeId: AgentNode.ID?
    let isInteractionActive: Bool
    let zoomScale: CGFloat
    let palette: AgentTracePalette

    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var traceStore: TraceStore

    var body: some View {
        ZStack(alignment: .topLeading) {
            if nodes.isEmpty {
                GraphEmptyState(palette: palette)
                    .frame(width: contentSize.width, height: contentSize.height)
            } else {
                if preferences.showConnections {
                    connectionLayers
                }

                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    let source = NodeSource.of(index: index, historyCount: historyCount)
                    MovableNodeCard(
                        node: NodeCardModel(
                            node: node,
                            replayCostImproved: replayCostImproved(for: node),
                            workSummary: traceStore.nodeWorkSummaries[node.id]
                        ),
                        nodePosition: positionStore.positionState(for: node.id, defaultPosition: defaultPosition(for: index, node: node)),
                        selected: node.id == selectedNode?.id,
                        nodeSize: nodeSizes[node.id] ?? nodeSize,
                        isPerformanceMode: isInteractionActive || source == .history,
                        palette: palette
                    )
                    .equatable()
                    .opacity(source == .history ? historyOpacity : 1)
                    .environment(\.nodeSource, source)
                }
            }
        }
        .frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
        .scaleEffect(zoomScale, anchor: .topLeading)
        .frame(width: contentSize.width * zoomScale, height: contentSize.height * zoomScale, alignment: .topLeading)
    }

    @ViewBuilder
    private var connectionLayers: some View {
        GraphConnections(
            nodes: connectionNodes,
            positions: persistedPositions,
            contentSize: contentSize,
            nodeSizes: nodeSizes,
            defaultNodeSize: nodeSize,
            scope: activeDragNodeId.map { .excluding(nodeId: $0) } ?? .all,
            clusterBoundaryIndex: clusterBoundaryIndex,
            palette: palette
        )
        .equatable()

        if let activeDragNodeId {
            LiveGraphConnections(
                nodes: connectionNodes,
                positionStore: positionStore,
                activePosition: positionStore.positionState(
                    for: activeDragNodeId,
                    defaultPosition: defaultPositions[activeDragNodeId] ?? defaultPosition(for: 0, node: nodes.first)
                ),
                activeNodeId: activeDragNodeId,
                contentSize: contentSize,
                nodeSizes: nodeSizes,
                defaultNodeSize: nodeSize,
                defaultPositions: defaultPositions,
                clusterBoundaryIndex: clusterBoundaryIndex,
                palette: palette
            )
        }
    }

    private var clusterBoundaryIndex: Int? {
        guard historyCount > 0, historyCount < nodes.count else { return nil }
        return historyCount
    }

    private var connectionNodes: [GraphConnectionNode] {
        nodes.map {
            GraphConnectionNode(
                id: $0.id,
                graphGroupId: graphGroupIds[$0.id] ?? $0.graphGroupId,
                status: $0.status,
                isReplay: $0.isReplay,
                replaySourceId: $0.replaySourceId
            )
        }
    }

    private var graphGroupIds: [AgentNode.ID: String] {
        GraphClusterLayout.groupIds(for: nodes)
    }

    private var defaultPositions: [AgentNode.ID: CGPoint] {
        Dictionary(uniqueKeysWithValues: nodes.enumerated().map { index, node in
            (node.id, defaultPosition(for: index, node: node))
        })
    }

    private var persistedPositions: [AgentNode.ID: CGPoint] {
        Dictionary(uniqueKeysWithValues: nodes.enumerated().map { index, node in
            let base = defaultPosition(for: index, node: node)
            return (node.id, positionStore.persistedPosition(for: node.id, defaultPosition: base))
        })
    }

    private func defaultPosition(for index: Int, node: AgentNode?) -> CGPoint {
        if let node,
           node.isReplay,
           let sourceId = node.replaySourceId,
           let sourceNode = nodes.first(where: { $0.id == sourceId }) {
            let source = GraphClusterLayout.groupedPosition(
                for: sourceNode,
                in: nodes,
                groupIds: graphGroupIds,
                nodeSize: nodeSize,
                inset: nodeBoundaryInset,
                spacing: verticalNodeSpacing
            )
            return CGPoint(x: source.x + 400, y: source.y)
        }

        if let node {
            return GraphClusterLayout.groupedPosition(
                for: node,
                in: nodes,
                groupIds: graphGroupIds,
                nodeSize: nodeSize,
                inset: nodeBoundaryInset,
                spacing: verticalNodeSpacing
            )
        }

        return GraphClusterLayout.defaultPosition(
            index: index,
            historyCount: historyCount,
            nodeSize: nodeSize,
            inset: nodeBoundaryInset,
            spacing: verticalNodeSpacing
        )
    }

    private func replayCostImproved(for node: AgentNode) -> Bool {
        guard node.isReplay,
              let sourceId = node.replaySourceId,
              let source = nodes.first(where: { $0.id == sourceId }) else {
            return false
        }
        return costValue(node.cost) < costValue(source.cost)
    }

    private func costValue(_ value: String) -> Double {
        Double(value.trimmingCharacters(in: CharacterSet(charactersIn: "$"))) ?? 0
    }
}

private struct GraphEmptyState: View {
    let palette: AgentTracePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("No traces yet")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.text)

            Text("Run an agent through a source adapter. Execution events will appear here as nodes.")
                .font(.system(size: 12))
                .foregroundStyle(palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Text("tether capture -- <agent command>")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.textSecondary)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(palette.panelSecondary.opacity(0.86), in: RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                        .stroke(palette.borderSoft, lineWidth: 1)
                }
        }
        .padding(14)
        .frame(width: 278, alignment: .leading)
        .background(palette.elevated.opacity(0.72), in: RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous)
                .stroke(palette.borderSoft, lineWidth: 1)
        }
        .shadow(color: palette.liquidShade.opacity(0.10), radius: 10, x: 0, y: 6)
        .position(x: 420, y: 280)
    }
}
