import AppKit
import Networking
import SwiftUI
import UI

/// Developer and diagnostics tools for the desktop app.
struct DeveloperSettingsView: View {
    let palette: AgentTracePalette
    @EnvironmentObject private var preferences: AppPreferences

    @State private var statusMessage: String?
    @State private var statusIsError = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        SettingsPaneScaffold(
            title: "Developer",
            subtitle: "Diagnostics, logging, and tools for troubleshooting Tether.",
            palette: palette
        ) {
            loggingSection
            proxySection
            maintenanceSection
            aboutSection

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(statusIsError ? palette.pinkText : palette.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var loggingSection: some View {
        SettingsSection("Logging", palette: palette) {
            SettingsToggleRow(
                "Verbose logging",
                subtitle: "Write detailed diagnostics to the console for bug reports.",
                isOn: $preferences.verboseLogging,
                palette: palette
            )
        }
    }

    private var proxySection: some View {
        SettingsSection("Local proxy", palette: palette) {
            SettingsButtonRow(
                "Restart proxy",
                subtitle: "Relaunch the local proxy helper to apply changes or recover from errors.",
                buttonTitle: "Restart",
                systemImage: "arrow.clockwise",
                palette: palette
            ) {
                LocalProxyLauncher.shared.restart()
                statusMessage = "Local proxy restart requested."
                statusIsError = false
            }
        }
    }

    private var maintenanceSection: some View {
        SettingsSection("Maintenance", palette: palette) {
            SettingsButtonRow(
                "Application support folder",
                subtitle: "Open the directory where Tether stores local data.",
                buttonTitle: "Reveal in Finder",
                systemImage: "folder",
                palette: palette
            ) {
                revealApplicationSupport()
            }

            SettingsButtonRow(
                "Reset all preferences",
                subtitle: "Restore every Tether setting on this pane and others to its default.",
                buttonTitle: "Reset",
                systemImage: "arrow.counterclockwise",
                destructive: true,
                palette: palette
            ) {
                preferences.resetToDefaults()
                statusMessage = "All preferences were reset to defaults."
                statusIsError = false
            }
        }
    }

    private var aboutSection: some View {
        SettingsSection("About", palette: palette) {
            SettingsValueRow("Version", value: appVersion, palette: palette)
            SettingsValueRow("Build", value: buildNumber, palette: palette)
        }
    }

    /// Opens the user's Application Support directory in Finder.
    private func revealApplicationSupport() {
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            statusMessage = "Could not locate the Application Support directory."
            statusIsError = true
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
