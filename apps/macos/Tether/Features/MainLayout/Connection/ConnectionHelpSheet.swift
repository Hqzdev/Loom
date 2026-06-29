import SwiftUI
import UI

struct ConnectionHelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var systemColorScheme
    @EnvironmentObject private var preferences: AppPreferences

    private var palette: AgentTracePalette {
        AgentTracePalette(light: preferences.appearance.isLight(systemColorScheme: systemColorScheme))
    }

    var body: some View {
        ZStack {
            StageBackground(palette: palette)

            VStack(alignment: .leading, spacing: 24) {
                ConnectionHelpHeader(palette: palette)
                VStack(alignment: .leading, spacing: 12) {
                    HelpRow(systemImage: "1.circle", title: "Open Terminal", detail: "Run any supported agent command from a terminal session.", palette: palette)
                    HelpRow(systemImage: "2.circle", title: "Keep Tether Open", detail: "The workspace updates as new agent calls arrive.", palette: palette)
                    HelpRow(systemImage: "3.circle", title: "Use Proxy Settings", detail: "Configure port, upstream URLs, and cache from Settings.", palette: palette)
                }
                ConnectionHelpFooter(palette: palette, dismiss: dismiss)
            }
            .padding(24)
            .background(palette.window.opacity(0.88), in: RoundedRectangle(cornerRadius: palette.paperRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: palette.paperRadius, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
            .padding(12)
        }
        .frame(width: 480)
    }
}
