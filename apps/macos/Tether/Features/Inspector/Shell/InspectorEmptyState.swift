import SwiftUI
import UI

/// Empty inspector body shown when no graph node is selected.
struct InspectorEmptyState: View {
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 10) {
            Text("No node selected")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.textTertiary)

            Text("Prompt, response, and metadata will appear here.")
                .font(.system(size: 11.5))
                .foregroundStyle(palette.textQuaternary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.panel.opacity(0.52))
    }
}
