import SwiftUI
import UI

struct ConnectionHelpHeader: View {
    let palette: AgentTracePalette

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "terminal")
                .font(.title)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(palette.accent)
                .frame(width: 48, height: 48)
                .background(palette.accentBackground)
                .clipShape(RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous)
                        .stroke(palette.accent.opacity(0.18), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("How to Connect an Agent")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.text)

                Text("Tether watches local agent runs and proxy traffic on this Mac.")
                    .font(.callout)
                    .foregroundStyle(palette.textTertiary)
            }
        }
    }
}

struct HelpRow: View {
    let systemImage: String
    let title: String
    let detail: String
    let palette: AgentTracePalette

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(palette.accent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(palette.text)

                Text(detail)
                    .font(.callout)
                    .foregroundStyle(palette.textTertiary)
            }
        }
    }
}

struct ConnectionHelpFooter: View {
    let palette: AgentTracePalette
    let dismiss: DismissAction

    var body: some View {
        HStack {
            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .frame(width: 112, height: 38)
            }
            .buttonStyle(HelpPrimaryButtonStyle(palette: palette))
        }
    }
}

struct HelpPrimaryButtonStyle: ButtonStyle {
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

struct MainThreePaneLayoutView_Previews: PreviewProvider {
    static var previews: some View {
        MainThreePaneLayoutView(traceStore: TraceStore())
            .environmentObject(AppPreferences.shared)
    }
}
