import Foundation

/// Error details attached to a failed agent node.
public struct AgentError: Hashable, Codable, Sendable {
    /// Stable error code from the proxy or local observer.
    public let code: String

    /// Short error message.
    public let message: String

    /// Longer diagnostic detail.
    public let detail: String

    /// Creates an inspector-ready error payload.
    public init(code: String, message: String, detail: String) {
        self.code = code
        self.message = message
        self.detail = detail
    }
}
