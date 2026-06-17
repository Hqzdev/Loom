import Networking
import SwiftUI
import UI

/// Privacy controls: secret redaction, data retention, and destructive data actions.
struct PrivacySettingsView: View {
    let palette: AgentTracePalette
    @EnvironmentObject private var preferences: AppPreferences

    @State private var statusMessage: String?
    @State private var statusIsError = false

    var body: some View {
        SettingsPaneScaffold(
            title: "Privacy",
            subtitle: "Control how sensitive trace data is shown, retained, and removed.",
            palette: palette
        ) {
            redactionSection
            retentionSection
            dataSection

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(statusIsError ? palette.pinkText : palette.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var redactionSection: some View {
        SettingsSection("Redaction", palette: palette) {
            SettingsToggleRow(
                "Mask secrets in the inspector",
                subtitle: "Hide API keys and bearer tokens detected in prompts and responses.",
                isOn: $preferences.redactSecrets,
                palette: palette
            )
        }
    }

    private var retentionSection: some View {
        SettingsSection("Retention", palette: palette) {
            SettingsStepperRow(
                title: "Keep traces for",
                subtitle: "Older trace history can be cleared manually below. Zero keeps everything.",
                value: $preferences.retentionDays,
                range: 0...365,
                valueLabel: { $0 == 0 ? "Forever" : "\($0) days" },
                palette: palette
            )
        }
    }

    private var dataSection: some View {
        SettingsSection("Data", palette: palette) {
            SettingsButtonRow(
                "Delete all history",
                subtitle: "Permanently remove every stored trace from this device. Clearing the cache or the view leaves history untouched — this is the only way to delete it.",
                buttonTitle: "Delete History",
                systemImage: "trash",
                destructive: true,
                palette: palette
            ) {
                NotificationCenter.default.post(name: .agentTraceClearAllTraces, object: nil)
                statusMessage = "Requested deletion of all stored history."
                statusIsError = false
            }

            SettingsButtonRow(
                "Remove stored API keys",
                subtitle: "Delete OpenAI and Anthropic keys saved in the macOS Keychain.",
                buttonTitle: "Delete Keys",
                systemImage: "key.slash",
                destructive: true,
                palette: palette
            ) {
                deleteStoredKeys()
            }
        }
    }

    /// Deletes both provider keys from the Keychain and reports the result.
    private func deleteStoredKeys() {
        let openAIRemoved = KeychainStore.delete(.openAIAPIKey)
        let anthropicRemoved = KeychainStore.delete(.anthropicAPIKey)

        if openAIRemoved && anthropicRemoved {
            statusMessage = "Stored provider keys were removed from the Keychain."
            statusIsError = false
        } else {
            statusMessage = "Some keys could not be removed from the Keychain."
            statusIsError = true
        }
    }
}
