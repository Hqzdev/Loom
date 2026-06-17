import Combine
import Core
import Foundation
import SwiftUI
import UI

/// App-wide, UserDefaults-backed preferences shared across the desktop interface.
///
/// Each property persists immediately on change and publishes updates so any view
/// observing the object reacts live. Provider secrets are never stored here — those
/// remain in the macOS Keychain via `KeychainStore`.
@MainActor
final class AppPreferences: ObservableObject {
    /// Shared instance injected into the SwiftUI environment at the app root.
    static let shared = AppPreferences()

    private let store: UserDefaults

    // MARK: General

    @Published var appearance: AgentTraceThemeMode {
        didSet { store.set(appearance.rawValue, forKey: Key.appearance) }
    }

    @Published var confirmBeforeClearing: Bool {
        didSet { store.set(confirmBeforeClearing, forKey: Key.confirmBeforeClearing) }
    }

    // MARK: Agents

    @Published var captureOpenAI: Bool {
        didSet { store.set(captureOpenAI, forKey: Key.captureOpenAI) }
    }

    @Published var captureAnthropic: Bool {
        didSet { store.set(captureAnthropic, forKey: Key.captureAnthropic) }
    }

    @Published var captureCodex: Bool {
        didSet { store.set(captureCodex, forKey: Key.captureCodex) }
    }

    @Published var autoSelectNewNode: Bool {
        didSet { store.set(autoSelectNewNode, forKey: Key.autoSelectNewNode) }
    }

    @Published var wrapInspectorLines: Bool {
        didSet { store.set(wrapInspectorLines, forKey: Key.wrapInspectorLines) }
    }

    // MARK: Workspace

    @Published var showConnections: Bool {
        didSet { store.set(showConnections, forKey: Key.showConnections) }
    }

    @Published var invertScroll: Bool {
        didSet { store.set(invertScroll, forKey: Key.invertScroll) }
    }

    @Published var snapToGrid: Bool {
        didSet { store.set(snapToGrid, forKey: Key.snapToGrid) }
    }

    @Published var zoomSensitivity: Double {
        didSet { store.set(zoomSensitivity, forKey: Key.zoomSensitivity) }
    }

    // MARK: Privacy

    @Published var redactSecrets: Bool {
        didSet { store.set(redactSecrets, forKey: Key.redactSecrets) }
    }

    /// Number of days to retain trace history. `0` means keep forever.
    @Published var retentionDays: Int {
        didSet { store.set(retentionDays, forKey: Key.retentionDays) }
    }

    // MARK: Extensions

    @Published var codexIntegrationEnabled: Bool {
        didSet { store.set(codexIntegrationEnabled, forKey: Key.codexIntegrationEnabled) }
    }

    /// Optional custom path to the Codex log/database location.
    @Published var codexLogPath: String {
        didSet { store.set(codexLogPath, forKey: Key.codexLogPath) }
    }

    // MARK: Developer

    @Published var verboseLogging: Bool {
        didSet { store.set(verboseLogging, forKey: Key.verboseLogging) }
    }

    /// Loads persisted preferences, falling back to defaults field-by-field.
    init(store: UserDefaults = .standard) {
        self.store = store

        let appearanceRaw = store.string(forKey: Key.appearance) ?? AgentTraceThemeMode.light.rawValue
        appearance = AgentTraceThemeMode(rawValue: appearanceRaw) ?? .light
        confirmBeforeClearing = store.object(forKey: Key.confirmBeforeClearing) as? Bool ?? true

        captureOpenAI = store.object(forKey: Key.captureOpenAI) as? Bool ?? true
        captureAnthropic = store.object(forKey: Key.captureAnthropic) as? Bool ?? true
        captureCodex = store.object(forKey: Key.captureCodex) as? Bool ?? true
        autoSelectNewNode = store.object(forKey: Key.autoSelectNewNode) as? Bool ?? true
        wrapInspectorLines = store.object(forKey: Key.wrapInspectorLines) as? Bool ?? true

        showConnections = store.object(forKey: Key.showConnections) as? Bool ?? true
        invertScroll = store.object(forKey: Key.invertScroll) as? Bool ?? false
        snapToGrid = store.object(forKey: Key.snapToGrid) as? Bool ?? false
        zoomSensitivity = store.object(forKey: Key.zoomSensitivity) as? Double ?? 1.0

        redactSecrets = store.object(forKey: Key.redactSecrets) as? Bool ?? false
        retentionDays = store.object(forKey: Key.retentionDays) as? Int ?? 0

        codexIntegrationEnabled = store.object(forKey: Key.codexIntegrationEnabled) as? Bool ?? true
        codexLogPath = store.string(forKey: Key.codexLogPath) ?? ""

        verboseLogging = store.object(forKey: Key.verboseLogging) as? Bool ?? false
    }

    /// Returns whether a trace node's provider is currently enabled for capture/display.
    ///
    /// Provider is read from the node when available, with legacy fallbacks for
    /// older snapshots that predate explicit provider labels.
    func capturesProvider(of node: AgentNode) -> Bool {
        let provider = node.provider.lowercased()
        if provider == "codex-log" || node.cacheStatus == "codex-log" {
            return captureCodex && codexIntegrationEnabled
        }
        if provider == "anthropic" || node.model.lowercased().contains("claude") {
            return captureAnthropic
        }
        return captureOpenAI
    }

    /// Restores every preference to its default value.
    func resetToDefaults() {
        appearance = .light
        confirmBeforeClearing = true
        captureOpenAI = true
        captureAnthropic = true
        captureCodex = true
        autoSelectNewNode = true
        wrapInspectorLines = true
        showConnections = true
        invertScroll = false
        snapToGrid = false
        zoomSensitivity = 1.0
        redactSecrets = false
        retentionDays = 0
        codexIntegrationEnabled = true
        codexLogPath = ""
        verboseLogging = false
    }

    /// UserDefaults keys, namespaced to avoid collisions with proxy settings.
    private enum Key {
        static let appearance = "tether.pref.appearance"
        static let confirmBeforeClearing = "tether.pref.confirmBeforeClearing"
        static let captureOpenAI = "tether.pref.captureOpenAI"
        static let captureAnthropic = "tether.pref.captureAnthropic"
        static let captureCodex = "tether.pref.captureCodex"
        static let autoSelectNewNode = "tether.pref.autoSelectNewNode"
        static let wrapInspectorLines = "tether.pref.wrapInspectorLines"
        static let showConnections = "tether.pref.showConnections"
        static let invertScroll = "tether.pref.invertScroll"
        static let snapToGrid = "tether.pref.snapToGrid"
        static let zoomSensitivity = "tether.pref.zoomSensitivity"
        static let redactSecrets = "tether.pref.redactSecrets"
        static let retentionDays = "tether.pref.retentionDays"
        static let codexIntegrationEnabled = "tether.pref.codexIntegrationEnabled"
        static let codexLogPath = "tether.pref.codexLogPath"
        static let verboseLogging = "tether.pref.verboseLogging"
    }
}
