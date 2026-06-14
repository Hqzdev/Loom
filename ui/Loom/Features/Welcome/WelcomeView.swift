import Networking
import SwiftUI
import UI

struct WelcomeView: View {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    @State private var hasAppeared = false
    @State private var contentOpacity: Double = 1
    private let palette = AgentTracePalette(light: true)

    var body: some View {
        ZStack {
            StageBackground(palette: palette)

            VStack(spacing: 32) {
                WelcomeBranding(palette: palette)
                    .welcomeReveal(hasAppeared, delay: 0)

                HStack(spacing: 16) {
                    WelcomeFeatureCard(
                        systemImage: "terminal",
                        title: "Terminal-native",
                        description: "Point Claude Code or Codex to 127.0.0.1:8080. No SDK rewrite.",
                        palette: palette
                    )
                    .welcomeReveal(hasAppeared, delay: 0.15)

                    WelcomeFeatureCard(
                        systemImage: "point.3.connected.trianglepath.dotted",
                        title: "Every call mapped",
                        description: "Prompt, response, latency, model and cache status stay readable locally.",
                        palette: palette
                    )
                    .welcomeReveal(hasAppeared, delay: 0.30)

                    WelcomeFeatureCard(
                        systemImage: "arrow.trianglehead.branch",
                        title: "Replay the chain",
                        description: "Inspect failures, edit one response, and re-run downstream steps.",
                        palette: palette
                    )
                    .welcomeReveal(hasAppeared, delay: 0.45)
                }

                WelcomeFooter(palette: palette, launchAction: launchProxyServer)
                    .welcomeReveal(hasAppeared, delay: 0.60)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 34)
            .background(
                RoundedRectangle(cornerRadius: palette.paperRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [palette.paperTop, palette.paperBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: palette.paperRadius, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
            .shadow(color: Color(hex: 0x0f172a).opacity(0.08), radius: 30, x: 0, y: 18)
            .padding(12)
        }
        .frame(width: 720, height: 540)
        .tint(palette.accent)
        .preferredColorScheme(.light)
        .opacity(contentOpacity)
        .animation(.easeIn(duration: 0.3), value: contentOpacity)
        .onAppear {
            hasAppeared = true
        }
    }

    private func launchProxyServer() {
        _ = LocalProxyLauncher.shared.startIfAvailable()

        withAnimation(.easeIn(duration: 0.3)) {
            contentOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            hasSeenWelcome = true
        }
    }
}

private struct WelcomeBranding: View {
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.94))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(palette.borderStrong, lineWidth: 1)
                    }

                Image("BrandIcon")
                    .resizable()
                    .scaledToFit()
                    .padding(9)
            }
            .frame(width: 76, height: 76)
            .shadow(color: Color(hex: 0x0f172a).opacity(0.10), radius: 18, y: 10)

            Text("Tether")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.text)
                .padding(.top, 12)

            Text("Local trace debugger for AI agents")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.textTertiary)
                .padding(.top, 6)
        }
        .multilineTextAlignment(.center)
    }
}

private struct WelcomeFeatureCard: View {
    let systemImage: String
    let title: String
    let description: String
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(palette.accent)
                .frame(width: 42, height: 42)
                .background(palette.accentBackground)
                .clipShape(RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous)
                        .stroke(palette.accent.opacity(0.18), lineWidth: 1)
                )

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.text)
                .multilineTextAlignment(.center)
                .padding(.top, 12)

            Text(description)
                .font(.system(size: 12.5))
                .foregroundStyle(palette.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 160, alignment: .top)
        .background(Color.white.opacity(0.76), in: RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous)
                .stroke(palette.borderSoft, lineWidth: 1)
        )
    }
}

private struct WelcomeFooter: View {
    let palette: AgentTracePalette
    let launchAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Tested with Claude Code and Codex · 100% local · Your keys never leave this Mac")
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

private struct WelcomeRevealModifier: ViewModifier {
    let isVisible: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .animation(.easeOut(duration: 0.4).delay(delay), value: isVisible)
    }
}

private extension View {
    func welcomeReveal(_ isVisible: Bool, delay: Double) -> some View {
        modifier(WelcomeRevealModifier(isVisible: isVisible, delay: delay))
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
            .preferredColorScheme(.light)
    }
}
