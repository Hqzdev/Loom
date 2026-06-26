import Combine
import Core
import Networking
import SwiftUI
import UI

/// Main-actor state owner for the trace graph. It polls the single live trace
/// stream and combines proxy captures with local Codex observations.
@MainActor
final class TraceStore: ObservableObject {
    /// Calls captured in the current live trace stream.
    @Published var nodes: [AgentNode] = []

    @Published var proxyStatus: ProxyConnectionStatus = .connecting
    @Published var workspaceChanges: WorkspaceChangeSummary = .empty
    @Published var nodeWorkSummaries: [AgentNode.ID: AgentNodeWorkSummary] = [:]

    let client: TraceAPIClient
    let codexObserver: CodexLogObserver
    var pollingTask: Task<Void, Never>?
    var codexBaselineLogId: Int?
    var graphInteractionActive = false
    var refreshAfterInteraction = false
    var deferredSnapshot: TraceSnapshot?
    var nodeDetails: [AgentNode.ID: AgentNode] = [:]
    var loadingNodeDetailIds: Set<AgentNode.ID> = []
    var lastWorkspaceSnapshot: WorkspaceSnapshot?
    var pendingAttributionNodeIds: [AgentNode.ID] = []

    /// Creates a store backed by the local proxy client and Codex log observer.
    init(
        client: TraceAPIClient? = nil,
        codexObserver: CodexLogObserver = CodexLogObserver()
    ) {
        self.client = client ?? TraceAPIClient()
        self.codexObserver = codexObserver
    }

    /// Starts the periodic refresh loop if it is not already running.
    func startPolling() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                if self.graphInteractionActive {
                    self.refreshAfterInteraction = true
                    do {
                        try await Task.sleep(for: .milliseconds(180))
                    } catch {
                        break
                    }
                    continue
                }

                await refresh()
                await refreshWorkspaceChanges()

