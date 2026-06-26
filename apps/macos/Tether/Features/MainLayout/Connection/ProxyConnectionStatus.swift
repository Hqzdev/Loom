import SwiftUI
import UI

/// Current connection mode shown in the sidebar header.
enum ProxyConnectionStatus: Equatable {
    case connecting
    case online
    case observingCodex(String)
    case observingAgents(String)
    case offline(String)

    /// Short status title for the sidebar header.
    var title: String {
        switch self {
        case .connecting:
            return "Local Proxy"
        case .online:
            return "Local Proxy"
        case .observingCodex:
            return "Codex Observer"
        case .observingAgents:
            return "Two Agents"
        case .offline:
            return "Proxy Offline"
        }
    }

    /// Detail text explaining the current capture mode.
    var detail: String {
        switch self {
        case .connecting:
            return "Connecting to 127.0.0.1:8080"
        case .online:
            return "Capturing real agent calls"
        case .observingCodex(let message):
            return message
        case .observingAgents(let message):
            return message
        case .offline(let message):
            return message.isEmpty ? "Start the proxy to capture calls" : message
        }
    }

    /// Accent color used for status iconography.
    func color(_ palette: AgentTracePalette) -> Color {
        switch self {
        case .connecting:
            return palette.amber
        case .online:
            return palette.green
        case .observingCodex, .observingAgents:
            return palette.green
        case .offline:
            return palette.pink
        }
    }
}
