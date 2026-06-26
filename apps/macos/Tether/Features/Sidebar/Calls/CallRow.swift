import Core
import SwiftUI
import UI

struct CallRow: View, Equatable {
    let node: CallRowModel
    let selected: Bool
    let onSelect: () -> Void
    let palette: AgentTracePalette

    static func == (lhs: CallRow, rhs: CallRow) -> Bool {
        lhs.node == rhs.node
            && lhs.selected == rhs.selected
            && lhs.palette == rhs.palette
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 9) {
                CallStatusRail(status: node.status, selected: selected, palette: palette)
                CallRowBody(node: node, palette: palette)
                CallRowMetrics(node: node, palette: palette)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(selected ? palette.active.opacity(0.70) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                    .stroke(selected ? palette.borderStrong : palette.borderSoft.opacity(0.0), lineWidth: 1)
            )
            .overlay(alignment: .leading) {
                if selected {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(palette.accent)
                        .frame(width: 2.5)
                        .padding(.vertical, 8)
                        .offset(x: -8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct CallRowModel: Identifiable, Equatable {
    let id: AgentNode.ID
    let agentName: String
    let stepName: String
    let timestamp: String
    let provider: String
    let model: String
    let cost: String
    let latency: String
    let stale: Bool
    let status: NodeStatus

    var hasBillableCost: Bool {
        cost != "$0.0000" && cost != "$0" && cost != "$0.00"
    }

    init(node: AgentNode) {
        id = node.id
        agentName = node.agentName
        stepName = node.stepName
        timestamp = node.timestamp
        provider = node.provider
        model = node.model
        cost = node.cost
        latency = node.latency
        stale = node.stale
        status = node.status
    }
}

private struct CallStatusRail: View {
    let status: NodeStatus
    let selected: Bool
    let palette: AgentTracePalette

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(palette.color(for: status))
            .frame(width: selected ? 3 : 2, height: 30)
            .padding(.top, 1)
            .frame(width: 7, alignment: .leading)
            .accessibilityHidden(true)
    }
}
