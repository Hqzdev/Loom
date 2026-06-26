import Core
import SwiftUI
import UI

struct GraphViewport: View {
    let freeformCanvasPadding: CGFloat = 960
    let panOverscrollPadding: CGFloat = 1_100
    let nodeBoundaryInset: CGFloat = 240
    let minimumCanvasSize = CGSize(width: 4_200, height: 2_800)
    let verticalNodeSpacing: CGFloat = 156

    let nodes: [AgentNode]
    let historyCount: Int
    let selectedNode: AgentNode?
    let nodeSize: CGSize
    let depthSpacing: CGFloat
    let positionStore: GraphNodePositionStore
    @Binding var nodeSizes: [AgentNode.ID: CGSize]
    let zoomScale: CGFloat
    let focusRequest: Int
    let onSelect: (AgentNode) -> Void
    let onZoom: (CGFloat, Bool) -> Void
    let onInteractionChanged: (Bool) -> Void
    let palette: AgentTracePalette

    @Environment(\.graphCanvasInputEnabled) private var inputEnabled
    @EnvironmentObject var preferences: AppPreferences

    @State var panOffset: CGSize = .zero
    @State var activeDragNodeId: AgentNode.ID?
    @State var activeInteraction: ActiveCanvasInteraction?

    var contentSize: CGSize {
        measuredContentSize
    }

    var measuredContentSize: CGSize {
        let movedBounds = nodeBounds
        return CGSize(
            width: max(minimumCanvasSize.width, movedBounds.maxX + freeformCanvasPadding),
            height: max(minimumCanvasSize.height, movedBounds.maxY + freeformCanvasPadding)
        )
    }

    var nodeBounds: CGRect {
        guard !nodes.isEmpty else { return CGRect(origin: .zero, size: nodeSize) }

        return nodes.enumerated().reduce(CGRect.null) { bounds, indexedNode in
            let node = indexedNode.element
            let origin = position(for: node, at: indexedNode.offset)
            let size = nodeSizes[node.id] ?? nodeSize
            return bounds.union(CGRect(origin: origin, size: size))
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(palette.window.opacity(0.44))
                    .contentShape(Rectangle())

                GraphCanvas(
                    nodes: nodes,
                    historyCount: historyCount,
                    selectedNode: selectedNode,
                    nodeSize: nodeSize,
                    contentSize: contentSize,
                    positionStore: positionStore,
                    nodeSizes: nodeSizes,
                    activeDragNodeId: activeDragNodeId,
                    isInteractionActive: activeInteraction != nil,
                    zoomScale: zoomScale,
                    palette: palette
                )
                .offset(panOffset)
            }
            .clipped()
            .coordinateSpace(name: "graphCanvas")
            .contentShape(Rectangle())
            .highPriorityGesture(canvasInteractionGesture(viewportSize: geometry.size))
            .background(
                MacCanvasEventBridge(
                    isEnabled: inputEnabled,
                    onScroll: { delta in panBy(scrollDelta(delta), viewportSize: geometry.size) },
                    onMagnify: { delta in onZoom(zoomScale * max(0.2, 1 + delta * preferences.zoomSensitivity), false) }
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
            )
            .onChange(of: zoomScale) { _, _ in
                panOffset = clampedPan(panOffset, viewportSize: geometry.size)
            }
            .onAppear {
                syncNodePositions()
            }
            .onChange(of: nodes.map(\.id)) { _, _ in
                syncNodePositions()
            }
            .onChange(of: nodes.count) { _, _ in
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    panOffset = clampedPan(panOffset, viewportSize: geometry.size)
                }
            }
            .onChange(of: focusRequest) { _, _ in
                centerSelectedNode(in: geometry.size)
            }
            .onDisappear {
                onInteractionChanged(false)
            }
        }
    }
}
