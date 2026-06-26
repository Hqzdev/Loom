import SwiftUI
import UI

struct SidebarSearchField: View {
    @Binding var searchText: String
    let searchFocused: FocusState<Bool>.Binding
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.textQuaternary)
                    .frame(width: 16)

                TextField("Filter calls...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(palette.text)
                    .focused(searchFocused)
            }
            .frame(height: 30)
            .padding(.horizontal, 9)
            .background(palette.window.opacity(0.72), in: RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }
}
