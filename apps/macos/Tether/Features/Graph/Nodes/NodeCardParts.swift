import Core
import SwiftUI
import UI

struct NodeCardHeader: View {
    let node: NodeCardModel
    let palette: AgentTracePalette

    var body: some View {
        HStack(spacing: 9) {
            StatusDot(status: node.status, palette: palette)
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.stepName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)

                Text(node.promptPreview)
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 6) {
                    AgentBadge(name: node.isExecutionEvent ? "Execution" : node.agentName, palette: palette)
                    if node.isExecutionEvent {
                        NodeInfoBadge(text: node.executionStatus, palette: palette)
                    }
                    if node.changedFileCount > 0 {
                        NodeInfoBadge(text: "Files \(node.changedFileCount)", palette: palette)
                    }
                    if let changedLineSummary = node.changedLineSummary {
                        NodeInfoBadge(text: changedLineSummary, palette: palette)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if node.stale {
                Text("STALE")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(palette.amber)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(palette.amber.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
            }
        }
    }
}

private struct NodeInfoBadge: View {
    let text: String
    let palette: AgentTracePalette

    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
            .foregroundStyle(palette.textTertiary)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(palette.panelSecondary.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                    .stroke(palette.borderSoft, lineWidth: 1)
            }
    }
}

struct NodeCardFooter: View {
    let node: NodeCardModel
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 7) {
            HStack(alignment: .top, spacing: 12) {
                NodeMetric(symbol: "clock", label: "Latency", value: node.latency, palette: palette)
                if node.isExecutionEvent {
                    NodeMetric(symbol: "terminal", label: "Result", value: node.executionStatus, palette: palette)
                } else {
                    NodeMetric(
                        symbol: "number",
                        label: "Tokens",
                        value: "\(node.tokensIn) in / \(node.tokensOut) out",
                        palette: palette
                    )
                }
            }

            if node.hasBillableCost {
                HStack {
                    NodeMetric(symbol: "creditcard", label: "Cost", value: node.cost, palette: palette)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.top, 9)
        .overlay(alignment: .top) {
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(palette.border)
        }
        .padding(.top, 9)
    }
}

private struct NodeMetric: View {
    let symbol: String
    let label: String
    let value: String
    let palette: AgentTracePalette

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(palette.textQuaternary)
                .frame(width: 12)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(palette.textQuaternary)
                    .lineLimit(1)

                Text(value)
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NodeCardBackground: View {
    let selected: Bool
    let isPerformanceMode: Bool
    let replayCostImproved: Bool
    let palette: AgentTracePalette

    var body: some View {
        ZStack {
            if isPerformanceMode {
                palette.nodeTop.opacity(0.72)
            } else {
                LinearGradient(
                    colors: [palette.nodeTop.opacity(0.62), palette.nodeBottom.opacity(0.42)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            if selected {
                palette.accentBackground.opacity(0.85)
            }

            if replayCostImproved {
                palette.greenBackground.opacity(0.70)
            }
        }
    }
}

struct NodeCardBorder: View {
    let selected: Bool
    let isReplay: Bool
    let palette: AgentTracePalette

    var body: some View {
        RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous)
            .stroke(
                selected ? palette.accent : palette.borderStrong,
                style: StrokeStyle(lineWidth: selected ? 2 : 1, dash: isReplay ? [4, 3] : [])
            )
    }
}
