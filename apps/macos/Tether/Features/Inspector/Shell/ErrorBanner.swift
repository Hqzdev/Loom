import Core
import SwiftUI
import UI

/// Error banner shown above a failed node response.
struct ErrorBanner: View {
    let error: AgentError
    let palette: AgentTracePalette

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Text("x")
                .font(.system(size: 11.5, weight: .bold, design: .monospaced))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(error.code) - \(error.message)")
                    .font(.system(size: 11.5, weight: .semibold))
                Text(error.detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.textQuaternary)
            }
        }
        .foregroundStyle(palette.pinkText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(palette.pinkBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.pinkDim)
                .frame(height: 1)
        }
    }
}
