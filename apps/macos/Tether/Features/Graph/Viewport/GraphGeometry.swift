import Combine
import SwiftUI

/// Stores graph node positions outside the canvas view tree so live drag updates
/// only invalidate the moved node and its live connection overlay.
@MainActor
final class GraphNodePositionStore: ObservableObject {
    private var positions: [String: GraphNodePosition] = [:]

    /// Returns the observable position state for one node, creating it if needed.
    func positionState(for nodeId: String, defaultPosition: CGPoint) -> GraphNodePosition {
        if let position = positions[nodeId] {
            return position
        }

        let position = GraphNodePosition(id: nodeId, basePosition: defaultPosition)
        positions[nodeId] = position
        return position
    }

    /// Keeps position state aligned with the currently visible graph nodes.
    func sync(defaultPositions: [String: CGPoint]) {
        positions = positions.filter { defaultPositions.keys.contains($0.key) }

        for (nodeId, defaultPosition) in defaultPositions {
            positionState(for: nodeId, defaultPosition: defaultPosition)
                .updateBasePosition(defaultPosition)
        }
    }

    /// Drops positions for nodes that disappeared from the trace snapshot.
    func prune(validNodeIds: Set<String>) {
        positions = positions.filter { validNodeIds.contains($0.key) }
    }

    /// Resets every node to its automatic timeline position.
    func reset() {
        for position in positions.values {
            position.reset()
        }
    }

    /// Returns the current canvas origin for one node.
    func position(for nodeId: String, defaultPosition: CGPoint) -> CGPoint {
        positions[nodeId]?.position ?? defaultPosition
    }

    /// Returns the persisted canvas origin for one node, ignoring a live drag.
    func persistedPosition(for nodeId: String, defaultPosition: CGPoint) -> CGPoint {
        positions[nodeId]?.persistedPosition ?? defaultPosition
    }

    /// Returns the current offset from the node's automatic timeline position.
    func offset(for nodeId: String) -> CGSize {
        positions[nodeId]?.currentOffset ?? .zero
    }

    /// Updates the transient drag position for one node.
    func setLiveOffset(_ offset: CGSize, for nodeId: String, defaultPosition: CGPoint) {
        positionState(for: nodeId, defaultPosition: defaultPosition)
            .setLiveOffset(offset)
    }

    /// Commits a drag result so future snapshots keep the user's layout.
    func commitOffset(_ offset: CGSize, for nodeId: String, defaultPosition: CGPoint) {
        positionState(for: nodeId, defaultPosition: defaultPosition)
            .commitOffset(offset)
    }

    /// Clears the transient drag marker without changing the persisted position.
    func finishDrag(for nodeId: String) {
        positions[nodeId]?.finishDrag()
    }
}

/// Per-node observable position state. A drag only publishes changes through the
/// moved node's instance instead of invalidating the whole graph canvas.
@MainActor
final class GraphNodePosition: ObservableObject, Identifiable {
    let id: String

    @Published private(set) var position: CGPoint
    @Published private(set) var isDragging = false

    private var basePosition: CGPoint
    private var persistedOffset: CGSize = .zero
    private var liveOffset: CGSize?

    var persistedPosition: CGPoint {
        basePosition.offset(by: persistedOffset)
    }

    var currentOffset: CGSize {
        liveOffset ?? persistedOffset
    }

    init(id: String, basePosition: CGPoint) {
        self.id = id
        self.basePosition = basePosition
        self.position = basePosition
    }

    /// Updates the automatic timeline origin while preserving user offsets.
    func updateBasePosition(_ basePosition: CGPoint) {
        guard self.basePosition != basePosition else { return }

        self.basePosition = basePosition
        position = basePosition.offset(by: currentOffset)
    }

    /// Applies a live drag offset.
    func setLiveOffset(_ offset: CGSize) {
        liveOffset = offset
        isDragging = true
        position = basePosition.offset(by: offset)
    }

    /// Stores the final drag offset.
    func commitOffset(_ offset: CGSize) {
        persistedOffset = offset
        liveOffset = nil
        isDragging = false
        position = basePosition.offset(by: offset)
    }

    /// Ends drag state without changing the stored offset.
    func finishDrag() {
        liveOffset = nil
        isDragging = false
        position = basePosition.offset(by: persistedOffset)
    }

    /// Clears all manual layout changes.
    func reset() {
        persistedOffset = .zero
        liveOffset = nil
        isDragging = false
        position = basePosition
    }
}

