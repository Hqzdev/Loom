import Foundation

/// Result of editing a node output and invalidating downstream nodes.
public struct TraceInvalidationResult: Codable, Hashable, Sendable {
    public let nodeId: AgentNode.ID
    public let reason: String
    public let previousOutputHash: String
    public let outputHash: String
    public let invalidated: [AgentNode.ID]

    public init(
        nodeId: AgentNode.ID,
        reason: String,
        previousOutputHash: String,
        outputHash: String,
        invalidated: [AgentNode.ID]
    ) {
        self.nodeId = nodeId
        self.reason = reason
        self.previousOutputHash = previousOutputHash
        self.outputHash = outputHash
        self.invalidated = invalidated
    }
}

/// Result of replaying a retained node request upstream.
public struct TraceReplayResult: Codable, Hashable, Sendable {
    public let nodeId: AgentNode.ID
    public let reason: String
    public let previousOutputHash: String
    public let outputHash: String
    public let statusCode: Int
    public let cost: String
    public let tokensIn: Int
    public let tokensOut: Int
    public let invalidated: [AgentNode.ID]

    public init(
        nodeId: AgentNode.ID,
        reason: String,
        previousOutputHash: String,
        outputHash: String,
        statusCode: Int,
        cost: String,
        tokensIn: Int,
        tokensOut: Int,
        invalidated: [AgentNode.ID]
    ) {
        self.nodeId = nodeId
        self.reason = reason
        self.previousOutputHash = previousOutputHash
        self.outputHash = outputHash
        self.statusCode = statusCode
        self.cost = cost
        self.tokensIn = tokensIn
        self.tokensOut = tokensOut
        self.invalidated = invalidated
    }
}

/// Downstream node preview for a potential replay boundary.
public struct TraceDownstreamResult: Codable, Hashable, Sendable {
    public let nodeId: AgentNode.ID
    public let downstream: [AgentNode.ID]
}
