import SwiftUI
import UI

struct SidebarStatusHeader: View {
    let proxyStatus: ProxyConnectionStatus
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: proxyStatus.symbolName)
                    .font(.callout)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(proxyStatus.color(palette))
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text(proxyStatus.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(proxyStatus.color(palette))
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(proxyStatus.backgroundTint(palette), in: RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                    .stroke(proxyStatus.color(palette).opacity(0.20), lineWidth: 1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }
}
