import Core
import Networking
import SwiftUI
import UI

struct InspectorReplayFooter: View {
    @Binding var editing: Bool
    @Binding var draft: String
    @Binding var tab: InspectorTab
    let node: AgentNode
    let responseText: String
    @Binding var responseEdits: [AgentNode.ID: String]
    @Binding var replayImpacts: [AgentNode.ID: TraceInvalidationResult]
    let onSaveMockResponse: SaveMockResponseAction
    let onRunMultiple: RunMultipleAction
    let onReplayWithModel: ReplayWithModelAction
    let palette: AgentTracePalette
    @State private var saving = false
    @State private var saveError: String?
    @State private var runs: [TraceReplayResult] = []
    @State private var showingRunResults = false
    @State private var running = false
    @State private var runError: String?

    private let runCount = 3

    private var replayUnsupportedReason: String? {
        node.replayUnsupportedReason
    }

    var body: some View {
        VStack(spacing: 12) {
            if let replayUnsupportedReason {
                Text(replayUnsupportedReason)
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            } else if editing {
                Button {
                    saveDraft()
                } label: {
                    Text(saving ? "Saving replay boundary..." : "Save mocked response and replay")
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(TimeTravelButtonStyle(role: .primary, palette: palette))
                .disabled(saving)

                Button {
                    editing = false
                    saveError = nil
                } label: {
                    Text(saveError ?? "Downstream steps will re-run against this edit - cancel")
                        .font(.system(size: 11))
                        .foregroundStyle(saveError == nil ? palette.textTertiary : palette.pinkText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            } else {
                ReplayAction(
                    title: "Time-travel - edit response",
                    caption: nil,
                    role: .primary,
                    disabled: false,
                    palette: palette
                ) {
                    draft = responseText
                    editing = true
                    tab = .response
                }

                ReplayAction(
                    title: running ? "Running \(runCount)x..." : "Run \(runCount)x and compare",
                    caption: runError,
                    role: .secondary,
                    disabled: running,
                    captionColor: palette.pinkText,
                    palette: palette,
                    action: runMultiple
                )
            }

            if replayUnsupportedReason == nil {
                CometReplaySection(
                    node: node,
                    onReplayWithModel: onReplayWithModel,
                    palette: palette
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(palette.panelSecondary.opacity(0.50))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.border)
                .frame(height: 1)
        }
        .sheet(isPresented: $showingRunResults) {
            NonDeterminismResultsView(runs: runs, palette: palette)
        }
    }

    private func runMultiple() {
        guard !running else { return }

        running = true
        runError = nil
        Task {
            do {
                let results = try await onRunMultiple.perform(node, runCount)
                await MainActor.run {
                    runs = results
                    running = false
                    showingRunResults = true
                }
            } catch {
                await MainActor.run {
                    runError = error.localizedDescription
                    running = false
                }
            }
        }
    }

    private func saveDraft() {
        guard !saving else { return }

        saving = true
        saveError = nil
        Task {
            do {
                let impact = try await onSaveMockResponse.perform(node, draft)
                await MainActor.run {
                    responseEdits[node.id] = draft
                    replayImpacts[node.id] = impact
                    editing = false
                    tab = .context
                    saving = false
                }
            } catch {
                await MainActor.run {
                    saveError = error.localizedDescription
                    saving = false
                }
            }
        }
    }
}

private extension AgentNode {
    var replayUnsupportedReason: String? {
        let source = provider.lowercased()
        if source == "codex-log" || cacheStatus == "codex-log" {
            return "This node came from a local source log. Replay needs a proxy-captured request, so inspect the local evidence here or capture the run through the Tether proxy."
        }
        return nil
    }
}
