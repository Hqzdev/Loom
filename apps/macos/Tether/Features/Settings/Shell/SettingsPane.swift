import Foundation

enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case shortcuts
    case agents
    case workspace
    case privacy
    case usage
    case proxy
    case extensions
    case developer

    var id: String { rawValue }

    static let settings: [SettingsPane] = [.general, .shortcuts, .agents, .workspace, .privacy, .usage]
    static let desktop: [SettingsPane] = [.proxy, .extensions, .developer]

    var title: String {
        switch self {
        case .general:
            return "General"
        case .shortcuts:
            return "Shortcuts"
        case .agents:
            return "Agents"
        case .workspace:
            return "Workspace"
        case .privacy:
            return "Privacy"
        case .usage:
            return "Usage"
        case .proxy:
            return "Proxy"
        case .extensions:
            return "Extensions"
        case .developer:
            return "Developer"
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            return "gearshape"
        case .shortcuts:
            return "keyboard"
        case .agents:
            return "person.2"
        case .workspace:
            return "rectangle.3.group"
        case .privacy:
            return "lock.shield"
        case .usage:
            return "chart.bar"
        case .proxy:
            return "network"
        case .extensions:
            return "puzzlepiece.extension"
        case .developer:
            return "wrench.and.screwdriver"
        }
    }
}
