import AppKit
import Networking
import SwiftUI
import UI

struct AppSettingsView: View {
    var onClose: (() -> Void)?

    private let palette = AgentTracePalette(light: true)
    @State private var selectedPane: SettingsPane = .general
    @State private var searchText = ""

    var body: some View {
        HStack(spacing: 0) {
            settingsSidebar
                .frame(width: 214)
                .background(palette.panel.opacity(0.96))

            VerticalDividerLine(palette: palette)

            settingsDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 920, height: 560)
        .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
        .shadow(color: Color(hex: 0x0f172a).opacity(0.18), radius: 34, x: 0, y: 22)
        .preferredColorScheme(.light)
    }

    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.textTertiary)

                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
            .padding(.top, 14)
            .padding(.horizontal, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsPaneGroup(
                        title: "Settings",
                        panes: SettingsPane.settings,
                        selectedPane: $selectedPane,
                        palette: palette
                    )

                    SettingsPaneGroup(
                        title: "Desktop app",
                        panes: SettingsPane.desktop,
                        selectedPane: $selectedPane,
                        palette: palette
                    )
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
        }
    }

    @ViewBuilder
    private var settingsDetail: some View {
        ZStack(alignment: .topTrailing) {
            switch selectedPane {
            case .general:
                ProxySettingsView(
                    title: "General desktop settings",
                    subtitle: "Configure how Tether captures local agent traffic.",
                    palette: palette
                )

            case .proxy:
                ProxySettingsView(
                    title: "Proxy settings",
                    subtitle: "Edit upstream URLs, listen port, and local cache behavior.",
                    palette: palette
                )

            default:
                PlaceholderSettingsView(pane: selectedPane, palette: palette)
            }

            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.textSecondary)
                .contentShape(Rectangle())
                .padding(.top, 18)
                .padding(.trailing, 18)
            }
        }
    }
}

private enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case agents
    case workspace
    case privacy
    case usage
    case proxy
    case extensions
    case developer

    var id: String { rawValue }

    static let settings: [SettingsPane] = [.general, .agents, .workspace, .privacy, .usage]
    static let desktop: [SettingsPane] = [.proxy, .extensions, .developer]

    var title: String {
        switch self {
        case .general:
            return "General"
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

private struct SettingsPaneGroup: View {
    let title: String
    let panes: [SettingsPane]
    @Binding var selectedPane: SettingsPane
    let palette: AgentTracePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.textTertiary)
                .padding(.horizontal, 10)
                .padding(.bottom, 4)

            ForEach(panes) { pane in
                SettingsPaneButton(
                    pane: pane,
                    selected: selectedPane == pane,
                    palette: palette
                ) {
                    selectedPane = pane
                }
            }
        }
    }
}

private struct SettingsPaneButton: View {
    let pane: SettingsPane
    let selected: Bool
    let palette: AgentTracePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: pane.systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)
                    .foregroundStyle(selected ? palette.text : palette.textTertiary)

                Text(pane.title)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? palette.text : palette.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(
                selected ? palette.active.opacity(0.86) : Color.clear,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct PlaceholderSettingsView: View {
    let pane: SettingsPane
    let palette: AgentTracePalette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(pane.title) settings")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(palette.text)

                    Text("This section is ready for product-specific controls.")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.textTertiary)
                }

                SettingsSection("Available", palette: palette) {
                    SettingsRow("No controls yet", subtitle: "Proxy and cache settings are available in General and Proxy.", palette: palette) {
                        EmptyView()
                    }
                }
            }
            .padding(.top, 66)
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

private struct VerticalDividerLine: View {
    let palette: AgentTracePalette

    var body: some View {
        Rectangle()
            .fill(palette.border)
            .frame(width: 1)
    }
}

private struct ProxySettingsView: View {
    let title: String
    let subtitle: String
    let palette: AgentTracePalette

