import SwiftUI
import UI

/// Header text for a proxy settings detail pane.
struct ProxySettingsHeader: View {
    let title: String
    let subtitle: String
    let palette: AgentTracePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(palette.text)

            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(palette.textTertiary)
        }
    }
}

/// Text field row for an upstream provider URL.
struct UpstreamURLField: View {
    let title: String
    @Binding var value: String
    let palette: AgentTracePalette

    var body: some View {
        SettingsRow(title, subtitle: "\(title)-compatible API endpoint", palette: palette) {
            TextField("", text: $value)
                .settingsField(palette: palette)
                .frame(width: 320)
        }
    }
}

/// Secure field row for a provider API key.
struct ProviderKeyField: View {
    let title: String
    let stored: Bool
    let placeholder: String
    @Binding var key: String
    let palette: AgentTracePalette

    var body: some View {
        SettingsRow(
            title,
            subtitle: stored ? "Stored in macOS Keychain" : "Optional fallback for \(title)-compatible calls",
            palette: palette
        ) {
            SecureField(stored ? "stored" : placeholder, text: $key)
                .settingsField(palette: palette)
                .frame(width: 320)
        }
    }
}

/// Footer bar with validation status and save action.
struct ProxySettingsFooter: View {
    let message: String
    let isError: Bool
    let palette: AgentTracePalette
    let save: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HorizontalDividerLine(palette: palette)

            HStack(spacing: 12) {
                Spacer(minLength: 0)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(isError ? palette.pinkText : palette.textTertiary)

                Button {
                    save()
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
}
