import Foundation

/// UI-facing snapshot for visible captured agent nodes.
public struct TraceSnapshot: Codable, Hashable, Sendable {
    /// Ordered nodes that should be rendered in the trace graph.
    public let nodes: [AgentNode]

    /// Node ids marked stale by replay or mocked-output edits.
    public let staleNodeIds: [AgentNode.ID]

    /// Creates a trace snapshot from already-normalized graph nodes.
    public init(
        nodes: [AgentNode],
        staleNodeIds: [AgentNode.ID] = []
    ) {
        self.nodes = nodes
        self.staleNodeIds = staleNodeIds
    }

    enum CodingKeys: String, CodingKey {
        case nodes
        case staleNodeIds
    }

    /// Decodes older snapshots that predate `staleNodeIds`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nodes = try container.decode([AgentNode].self, forKey: .nodes)
        staleNodeIds = try container.decodeIfPresent([AgentNode.ID].self, forKey: .staleNodeIds) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodes, forKey: .nodes)
        try container.encode(staleNodeIds, forKey: .staleNodeIds)
    }
}
