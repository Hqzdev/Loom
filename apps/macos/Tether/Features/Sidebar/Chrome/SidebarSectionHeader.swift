import SwiftUI
import UI

struct SidebarSectionHeader: View {
    let title: String
    let detail: String
    let palette: AgentTracePalette

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)

            Spacer()

            Text(detail)
                .font(.system(size: 10.5, design: .monospaced))
        }
        .textCase(nil)
        .foregroundStyle(palette.textTertiary)
        .padding(.leading, 18)
        .padding(.trailing, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
}