    @State private var portText = String(ProxySettingsStore.current.port)
    @State private var openAIUpstreamURL = ProxySettingsStore.current.openAIUpstreamURL
    @State private var anthropicUpstreamURL = ProxySettingsStore.current.anthropicUpstreamURL
    @State private var localCacheEnabled = ProxySettingsStore.current.localCacheEnabled
    @State private var footerMessage = "Requires proxy restart"
    @State private var footerMessageIsError = false
    @State private var openAIKey = ""
    @State private var anthropicKey = ""
    @State private var openAIKeyStored = KeychainStore.hasValue(.openAIAPIKey)
    @State private var anthropicKeyStored = KeychainStore.hasValue(.anthropicAPIKey)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(palette.text)

                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(palette.textTertiary)
                    }

                    SettingsSection("Listen", palette: palette) {
                        SettingsRow("Port", subtitle: "Local port used by the desktop proxy", palette: palette) {
                            TextField("", text: $portText)
                                .settingsField(palette: palette)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 96)
                        }
                    }

                    SettingsSection("Upstream URLs", palette: palette) {
                        SettingsRow("OpenAI", subtitle: "OpenAI-compatible API endpoint", palette: palette) {
                            TextField("", text: $openAIUpstreamURL)
                                .settingsField(palette: palette)
                                .frame(width: 320)
                        }

                        SettingsRow("Anthropic", subtitle: "Anthropic-compatible API endpoint", palette: palette) {
                            TextField("", text: $anthropicUpstreamURL)
                                .settingsField(palette: palette)
                                .frame(width: 320)
                        }
                    }

                    SettingsSection("Provider Keys", palette: palette) {
                        SettingsRow(
                            "OpenAI",
                            subtitle: openAIKeyStored ? "Stored in macOS Keychain" : "Optional fallback for OpenAI-compatible calls",
                            palette: palette
                        ) {
                            SecureField(openAIKeyStored ? "stored" : "sk-...", text: $openAIKey)
                                .settingsField(palette: palette)
                                .frame(width: 320)
                        }

                        SettingsRow(
                            "Anthropic",
                            subtitle: anthropicKeyStored ? "Stored in macOS Keychain" : "Optional fallback for Anthropic-compatible calls",
                            palette: palette
                        ) {
                            SecureField(anthropicKeyStored ? "stored" : "sk-ant-...", text: $anthropicKey)
                                .settingsField(palette: palette)
                                .frame(width: 320)
                        }

                        Text("Stored in the macOS Keychain. The proxy injects these on upstream calls when your client does not send its own key.")
                            .font(.caption)
                            .foregroundStyle(palette.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                    }

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
                .padding(.top, 66)
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .top)
            }

            Spacer(minLength: 0)

            HorizontalDividerLine(palette: palette)

            HStack(spacing: 12) {
                Spacer(minLength: 0)

                Text(footerMessage)
                    .font(.caption)
                    .foregroundStyle(footerMessageIsError ? palette.pinkText : palette.textTertiary)

                Button {
                    saveAndRestart()
                } label: {
                    Text("Save & Restart")
                        .frame(width: 132, height: 34)
                }
                .buttonStyle(SettingsPrimaryButtonStyle(palette: palette))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(palette.panel.opacity(0.90))
        }
    }

    private func saveAndRestart() {
        do {
            let settings = try validatedSettings()
            ProxySettingsStore.save(settings)

            if !openAIKey.isEmpty {
                KeychainStore.save(.openAIAPIKey, value: openAIKey)
                openAIKey = ""
                openAIKeyStored = true
            }
            if !anthropicKey.isEmpty {
                KeychainStore.save(.anthropicAPIKey, value: anthropicKey)
                anthropicKey = ""
                anthropicKeyStored = true
            }

            LocalProxyLauncher.shared.restart()
            footerMessage = "Requires proxy restart"
            footerMessageIsError = false
        } catch {
            footerMessage = error.localizedDescription
            footerMessageIsError = true
        }
    }

    private func clearCache() {
        Task {
            do {
                try await TraceAPIClient().clearCache()
                footerMessage = "Cache cleared"
                footerMessageIsError = false
            } catch {
                footerMessage = error.localizedDescription
                footerMessageIsError = true
            }
        }
    }

    private func validatedSettings() throws -> ProxySettings {
        let trimmedPort = portText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let port = Int(trimmedPort), (1...65535).contains(port) else {
            throw ProxySettingsValidationError.invalidPort
        }

        let openAIURL = try normalizedURL(openAIUpstreamURL, label: "OpenAI")
        let anthropicURL = try normalizedURL(anthropicUpstreamURL, label: "Anthropic")

        return ProxySettings(
            port: port,
            openAIUpstreamURL: openAIURL,
            anthropicUpstreamURL: anthropicURL,
            localCacheEnabled: localCacheEnabled
        )
    }

    private func normalizedURL(_ value: String, label: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil
        else {
            throw ProxySettingsValidationError.invalidURL(label)
        }

        return trimmed
    }
}

private struct SettingsSection<Content: View>: View {
    private let title: String
    private let palette: AgentTracePalette
    private let content: Content

    init(_ title: String, palette: AgentTracePalette, @ViewBuilder content: () -> Content) {
        self.title = title
        self.palette = palette
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .fontWeight(.semibold)
                .foregroundStyle(palette.text)

            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 16)
            .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
        }
    }
}

private struct SettingsRow<Content: View>: View {
    private let title: String
    private let subtitle: String?
    private let palette: AgentTracePalette
    private let content: Content

    init(_ title: String, subtitle: String? = nil, palette: AgentTracePalette, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.palette = palette
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.text)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textTertiary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            content
        }
        .frame(minHeight: 70)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.borderSoft)
                .frame(height: 1)
                .padding(.leading, 0)
        }
    }
}

private struct SettingsFieldModifier: ViewModifier {
    let palette: AgentTracePalette

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.system(size: 12.5, design: .monospaced))
            .foregroundStyle(palette.text)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
    }
}

private extension View {
    func settingsField(palette: AgentTracePalette) -> some View {
        modifier(SettingsFieldModifier(palette: palette))
    }
}

private struct SettingsPrimaryButtonStyle: ButtonStyle {
    let palette: AgentTracePalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .background(palette.text)
            .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.86 : 1)
    }
}

private struct SettingsSecondaryButtonStyle: ButtonStyle {
    let palette: AgentTracePalette
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(destructive ? palette.pinkText : palette.textSecondary)
            .padding(.horizontal, 12)
            .background(
                destructive ? palette.pinkBackground : palette.panelSecondary,
                in: RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                    .stroke(destructive ? palette.pinkDim : palette.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

private struct SettingsIconButtonStyle: ButtonStyle {
    let palette: AgentTracePalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(palette.textSecondary)
            .background(
                configuration.isPressed ? palette.active : palette.panelSecondary,
                in: RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
    }
}
