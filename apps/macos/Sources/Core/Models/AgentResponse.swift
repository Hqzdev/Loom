import Foundation

/// Response body captured for an agent node.
public struct AgentResponse: Hashable, Codable, Sendable {
    /// Language used by the inspector renderer.
    public let language: ResponseLanguage

    /// Raw response text.
    public let text: String

    /// Creates response content for inspector display and exports.
    public init(language: ResponseLanguage, text: String) {
        self.language = language
        self.text = text
    }
}
