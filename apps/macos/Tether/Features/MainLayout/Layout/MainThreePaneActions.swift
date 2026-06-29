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
                reason: "local-agent-log-mock",
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
        if node.cacheStatus == "codex-log" {
            return (0..<max(1, count)).map { _ in
                TraceReplayResult(
                    nodeId: node.id,
                    reason: "local-agent-log-not-replayable",
                    previousOutputHash: node.outputHash,
                    outputHash: node.outputHash,
                    statusCode: 204,
                    cost: "$0.0000",
                    tokensIn: node.tokensIn,
                    tokensOut: node.tokensOut,
                    invalidated: []
                )
            }
        }

        var results: [TraceReplayResult] = []
        results.reserveCapacity(count)
        for _ in 0..<max(1, count) {
            let result = try await traceStore.client.replayNode(nodeId: node.id)
            results.append(result)
        }
        await traceStore.refresh()
        return results
    }

    /// Creates a CometAPI replay branch using a different model.
    @MainActor
    func replayWithModel(node: AgentNode, model: String) async throws -> ReplayResult {
        let result = try await CometAPIClient.replayWithModel(traceId: node.id, model: model)
        await traceStore.refresh()
        return result
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

    func copyFailureAnalysisPrompt() {
        Task { @MainActor in
            await traceStore.loadVisibleNodeDetailsIfNeeded()
            let snapshot = TraceSnapshot(nodes: nodes)

            guard !snapshot.nodes.isEmpty else {
                showShortcutFeedback("No trace to analyze")
                return
            }

            do {
                let data = try jsonData(for: snapshot)
                let traceJSON = String(data: data, encoding: .utf8) ?? "{}"
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(failureAnalysisPrompt(traceJSON: traceJSON), forType: .string)
                showShortcutFeedback("Failure analysis prompt copied")
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    func failureAnalysisPrompt(traceJSON: String) -> String {
        """
        You are analyzing an AI agent trace to find the root cause of failure.

        TRACE:
        \(traceJSON)

        Analyze the trace and identify:
        1. The exact step index where the agent first went wrong
        2. The error type from this list:
           - IGNORED_TOOL_OUTPUT (tool was called but result not used in next prompt)
           - HALLUCINATED_FACT (agent stated fact not present in any tool result)
           - LOOP_DETECTED (same tool called 3+ times with same/similar input)
           - MISSING_CONTEXT (agent lacked information needed to proceed correctly)
           - PROMPT_AMBIGUITY (instruction was unclear causing wrong direction)
           - CONFLICTING_MEMORY (injected context contradicted tool output)
        3. One sentence explanation of what went wrong
        4. One sentence of what should have happened instead

        Return ONLY valid JSON, no markdown, no explanation:
        {
          "step_index": 2,
          "error_type": "IGNORED_TOOL_OUTPUT",
          "explanation": "Agent received search result but constructed next prompt without including it.",
          "suggestion": "Inject tool output directly into next prompt context."
        }

        If no error found, return:
        { "step_index": -1, "error_type": "NONE", "explanation": "No failure detected.", "suggestion": "" }
        """
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
