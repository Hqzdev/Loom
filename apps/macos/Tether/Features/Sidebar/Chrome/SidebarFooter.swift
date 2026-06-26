import SwiftUI
import UI

struct SidebarFooter: View {
    let onShowSettings: () -> Void
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 8) {
            SidebarButton(title: "Settings", palette: palette) {
                onShowSettings()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(palette.panelSecondary.opacity(0.42))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.border)
                .frame(height: 1)
        }
    }
}

private struct SidebarButton: View {
    let title: String
    var selected = false
    let palette: AgentTracePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "gearshape")
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .foregroundStyle(selected ? palette.text : palette.textSecondary)
                .background(selected ? palette.active : palette.window.opacity(0.58), in: RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                        .stroke(palette.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}
