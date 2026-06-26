import Core
import SwiftUI
import UI

/// Draws animated rounded bottom-to-top paths between graph node cards.
struct GraphConnections: View, Equatable {
    let nodes: [GraphConnectionNode]
    let positions: [AgentNode.ID: CGPoint]
    let contentSize: CGSize
    let nodeSizes: [AgentNode.ID: CGSize]
    let defaultNodeSize: CGSize
    let scope: GraphConnectionScope
    /// Index of the first live node; the edge into it from history is not drawn.
    var clusterBoundaryIndex: Int?
    let palette: AgentTracePalette

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, _ in
                guard nodes.count > 1 else { return }

                let dashPhase = dashPhase(at: timeline.date)
                for index in 1..<nodes.count {
                    drawConnection(at: index, dashPhase: dashPhase, in: context)
                }
            }
        }
        .frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    /// Draws one edge from the previous node to the current node.
    private func drawConnection(at index: Int, dashPhase: CGFloat, in context: GraphicsContext) {
        // Never bridge the history cluster and the live cluster.
        if clusterBoundaryIndex == index {
            return
        }

        let current = nodes[index]
        let previous = replaySource(for: current) ?? nodes[index - 1]

        guard previous.graphGroupId == current.graphGroupId else {
            return
        }

        guard scope.includes(previousId: previous.id, currentId: current.id) else {
            return
        }

        guard let from = positions[previous.id], let to = positions[current.id] else {
            return
        }

        let fromSize = nodeSizes[previous.id] ?? defaultNodeSize
        let toSize = nodeSizes[current.id] ?? defaultNodeSize
        let anchors = current.isReplay
            ? horizontalAnchorPair(from: from, sourceSize: fromSize, to: to, targetSize: toSize)
            : verticalAnchorPair(from: from, sourceSize: fromSize, to: to, targetSize: toSize)

        let path = current.isReplay
            ? roundedHorizontalPath(from: anchors.start, to: anchors.end)
            : roundedVerticalPath(from: anchors.start, to: anchors.end)

        let edgeColor = current.isReplay ? palette.violet : palette.color(for: current.status)
        context.stroke(path, with: .color(edgeColor.opacity(0.20)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        context.stroke(
            path,
            with: .color(edgeColor.opacity(0.92)),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: current.isReplay ? [4, 8] : [9, 15], dashPhase: dashPhase)
        )
        drawEndpoint(at: anchors.end, color: edgeColor, in: context)
    }

    private func replaySource(for node: GraphConnectionNode) -> GraphConnectionNode? {
        guard node.isReplay, let sourceId = node.replaySourceId else { return nil }
        return nodes.first { $0.id == sourceId }
    }

    /// Negative phase moves the dash train forward along the path direction.
    private func dashPhase(at date: Date) -> CGFloat {
        -CGFloat(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2)) * 48
    }

    /// Draws the circular endpoint marker for an edge.
    private func drawEndpoint(at point: CGPoint, color: Color, in context: GraphicsContext) {
        let marker = Path(ellipseIn: CGRect(x: point.x - 5.5, y: point.y - 5.5, width: 11, height: 11))
        context.fill(marker, with: .color(palette.window))
        context.stroke(marker, with: .color(color), lineWidth: 2)
    }

    /// Resolves the fixed bottom-to-top anchor pair for a sequential path.
    private func verticalAnchorPair(from sourceOrigin: CGPoint, sourceSize: CGSize, to targetOrigin: CGPoint, targetSize: CGSize) -> NodeAnchorPair {
        NodeAnchorPair(
            startSide: .bottom,
            endSide: .top,
            sourceOrigin: sourceOrigin,
            sourceSize: sourceSize,
            targetOrigin: targetOrigin,
            targetSize: targetSize
        )
    }

    private func horizontalAnchorPair(from sourceOrigin: CGPoint, sourceSize: CGSize, to targetOrigin: CGPoint, targetSize: CGSize) -> NodeAnchorPair {
        NodeAnchorPair(
            startSide: .right,
            endSide: .left,
            sourceOrigin: sourceOrigin,
            sourceSize: sourceSize,
            targetOrigin: targetOrigin,
            targetSize: targetSize
        )
    }

    /// Builds a smooth bottom-to-top curve without hard elbows.
    private func roundedVerticalPath(from start: CGPoint, to end: CGPoint) -> Path {
        let verticalDistance = abs(end.y - start.y)
        let direction: CGFloat = end.y >= start.y ? 1 : -1
        let controlDistance = max(42, min(180, verticalDistance * 0.56))
        var path = Path()
        path.move(to: start)
        path.addCurve(
            to: end,
            control1: CGPoint(x: start.x, y: start.y + controlDistance * direction),
            control2: CGPoint(x: end.x, y: end.y - controlDistance * direction)
        )
        return path
    }

    private func roundedHorizontalPath(from start: CGPoint, to end: CGPoint) -> Path {
        let horizontalDistance = abs(end.x - start.x)
        let direction: CGFloat = end.x >= start.x ? 1 : -1
        let controlDistance = max(60, min(180, horizontalDistance * 0.48))
        var path = Path()
        path.move(to: start)
        path.addCurve(
            to: end,
            control1: CGPoint(x: start.x + controlDistance * direction, y: start.y),
            control2: CGPoint(x: end.x - controlDistance * direction, y: end.y)
        )
        return path
    }
}

/// Redraws only the connection edges touching the active dragged node.
struct LiveGraphConnections: View {
    let nodes: [GraphConnectionNode]
    let positionStore: GraphNodePositionStore
    @ObservedObject var activePosition: GraphNodePosition
    let activeNodeId: AgentNode.ID
    let contentSize: CGSize
    let nodeSizes: [AgentNode.ID: CGSize]
    let defaultNodeSize: CGSize
    let defaultPositions: [AgentNode.ID: CGPoint]
    var clusterBoundaryIndex: Int?
    let palette: AgentTracePalette

    var body: some View {
        GraphConnections(
            nodes: nodes,
            positions: currentPositions,
            contentSize: contentSize,
            nodeSizes: nodeSizes,
            defaultNodeSize: defaultNodeSize,
            scope: .only(nodeId: activeNodeId),
            clusterBoundaryIndex: clusterBoundaryIndex,
            palette: palette
        )
    }

    private var currentPositions: [AgentNode.ID: CGPoint] {
        Dictionary(uniqueKeysWithValues: nodes.map { node in
            let defaultPosition = defaultPositions[node.id] ?? .zero
            let position = node.id == activePosition.id
                ? activePosition.position
                : positionStore.persistedPosition(for: node.id, defaultPosition: defaultPosition)
            return (node.id, position)
        })
    }
}