/// Sides used as connection anchors on node cards.
enum NodeAnchorSide: CaseIterable {
    case top
    case bottom
    case left
    case right

    /// Unit direction pointing away from this side.
    var normal: CGSize {
        switch self {
        case .top:
            return CGSize(width: 0, height: -1)
        case .bottom:
            return CGSize(width: 0, height: 1)
        case .left:
            return CGSize(width: -1, height: 0)
        case .right:
            return CGSize(width: 1, height: 0)
        }
    }

    /// Whether this side is top or bottom.
    var isVertical: Bool {
        self == .top || self == .bottom
    }

    /// Returns the point on a node rectangle represented by this side.
    func point(for origin: CGPoint, nodeSize: CGSize) -> CGPoint {
        switch self {
        case .top:
            return CGPoint(x: origin.x + nodeSize.width / 2, y: origin.y)
        case .bottom:
            return CGPoint(x: origin.x + nodeSize.width / 2, y: origin.y + nodeSize.height)
        case .left:
            return CGPoint(x: origin.x, y: origin.y + nodeSize.height / 2)
        case .right:
            return CGPoint(x: origin.x + nodeSize.width, y: origin.y + nodeSize.height / 2)
        }
    }

    /// Returns the marker position within a node card.
    func markerPosition(in size: CGSize) -> CGPoint {
        switch self {
        case .top:
            return CGPoint(x: size.width / 2, y: 0)
        case .bottom:
            return CGPoint(x: size.width / 2, y: size.height)
        case .left:
            return CGPoint(x: 0, y: size.height / 2)
        case .right:
            return CGPoint(x: size.width, y: size.height / 2)
        }
    }
}

/// Concrete source and target anchors for one graph connection.
struct NodeAnchorPair {
    let start: CGPoint
    let end: CGPoint
    let startSide: NodeAnchorSide
    let endSide: NodeAnchorSide
    let distance: CGFloat

    /// Creates an anchor pair directly from concrete points.
    init(start: CGPoint, end: CGPoint, startSide: NodeAnchorSide, endSide: NodeAnchorSide, distance: CGFloat) {
        self.start = start
        self.end = end
        self.startSide = startSide
        self.endSide = endSide
        self.distance = distance
    }

    /// Creates an anchor pair by resolving sides against source and target rectangles.
    init(startSide: NodeAnchorSide, endSide: NodeAnchorSide, sourceOrigin: CGPoint, sourceSize: CGSize, targetOrigin: CGPoint, targetSize: CGSize) {
        let start = startSide.point(for: sourceOrigin, nodeSize: sourceSize)
        let end = endSide.point(for: targetOrigin, nodeSize: targetSize)
        self.init(start: start, end: end, startSide: startSide, endSide: endSide, distance: CGSize(width: end.x - start.x, height: end.y - start.y).length)
    }

    /// Scores readability for this anchor pair; lower is better.
    func score(preferredSides: (start: NodeAnchorSide, end: NodeAnchorSide)) -> CGFloat {
        let delta = CGSize(width: end.x - start.x, height: end.y - start.y)
        let direction = delta.normalized
        let startsAgainstFlow = max(0, -direction.dot(startSide.normal)) * 120
        let endsAgainstFlow = max(0, direction.dot(endSide.normal)) * 120
        let readabilityPenalty: CGFloat = startSide == preferredSides.start && endSide == preferredSides.end ? 0 : 24
        return distance + startsAgainstFlow + endsAgainstFlow + readabilityPenalty
    }
}

extension CGSize {
    /// Euclidean length of the vector.
    var length: CGFloat {
        (width * width + height * height).squareRoot()
    }

    /// Unit vector with a small lower bound to avoid division by zero.
    var normalized: CGSize {
        let safeLength = max(length, 0.001)
        return CGSize(width: width / safeLength, height: height / safeLength)
    }

    /// Dot product with another vector.
    func dot(_ other: CGSize) -> CGFloat {
        width * other.width + height * other.height
    }
}

extension CGPoint {
    /// Center point for a rectangle at this origin.
    func center(in size: CGSize) -> CGPoint {
        CGPoint(x: x + size.width / 2, y: y + size.height / 2)
    }

    /// Offsets this point along a vector by a distance.
    func offset(by direction: CGSize, distance: CGFloat) -> CGPoint {
        CGPoint(x: x + direction.width * distance, y: y + direction.height * distance)
    }

    /// Offsets this point by a size delta.
    func offset(by delta: CGSize) -> CGPoint {
        CGPoint(x: x + delta.width, y: y + delta.height)
    }
}
