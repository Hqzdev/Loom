import AppKit
import Core
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

            Button("Copy Failure Analysis Prompt") {
                NotificationCenter.default.post(name: .agentTraceCopyFailureAnalysisPrompt, object: nil)
            }
            .keyboardShortcut("f", modifiers: [.shift, .command])

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
            .keyboardShortcut(.escape, modifiers: [])
        }

        CommandMenu("View") {
            Button("Open Quickview") {
                NotificationCenter.default.post(name: .agentTraceToggleQuickview, object: nil)
            }
            .keyboardShortcut("t", modifiers: .command)

            Button("Find Nodes") {
                NotificationCenter.default.post(name: .agentTraceFocusSearch, object: nil)
            }
            .keyboardShortcut("f", modifiers: .command)

            Button("Toggle Inspector") {
                NotificationCenter.default.post(name: .agentTraceToggleInspector, object: nil)
            }
            .keyboardShortcut(.space, modifiers: [])

            Button("Content Tab") {
                NotificationCenter.default.post(name: .agentTraceSelectInspectorTab, object: InspectorTab.context)
            }
            .keyboardShortcut("1", modifiers: [])

            Button("Parameters Tab") {
                NotificationCenter.default.post(name: .agentTraceSelectInspectorTab, object: InspectorTab.llmCall)
            }
            .keyboardShortcut("2", modifiers: [])

            Button("Resolution Tab") {
                NotificationCenter.default.post(name: .agentTraceSelectInspectorTab, object: InspectorTab.response)
            }
            .keyboardShortcut("3", modifiers: [])

            Divider()

            Button("Previous Node") {
                NotificationCenter.default.post(name: .agentTraceSelectPreviousNode, object: nil)
            }
            .keyboardShortcut("[", modifiers: .command)

            Button("Next Node") {
                NotificationCenter.default.post(name: .agentTraceSelectNextNode, object: nil)
            }
            .keyboardShortcut("]", modifiers: .command)

            Divider()

            Button("Replay Selected Node") {
                NotificationCenter.default.post(name: .agentTraceReplaySelectedNode, object: nil)
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("Reload") {
                NotificationCenter.default.post(name: .agentTraceReload, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.shift, .command])
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
    static let agentTraceCopyFailureAnalysisPrompt = Notification.Name("agentTraceCopyFailureAnalysisPrompt")
    static let agentTraceCopySelection = Notification.Name("agentTraceCopySelection")
    static let agentTraceClearView = Notification.Name("agentTraceClearView")
    static let agentTraceClearAllTraces = Notification.Name("agentTraceClearAllTraces")
    static let agentTraceShowInspector = Notification.Name("agentTraceShowInspector")
    static let agentTraceShowGraph = Notification.Name("agentTraceShowGraph")
    static let agentTraceToggleInspector = Notification.Name("agentTraceToggleInspector")
    static let agentTraceToggleQuickview = Notification.Name("agentTraceToggleQuickview")
    static let agentTraceFocusSearch = Notification.Name("agentTraceFocusSearch")
    static let agentTraceSelectInspectorTab = Notification.Name("agentTraceSelectInspectorTab")
    static let agentTraceSelectPreviousNode = Notification.Name("agentTraceSelectPreviousNode")
    static let agentTraceSelectNextNode = Notification.Name("agentTraceSelectNextNode")
    static let agentTraceReplaySelectedNode = Notification.Name("agentTraceReplaySelectedNode")
    static let agentTraceReload = Notification.Name("agentTraceReload")
    static let agentTraceShowOnboarding = Notification.Name("agentTraceShowOnboarding")
    static let agentTraceShowSettings = Notification.Name("agentTraceShowSettings")
    static let agentTraceResetGraphLayout = Notification.Name("agentTraceResetGraphLayout")
}