                do {
                    try await Task.sleep(for: .seconds(1.2))
                } catch {
                    break
                }
            }
        }
    }

    func refreshWorkspaceChanges() async {
        let snapshot = await WorkspaceChangeReader.snapshot()
        let summary = snapshot.summary
        if workspaceChanges != summary {
            workspaceChanges = summary
        }

        attributePendingNodes(using: snapshot)
        lastWorkspaceSnapshot = snapshot
    }

    /// Stops the periodic refresh loop.
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Refreshes the combined live proxy + Codex stream.
    func refresh() async {
        guard !graphInteractionActive else {
            refreshAfterInteraction = true
            return
        }

        await refreshLive()
    }

    /// Polls the live view, combining the proxy trace stream with local Codex events.
    private func refreshLive() async {
        async let codexResult = loadCodexSnapshot()
        let proxyResult = await loadProxySnapshot()
        let codex = await codexResult
        guard !shouldDeferRefreshResult() else { return }

        let proxySnapshot = try? proxyResult.get()
        let codexSnapshot = try? codex.get()
        let proxyError: Error? = {
            if case .failure(let error) = proxyResult { return error }
            return nil
        }()

        if let combinedSnapshot = combinedSnapshot(
            proxySnapshot: proxySnapshot,
            codexSnapshot: codexSnapshot
        ) {
            apply(snapshot: combinedSnapshot)
            proxyStatus = .observingAgents(agentSummary(for: combinedSnapshot.nodes))
            return
        }

        if let proxySnapshot, !proxySnapshot.nodes.isEmpty {
            apply(snapshot: proxySnapshot)
            proxyStatus = .online
            return
        }

        if let codexSnapshot, !codexSnapshot.nodes.isEmpty {
            apply(snapshot: codexSnapshot)
            proxyStatus = .observingCodex("Watching Terminal Codex automatically")
            return
        }

        if let proxySnapshot {
            apply(snapshot: proxySnapshot)
            proxyStatus = .online
            return
        }

        if let codexSnapshot {
            apply(snapshot: codexSnapshot)
            proxyStatus = .observingCodex("Open Terminal and run codex")
            return
        }

        proxyStatus = .offline(proxyError?.localizedDescription ?? "Start the proxy or run codex in Terminal")
    }

    /// Applies a snapshot to the currently visible graph.
    func apply(snapshot: TraceSnapshot) {
        guard !graphInteractionActive else {
            deferredSnapshot = snapshot
            return
        }

        commit(snapshot: snapshot)
    }

    /// Marks graph gestures so refreshes do not invalidate SwiftUI during drag or pan.
    func setGraphInteractionActive(_ isActive: Bool) {
        guard graphInteractionActive != isActive else { return }

        graphInteractionActive = isActive

        guard !isActive else { return }

        flushDeferredTraceUpdates()

        if refreshAfterInteraction {
            refreshAfterInteraction = false
            Task { [weak self] in
                await self?.refresh()
            }
        }
    }

    /// Applies buffered updates once the current graph gesture ends.
    func flushDeferredTraceUpdates() {
        if let snapshot = deferredSnapshot {
            deferredSnapshot = nil
            commit(snapshot: snapshot)
        }
    }

    /// Commits a snapshot. Only writes when visible state changes.
    func commit(snapshot: TraceSnapshot) {
        let incomingNodes = snapshot.nodes.map(hydrated(_:))
        guard !incomingNodes.isEmpty else {
            if nodes.isEmpty {
                return
            }

            return
        }

        let existingIds = Set(nodes.map(\.id))
        let liveCluster = mergedVisibleNodes(with: incomingNodes)
        let newNodeIds = liveCluster
            .filter { !existingIds.contains($0.id) }
            .map(\.id)
        trackNewNodesForAttribution(newNodeIds, in: liveCluster)

        guard nodes != liveCluster else {
            return
        }

        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            nodes = liveCluster
        }
    }

    private func trackNewNodesForAttribution(_ nodeIds: [AgentNode.ID], in nodes: [AgentNode]) {
        guard !nodeIds.isEmpty else { return }

        for nodeId in nodeIds {
            if let node = nodes.first(where: { $0.id == nodeId }) {
                nodeWorkSummaries[nodeId] = AgentNodeWorkSummary(promptText: node.workPromptText)
            }
        }

        pendingAttributionNodeIds.append(contentsOf: nodeIds)
    }

    private func attributePendingNodes(using snapshot: WorkspaceSnapshot) {
        guard !pendingAttributionNodeIds.isEmpty else { return }

        let changed = lastWorkspaceSnapshot.map { snapshot.changedSummary(since: $0) } ?? .empty
        guard changed.hasChanges, let targetNodeId = pendingAttributionNodeIds.last else { return }

        for nodeId in pendingAttributionNodeIds {
            guard let node = nodes.first(where: { $0.id == nodeId }) else { continue }
            let existing = nodeWorkSummaries[nodeId]
            let files = nodeId == targetNodeId ? changed.files : existing?.changedFiles ?? []
            nodeWorkSummaries[nodeId] = AgentNodeWorkSummary(
                promptText: node.workPromptText,
                changedFiles: files
            )
        }

        pendingAttributionNodeIds.removeAll()
    }

    private func mergedVisibleNodes(with incomingNodes: [AgentNode]) -> [AgentNode] {
        var nodesById: [AgentNode.ID: AgentNode] = [:]
        var orderedIds = nodes.map(\.id)

        for node in nodes {
            nodesById[node.id] = node
        }

        for node in incomingNodes {
            if nodesById[node.id] == nil {
                orderedIds.append(node.id)
            }

            nodesById[node.id] = node
        }

        let mergedNodes = orderedIds.compactMap { nodesById[$0] }
        return relayoutGroupedNodes(mergedNodes)
    }

    private func relayoutGroupedNodes(_ mergedNodes: [AgentNode]) -> [AgentNode] {
        var groupOrder: [String] = []
        var nextDepthByGroup: [String: Int] = [:]
        let groupByNodeId = resolvedGroupIds(for: mergedNodes)
        let maxLatency = max(mergedNodes.map(\.latencyMs).max() ?? 0, 1)

        return mergedNodes.map { node in
            let groupId = groupByNodeId[node.id] ?? node.graphGroupId
            if !groupOrder.contains(groupId) {
                groupOrder.append(groupId)
            }

            let depth = nextDepthByGroup[groupId, default: 0]
            nextDepthByGroup[groupId] = depth + 1

            return node.withGraphLayout(
                depth: depth,
                barPercent: max(0.06, min(Double(node.latencyMs) / Double(maxLatency), 1.0))
            )
        }
    }

    private func resolvedGroupIds(for nodes: [AgentNode]) -> [AgentNode.ID: String] {
        var groups: [AgentNode.ID: String] = [:]

        for node in nodes {
            groups[node.id] = node.graphGroupId
        }

        for node in nodes where node.isReplay {
            if let sourceId = node.replaySourceId, let sourceGroupId = groups[sourceId] {
                groups[node.id] = sourceGroupId
            }
        }

        return groups
    }

    /// Attaches any lazily loaded inspector payload to a graph summary node.
    private func hydrated(_ node: AgentNode) -> AgentNode {
        guard let detail = nodeDetails[node.id] else { return node }
        return node.hydrated(with: detail)
    }

    /// Drops buffered live updates after an explicit clear or trace reset.
    func resetDeferredTraceUpdates() {
        deferredSnapshot = nil
        refreshAfterInteraction = false
        nodeDetails = [:]
        loadingNodeDetailIds = []
        nodeWorkSummaries = [:]
        pendingAttributionNodeIds = []
        lastWorkspaceSnapshot = nil
    }

    /// Returns true when an in-flight refresh should yield to active graph input.
    func shouldDeferRefreshResult() -> Bool {
        guard graphInteractionActive else { return false }

        refreshAfterInteraction = true
        return true
    }

    /// Lazily hydrates prompt/response/error payloads for the selected proxy node.
    func loadNodeDetailIfNeeded(_ nodeId: AgentNode.ID) async {
        guard let node = nodes.first(where: { $0.id == nodeId }),
              node.needsDetailPayload,
              nodeDetails[nodeId] == nil,
              !loadingNodeDetailIds.contains(nodeId)
        else {
            return
        }

        loadingNodeDetailIds.insert(nodeId)
        defer {
            loadingNodeDetailIds.remove(nodeId)
        }

        do {
            let detail = try await client.traceNodeDetail(nodeId: nodeId)
            nodeDetails[nodeId] = detail
            hydrateVisibleNode(nodeId, with: detail)
        } catch {
        }
    }

    /// Replaces a node in whichever cluster currently holds it with its hydrated form.
    private func hydrateVisibleNode(_ nodeId: AgentNode.ID, with detail: AgentNode) {
        if let index = nodes.firstIndex(where: { $0.id == nodeId }) {
            let hydratedNode = nodes[index].hydrated(with: detail)
            if nodes[index] != hydratedNode {
                nodes[index] = hydratedNode
            }

            let existing = nodeWorkSummaries[nodeId]
            nodeWorkSummaries[nodeId] = AgentNodeWorkSummary(
                promptText: hydratedNode.workPromptText,
                changedFiles: existing?.changedFiles ?? []
            )
        }

    }

    /// Hydrates every currently visible summary node before full-fidelity export.
    func loadVisibleNodeDetailsIfNeeded() async {
        let nodeIds = nodes
            .filter(\.needsDetailPayload)
            .map(\.id)

        for nodeId in nodeIds {
            await loadNodeDetailIfNeeded(nodeId)
        }
    }
}

