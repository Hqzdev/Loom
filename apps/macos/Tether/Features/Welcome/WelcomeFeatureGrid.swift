import SwiftUI
import UI

struct WelcomeFeatureGrid: View {
    let palette: AgentTracePalette
    let hasAppeared: Bool

    var body: some View {
        HStack(spacing: 16) {
            WelcomeFeatureCard(
                systemImage: "terminal",
                title: "Adapter-native",
                description: "Capture supported agent CLIs, frameworks, OpenAI-compatible traffic, and custom local workflows.",
                palette: palette
            )
            .welcomeReveal(hasAppeared, delay: 0.15)

            WelcomeFeatureCard(
                systemImage: "point.3.connected.trianglepath.dotted",
                title: "Every action mapped",
                description: "Prompt, file diff, command status, latency, model, and cache state stay readable locally.",
                palette: palette
            )
            .welcomeReveal(hasAppeared, delay: 0.30)

            WelcomeFeatureCard(
                systemImage: "arrow.trianglehead.branch",
                title: "Recover the run",
                description: "Inspect failures, replay supported branches, or roll back from local evidence.",
                palette: palette
            )
            .welcomeReveal(hasAppeared, delay: 0.45)
        }
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
