import AppKit
import SwiftUI
import UI

/// Integrations Tether can observe alongside the local proxy.
struct ExtensionsSettingsView: View {
    let palette: AgentTracePalette
    @EnvironmentObject private var preferences: AppPreferences

    /// Local Codex state directory used by the Terminal Codex integration.
    private var codexDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
    }

    private var codexLogsDetected: Bool {
        FileManager.default.fileExists(atPath: codexDirectory.appendingPathComponent("logs_2.sqlite").path)
    }

    var body: some View {
        SettingsPaneScaffold(
            title: "Extensions",
            subtitle: "Connect Tether to other local agent tools running on your Mac.",
            palette: palette
        ) {
            codexSection
        }
    }

    private var codexSection: some View {
        SettingsSection("Terminal Codex", palette: palette) {
            SettingsToggleRow(
                "Enable Codex integration",
                subtitle: "Automatically observe Codex CLI runs from your local databases.",
                isOn: $preferences.codexIntegrationEnabled,
                palette: palette
            )

            SettingsValueRow(
                "Local databases",
                subtitle: codexDirectory.path,
                value: codexLogsDetected ? "Detected" : "Not found",
                palette: palette
            )

            SettingsButtonRow(
                "Codex folder",
                subtitle: "Open the ~/.codex directory Tether reads session logs from.",
                buttonTitle: "Reveal in Finder",
                systemImage: "folder",
                palette: palette
            ) {
                NSWorkspace.shared.activateFileViewerSelecting([codexDirectory])
            }
        }
    }
}
