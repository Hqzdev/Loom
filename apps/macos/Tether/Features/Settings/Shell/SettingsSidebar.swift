import SwiftUI
import UI

struct SettingsSidebar: View {
    @Binding var selectedPane: SettingsPane
    @Binding var searchText: String
    let palette: AgentTracePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSearchField(searchText: $searchText, palette: palette)
                .padding(.top, 14)
                .padding(.horizontal, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    let settingsPanes = filtered(SettingsPane.settings)
                    let desktopPanes = filtered(SettingsPane.desktop)

                    if settingsPanes.isEmpty && desktopPanes.isEmpty {
                        Text("No settings match \u{201C}\(searchText)\u{201D}")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.textTertiary)
                            .padding(.horizontal, 10)
                            .padding(.top, 4)
                    }

                    if !settingsPanes.isEmpty {
                        SettingsPaneGroup(title: "Settings", panes: settingsPanes, selectedPane: $selectedPane, palette: palette)
                    }
                    if !desktopPanes.isEmpty {
                        SettingsPaneGroup(title: "Desktop app", panes: desktopPanes, selectedPane: $selectedPane, palette: palette)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
        }
    }

    private func filtered(_ panes: [SettingsPane]) -> [SettingsPane] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return panes }
        return panes.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }
}

private struct SettingsSearchField: View {
    @Binding var searchText: String
    let palette: AgentTracePalette

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.textTertiary)

            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(palette.elevated.opacity(0.78), in: RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
    }
}

private struct SettingsPaneGroup: View {
    let title: String
    let panes: [SettingsPane]
    @Binding var selectedPane: SettingsPane
    let palette: AgentTracePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(palette.textTertiary)
                .padding(.horizontal, 10)
                .padding(.bottom, 4)

            ForEach(panes) { pane in
                SettingsPaneButton(pane: pane, selected: selectedPane == pane, palette: palette) {
                    selectedPane = pane
                }
            }
        }
    }
}
