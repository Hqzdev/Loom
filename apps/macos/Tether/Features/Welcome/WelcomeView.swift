import Networking
import SwiftUI
import UI

/// First-run welcome window for launching the local proxy helper.
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

                WelcomeFeatureGrid(palette: palette, hasAppeared: hasAppeared)
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

    /// Starts the local proxy helper and dismisses the welcome flow.
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

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
            .preferredColorScheme(.light)
    }
}
