import Foundation

public extension AgentNode {
    var graphGroupId: String {
        let normalizedAgent = agentName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        let normalizedCache = cacheStatus.lowercased()

        if normalizedCache == "codex-log" {
            return "codex:\(stableGroupToken)"
        }

        if isReplay, let replaySourceId {
            return "replay:\(replaySourceId)"
        }

        return "\(normalizedAgent.isEmpty ? "agent" : normalizedAgent):\(stableGroupToken)"
    }

    var graphGroupTitle: String {
        if cacheStatus.lowercased() == "codex-log" {
            return "Local Agent"
        }

        if isReplay {
            return "\(agentName) Replay"
        }

        return agentName.isEmpty ? "Agent" : agentName
    }

    private var stableGroupToken: String {
        if !traceId.isEmpty {
            return traceId
        }

        if !requestId.isEmpty {
            return requestId
        }

        return id
    }
}
