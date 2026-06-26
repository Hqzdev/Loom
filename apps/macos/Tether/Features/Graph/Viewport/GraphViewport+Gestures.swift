import Core
import SwiftUI

extension GraphViewport {
    /// Builds the combined node-drag, resize, and canvas-pan gesture.
    func canvasInteractionGesture(viewportSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                beginInteractionIfNeeded(value)
                updateInteraction(value, viewportSize: viewportSize)
            }
            .onEnded { value in
                finishInteraction(value, viewportSize: viewportSize)
            }
    }

    /// Begins the correct interaction based on the initial hit target.
    private func beginInteractionIfNeeded(_ value: DragGesture.Value) {
        guard activeInteraction == nil else { return }

        let contentPt = contentPoint(for: value.startLocation)
        guard let hit = nodeAndIndex(at: contentPt) else {
            activeInteraction = .canvas(startOffset: panOffset)
            onInteractionChanged(true)
            return
        }

        let origin = position(for: hit.node, at: hit.index)
        let size = nodeSizes[hit.node.id] ?? nodeSize

        if contentPt.x >= origin.x + size.width - 20 && contentPt.y >= origin.y + size.height - 20 {
            activeInteraction = .resize(nodeId: hit.node.id, startSize: size)
        } else {
            activeInteraction = .node(nodeId: hit.node.id, startOffset: positionStore.offset(for: hit.node.id), hasMoved: false)
        }
        onInteractionChanged(true)
    }

    /// Applies drag updates to the active interaction.
    private func updateInteraction(_ value: DragGesture.Value, viewportSize: CGSize) {
        switch activeInteraction {
        case let .node(nodeId, startOffset, hasMoved):
            updateNodeDrag(nodeId: nodeId, startOffset: startOffset, hasMoved: hasMoved, translation: value.translation)
        case let .canvas(startOffset):
            panOffset = clampedPan(
                CGSize(width: startOffset.width + value.translation.width, height: startOffset.height + value.translation.height),
                viewportSize: viewportSize
            )
        case let .resize(nodeId, startSize):
            let translation = unscaledTranslation(value.translation)
            nodeSizes[nodeId] = CGSize(width: max(180, startSize.width + translation.width), height: max(80, startSize.height + translation.height))
        case nil:
            break
        }
    }

    /// Commits the active interaction back into durable viewport state.
    private func finishInteraction(_ value: DragGesture.Value, viewportSize: CGSize) {
        defer {
            onInteractionChanged(false)
        }

        switch activeInteraction {
        case let .node(nodeId, startOffset, hasMoved):
            if hasMoved {
                let moved = movedNodeOffset(nodeId: nodeId, startOffset: startOffset, translation: unscaledTranslation(value.translation))
                let snapped = snappedOffset(moved)
                if let indexedNode = nodes.enumerated().first(where: { $0.element.id == nodeId }) {
                    positionStore.commitOffset(snapped, for: nodeId, defaultPosition: defaultPosition(for: indexedNode.element, at: indexedNode.offset))
                }
            } else if let node = nodes.first(where: { $0.id == nodeId }) {
                onSelect(node)
            }
            if let activeDragNodeId {
                positionStore.finishDrag(for: activeDragNodeId)
            }
            activeDragNodeId = nil
            activeInteraction = nil
        case let .canvas(startOffset):
            panOffset = clampedPan(
                CGSize(width: startOffset.width + value.translation.width, height: startOffset.height + value.translation.height),
                viewportSize: viewportSize
            )
            activeInteraction = nil
        case .resize:
            activeInteraction = nil
        case nil:
            break
        }
    }

    /// Updates the transient node drag preview after the movement threshold is crossed.
    private func updateNodeDrag(nodeId: AgentNode.ID, startOffset: CGSize, hasMoved: Bool, translation: CGSize) {
        let translation = unscaledTranslation(translation)
        guard hasMoved || translation.length >= 8 else { return }
        let finalOffset = movedNodeOffset(nodeId: nodeId, startOffset: startOffset, translation: translation)

        if !hasMoved {
            activeInteraction = .node(nodeId: nodeId, startOffset: startOffset, hasMoved: true)
        }

        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            if let indexedNode = nodes.enumerated().first(where: { $0.element.id == nodeId }) {
                activeDragNodeId = nodeId
                positionStore.setLiveOffset(finalOffset, for: nodeId, defaultPosition: defaultPosition(for: indexedNode.element, at: indexedNode.offset))
            }
        }
    }
}
