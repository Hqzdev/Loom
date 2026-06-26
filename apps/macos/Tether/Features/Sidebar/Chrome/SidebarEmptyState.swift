import SwiftUI
import UI

/// Empty call-list state shown before traffic is captured.
struct SidebarEmptyState: View {
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 8) {
            Text("No calls captured")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(palette.textTertiary)

            Text("Run codex in Terminal or send traffic through the proxy.")
                .font(.system(size: 11.5))
                .foregroundStyle(palette.textQuaternary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 210)
        }
    }
}
