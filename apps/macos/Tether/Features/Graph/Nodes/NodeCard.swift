import Core
import SwiftUI
import UI

struct MovableNodeCard: View, Equatable {
    let node: NodeCardModel
    @ObservedObject var nodePosition: GraphNodePosition
    let selected: Bool
    let nodeSize: CGSize
    let isPerformanceMode: Bool
    let palette: AgentTracePalette

    var body: some View {
        NodeCard(node: node, selected: selected, size: nodeSize, isPerformanceMode: isPerformanceMode, palette: palette)
            .position(x: nodePosition.position.x + nodeSize.width / 2, y: nodePosition.position.y + nodeSize.height / 2)
            .scaleEffect(nodePosition.isDragging ? 1.008 : 1)
            .zIndex(nodePosition.isDragging ? 30 : selected ? 10 : 1)
            .contentShape(RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous))
            .allowsHitTesting(false)
            .transaction { transaction in
                if nodePosition.isDragging {
                    transaction.animation = nil
                }
            }
    }

    static func == (lhs: MovableNodeCard, rhs: MovableNodeCard) -> Bool {
        lhs.node == rhs.node
            && lhs.nodePosition === rhs.nodePosition
            && lhs.selected == rhs.selected
            && lhs.nodeSize == rhs.nodeSize
            && lhs.isPerformanceMode == rhs.isPerformanceMode
            && lhs.palette == rhs.palette
    }
}

struct NodeCardModel: Identifiable, Equatable {
    let id: AgentNode.ID
    let agentName: String
    let stepName: String
    let provider: String
    let model: String
    let cost: String
    let latency: String
    let barPercent: Double
    let tokensIn: Int
    let tokensOut: Int
    let requestId: String
    let stale: Bool
    let isReplay: Bool
    let replayCostImproved: Bool
    let status: NodeStatus
    let promptPreview: String
    let changedFileCount: Int
    let changedLineSummary: String?
    let isExecutionEvent: Bool
    let executionStatus: String

    var hasBillableCost: Bool {
        !isExecutionEvent && cost != "$0.0000" && cost != "$0" && cost != "$0.00"
    }

    init(
        node: AgentNode,
        replayCostImproved: Bool = false,
        workSummary: AgentNodeWorkSummary? = nil
    ) {
        let workSummary = workSummary ?? AgentNodeWorkSummary(promptText: node.cardPreviewText)
        id = node.id
        agentName = node.agentName
        stepName = node.stepName
        provider = node.provider
        model = node.model
        cost = node.cost
        latency = node.latency
        barPercent = node.barPercent
        tokensIn = node.tokensIn
        tokensOut = node.tokensOut
        requestId = node.requestId
        stale = node.stale
        isReplay = node.isReplay
        self.replayCostImproved = replayCostImproved
        status = node.status
        promptPreview = workSummary.promptText
        changedFileCount = workSummary.fileCount
        changedLineSummary = workSummary.lineSummary
        isExecutionEvent = node.isExecutionEvent
        executionStatus = node.status == .success ? "exit 0" : node.error.map { "exit \($0.code)" } ?? node.status.label.lowercased()
    }
}

private extension AgentNode {
    var cardPreviewText: String {
        return workPromptText
    }
}

private struct NodeCard: View {
    let node: NodeCardModel
    let selected: Bool
    let size: CGSize
    let isPerformanceMode: Bool
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 0) {
            NodeCardHeader(node: node, palette: palette)
            ProgressBar(value: node.barPercent, status: node.status, palette: palette)
                .padding(.top, 10)
            NodeCardFooter(node: node, palette: palette)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
        .background(
            NodeCardBackground(
                selected: selected,
                isPerformanceMode: isPerformanceMode,
                replayCostImproved: node.isReplay && node.replayCostImproved,
                palette: palette
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(palette.color(for: node.status))
                .frame(width: 3)
                .padding(.vertical, 10)
        }
        .overlay(NodeCardBorder(selected: selected, isReplay: node.isReplay, palette: palette))
        .shadow(color: selected && !isPerformanceMode ? Color(hex: 0x0f172a).opacity(0.10) : .clear, radius: 12, x: 0, y: 6)
        .overlay {
            if !isPerformanceMode {
                NodeAnchorMarkers(palette: palette)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .padding(6)
        }
        .overlay(alignment: .topTrailing) {
            if node.isReplay {
                Text("↻")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(palette.violet)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(palette.violet.opacity(0.10))
                    .clipShape(Capsule())
                    .padding(8)
            }
        }
    }
}
