import SwiftUI
import UI

/// Logo and product title for the welcome window.
struct WelcomeBranding: View {
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.94))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(palette.borderStrong, lineWidth: 1)
                    }

                Image("BrandIcon")
                    .resizable()
                    .scaledToFit()
                    .padding(9)
            }
            .frame(width: 76, height: 76)
            .shadow(color: Color(hex: 0x0f172a).opacity(0.10), radius: 18, y: 10)

            Text("Tether")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.text)
                .padding(.top, 12)

            Text("Local trace debugger for AI agents")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.textTertiary)
                .padding(.top, 6)
        }
        .multilineTextAlignment(.center)
    }
}
