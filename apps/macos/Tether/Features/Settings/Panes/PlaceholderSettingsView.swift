import SwiftUI
import UI

/// Placeholder content for settings panes that do not have controls yet.
struct PlaceholderSettingsView: View {
    let pane: SettingsPane
    let palette: AgentTracePalette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(pane.title) settings")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(palette.text)

                    Text("This section is ready for product-specific controls.")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.textTertiary)
                }

                SettingsSection("Available", palette: palette) {
                    SettingsRow("No controls yet", subtitle: "Proxy and cache settings are available in General and Proxy.", palette: palette) {
                        EmptyView()
                    }
                }
            }
            .padding(.top, 66)
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
