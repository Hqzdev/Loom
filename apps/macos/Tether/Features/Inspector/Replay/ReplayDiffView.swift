import Core
import Networking
import SwiftUI
import UI

/// Side-by-side comparison between an original node and a CometAPI replay branch.
struct ReplayDiffView: View {
    let original: AgentNode
    let replay: ReplayResult
    let palette: AgentTracePalette

    private var replayTokenTotal: Int {
        replay.inputTokens + replay.outputTokens
    }

    private var originalTokenTotal: Int {
        original.tokensIn + original.tokensOut
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Cross-model replay")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(palette.text)

            HStack(alignment: .top, spacing: 0) {
                comparisonPane(
                    title: "Original",
                    model: original.model,
                    cost: original.cost,
                    latency: "\(original.latencyMs)ms",
                    tokens: "\(originalTokenTotal) tokens",
                    text: original.response.text,
                    highlights: originalHighlights
                )

                Rectangle()
                    .fill(palette.border)
                    .frame(width: 1)

                comparisonPane(
                    title: "CometAPI Replay",
                    model: replay.model,
                    cost: String(format: "$%.4f", replay.costUsd),
                    latency: "\(replay.latencyMs)ms",
                    tokens: "\(replayTokenTotal) tokens",
                    text: replay.responseText,
                    highlights: replayHighlights
                )
            }
            .background(palette.panel.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
        }
        .padding(20)
        .frame(width: 820, height: 560)
        .background(palette.window)
    }

    private func comparisonPane(
        title: String,
        model: String,
        cost: String,
        latency: String,
        tokens: String,
        text: String,
        highlights: Set<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text(model)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(palette.violet)
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                metricText(cost, better: isReplayCostBetter(for: cost))
                metricText(latency, better: isReplayLatencyBetter(for: latency))
                Text(tokens)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(palette.textTertiary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(sentences(in: text).enumerated()), id: \.offset) { index, sentence in
                        Text(sentence)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(palette.text)
                            .textSelection(.enabled)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                highlights.contains(index)
                                    ? Color.yellow.opacity(0.20)
                                    : Color.clear
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func metricText(_ value: String, better: Bool?) -> some View {
        Text(value)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(metricColor(better))
    }

    private func metricColor(_ better: Bool?) -> Color {
        guard let better else { return palette.textTertiary }
        return better ? palette.green : palette.pinkText
    }

    private func isReplayCostBetter(for displayed: String) -> Bool? {
        guard displayed.hasPrefix("$") else { return nil }
        let originalCost = costValue(original.cost)
        if displayed == original.cost { return nil }
        return replay.costUsd < originalCost
    }

    private func isReplayLatencyBetter(for displayed: String) -> Bool? {
        guard displayed == "\(replay.latencyMs)ms" else { return nil }
        return replay.latencyMs < original.latencyMs
    }

    private var originalHighlights: Set<Int> {
        differingSentenceIndexes(left: sentences(in: original.response.text), right: sentences(in: replay.responseText))
    }

    private var replayHighlights: Set<Int> {
        differingSentenceIndexes(left: sentences(in: replay.responseText), right: sentences(in: original.response.text))
    }

    private func differingSentenceIndexes(left: [String], right: [String]) -> Set<Int> {
        Set(left.indices.filter { index in
            guard index < right.count else { return true }
            return left[index] != right[index]
        })
    }

    private func sentences(in text: String) -> [String] {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [""] }
        let parts = normalized
            .replacingOccurrences(of: "\n\n", with: "\n")
            .split(whereSeparator: { character in
                character == "\n" || character == "." || character == "!" || character == "?"
            })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? [normalized] : parts
    }

    private func costValue(_ value: String) -> Double {
        Double(value.trimmingCharacters(in: CharacterSet(charactersIn: "$"))) ?? 0
    }
}
