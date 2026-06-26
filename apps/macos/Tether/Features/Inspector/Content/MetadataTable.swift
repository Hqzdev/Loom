import Core
import SwiftUI
import UI

struct MetadataTable: View {
    let node: AgentNode
    let edited: Bool
    let palette: AgentTracePalette

    private var rows: [(String, String, Color?)] {
        var rows = [
            ("Request ID", node.requestId, nil),
            ("Agent", node.isExecutionEvent ? "Execution" : node.agentName, nil),
            ("Provider", node.provider, nil),
            ("Status", node.error?.code ?? node.status.label, palette.color(for: node.status)),
            ("Model", node.model, nil),
            ("Exact Latency", node.latency, node.status == .cached ? palette.cyan : nil),
            ("Tokens In", "\(node.tokensIn)", nil),
            ("Tokens Out", "\(node.tokensOut)", nil),
            ("Cost", node.cost, nil),
            ("Cache Status", node.cacheStatus, node.cacheStatus == "HIT" ? palette.cyan : nil),
            ("Temperature", node.temperature.map { String(format: "%.2f", $0) } ?? "n/a", nil),
            ("Input Hash", node.inputHash, nil),
            ("Output Hash", node.outputHash, nil),
            ("Replay State", node.stale ? "STALE" : "fresh", node.stale ? palette.amber : nil),
            ("Timestamp", node.timestamp, nil),
            ("Mock Override", edited ? "ACTIVE" : "none", edited ? palette.pink : nil)
        ]
        if let execution = node.contextInputs.execution {
            rows.insert(("Command", execution.commandLine, nil), at: 1)
            rows.insert(("CWD", execution.cwd, nil), at: 2)
            rows.insert(("Exit Code", execution.exitCode.map(String.init) ?? "n/a", palette.color(for: node.status)), at: 3)
            rows.insert(("Git Diff", execution.diffAfterSummary, nil), at: 4)
        }
        return rows
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(rows, id: \.0) { row in
                    MetadataRow(row: row, palette: palette)
                }
            }
        }
        .background(palette.panel.opacity(0.52))
    }
}

private struct MetadataRow: View {
    let row: (String, String, Color?)
    let palette: AgentTracePalette

    var body: some View {
        HStack(spacing: 16) {
            Text(row.0)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(palette.textTertiary)
                .frame(width: 132, alignment: .leading)

            Text(row.1)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(row.2 ?? palette.text)
                .lineLimit(nil)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.borderSoft)
                .frame(height: 1)
        }
    }
}
