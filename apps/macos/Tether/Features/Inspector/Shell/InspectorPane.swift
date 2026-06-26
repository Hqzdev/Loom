import Core
import Networking
import SwiftUI
import UI

struct SaveMockResponseAction: Sendable {
    let perform: @MainActor @Sendable (AgentNode, String) async throws -> TraceInvalidationResult

    init(_ perform: @escaping @MainActor @Sendable (AgentNode, String) async throws -> TraceInvalidationResult) {
        self.perform = perform
    }
}

struct RunMultipleAction: Sendable {
    let perform: @MainActor @Sendable (AgentNode, Int) async throws -> [TraceReplayResult]

    init(_ perform: @escaping @MainActor @Sendable (AgentNode, Int) async throws -> [TraceReplayResult]) {
        self.perform = perform
    }
}

struct ReplayWithModelAction: Sendable {
    let perform: @MainActor @Sendable (AgentNode, String) async throws -> ReplayResult

    init(_ perform: @escaping @MainActor @Sendable (AgentNode, String) async throws -> ReplayResult) {
        self.perform = perform
    }
}

struct InspectorPane: View {
    let node: AgentNode?
    @Binding var tab: InspectorTab
    @Binding var responseEdits: [AgentNode.ID: String]
    @Binding var replayImpacts: [AgentNode.ID: TraceInvalidationResult]
    let onSaveMockResponse: SaveMockResponseAction
    let onRunMultiple: RunMultipleAction
    let onReplayWithModel: ReplayWithModelAction
    let palette: AgentTracePalette

    @State private var editing = false
    @State private var draft = ""
    @State private var pendingActionPlan: ActionPlan?

    private var responseText: String {
        guard let node else { return "" }
        return responseEdits[node.id] ?? node.response.text
    }

    var body: some View {
        VStack(spacing: 0) {
            InspectorHeader(node: node, tab: $tab, palette: palette)

            if let node {
                InspectorBody(
                    node: node,
                    tab: tab,
                    responseText: responseText,
                    edited: responseEdits[node.id] != nil,
                    replayImpact: replayImpacts[node.id],
                    editing: editing,
                    draft: $draft,
                    palette: palette
                )
            } else {
                InspectorEmptyState(palette: palette)
            }

            if let node {
                if node.isRepairCandidate {
                    RepairCandidatePanel(node: node, palette: palette) {
                        pendingActionPlan = ActionEngine.shared.plan(for: node)
                    }
                }

                InspectorReplayFooter(
                    editing: $editing,
                    draft: $draft,
                    tab: $tab,
                    node: node,
                    responseText: responseText,
                    responseEdits: $responseEdits,
                    replayImpacts: $replayImpacts,
                    onSaveMockResponse: onSaveMockResponse,
                    onRunMultiple: onRunMultiple,
                    onReplayWithModel: onReplayWithModel,
                    palette: palette
                )
            }
        }
        .background(palette.panel.opacity(0.54))
        .onChange(of: node?.id) {
            editing = false
            draft = ""
            pendingActionPlan = nil
        }
        .onChange(of: tab) {
            editing = false
        }
        .sheet(item: $pendingActionPlan) { plan in
            ConfirmActionSheet(plan: plan, palette: palette)
        }
    }
}

private struct RepairCandidatePanel: View {
    let node: AgentNode
    let palette: AgentTracePalette
    let onPlan: () -> Void

    private var commandLine: String {
        if let commandLine = node.contextInputs.execution?.commandLine, !commandLine.isEmpty {
            return commandLine
        }
        return node.prompt.user
    }

    private var exitLabel: String {
        if let exitCode = node.contextInputs.execution?.exitCode {
            return "exit \(exitCode)"
        }
        return node.error.map { "exit \($0.code)" } ?? "failed"
    }

    private var planRows: [String] {
        [
            "Inspect stdout/stderr and git diff",
            "Classify failure as dependency, test, auth, or command error",
            "Build a confirmed repair plan before executing anything"
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.amber)
                    .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Repair candidate")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(palette.text)

                    Text("\(exitLabel) · \(commandLine)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(palette.textTertiary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 5) {
                ForEach(planRows, id: \.self) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("→")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(palette.textQuaternary)
                        Text(row)
                            .font(.system(size: 11))
                            .foregroundStyle(palette.textSecondary)
                    }
                }
            }

            Button {
                onPlan()
            } label: {
                Text("Review repair plan")
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
            }
            .buttonStyle(TimeTravelButtonStyle(role: .secondary, palette: palette))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(palette.amber.opacity(0.08))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.amber.opacity(0.24))
                .frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.border)
                .frame(height: 1)
        }
    }
}

private struct ConfirmActionSheet: View {
    let plan: ActionPlan
    let palette: AgentTracePalette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checklist.checked")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 5) {
                    Text(plan.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(palette.text)

                    Text(plan.summary)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(palette.textTertiary)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 0)
            }
            .padding(18)

            VStack(alignment: .leading, spacing: 0) {
                MetadataInlineRow(label: "Action", value: plan.actionType, palette: palette)
                MetadataInlineRow(label: "Caused By", value: plan.causedBy, palette: palette)
                MetadataInlineRow(label: "Credential", value: plan.credentialUse, palette: palette)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Will execute after backend is available")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.textTertiary)
                    .padding(.horizontal, 18)
                    .padding(.top, 14)

                ForEach(plan.steps) { step in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "circle")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(palette.textQuaternary)
                            .frame(width: 14, height: 18)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.title)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(palette.text)
                            Text(step.detail)
                                .font(.system(size: 11.5))
                                .foregroundStyle(palette.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
            .padding(.bottom, 14)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                }
                .buttonStyle(TimeTravelButtonStyle(role: .secondary, palette: palette))

                Button {
                } label: {
                    Text("Confirm execution unavailable")
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                }
                .buttonStyle(TimeTravelButtonStyle(role: .primary, palette: palette))
                .disabled(!plan.executionAvailable)
            }
            .padding(18)
            .background(palette.panelSecondary.opacity(0.60))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(palette.border)
                    .frame(height: 1)
            }
        }
        .frame(width: 520, height: 520)
        .background(palette.panel)
    }
}

private struct InspectorHeader: View {
    let node: AgentNode?
    @Binding var tab: InspectorTab
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                if let node {
                    HStack(alignment: .top, spacing: 12) {
                        Text(node.stepName)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(palette.text)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        InspectorStatusBadge(status: node.status, stale: node.stale, palette: palette)
                    }

                    InspectorModelBadges(node: node, palette: palette)
                } else {
                    Text("Inspector")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            InspectorTabPicker(tab: $tab, palette: palette)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.border)
                .frame(height: 1)
        }
    }
}

private struct InspectorStatusBadge: View {
    let status: NodeStatus
    let stale: Bool
    let palette: AgentTracePalette

    private var text: String {
        stale ? "STALE" : status.label
    }

    private var color: Color {
        stale ? palette.amber : palette.color(for: status)
    }

    private var background: Color {
        stale ? palette.amber.opacity(0.10) : palette.background(for: status)
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(color.opacity(0.22), lineWidth: 1)
            }
            .fixedSize()
    }
}

private struct InspectorModelBadges: View {
    let node: AgentNode
    let palette: AgentTracePalette

    var body: some View {
        HStack(spacing: 6) {
            AgentBadge(name: node.agentName, palette: palette)

            Text("\(node.provider) / \(node.model)")
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(palette.violet)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(palette.violet.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                        .stroke(palette.violetBorder, lineWidth: 1)
                )
        }
    }
}
