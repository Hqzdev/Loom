import Foundation

/// Prompt text captured for an agent node.
public struct AgentPrompt: Hashable, Codable, Sendable {
    /// System or developer prompt content.
    public let system: String

    /// User prompt content.
    public let user: String

    /// Creates prompt content for inspector display and exports.
    public init(system: String, user: String) {
        self.system = system
        self.user = user
    }
}
