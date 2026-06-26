import SwiftUI
import UI

/// Workspace and graph canvas preferences.
struct WorkspaceSettingsView: View {
    let palette: AgentTracePalette
    @EnvironmentObject private var preferences: AppPreferences
    @StateObject private var access = WorkspaceAccessStore.shared

    var body: some View {
        SettingsPaneScaffold(
            title: "Workspace",
            subtitle: "Tune the trace graph canvas and how nodes are laid out.",
            palette: palette
        ) {
            accessSection
            graphSection
            navigationSection
            layoutSection
        }
    }

    private var accessSection: some View {
        SettingsSection("Access", palette: palette) {
            SettingsValueRow(
                "Workspace folder",
                subtitle: access.workspacePath ?? "Required for file and git diff attribution.",
                value: access.hasWorkspaceAccess ? "Granted" : "Not granted",
                palette: palette
            )

            SettingsButtonRow(
                "Workspace access",
                subtitle: "Grant once so Tether can read this repo without repeated macOS prompts.",
                buttonTitle: access.hasWorkspaceAccess ? "Change Folder" : "Grant Access",
                systemImage: "folder.badge.gearshape",
                palette: palette
            ) {
                access.requestWorkspaceAccess()
            }

            if access.hasWorkspaceAccess {
                SettingsButtonRow(
                    "Forget workspace access",
                    subtitle: "Remove the saved permission and stop reading this folder.",
                    buttonTitle: "Forget",
                    systemImage: "xmark.circle",
                    destructive: true,
                    palette: palette
                ) {
                    access.forgetWorkspaceAccess()
                }
            }
        }
    }

    private var graphSection: some View {
        SettingsSection("Graph", palette: palette) {
            SettingsToggleRow(
                "Show connections",
                subtitle: "Draw the lines linking parent and child agent calls.",
                isOn: $preferences.showConnections,
                palette: palette
            )
            SettingsToggleRow(
                "Snap nodes to grid",
                subtitle: "Align dragged nodes to a regular grid for tidier layouts.",
                isOn: $preferences.snapToGrid,
                palette: palette
            )
        }
    }

    private var navigationSection: some View {
        SettingsSection("Navigation", palette: palette) {
            SettingsToggleRow(
                "Invert scroll panning",
                subtitle: "Reverse the direction the canvas pans when you scroll.",
                isOn: $preferences.invertScroll,
                palette: palette
            )

            SettingsRow(
                "Zoom sensitivity",
                subtitle: "How quickly pinch and magnify gestures change the zoom level.",
                palette: palette
            ) {
                HStack(spacing: 10) {
                    Text(String(format: "%.1f×", preferences.zoomSensitivity))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.text)
                        .monospacedDigit()
                        .frame(minWidth: 40, alignment: .trailing)

                    Slider(value: $preferences.zoomSensitivity, in: 0.5...2.0, step: 0.1)
                        .frame(width: 160)
                }
            }
        }
    }

    private var layoutSection: some View {
        SettingsSection("Layout", palette: palette) {
            SettingsButtonRow(
                "Reset node positions",
                subtitle: "Clear manual drag offsets and return the graph to its automatic layout.",
                buttonTitle: "Reset Layout",
                systemImage: "arrow.counterclockwise",
                palette: palette
            ) {
                NotificationCenter.default.post(name: .agentTraceResetGraphLayout, object: nil)
            }
        }
    }
}
