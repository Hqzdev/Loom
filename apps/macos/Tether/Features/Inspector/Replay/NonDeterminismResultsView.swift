import Core
import SwiftUI
import UI

/// Sheet that compares repeated replay results to reveal provider non-determinism.
struct NonDeterminismResultsView: View {
    let runs: [TraceReplayResult]
    let palette: AgentTracePalette

    @Environment(\.dismiss) private var dismiss

    /// Number of runs whose output hash differs from the first run.
    private var differingCount: Int {
        guard let first = runs.first else { return 0 }
        return runs.filter { $0.outputHash != first.outputHash }.count
    }

    /// True when every run produced the same output hash.
    private var isDeterministic: Bool {
        differingCount == 0 && !runs.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .overlay(palette.border)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(runs.enumerated()), id: \.offset) { index, run in
                        RunRow(index: index + 1, run: run, palette: palette)

                        if index < runs.count - 1 {
                            Divider()
                                .overlay(palette.borderSoft)
                        }
                    }
                }
            }
        }
        .frame(width: 360, height: 320)
        .background(palette.panel)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Non-Determinism Check")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.text)

                verdict
            }

            Spacer(minLength: 0)

            Button("Done") { dismiss() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var verdict: some View {
        if isDeterministic {
            verdictBadge(text: "Deterministic", color: palette.green)
        } else if !runs.isEmpty {
            verdictBadge(
                text: "Non-deterministic (\(differingCount)/\(runs.count) differ)",
                color: palette.amber
            )
        }
    }

    private func verdictBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
    }
}

/// One replayed run rendered as a compact metadata row.
private struct RunRow: View {
    let index: Int
    let run: TraceReplayResult
    let palette: AgentTracePalette

    private var shortHash: String {
        String(run.outputHash.prefix(8))
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("Run #\(index)")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(palette.text)
                .frame(width: 54, alignment: .leading)

            Text(shortHash)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(palette.violet)

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text(run.cost)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(palette.textSecondary)

                Text("\(run.tokensIn) in / \(run.tokensOut) out")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(palette.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