extension AgentNode {
    /// Summary payloads intentionally omit inspector-only text fields.
    var needsDetailPayload: Bool {
        cacheStatus != "codex-log"
            && prompt.system.isEmpty
            && prompt.user.isEmpty
            && response.text.isEmpty
    }

    var workPromptText: String {
        if let execution = contextInputs.execution {
            return execution.commandLine.isEmpty ? execution.eventType : execution.commandLine
        }

        let prompt = prompt.user.trimmingCharacters(in: .whitespacesAndNewlines)
        if !prompt.isEmpty {
            return prompt
        }

        return stepName
    }

    /// Preserves fresh graph summary fields while attaching inspector payloads.
    func hydrated(with detail: AgentNode) -> AgentNode {
        AgentNode(
            id: id,
            agentName: agentName,
            depth: depth,
            stepName: stepName,
            timestamp: timestamp,
            provider: provider,
            model: model,
            cost: cost,
            latency: latency,
            latencyMs: latencyMs,
            barPercent: barPercent,
            tokensIn: tokensIn,
            tokensOut: tokensOut,
            requestId: requestId,
            cacheStatus: cacheStatus,
            temperature: temperature,
            traceId: detail.traceId.isEmpty ? traceId : detail.traceId,
            parentSpanId: detail.parentSpanId ?? parentSpanId,
            toolUseIds: detail.toolUseIds.isEmpty ? toolUseIds : detail.toolUseIds,
            contextInputs: detail.contextInputs.sources.isEmpty && detail.contextInputs.withheld.isEmpty && detail.contextInputs.execution == nil ? contextInputs : detail.contextInputs,
            inputHash: detail.inputHash.isEmpty ? inputHash : detail.inputHash,
            outputHash: detail.outputHash.isEmpty ? outputHash : detail.outputHash,
            stale: stale || detail.stale,
            isReplay: isReplay,
            replaySourceId: replaySourceId,
            replayProvider: replayProvider,
            status: status,
            prompt: detail.prompt,
            response: detail.response,
            error: detail.error
        )
    }

