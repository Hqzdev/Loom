import SwiftUI
import UI

/// Agent capture and display preferences.
struct AgentSettingsView: View {
    let palette: AgentTracePalette
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        SettingsPaneScaffold(
            title: "Agents",
            subtitle: "Choose which providers Tether shows and how agent calls are presented.",
            palette: palette
        ) {
            captureSection
            displaySection
        }
    }

    private var captureSection: some View {
        SettingsSection("Capture", palette: palette) {
            SettingsToggleRow(
                "OpenAI traffic",
                subtitle: "Show calls routed to OpenAI-compatible models.",
                isOn: $preferences.captureOpenAI,
                palette: palette
            )
            SettingsToggleRow(
                "Anthropic traffic",
                subtitle: "Show calls routed to Anthropic Claude models.",
                isOn: $preferences.captureAnthropic,
                palette: palette
            )
            SettingsToggleRow(
                "Terminal Codex",
                subtitle: "Show locally observed Codex CLI runs.",
                isOn: $preferences.captureCodex,
                palette: palette
            )
        }
    }

    private var displaySection: some View {
        SettingsSection("Display", palette: palette) {
            SettingsToggleRow(
                "Follow newest call",
                subtitle: "Automatically select the most recent agent node as traces stream in.",
                isOn: $preferences.autoSelectNewNode,
                palette: palette
            )
            SettingsToggleRow(
                "Wrap long lines",
                subtitle: "Wrap prompt and response text in the inspector instead of scrolling horizontally.",
                isOn: $preferences.wrapInspectorLines,
                palette: palette
            )
        }
    }
}
