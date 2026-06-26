import Foundation

/// Execution state for a graph node.
public enum NodeStatus: String, Hashable, Codable, Sendable {
    case success
    case cached
    case running
    case error

    /// Uppercase display label for compact badges.
    public var label: String {
        rawValue.uppercased()
    }

    /// SF Symbol name used by status indicators.
    public var symbolName: String {
        switch self {
        case .success:
            return "lightbulb.fill"
        case .cached:
            return "externaldrive.fill"
        case .running:
            return "dot.radiowaves.left.and.right"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}
