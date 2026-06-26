import Core
import SwiftUI
import UI

struct InspectorTabPicker: View {
    @Binding var tab: InspectorTab
    let palette: AgentTracePalette

    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(InspectorTab.allCases) { item in
                let selected = tab == item
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        tab = item
                    }
                } label: {
                    Text(item.title)
                        .font(.system(size: 11.5, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? palette.accent : palette.textTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .contentShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                                    .fill(palette.accentBackground.opacity(0.95))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                                            .stroke(palette.accent.opacity(0.42), lineWidth: 1)
                                    }
                                    .matchedGeometryEffect(id: "selection", in: pill)
                            }
                        }
                        .overlay(alignment: .bottom) {
                            if selected {
                                Capsule()
                                    .fill(palette.accent)
                                    .frame(height: 2)
                                    .padding(.horizontal, 10)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous)
                .fill(palette.panelSecondary.opacity(0.55))
                .overlay {
                    RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous)
                        .stroke(palette.glassStrokeSoft, lineWidth: 1)
                }
        }
        .frame(maxWidth: .infinity)
    }
}
