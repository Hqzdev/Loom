import Networking
import ServiceManagement
import SwiftUI
import UI

struct GeneralSettingsView: View {
    let palette: AgentTracePalette
    @EnvironmentObject private var preferences: AppPreferences

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var statusMessage: String?
    @State private var statusIsError = false

    var body: some View {
        SettingsPaneScaffold(
            title: "General",
            subtitle: "Startup behavior and confirmations for the Tether desktop app.",
            palette: palette
        ) {
            appearanceSection
            startupSection
            behaviorSection

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(statusIsError ? palette.pinkText : palette.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var appearanceSection: some View {
        SettingsSection("Appearance", palette: palette) {
            SettingsValueRow(
                "Theme",
                subtitle: "Tether currently ships with a focused light workspace.",
                value: "Light",
                palette: palette
            )
        }
    }

    private var startupSection: some View {
        SettingsSection("Startup", palette: palette) {
            SettingsToggleRow(
                "Launch at login",
                subtitle: "Open Tether automatically when you sign in to macOS.",
                isOn: $launchAtLogin,
                palette: palette
            )
            .onChange(of: launchAtLogin) { _, newValue in
                applyLaunchAtLogin(newValue)
            }
        }
    }

    private var behaviorSection: some View {
        SettingsSection("Behavior", palette: palette) {
            SettingsToggleRow(
                "Confirm before clearing traces",
                subtitle: "Ask for confirmation before permanently clearing captured traces.",
                isOn: $preferences.confirmBeforeClearing,
                palette: palette
            )
        }
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                statusMessage = "Tether will launch at login."
            } else {
                try SMAppService.mainApp.unregister()
                statusMessage = "Tether will no longer launch at login."
            }
            statusIsError = false
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
