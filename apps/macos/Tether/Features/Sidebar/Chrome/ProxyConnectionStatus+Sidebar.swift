import SwiftUI
import UI

extension ProxyConnectionStatus {
    /// SF Symbol shown in the sidebar status header.
    var symbolName: String {
        switch self {
        case .connecting:
            return "arrow.triangle.2.circlepath"
        case .online:
            return "checkmark.circle.fill"
        case .observingCodex:
            return "terminal.fill"
        case .observingAgents:
            return "rectangle.2.swap"
        case .offline:
            return "exclamationmark.triangle.fill"
        }
    }

    /// Background tint used by the sidebar status card.
    func backgroundTint(_ palette: AgentTracePalette) -> Color {
        switch self {
        case .connecting:
            return palette.amber.opacity(0.10)
        case .online:
            return palette.green.opacity(0.12)
        case .observingCodex, .observingAgents:
            return palette.green.opacity(0.12)
        case .offline:
            return palette.glassTint
        }
    }
}
