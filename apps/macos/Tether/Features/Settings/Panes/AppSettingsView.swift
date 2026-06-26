import SwiftUI
import UI

struct AppSettingsView: View {
    var onClose: (() -> Void)?

    let palette: AgentTracePalette
    @State var selectedPane: SettingsPane = .general
    @State var searchText = ""

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(
                selectedPane: $selectedPane,
                searchText: $searchText,
                palette: palette
            )
            .frame(width: 214)
            .background(palette.panel.opacity(0.96))

            VerticalDividerLine(palette: palette)
            settingsDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 920, height: 560)
        .background(palette.window.opacity(0.96), in: RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
        .shadow(color: palette.liquidShade.opacity(0.42), radius: 24, x: 0, y: 14)
    }

    @ViewBuilder
    private var paneContent: some View {
        switch selectedPane {
        case .general:
            GeneralSettingsView(palette: palette)
        case .shortcuts:
            ShortcutsSettingsView(palette: palette)
        case .agents:
            AgentSettingsView(palette: palette)
        case .workspace:
            WorkspaceSettingsView(palette: palette)
        case .privacy:
            PrivacySettingsView(palette: palette)
        case .usage:
            UsageSettingsView(palette: palette)
        case .proxy:
            ProxySettingsView(
                title: "Proxy settings",
                subtitle: "Edit upstream URLs, listen port, and local cache behavior.",
                palette: palette
            )
        case .extensions:
            ExtensionsSettingsView(palette: palette)
        case .developer:
            DeveloperSettingsView(palette: palette)
        }
    }

    @ViewBuilder
    private var settingsDetail: some View {
        ZStack(alignment: .topTrailing) {
            paneContent

            if let onClose {
                SettingsCloseButton(palette: palette, onClose: onClose)
            }
        }
    }
}

struct ShortcutsSettingsView: View {
    let palette: AgentTracePalette

    private let groups: [(String, [ShortcutRow])] = [
        (
            "Workspace",
            [
                ShortcutRow(action: "Open Quickview", shortcut: "Cmd T", detail: "Show the latest run without switching context."),
                ShortcutRow(action: "Search Nodes", shortcut: "Cmd F", detail: "Focus node search when the graph gets large."),
                ShortcutRow(action: "Toggle Inspector", shortcut: "Space", detail: "Show or hide node details with immediate feedback."),
                ShortcutRow(action: "Previous Node", shortcut: "Cmd [", detail: "Move selection to the previous graph node."),
                ShortcutRow(action: "Next Node", shortcut: "Cmd ]", detail: "Move selection to the next graph node.")
            ]
        ),
        (
            "Trace Actions",
            [
                ShortcutRow(action: "Replay Selected Node", shortcut: "Cmd R", detail: "Replay the selected node and refresh the trace."),
                ShortcutRow(action: "Reload Trace", shortcut: "Cmd Shift R", detail: "Refresh the current trace from local sources."),
                ShortcutRow(action: "Clear View", shortcut: "Escape", detail: "Reset transient selection without deleting trace data.")
            ]
        ),
        (
            "Inspector Tabs",
            [
                ShortcutRow(action: "Content", shortcut: "1", detail: "Jump to the primary inspector content."),
                ShortcutRow(action: "Parameters", shortcut: "2", detail: "Jump to request parameters and model context."),
                ShortcutRow(action: "Resolution", shortcut: "3", detail: "Jump to response and failure resolution.")
            ]
        )
    ]

    var body: some View {
        SettingsPaneScaffold(
            title: "Shortcuts",
            subtitle: "Fast paths for inspecting, replaying, and moving through traces.",
            palette: palette
        ) {
            ForEach(groups, id: \.0) { group in
                SettingsSection(group.0, palette: palette) {
                    ForEach(group.1) { row in
                        ShortcutSettingsRow(row: row, palette: palette)
                    }
                }
            }
        }
    }
}

private struct ShortcutRow: Identifiable {
    let id = UUID()
    let action: String
    let shortcut: String
    let detail: String
}

private struct ShortcutSettingsRow: View {
    let row: ShortcutRow
    let palette: AgentTracePalette

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(row.action)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.text)

                Text(row.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textTertiary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(row.shortcut)
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(palette.textSecondary)
                .padding(.horizontal, 9)
                .frame(height: 28)
                .background(palette.panelSecondary, in: RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                        .stroke(palette.border, lineWidth: 1)
                }
        }
        .frame(minHeight: 64)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.borderSoft)
                .frame(height: 1)
        }
    }
}
