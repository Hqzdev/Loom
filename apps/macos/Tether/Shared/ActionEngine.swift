import Core
import Foundation

@MainActor
final class ActionEngine {
    static let shared = ActionEngine()

    private init() {}

    func plan(for node: AgentNode) -> ActionPlan? {
        guard node.isRepairCandidate else { return nil }

        if node.isExecutionEvent {
            return failedShellCommandPlan(for: node)
        }

        return nil
    }

    private func failedShellCommandPlan(for node: AgentNode) -> ActionPlan {
        let commandLine = node.contextInputs.execution?.commandLine ?? node.prompt.user
        let exitCode = node.contextInputs.execution?.exitCode.map(String.init) ?? node.error?.code ?? "unknown"
        let diffSummary = node.contextInputs.execution?.diffAfterSummary ?? "diff unavailable"

        return ActionPlan(
            id: "repair-plan-\(node.id)",
            title: "Repair failed shell command",
            causedBy: node.id,
            actionType: "shell.plan",
            summary: "Command failed with exit \(exitCode): \(commandLine)",
            credentialUse: "No credential will be read for this planning step.",
            steps: [
                ActionPlanStep(id: "inspect-output", title: "Inspect command output", detail: "Use retained stdout/stderr to classify the failure."),
                ActionPlanStep(id: "inspect-diff", title: "Inspect repository impact", detail: "Current git snapshot: \(diffSummary)."),
                ActionPlanStep(id: "choose-strategy", title: "Choose repair strategy", detail: "Prepare a dependency, test, auth, or command fix before execution."),
                ActionPlanStep(id: "wait-backend", title: "Wait for execution backend", detail: "/internal/actions/execute is required before Tether can run this plan.")
            ],
            executionAvailable: false
        )
    }
}

struct ActionPlan: Identifiable, Hashable {
    let id: String
    let title: String
    let causedBy: AgentNode.ID
    let actionType: String
    let summary: String
    let credentialUse: String
    let steps: [ActionPlanStep]
    let executionAvailable: Bool
}

struct ActionPlanStep: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
}
