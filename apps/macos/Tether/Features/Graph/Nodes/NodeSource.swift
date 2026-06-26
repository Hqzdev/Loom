import Core
import SwiftUI

/// Where a graph node came from: read-only session history, or a live capture.
enum NodeSource: Equatable {
    case history
    case live

    /// Classifies a node by its position in the history-first ordered node array.
    static func of(index: Int, historyCount: Int) -> NodeSource {
        index < historyCount ? .history : .live
    }
}

/// Shared geometry for the two-cluster trace layout. The history cluster sits in
/// the left column; new live calls form a second column offset to its right so
/// the two never overlap or connect.
enum GraphClusterLayout {
    /// Horizontal gap between the right edge of the history column and the live column.
    static let liveClusterGap: CGFloat = 400
    static let graphGroupGap: CGFloat = 260

    /// Automatic canvas origin for the node at `index` in a history-first array.
    ///
    /// With no history (`historyCount == 0`) this collapses to the original
    /// single-column timeline, so the live-only view is unaffected.
    static func defaultPosition(
        index: Int,
        historyCount: Int,
        nodeSize: CGSize,
        inset: CGFloat,
        spacing: CGFloat
    ) -> CGPoint {
        let isHistory = index < historyCount
        let intraClusterIndex = isHistory ? index : index - historyCount
        let liveColumnX = historyCount > 0
            ? inset + nodeSize.width + liveClusterGap
            : inset
        let x = isHistory ? inset : liveColumnX
        let y = inset + CGFloat(intraClusterIndex) * spacing
        return CGPoint(x: x, y: y)
    }

    static func groupIds(for nodes: [AgentNode]) -> [AgentNode.ID: String] {
        var groups: [AgentNode.ID: String] = [:]

        for node in nodes {
            groups[node.id] = node.graphGroupId
        }

        for node in nodes where node.isReplay {
            if let sourceId = node.replaySourceId, let sourceGroupId = groups[sourceId] {
                groups[node.id] = sourceGroupId
            }
        }

        return groups
    }

    static func groupedPosition(
        for node: AgentNode,
        in nodes: [AgentNode],
        groupIds: [AgentNode.ID: String],
        nodeSize: CGSize,
        inset: CGFloat,
        spacing: CGFloat
    ) -> CGPoint {
        let nodeGroupId = groupIds[node.id] ?? node.graphGroupId
        let orderedGroupIds = nodes.reduce(into: [String]()) { result, candidate in
            let groupId = groupIds[candidate.id] ?? candidate.graphGroupId
            if !result.contains(groupId) {
                result.append(groupId)
            }
        }
        let groupIndex = orderedGroupIds.firstIndex(of: nodeGroupId) ?? 0
        let groupNodes = nodes.filter { (groupIds[$0.id] ?? $0.graphGroupId) == nodeGroupId }
        let intraGroupIndex = groupNodes.firstIndex(where: { $0.id == node.id }) ?? 0
        let x = inset + CGFloat(groupIndex) * (nodeSize.width + graphGroupGap)
        let y = inset + CGFloat(intraGroupIndex) * spacing

        return CGPoint(x: x, y: y)
    }
}

private struct NodeSourceKey: EnvironmentKey {
    static let defaultValue: NodeSource = .live
}

extension EnvironmentValues {
    /// The source cluster of the node a card is rendering, for muted history styling.
    var nodeSource: NodeSource {
        get { self[NodeSourceKey.self] }
        set { self[NodeSourceKey.self] = newValue }
    }
}
