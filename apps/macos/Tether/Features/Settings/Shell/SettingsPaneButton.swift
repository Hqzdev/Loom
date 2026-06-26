import SwiftUI
import UI

struct SettingsPaneButton: View {
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
                in: RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
