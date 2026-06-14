import Foundation

public struct TraceSnapshot: Codable, Hashable, Sendable {
    public let session: TraceSession?
    public let nodes: [AgentNode]

    public init(session: TraceSession?, nodes: [AgentNode]) {
        self.session = session
        self.nodes = nodes
    }
}

public struct AgentNode: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let agentName: String
    public let depth: Int
    public let stepName: String
    public let timestamp: String
    public let model: String
    public let cost: String
    public let latency: String
    public let latencyMs: Int
    public let barPercent: Double
    public let tokensIn: Int
    public let tokensOut: Int
    public let requestId: String
    public let cacheStatus: String
    public let temperature: Double?
    public let status: NodeStatus
    public let prompt: AgentPrompt
    public let response: AgentResponse
    public let error: AgentError?

    public init(
        id: String,
        agentName: String? = nil,
        depth: Int,
        stepName: String,
        timestamp: String,
        model: String,
        cost: String,
        latency: String,
        latencyMs: Int,
        barPercent: Double,
        tokensIn: Int,
        tokensOut: Int,
        requestId: String,
        cacheStatus: String,
        temperature: Double?,
        status: NodeStatus,
        prompt: AgentPrompt,
        response: AgentResponse,
        error: AgentError?
    ) {
        self.id = id
        self.agentName = agentName ?? Self.defaultAgentName(
            model: model,
            stepName: stepName,
            cacheStatus: cacheStatus
        )
        self.depth = depth
        self.stepName = stepName
        self.timestamp = timestamp
        self.model = model
        self.cost = cost
        self.latency = latency
        self.latencyMs = latencyMs
        self.barPercent = barPercent
        self.tokensIn = tokensIn
        self.tokensOut = tokensOut
        self.requestId = requestId
        self.cacheStatus = cacheStatus
        self.temperature = temperature
        self.status = status
        self.prompt = prompt
        self.response = response
        self.error = error
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case agentName
        case depth
        case stepName
        case timestamp
        case model
        case cost
        case latency
        case latencyMs
        case barPercent
        case tokensIn
        case tokensOut
        case requestId
        case cacheStatus
        case temperature
        case status
        case prompt
        case response
        case error
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let depth = try container.decode(Int.self, forKey: .depth)
        let stepName = try container.decode(String.self, forKey: .stepName)
        let timestamp = try container.decode(String.self, forKey: .timestamp)
        let model = try container.decode(String.self, forKey: .model)
        let cost = try container.decode(String.self, forKey: .cost)
        let latency = try container.decode(String.self, forKey: .latency)
        let latencyMs = try container.decode(Int.self, forKey: .latencyMs)
        let barPercent = try container.decode(Double.self, forKey: .barPercent)
        let tokensIn = try container.decode(Int.self, forKey: .tokensIn)
        let tokensOut = try container.decode(Int.self, forKey: .tokensOut)
        let requestId = try container.decode(String.self, forKey: .requestId)
        let cacheStatus = try container.decode(String.self, forKey: .cacheStatus)
        let temperature = try container.decodeIfPresent(Double.self, forKey: .temperature)
        let status = try container.decode(NodeStatus.self, forKey: .status)
        let prompt = try container.decode(AgentPrompt.self, forKey: .prompt)
        let response = try container.decode(AgentResponse.self, forKey: .response)
        let error = try container.decodeIfPresent(AgentError.self, forKey: .error)
        let agentName = try container.decodeIfPresent(String.self, forKey: .agentName)

        self.init(
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

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(agentName, forKey: .agentName)
        try container.encode(depth, forKey: .depth)
        try container.encode(stepName, forKey: .stepName)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(model, forKey: .model)
        try container.encode(cost, forKey: .cost)
        try container.encode(latency, forKey: .latency)
        try container.encode(latencyMs, forKey: .latencyMs)
        try container.encode(barPercent, forKey: .barPercent)
        try container.encode(tokensIn, forKey: .tokensIn)
        try container.encode(tokensOut, forKey: .tokensOut)
        try container.encode(requestId, forKey: .requestId)
        try container.encode(cacheStatus, forKey: .cacheStatus)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encode(status, forKey: .status)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(response, forKey: .response)
        try container.encodeIfPresent(error, forKey: .error)
    }

    private static func defaultAgentName(
        model: String,
        stepName: String,
        cacheStatus: String
    ) -> String {
        let model = model.lowercased()
        let stepName = stepName.lowercased()
        let cacheStatus = cacheStatus.lowercased()

        if cacheStatus == "codex-log" || stepName.contains("codex") {
            return "Codex"
        }

        if model.contains("claude") || stepName.contains("anthropic") {
            return "Claude Code"
        }

        if stepName.contains("openai") {
            return "Codex"
        }

        return "Agent"
    }
}

public struct TraceSession: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let title: String
    public let trigger: String
    public let startedAt: String

    public init(id: String, title: String, trigger: String, startedAt: String) {
        self.id = id
        self.title = title
        self.trigger = trigger
        self.startedAt = startedAt
    }
}

public struct TraceSessionList: Hashable, Codable, Sendable {
    public let sessions: [TraceSession]
    public let currentSessionId: String?

    public init(sessions: [TraceSession], currentSessionId: String?) {
        self.sessions = sessions
        self.currentSessionId = currentSessionId
    }
}

public struct AgentPrompt: Hashable, Codable, Sendable {
    public let system: String
    public let user: String

    public init(system: String, user: String) {
        self.system = system
        self.user = user
    }
}

public struct AgentResponse: Hashable, Codable, Sendable {
    public let language: ResponseLanguage
    public let text: String

    public init(language: ResponseLanguage, text: String) {
        self.language = language
        self.text = text
    }
}

public struct AgentError: Hashable, Codable, Sendable {
    public let code: String
    public let message: String
    public let detail: String

    public init(code: String, message: String, detail: String) {
        self.code = code
        self.message = message
        self.detail = detail
    }
}

public enum ResponseLanguage: String, Hashable, Codable, Sendable {
    case json
    case text
}

public enum NodeStatus: String, Hashable, Codable, Sendable {
    case success
    case cached
    case running
    case error

    public var label: String {
        rawValue.uppercased()
    }

    public var symbolName: String {
        switch self {
        case .success:
            return "lightbulb.fill"
        case .cached:
            return "externaldrive.fill"
        case .running:
            return "dot.radiowaves.left.and.right"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}

public enum InspectorTab: String, CaseIterable, Identifiable, Sendable {
    case prompt
    case response
    case metadata

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .prompt:
            return "Prompt"
        case .response:
            return "Response"
        case .metadata:
            return "Metadata"
        }
    }
}
