import Core
import SwiftUI

extension GraphViewport {
    /// Applies the user's invert-scroll preference to a raw scroll delta.
    func scrollDelta(_ delta: CGSize) -> CGSize {
        guard preferences.invertScroll else { return delta }
        return CGSize(width: -delta.width, height: -delta.height)
    }

    /// Rounds a node offset to the snap grid when snap-to-grid is enabled.
    func snappedOffset(_ offset: CGSize) -> CGSize {
        guard preferences.snapToGrid else { return offset }
        let grid: CGFloat = 24
        return CGSize(
            width: (offset.width / grid).rounded() * grid,
            height: (offset.height / grid).rounded() * grid
        )
    }

    /// Applies trackpad or mouse-wheel panning inside the viewport bounds.
    func panBy(_ delta: CGSize, viewportSize: CGSize) {
        panOffset = clampedPan(
            CGSize(width: panOffset.width + delta.width, height: panOffset.height + delta.height),
            viewportSize: viewportSize
        )
    }

    func centerSelectedNode(in viewportSize: CGSize) {
        guard let selectedNode, let index = nodes.firstIndex(where: { $0.id == selectedNode.id }) else { return }

        let origin = position(for: selectedNode, at: index)
        let size = nodeSizes[selectedNode.id] ?? nodeSize
        let center = CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
        let target = CGSize(
            width: viewportSize.width / 2 - center.x * zoomScale,
            height: viewportSize.height / 2 - center.y * zoomScale
        )

        withAnimation(.smooth(duration: 0.22)) {
            panOffset = clampedPan(target, viewportSize: viewportSize)
        }
    }

    func clampedPan(_ offset: CGSize, viewportSize: CGSize) -> CGSize {
        let bounds = nodeBounds.isNull ? CGRect(origin: .zero, size: contentSize) : nodeBounds
        let minimumX = min(0, viewportSize.width - bounds.maxX * zoomScale - panOverscrollPadding)
        let minimumY = min(0, viewportSize.height - bounds.maxY * zoomScale - panOverscrollPadding)
        let maximumX = max(panOverscrollPadding, -bounds.minX * zoomScale + panOverscrollPadding)
        let maximumY = max(panOverscrollPadding, -bounds.minY * zoomScale + panOverscrollPadding)

        return CGSize(width: min(max(offset.width, minimumX), maximumX), height: min(max(offset.height, minimumY), maximumY))
    }

    /// Converts a viewport coordinate into unscaled canvas coordinates.
    func contentPoint(for viewportPoint: CGPoint) -> CGPoint {
        let safeZoomScale = max(zoomScale, 0.01)
        return CGPoint(x: (viewportPoint.x - panOffset.width) / safeZoomScale, y: (viewportPoint.y - panOffset.height) / safeZoomScale)
    }

    /// Finds the topmost node containing a canvas coordinate.
    func nodeAndIndex(at contentPoint: CGPoint) -> (node: AgentNode, index: Int)? {
        for indexedNode in Array(nodes.enumerated()).reversed() {
            let node = indexedNode.element
            let origin = position(for: node, at: indexedNode.offset)
            let size = nodeSizes[node.id] ?? nodeSize
            let rect = CGRect(origin: origin, size: size).insetBy(dx: -6, dy: -6)

            if rect.contains(contentPoint) {
                return (node, indexedNode.offset)
            }
        }

        return nil
    }

    /// Returns a node's current canvas origin after persisted and active offsets.
    func position(for node: AgentNode, at index: Int) -> CGPoint {
        positionStore.position(for: node.id, defaultPosition: defaultPosition(for: node, at: index))
    }

    /// Returns the automatic timeline position for a node, splitting the history
    /// cluster (left) from the offset live cluster (right).
    func defaultPosition(for node: AgentNode, at index: Int) -> CGPoint {
        if node.isReplay,
           let sourceId = node.replaySourceId,
           let sourceNode = nodes.first(where: { $0.id == sourceId }) {
            let source = GraphClusterLayout.groupedPosition(
                for: sourceNode,
                in: nodes,
                groupIds: GraphClusterLayout.groupIds(for: nodes),
                nodeSize: nodeSize,
                inset: nodeBoundaryInset,
                spacing: verticalNodeSpacing
            )
            return CGPoint(x: source.x + 400, y: source.y)
        }

        return GraphClusterLayout.groupedPosition(
            for: node,
            in: nodes,
            groupIds: GraphClusterLayout.groupIds(for: nodes),
            nodeSize: nodeSize,
            inset: nodeBoundaryInset,
            spacing: verticalNodeSpacing
        )
    }

    /// Converts screen-space drag translation into canvas-space movement.
    func unscaledTranslation(_ translation: CGSize) -> CGSize {
        let safeZoomScale = max(zoomScale, 0.01)
        return CGSize(width: translation.width / safeZoomScale, height: translation.height / safeZoomScale)
    }

    func movedNodeOffset(nodeId: AgentNode.ID, startOffset: CGSize, translation: CGSize) -> CGSize {
        CGSize(width: startOffset.width + translation.width, height: startOffset.height + translation.height)
    }

    /// Synchronizes the external position store with the current visible nodes.
    func syncNodePositions() {
        positionStore.sync(
            defaultPositions: Dictionary(uniqueKeysWithValues: nodes.enumerated().map { index, node in
                (node.id, defaultPosition(for: node, at: index))
            })
        )
    }
}

/// Current canvas gesture interaction.
enum ActiveCanvasInteraction {
    case node(nodeId: AgentNode.ID, startOffset: CGSize, hasMoved: Bool)
    case canvas(startOffset: CGSize)
    case resize(nodeId: AgentNode.ID, startSize: CGSize)
}
