import Combine
import Core
import Networking
import SwiftUI
import UI

enum ProxyConnectionStatus: Equatable {
    case connecting
    case online
    case observingCodex(String)
    case observingAgents(String)
    case offline(String)

    var title: String {
        switch self {
        case .connecting:
            return "Local Proxy"
        case .online:
            return "Local Proxy"
        case .observingCodex:
            return "Codex Observer"
        case .observingAgents:
            return "Two Agents"
        case .offline:
            return "Proxy Offline"
        }
    }

    var detail: String {
        switch self {
        case .connecting:
            return "Connecting to 127.0.0.1:8080"
        case .online:
            return "Capturing real agent calls"
        case .observingCodex(let message):
            return message
        case .observingAgents(let message):
            return message
        case .offline(let message):
            return message.isEmpty ? "Start the proxy to capture calls" : message
        }
    }

    func color(_ palette: AgentTracePalette) -> Color {
        switch self {
        case .connecting:
            return palette.amber
        case .online:
            return palette.green
        case .observingCodex, .observingAgents:
            return palette.green
        case .offline:
            return palette.pink
        }
    }
}

@MainActor
final class TraceStore: ObservableObject {
    @Published private(set) var session: TraceSession?
    @Published private(set) var sessions: [TraceSession] = []
    @Published private(set) var currentSessionId: TraceSession.ID?
    @Published private(set) var selectedSessionId: TraceSession.ID?
    @Published private(set) var nodes: [AgentNode] = []
    @Published private(set) var proxyStatus: ProxyConnectionStatus = .connecting

    private let client: TraceAPIClient
    private let codexObserver: CodexLogObserver
    private var pollingTask: Task<Void, Never>?
    private var codexBaselineLogId: Int?

    init(
        client: TraceAPIClient? = nil,
        codexObserver: CodexLogObserver = CodexLogObserver()
    ) {
        self.client = client ?? TraceAPIClient()
        self.codexObserver = codexObserver
    }

    func startPolling() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                await refresh()