    func withGraphLayout(depth: Int, barPercent: Double) -> AgentNode {
        AgentNode(
            id: id,
            agentName: agentName,
            depth: depth,
            stepName: stepName,
            timestamp: timestamp,
            provider: provider,
            model: model,
            cost: cost,
            latency: latency,
            latencyMs: latencyMs,
            barPercent: barPercent,
            tokensIn: tokensIn,
            tokensOut: tokensOut,
            requestId: requestId,
            cacheStatus: cacheStatus,
            temperature: temperature,
            traceId: traceId,
            parentSpanId: parentSpanId,
            toolUseIds: toolUseIds,
            contextInputs: contextInputs,
            inputHash: inputHash,
            outputHash: outputHash,
            stale: stale,
            isReplay: isReplay,
            replaySourceId: replaySourceId,
            replayProvider: replayProvider,
            status: status,
            prompt: prompt,
            response: response,
            error: error
        )
    }
}

struct WorkspaceChangeFile: Equatable, Identifiable, Sendable {
    var id: String { path }

    let path: String
    let status: String
    let additions: Int
    let deletions: Int
}

struct WorkspaceChangeSummary: Equatable, Sendable {
    let files: [WorkspaceChangeFile]

    var fileCount: Int { files.count }
    var additions: Int { files.reduce(0) { $0 + $1.additions } }
    var deletions: Int { files.reduce(0) { $0 + $1.deletions } }
    var hasChanges: Bool { !files.isEmpty }

    static let empty = WorkspaceChangeSummary(files: [])
}

struct AgentNodeWorkSummary: Equatable, Sendable {
    let promptText: String
    let changedFiles: [WorkspaceChangeFile]

    init(promptText: String, changedFiles: [WorkspaceChangeFile] = []) {
        self.promptText = promptText
        self.changedFiles = changedFiles
    }

    var fileCount: Int { changedFiles.count }
    var additions: Int { changedFiles.reduce(0) { $0 + $1.additions } }
    var deletions: Int { changedFiles.reduce(0) { $0 + $1.deletions } }
    var hasChangedFiles: Bool { !changedFiles.isEmpty }
    var lineSummary: String? {
        hasChangedFiles ? "+\(additions) -\(deletions)" : nil
    }

    static let empty = AgentNodeWorkSummary(promptText: "Prompt not retained")
}

struct WorkspaceSnapshot: Equatable, Sendable {
    let files: [String: WorkspaceSnapshotFile]

    var summary: WorkspaceChangeSummary {
        WorkspaceChangeSummary(files: files.values.map(\.change).sorted { $0.path < $1.path })
    }

