import SwiftUI
import UI

struct WelcomeFooter: View {
    let palette: AgentTracePalette
    let launchAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Source adapters for AI coding agents · local traces · keys stay in macOS Keychain")
                .font(.caption)
                .foregroundStyle(palette.textQuaternary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Button(action: launchAction) {
                Label("Launch Proxy Server", systemImage: "play.fill")
                    .frame(width: 260, height: 42)
            }
            .buttonStyle(WelcomePrimaryButtonStyle(palette: palette))
            .padding(.top, 16)

            Text("You can change the port anytime in Settings")
                .font(.caption2)
                .foregroundStyle(palette.textTertiary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WelcomePrimaryButtonStyle: ButtonStyle {
    let palette: AgentTracePalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [palette.accent, palette.accentTwo, palette.accentThree],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
            .shadow(color: palette.accent.opacity(configuration.isPressed ? 0.08 : 0.18), radius: 16, y: 8)
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}
