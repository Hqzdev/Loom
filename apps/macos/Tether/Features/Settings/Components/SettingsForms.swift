import SwiftUI
import UI

struct SettingsPaneHeader: View {
    let title: String
    let subtitle: String
    let palette: AgentTracePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(palette.text)

            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(palette.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsPaneScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    let palette: AgentTracePalette
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                SettingsPaneHeader(title: title, subtitle: subtitle, palette: palette)
                content
            }
            .padding(.top, 66)
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    let palette: AgentTracePalette

    init(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>, palette: AgentTracePalette) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.palette = palette
    }

    var body: some View {
        SettingsRow(title, subtitle: subtitle, palette: palette) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

struct SettingsPickerRow<Option: Hashable & Identifiable>: View {
    let title: String
    let subtitle: String?
    @Binding var selection: Option
    let options: [Option]
    let label: (Option) -> String
    let palette: AgentTracePalette

    var body: some View {
        SettingsRow(title, subtitle: subtitle, palette: palette) {
            Picker("", selection: $selection) {
                ForEach(options) { option in
                    Text(label(option)).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .fixedSize()
        }
    }
}

struct SettingsStepperRow: View {
    let title: String
    let subtitle: String?
    @Binding var value: Int
    let range: ClosedRange<Int>
    let valueLabel: (Int) -> String
    let palette: AgentTracePalette

    var body: some View {
        SettingsRow(title, subtitle: subtitle, palette: palette) {
            HStack(spacing: 10) {
                Text(valueLabel(value))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.text)
                    .frame(minWidth: 72, alignment: .trailing)
                    .monospacedDigit()

                Stepper("", value: $value, in: range)
                    .labelsHidden()
            }
        }
    }
}

struct SettingsButtonRow: View {
    let title: String
    let subtitle: String?
    let buttonTitle: String
    let systemImage: String
    let destructive: Bool
    let palette: AgentTracePalette
    let action: () -> Void

    init(
        _ title: String,
        subtitle: String? = nil,
        buttonTitle: String,
        systemImage: String,
        destructive: Bool = false,
        palette: AgentTracePalette,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.buttonTitle = buttonTitle
        self.systemImage = systemImage
        self.destructive = destructive
        self.palette = palette
        self.action = action
    }

    var body: some View {
        SettingsRow(title, subtitle: subtitle, palette: palette) {
            Button(action: action) {
                Label(buttonTitle, systemImage: systemImage)
                    .frame(height: 30)
            }
            .buttonStyle(SettingsSecondaryButtonStyle(palette: palette, destructive: destructive))
        }
    }
}

struct SettingsValueRow: View {
    let title: String
    let subtitle: String?
    let value: String
    let palette: AgentTracePalette

    init(_ title: String, subtitle: String? = nil, value: String, palette: AgentTracePalette) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.palette = palette
    }

    var body: some View {
        SettingsRow(title, subtitle: subtitle, palette: palette) {
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.text)
                .monospacedDigit()
        }
    }
}