    func changedSummary(since previous: WorkspaceSnapshot) -> WorkspaceChangeSummary {
        let changed = Set(files.keys)
            .union(previous.files.keys)
            .compactMap { path -> WorkspaceChangeFile? in
                let current = files[path]
                let previousFile = previous.files[path]
                guard current != previousFile else { return nil }

                guard let current else {
                    return WorkspaceChangeFile(
                        path: path,
                        status: "Deleted",
                        additions: 0,
                        deletions: previousFile?.change.additions ?? 0
                    )
                }

                let additions = max(0, current.change.additions - (previousFile?.change.additions ?? 0))
                let deletions = max(0, current.change.deletions - (previousFile?.change.deletions ?? 0))
                return WorkspaceChangeFile(
                    path: current.change.path,
                    status: current.change.status,
                    additions: additions,
                    deletions: deletions
                )
            }
            .sorted { $0.path < $1.path }

        return WorkspaceChangeSummary(files: changed)
    }

    nonisolated static let empty = WorkspaceSnapshot(files: [:])
}

struct WorkspaceSnapshotFile: Equatable, Sendable {
    let change: WorkspaceChangeFile
    let fingerprint: String
}

enum WorkspaceChangeReader {
    nonisolated static func read() async -> WorkspaceChangeSummary {
        await snapshot().summary
    }

    nonisolated static func snapshot() async -> WorkspaceSnapshot {
        await Task.detached(priority: .utility) {
            guard let snapshot = WorkspaceAccessStore.withWorkspaceAccess({ root in
                snapshot(root: root)
            }) else {
                return .empty
            }
            return snapshot
        }.value
    }

    private nonisolated static func snapshot(root: URL) -> WorkspaceSnapshot {
            let statuses = statusByPath(root: root)
            let stats = statsByPath(root: root)
            let paths = Array(Set(statuses.keys).union(stats.keys)).sorted()
            let files = paths.map { path -> (String, WorkspaceSnapshotFile) in
                let stat = stats[path] ?? addedFileStat(root: root, path: path, status: statuses[path])
                let change = WorkspaceChangeFile(
                    path: path,
                    status: statuses[path] ?? "Modified",
                    additions: stat.0,
                    deletions: stat.1
                )
                return (path, WorkspaceSnapshotFile(change: change, fingerprint: fingerprint(root: root, path: path)))
            }

            return WorkspaceSnapshot(files: Dictionary(uniqueKeysWithValues: files))
    }

    private nonisolated static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private nonisolated static func statusByPath(root: URL) -> [String: String] {
        let output = runGit(["-C", root.path, "status", "--porcelain=v1"])
        var statuses: [String: String] = [:]

        for line in output.split(separator: "\n") {
            guard line.count >= 4 else { continue }
            let code = String(line.prefix(2))
            let pathStart = line.index(line.startIndex, offsetBy: 3)
            let path = String(line[pathStart...])
            statuses[path] = label(for: code)
        }

        return statuses
    }

    private nonisolated static func statsByPath(root: URL) -> [String: (Int, Int)] {
        let output = runGit(["-C", root.path, "diff", "--numstat", "HEAD", "--"])
        var stats: [String: (Int, Int)] = [:]

        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 2).map(String.init)
            guard parts.count == 3 else { continue }
            stats[parts[2]] = (Int(parts[0]) ?? 0, Int(parts[1]) ?? 0)
        }

        return stats
    }

    private nonisolated static func addedFileStat(root: URL, path: String, status: String?) -> (Int, Int) {
        guard status == "Added" else { return (0, 0) }
        let fileURL = root.appendingPathComponent(path)
        guard let data = try? Data(contentsOf: fileURL),
              let text = String(data: data, encoding: .utf8) else {
            return (0, 0)
        }

        let lineCount = text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count
        return (lineCount, 0)
    }

    private nonisolated static func fingerprint(root: URL, path: String) -> String {
        let fileURL = root.appendingPathComponent(path)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) else {
            return "missing"
        }

        let size = attributes[.size] as? NSNumber
        let modified = attributes[.modificationDate] as? Date
        return "\(size?.intValue ?? 0):\(modified?.timeIntervalSince1970 ?? 0)"
    }

    private nonisolated static func runGit(_ arguments: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    private nonisolated static func label(for code: String) -> String {
        if code.contains("A") || code.contains("?") { return "Added" }
        if code.contains("D") { return "Deleted" }
        if code.contains("R") { return "Renamed" }
        if code.contains("M") { return "Modified" }
        return "Changed"
    }
}
