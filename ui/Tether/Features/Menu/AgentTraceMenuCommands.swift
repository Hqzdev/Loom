import AppKit
import SwiftUI

struct AgentTraceMenuCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings...") {
                NotificationCenter.default.post(name: .agentTraceShowSettings, object: nil)
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandGroup(replacing: .newItem) {
            Button("Export Traces...") {
                NotificationCenter.default.post(name: .agentTraceExportTraces, object: nil)
            }
            .keyboardShortcut("e", modifiers: .command)

            Divider()
        }

        CommandGroup(replacing: .pasteboard) {
            Button("Copy") {
                NotificationCenter.default.post(name: .agentTraceCopySelection, object: nil)
            }
            .keyboardShortcut("c", modifiers: .command)

            Button("Select All") {
                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("a", modifiers: .command)

            Divider()

            Button("Clear View") {
                NotificationCenter.default.post(name: .agentTraceClearView, object: nil)
            }
            .keyboardShortcut("k", modifiers: [.option, .command])
        }

        CommandMenu("View") {
            Button("Show Inspector") {
                NotificationCenter.default.post(name: .agentTraceShowInspector, object: nil)
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Show Graph") {
                NotificationCenter.default.post(name: .agentTraceShowGraph, object: nil)
            }
            .keyboardShortcut("2", modifiers: .command)

            Divider()

            Button("Reload") {
                NotificationCenter.default.post(name: .agentTraceReload, object: nil)
            }
            .keyboardShortcut("r", modifiers: .command)
        }

        CommandGroup(replacing: .help) {
            Button("Tether Help") {
                NotificationCenter.default.post(name: .agentTraceShowOnboarding, object: nil)
            }

            Button("How to Connect an Agent...") {
                NotificationCenter.default.post(name: .agentTraceShowOnboarding, object: nil)
            }

            Divider()

            Button("Send Feedback...") {
                if let url = URL(string: "mailto:?subject=Tether%20Feedback") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}

extension Notification.Name {
    static let agentTraceNewSession = Notification.Name("agentTraceNewSession")
    static let agentTraceExportTraces = Notification.Name("agentTraceExportTraces")
    static let agentTraceCopySelection = Notification.Name("agentTraceCopySelection")
    /// Non-destructive: clears transient selection without deleting data.
    static let agentTraceClearView = Notification.Name("agentTraceClearView")
    /// Destructive: permanently deletes every stored trace. Only the dedicated
    /// Privacy settings button posts this.
    static let agentTraceClearAllTraces = Notification.Name("agentTraceClearAllTraces")
    static let agentTraceShowInspector = Notification.Name("agentTraceShowInspector")
    static let agentTraceShowGraph = Notification.Name("agentTraceShowGraph")
    static let agentTraceReload = Notification.Name("agentTraceReload")
    static let agentTraceShowOnboarding = Notification.Name("agentTraceShowOnboarding")
    static let agentTraceShowSettings = Notification.Name("agentTraceShowSettings")
    static let agentTraceResetGraphLayout = Notification.Name("agentTraceResetGraphLayout")
}
