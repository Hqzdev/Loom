import Core
import SwiftUI
import UI

struct TitleBar: View {
    let session: TraceSession?
    let palette: AgentTracePalette

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(palette.accent)
                    .frame(width: 26, height: 26)
                    .background(palette.accentBackground)
                    .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                            .stroke(palette.accent.opacity(0.18), lineWidth: 1)
                    )

                Text("Tether")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.text)

                if let session {
                    Text(session.id)
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(palette.textTertiary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(palette.panelSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                                .stroke(palette.border, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous)
                    .stroke(palette.border.opacity(0.92), lineWidth: 1)
            )
            .shadow(color: Color(hex: 0x0f172a).opacity(0.07), radius: 18, x: 0, y: 8)

            Spacer(minLength: 12)
        }
        .frame(height: 64)
        .padding(.leading, 88)
        .padding(.trailing, 16)
    }
}
