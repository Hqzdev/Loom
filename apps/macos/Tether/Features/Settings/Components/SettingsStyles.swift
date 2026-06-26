import SwiftUI
import UI

struct SettingsFieldModifier: ViewModifier {
    let palette: AgentTracePalette

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.system(size: 12.5, design: .monospaced))
            .foregroundStyle(palette.text)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(palette.elevated.opacity(0.88), in: RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
    }
}

extension View {
    func settingsField(palette: AgentTracePalette) -> some View {
        modifier(SettingsFieldModifier(palette: palette))
    }
}

struct SettingsPrimaryButtonStyle: ButtonStyle {
    let palette: AgentTracePalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(palette.light ? Color.white : Color(hex: 0x111113))
            .background(palette.text)
            .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.86 : 1)
    }
}

struct SettingsSecondaryButtonStyle: ButtonStyle {
    let palette: AgentTracePalette
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(destructive ? palette.pinkText : palette.textSecondary)
            .padding(.horizontal, 12)
            .background(
                destructive ? palette.pinkBackground : palette.panelSecondary,
                in: RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                    .stroke(destructive ? palette.pinkDim : palette.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct SettingsCloseButton: View {
    let palette: AgentTracePalette
    let onClose: () -> Void

    var body: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.textSecondary)
        .contentShape(Rectangle())
        .padding(.top, 18)
        .padding(.trailing, 18)
    }
}
