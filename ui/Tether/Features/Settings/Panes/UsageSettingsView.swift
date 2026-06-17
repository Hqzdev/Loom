import Core
import Networking
import SwiftUI
import UI

/// Read-only usage dashboard aggregated from the live trace store.
struct UsageSettingsView: View {
    let palette: AgentTracePalette
    @EnvironmentObject private var traceStore: TraceStore

    @State private var statusMessage: String?
    @State private var statusIsError = false

    private var stats: UsageStats {
        UsageStats(nodes: traceStore.nodes)
    }

    var body: some View {
        SettingsPaneScaffold(
            title: "Usage",
            subtitle: "A live summary of the agent calls Tether has captured this session.",
            palette: palette
        ) {
            overviewSection
            tokensSection
            if !stats.modelBreakdown.isEmpty {
                modelSection
            }
            cacheSection

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(statusIsError ? palette.pinkText : palette.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var overviewSection: some View {
        SettingsSection("Overview", palette: palette) {
            SettingsValueRow("Total calls", value: "\(stats.nodeCount)", palette: palette)
            SettingsValueRow("Errors", value: "\(stats.errorCount)", palette: palette)
            SettingsValueRow("Cache hits", value: "\(stats.cachedCount)", palette: palette)
            SettingsValueRow("Total latency", value: stats.formattedTotalLatency, palette: palette)
            SettingsValueRow("Average latency", value: stats.formattedAverageLatency, palette: palette)
        }
    }

    private var tokensSection: some View {
        SettingsSection("Tokens & cost", palette: palette) {
            SettingsValueRow("Input tokens", value: stats.tokensIn.formatted(), palette: palette)
            SettingsValueRow("Output tokens", value: stats.tokensOut.formatted(), palette: palette)
            SettingsValueRow("Total tokens", value: stats.totalTokens.formatted(), palette: palette)
            SettingsValueRow("Estimated cost", value: stats.formattedCost, palette: palette)
        }
    }

    private var modelSection: some View {
        SettingsSection("By model", palette: palette) {
            ForEach(stats.modelBreakdown) { entry in
                SettingsValueRow(
                    entry.model,
                    subtitle: "\(entry.totalTokens.formatted()) tokens",
                    value: "\(entry.count) calls",
                    palette: palette
                )
            }
        }
    }

    private var cacheSection: some View {
        SettingsSection("Cache", palette: palette) {
            SettingsButtonRow(
                "Local response cache",
                subtitle: "Remove saved proxy cache files to force fresh upstream calls.",
                buttonTitle: "Clear Cache",
                systemImage: "trash",
                destructive: true,
                palette: palette
            ) {
                clearCache()
            }
        }
    }

    /// Clears the proxy response cache through the local API.
    private func clearCache() {
        Task {
            do {
                try await TraceAPIClient().clearCache()
                statusMessage = "Local response cache cleared."
                statusIsError = false
            } catch {
                statusMessage = error.localizedDescription
                statusIsError = true
            }
        }
    }
}

/// Aggregated, display-ready usage metrics derived from captured trace nodes.
private struct UsageStats {
    let nodeCount: Int
    let errorCount: Int
    let cachedCount: Int
    let totalLatencyMs: Int
    let tokensIn: Int
    let tokensOut: Int
    let totalCost: Double
    let modelBreakdown: [ModelUsage]

    var totalTokens: Int { tokensIn + tokensOut }

    var formattedTotalLatency: String { Self.formatLatency(totalLatencyMs) }

    var formattedAverageLatency: String {
        guard nodeCount > 0 else { return "—" }
        return Self.formatLatency(totalLatencyMs / nodeCount)
    }

    var formattedCost: String {
        guard totalCost > 0 else { return "$0.00" }
        return String(format: "$%.4f", totalCost)
    }

    init(nodes: [AgentNode]) {
        nodeCount = nodes.count
        errorCount = nodes.filter { $0.status == .error }.count
        cachedCount = nodes.filter { $0.status == .cached }.count
        totalLatencyMs = nodes.reduce(0) { $0 + $1.latencyMs }
        tokensIn = nodes.reduce(0) { $0 + $1.tokensIn }
        tokensOut = nodes.reduce(0) { $0 + $1.tokensOut }
        totalCost = nodes.reduce(0) { $0 + Self.parseCost($1.cost) }

        var grouped: [String: ModelUsage] = [:]
        for node in nodes {
            let key = node.model.isEmpty ? "Unknown" : node.model
            var entry = grouped[key] ?? ModelUsage(model: key, count: 0, totalTokens: 0)
            entry.count += 1
            entry.totalTokens += node.tokensIn + node.tokensOut
            grouped[key] = entry
        }
        modelBreakdown = grouped.values.sorted { $0.count > $1.count }
    }

    /// Parses a display cost string such as "$0.0123" into a Double.
    private static func parseCost(_ value: String) -> Double {
        let cleaned = value.filter { $0.isNumber || $0 == "." }
        return Double(cleaned) ?? 0
    }

    /// Formats a millisecond duration for the usage rows.
    private static func formatLatency(_ milliseconds: Int) -> String {
        if milliseconds >= 1000 {
            return String(format: "%.2fs", Double(milliseconds) / 1000.0)
        }
        return "\(milliseconds)ms"
    }
}

/// Per-model usage row used by the usage breakdown section.
private struct ModelUsage: Identifiable {
    let model: String
    var count: Int
    var totalTokens: Int

    var id: String { model }
}
