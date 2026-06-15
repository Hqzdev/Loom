import SwiftUI

/// User-selectable appearance mode for the Tether desktop interface.
public enum AgentTraceThemeMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    /// Stable picker id backed by the raw storage value.
    public var id: String { rawValue }

    /// Human-readable title shown in settings controls.
    public var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    /// Explicit SwiftUI color scheme, or `nil` when the system setting should be inherited.
    public var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    /// Resolves whether the current theme should render with light-mode palette values.
    public func isLight(systemColorScheme: ColorScheme) -> Bool {
        switch self {
        case .system:
            return systemColorScheme == .light
        case .light:
            return true
        case .dark:
            return false
        }
    }
}
