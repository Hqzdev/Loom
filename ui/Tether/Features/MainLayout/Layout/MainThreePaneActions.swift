import AppKit
import Core
import Foundation
import Networking
import UniformTypeIdentifiers

extension MainThreePaneLayoutView {
    /// Clears transient UI state without deleting captured trace nodes.
    func returnToLiveView() {
        resetTransientSelection()
    }

    /// Permanently deletes every stored trace node.
    /// This is the only path that removes history; invoked from Privacy settings.
    func deleteAllHistory() {
        resetTransientSelection()
        traceStore.clearTrace()
    }

    /// Clears transient inspector edits and node selection on a trace reset.
    func resetTransientSelection() {
        responseEdits.removeAll()
        replayImpacts.removeAll()
        selectedNodeId = nil
    }

    /// Persists a mocked response through the proxy when possible and returns replay-boundary evidence.
    @MainActor
    func saveMockResponse(node: AgentNode, output: String) async throws -> TraceInvalidationResult {
        if node.cacheStatus == "codex-log" {
            return TraceInvalidationResult(
                nodeId: node.id,
                reason: "local-codex-log-mock",
                previousOutputHash: node.outputHash,
                outputHash: AgentNode.shortHash(output),
                invalidated: []
            )
        }

        let result = try await traceStore.client.editNodeOutput(nodeId: node.id, output: output)
        await traceStore.refresh()
        return result
    }

    /// Replays a node `count` times sequentially to surface provider non-determinism.
    @MainActor
    func runMultiple(node: AgentNode, count: Int = 3) async throws -> [TraceReplayResult] {
        var results: [TraceReplayResult] = []
        results.reserveCapacity(count)
        for _ in 0..<max(1, count) {
            let result = try await traceStore.client.replayNode(nodeId: node.id)
            results.append(result)
        }
        await traceStore.refresh()
        return results
    }

    /// Copies the currently selected inspector content to the pasteboard.
    func copySelection() {
        guard let text = clipboardTextForSelectedNode(), !text.isEmpty else {
            NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Exports the current trace snapshot as JSON or CSV.
    func exportTraces() {
        Task { @MainActor in
            await traceStore.loadVisibleNodeDetailsIfNeeded()
            presentExportPanel(for: TraceSnapshot(nodes: nodes))
        }
    }

    /// Presents the trace export panel for an already-hydrated snapshot.
    private func presentExportPanel(for snapshot: TraceSnapshot) {
        let panel = NSSavePanel()
        panel.title = "Export Traces"
        panel.nameFieldStringValue = "Tether-\(exportTimestamp()).json"
        panel.allowedContentTypes = [.json, .commaSeparatedText]
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            do {
                let data = url.pathExtension.lowercased() == "csv"
                    ? csvData(for: snapshot)
                    : try jsonData(for: snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    /// Returns pasteboard text matching the active inspector tab.
    func clipboardTextForSelectedNode() -> String? {
        guard let node = selectedNode else { return nil }

        switch inspectorTab {
        case .context:
            return contextClipboardText(for: node)
        case .llmCall:
            return llmCallClipboardText(for: node)
        case .response:
            return responseEdits[node.id] ?? node.response.text
        case .metadata:
            return metadataClipboardText(for: node)
        }
    }

    /// Copies the redacted context boundary instead of raw prompt text.
    func contextClipboardText(for node: AgentNode) -> String {
        let sources = AgentContextCategory.allCases.flatMap { category in
            node.contextInputs.sources
                .filter { $0.category == category }
                .map { source in
                    "\(category.title): \(source.pathOrId) #\(source.hash) \(source.sizeBytes)b"
                }
        }
        let withheld = node.contextInputs.withheld.isEmpty
            ? "Withheld: none"
            : "Withheld: \(node.contextInputs.withheld.joined(separator: ", "))"

        return ([
            "Input hash: \(node.inputHash)",
            "Output hash: \(node.outputHash)",
            withheld
        ] + sources).joined(separator: "\n")
    }

    /// Copies LLM call metadata without prompt/response bodies.
    func llmCallClipboardText(for node: AgentNode) -> String {
        [
            "Provider: \(node.provider)",
            "Model: \(node.model)",
            "Input hash: \(node.inputHash)",
            "Output hash: \(node.outputHash)",
            "Latency: \(node.latency)",
            "Cost: \(node.cost)",
            "Tokens: \(node.tokensIn) in / \(node.tokensOut) out",
            "Request ID: \(node.requestId)"
        ].joined(separator: "\n")
    }

    /// Encodes a snapshot for JSON export.
    func jsonData(for snapshot: TraceSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }

    /// Encodes a snapshot for CSV export.
    func csvData(for snapshot: TraceSnapshot) -> Data {
        let rows = csvRows(for: snapshot)
        let csv = rows
            .map { row in row.map(escapeCSV).joined(separator: ",") }
            .joined(separator: "\n")

        return Data(csv.utf8)
    }

    /// Escapes a value for RFC4180-style CSV output.
    func escapeCSV(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    /// Creates a timestamp suffix for exported trace files.
    func exportTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
