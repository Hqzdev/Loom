import SwiftUI
import UI

struct GraphPaneHeader: View {
    let context: String
    let title: String
    let totalLatency: String
    let stepCount: Int
    let agentCount: String
    let statusText: String
    let statusColor: Color
    let onCopyFailureAnalysisPrompt: () -> Void
    let palette: AgentTracePalette

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(context)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .layoutPriority(1)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                HeaderMetric(
                    label: "Total Time",
                    value: totalLatency,
                    valueColor: palette.text,
                    palette: palette
                )
                HeaderMetric(
                    label: "Steps",
                    value: "\(stepCount)",
                    valueColor: palette.text,
                    palette: palette
                )
                HeaderMetric(
                    label: "Agents",
                    value: agentCount,
                    valueColor: palette.accent,
                    palette: palette
                )
                HeaderMetric(
                    label: "Status",
                    value: statusText,
                    valueColor: statusColor,
                    palette: palette
                )
            }
            .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 0)

            Button(action: onCopyFailureAnalysisPrompt) {
                Label("Analyze Failure", systemImage: "doc.on.clipboard")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(stepCount == 0)
            .help("Copy a JSON-only failure analysis prompt for the full trace")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 11)
        .background(palette.panel.opacity(0.72))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.border)
                .frame(height: 1)
        }
    }
}

private struct HeaderMetric: View {
    let label: String
    let value: String
    let valueColor: Color
    let palette: AgentTracePalette

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(palette.textQuaternary)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(palette.panelSecondary.opacity(0.72), in: RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                .stroke(palette.borderSoft, lineWidth: 1)
        }
    }
}
