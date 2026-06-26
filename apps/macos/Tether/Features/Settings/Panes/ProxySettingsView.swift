import Networking
import SwiftUI
import UI

/// Settings detail form for local proxy, upstream URLs, API keys, and cache controls.
struct ProxySettingsView: View {
    let title: String
    let subtitle: String
    let palette: AgentTracePalette

    @State var portText = String(ProxySettingsStore.current.port)
    @State var openAIUpstreamURL = ProxySettingsStore.current.openAIUpstreamURL
    @State var anthropicUpstreamURL = ProxySettingsStore.current.anthropicUpstreamURL
    @State var localCacheEnabled = ProxySettingsStore.current.localCacheEnabled
    @State var footerMessage = "Requires proxy restart"
    @State var footerMessageIsError = false
    @State var openAIKey = ""
    @State var anthropicKey = ""
    @State var cometAPIKey = ""
    @State var openAIKeyStored = KeychainStore.hasValue(.openAIAPIKey)
    @State var anthropicKeyStored = KeychainStore.hasValue(.anthropicAPIKey)
    @State var cometAPIKeyStored = KeychainStore.hasValue(.cometAPIKey)
    @State var cometAPIStatus = "Not tested"
    @State var cometAPIStatusIsError = false
    @State var testingCometAPI = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    ProxySettingsHeader(title: title, subtitle: subtitle, palette: palette)
                    listenSection
                    upstreamSection
                    providerKeysSection
                    cometAPISection
                    cacheSection
                }
                .padding(.top, 66)
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .top)
            }

            Spacer(minLength: 0)
            ProxySettingsFooter(message: footerMessage, isError: footerMessageIsError, palette: palette, save: saveAndRestart)
        }
    }

    private var listenSection: some View {
        SettingsSection("Listen", palette: palette) {
            SettingsRow("Port", subtitle: "Local port used by the desktop proxy", palette: palette) {
                TextField("", text: $portText)
                    .settingsField(palette: palette)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 96)
            }
        }
    }

    private var upstreamSection: some View {
        SettingsSection("Upstream URLs", palette: palette) {
            UpstreamURLField(title: "OpenAI", value: $openAIUpstreamURL, palette: palette)
            UpstreamURLField(title: "Anthropic", value: $anthropicUpstreamURL, palette: palette)
        }
    }

    private var providerKeysSection: some View {
        SettingsSection("Provider Keys", palette: palette) {
            ProviderKeyField(title: "OpenAI", stored: openAIKeyStored, placeholder: "sk-...", key: $openAIKey, palette: palette)
            ProviderKeyField(title: "Anthropic", stored: anthropicKeyStored, placeholder: "sk-ant-...", key: $anthropicKey, palette: palette)
            Text("Stored in the macOS Keychain. The proxy injects these on upstream calls when your client does not send its own key.")
                .font(.caption)
                .foregroundStyle(palette.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
        }
    }

    private var cometAPISection: some View {
        SettingsSection("CometAPI", palette: palette) {
            ProviderKeyField(title: "CometAPI", stored: cometAPIKeyStored, placeholder: "sk-comet-...", key: $cometAPIKey, palette: palette)

            SettingsRow(
                "Connection",
                subtitle: cometAPIStatus,
                palette: palette
            ) {
                Button {
                    testCometAPIConnection()
                } label: {
                    if testingCometAPI {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 120, height: 30)
                    } else {
                        Label("Test", systemImage: cometAPIStatusIsError ? "xmark.circle" : "checkmark.circle")
                            .frame(width: 120, height: 30)
                    }
                }
                .buttonStyle(SettingsSecondaryButtonStyle(palette: palette))
                .disabled(testingCometAPI || (!cometAPIKeyStored && cometAPIKey.isEmpty))
            }

            Text("CometAPI keys are kept in Keychain and synced to the local proxy. Replay requests send only the selected model.")
                .font(.caption)
                .foregroundStyle(palette.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
        }
    }

    private var cacheSection: some View {
        SettingsSection("Cache", palette: palette) {
            SettingsRow("Enable local cache", subtitle: "Reuse compatible local responses when available", palette: palette) {
                Toggle("", isOn: $localCacheEnabled)
                    .labelsHidden()
            }

            SettingsRow("Cached responses", subtitle: "Remove saved proxy cache files", palette: palette) {
                Button {
                    clearCache()
                } label: {
                    Label("Clear Cache", systemImage: "trash")
                        .frame(height: 30)
                }
                .buttonStyle(SettingsSecondaryButtonStyle(palette: palette, destructive: true))
            }
        }
    }
}
