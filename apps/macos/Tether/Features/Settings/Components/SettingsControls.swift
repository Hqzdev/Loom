import SwiftUI
import UI

struct VerticalDividerLine: View {
    let palette: AgentTracePalette

    var body: some View {
        Rectangle()
            .fill(palette.border)
            .frame(width: 1)
    }
}

struct SettingsSection<Content: View>: View {
    private let title: String
    private let palette: AgentTracePalette
    private let content: Content

    init(_ title: String, palette: AgentTracePalette, @ViewBuilder content: () -> Content) {
        self.title = title
        self.palette = palette
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .fontWeight(.semibold)
                .foregroundStyle(palette.text)

            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 16)
            .background(palette.elevated.opacity(0.82), in: RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
        }
    }
}

struct SettingsRow<Content: View>: View {
    private let title: String
    private let subtitle: String?
    private let palette: AgentTracePalette
    private let content: Content

    init(_ title: String, subtitle: String? = nil, palette: AgentTracePalette, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.palette = palette
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.text)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textTertiary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            content
        }
        .frame(minHeight: 70)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.borderSoft)
                .frame(height: 1)
                .padding(.leading, 0)
        }
    }
}