                do {
                    try await Task.sleep(for: .seconds(1.2))
                } catch {
                    break
                }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh() async {
        async let proxySessionsResult = loadProxySessions()
        async let codexResult = loadCodexSnapshot()

        let (sessionList, codex) = await (proxySessionsResult, codexResult)
        let proxySessions = try? sessionList.get()
        let codexSnapshot = try? codex.get()
        var proxySnapshot: TraceSnapshot?
        var proxyError: Error?

        if let proxySessions {
            apply(sessionList: proxySessions)
            let sessionId = selectedSessionId ?? proxySessions.currentSessionId
            let proxyResult = await loadProxySnapshot(sessionId: sessionId)
            proxySnapshot = try? proxyResult.get()
            if case .failure(let error) = proxyResult {
                proxyError = error
            }
        } else if case .failure(let error) = sessionList {
            sessions = []
            currentSessionId = nil
            selectedSessionId = nil
            proxyError = error
        }

        let shouldCombineCodex = selectedSessionId == nil || selectedSessionId == currentSessionId
        if shouldCombineCodex, let combinedSnapshot = combinedSnapshot(
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

    func clearTrace() {
        Task {
            await clearAllTraces()
        }
    }

    func startNewSession() {
        Task {
            await createNewSession()
        }
    }

    func selectSession(_ sessionId: TraceSession.ID) {
        selectedSessionId = sessionId
        Task {
            await refresh()
        }
    }

    func reload() {
        Task {
            await refresh()
        }
    }

    private func apply(snapshot: TraceSnapshot) {
        session = snapshot.session
        nodes = snapshot.nodes
    }

    private func combinedSnapshot(
        proxySnapshot: TraceSnapshot?,
        codexSnapshot: TraceSnapshot?
    ) -> TraceSnapshot? {
        guard let proxySnapshot,
              let codexSnapshot,
              !proxySnapshot.nodes.isEmpty,
              !codexSnapshot.nodes.isEmpty
        else {
            return nil
        }

        let orderedNodes = (proxySnapshot.nodes + codexSnapshot.nodes)
            .sorted { lhs, rhs in
                if lhs.timestamp == rhs.timestamp {
                    return lhs.agentName < rhs.agentName
                }

                return lhs.timestamp < rhs.timestamp
            }
        let maxLatency = max(orderedNodes.map(\.latencyMs).max() ?? 0, 1)
        let nodes = orderedNodes.enumerated().map { index, node in
            node.withLayout(
                depth: index,
                barPercent: max(0.06, min(Double(node.latencyMs) / Double(maxLatency), 1.0))
            )
        }

        return TraceSnapshot(
            session: TraceSession(
                id: "\(proxySnapshot.session?.id ?? "proxy")+\(codexSnapshot.session?.id ?? "codex")",
                title: "Codex + Claude Code",
                trigger: "Multi-agent observer",
                startedAt: proxySnapshot.session?.startedAt ?? codexSnapshot.session?.startedAt ?? "--:--:--"
            ),
            nodes: nodes
        )
    }

    private func agentSummary(for nodes: [AgentNode]) -> String {
        let agents = orderedAgentNames(from: nodes)
        guard !agents.isEmpty else {
            return "Watching multiple agents"
        }

        return "Watching \(agents.joined(separator: " + "))"
    }

    private func orderedAgentNames(from nodes: [AgentNode]) -> [String] {
        let names = Set(nodes.map(\.agentName))
        let preferredOrder = ["Codex", "Claude Code"]
        let preferredNames = preferredOrder.filter(names.contains)
        let remainingNames = names
            .subtracting(preferredNames)
            .sorted()

        return preferredNames + remainingNames
    }

    private func apply(sessionList: TraceSessionList) {
        sessions = sessionList.sessions
        currentSessionId = sessionList.currentSessionId

        if let selectedSessionId, sessions.contains(where: { $0.id == selectedSessionId }) {
            return
        }

        selectedSessionId = sessionList.currentSessionId ?? sessions.first?.id
    }

    private func loadProxySessions() async -> Result<TraceSessionList, Error> {
        do {
            return .success(try await client.sessions())
        } catch {
            return .failure(error)
        }
    }

    private func loadProxySnapshot(sessionId: TraceSession.ID?) async -> Result<TraceSnapshot, Error> {
        do {
            return .success(try await client.currentTrace(sessionId: sessionId))
        } catch {
            return .failure(error)
        }
    }

    private func loadCodexSnapshot() async -> Result<TraceSnapshot?, Error> {
        do {
            return .success(try await codexObserver.currentSnapshot(afterLogId: codexBaselineLogId))
        } catch {
            return .failure(error)
        }
    }

    private func createNewSession() async {
        codexBaselineLogId = try? await codexObserver.latestResponseEventId()
        session = nil
        nodes = []

        do {
            let newSession = try await client.createSession()
            selectedSessionId = newSession.id
            currentSessionId = newSession.id
            if !sessions.contains(where: { $0.id == newSession.id }) {
                sessions.insert(newSession, at: 0)
            }
            proxyStatus = .online
            await refresh()
        } catch {
            proxyStatus = .observingCodex("Open Terminal and run codex")
        }
    }

    private func clearAllTraces() async {
        codexBaselineLogId = try? await codexObserver.latestResponseEventId()
        session = nil
        nodes = []

        do {
            try await client.clearTrace()
            selectedSessionId = nil
            proxyStatus = .online
            await refresh()
        } catch {
            proxyStatus = .observingCodex("Open Terminal and run codex")
        }
    }
}

private extension Result where Failure == Error {
    var errorDescription: String? {
        guard case .failure(let error) = self else { return nil }
        return error.localizedDescription
    }
}

private extension AgentNode {
    func withLayout(depth: Int, barPercent: Double) -> AgentNode {
        AgentNode(
            id: id,
            agentName: agentName,
            depth: depth,
            stepName: stepName,
            timestamp: timestamp,
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
            status: status,
            prompt: prompt,
            response: response,
            error: error
        )
    }
}
