import Networking
import ServiceManagement
import SwiftUI
import UI

/// General application settings: appearance, startup, and confirmation behavior.
struct GeneralSettingsView: View {
    let palette: AgentTracePalette
    @EnvironmentObject private var preferences: AppPreferences

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var statusMessage: String?
    @State private var statusIsError = false

    var body: some View {
        SettingsPaneScaffold(
            title: "General",
            subtitle: "Appearance, startup behavior, and confirmations for the Tether desktop app.",
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
            SettingsPickerRow(
                title: "Theme",
                subtitle: "Appearance controls are temporarily unavailable.",
                selection: $preferences.appearance,
                options: AgentTraceThemeMode.allCases,
                label: { $0.title },
                palette: palette
            )
            .disabled(true)
            .opacity(0.54)
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

    /// Registers or unregisters the login item, surfacing any failure inline.
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
