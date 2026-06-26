import Foundation

extension AgentNode {
    enum CodingKeys: String, CodingKey {
        case id
        case agentName
        case depth
        case stepName
        case timestamp
        case provider
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
        case traceId
        case parentSpanId
        case toolUseIds
        case contextInputs
        case inputHash
        case outputHash
        case stale
        case isReplay
        case replaySourceId
        case replayProvider
        case status
        case prompt
        case response
        case error
    }

    /// Decodes nodes from current payloads and older payloads that do not include `agentName`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let depth = try container.decode(Int.self, forKey: .depth)
        let stepName = try container.decode(String.self, forKey: .stepName)
        let timestamp = try container.decode(String.self, forKey: .timestamp)
        let provider = try container.decodeIfPresent(String.self, forKey: .provider)
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
        let traceId = try container.decodeIfPresent(String.self, forKey: .traceId) ?? ""
        let parentSpanId = try container.decodeIfPresent(String.self, forKey: .parentSpanId)
        let toolUseIds = (try? container.decodeIfPresent([String].self, forKey: .toolUseIds)) ?? []
        let contextInputs = try container.decodeIfPresent(AgentContextInputs.self, forKey: .contextInputs)
        let inputHash = try container.decodeIfPresent(String.self, forKey: .inputHash) ?? ""
        let outputHash = try container.decodeIfPresent(String.self, forKey: .outputHash) ?? ""
        let stale = try container.decodeIfPresent(Bool.self, forKey: .stale) ?? false
        let isReplay = try container.decodeIfPresent(Bool.self, forKey: .isReplay) ?? false
        let replaySourceId = try container.decodeIfPresent(String.self, forKey: .replaySourceId)
        let replayProvider = try container.decodeIfPresent(String.self, forKey: .replayProvider)
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

    /// Encodes every node field so exported traces match the OpenAPI contract.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(agentName, forKey: .agentName)
        try container.encode(depth, forKey: .depth)
        try container.encode(stepName, forKey: .stepName)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(provider, forKey: .provider)
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
        try container.encode(traceId, forKey: .traceId)
        try container.encodeIfPresent(parentSpanId, forKey: .parentSpanId)
        try container.encode(toolUseIds, forKey: .toolUseIds)
        try container.encode(contextInputs, forKey: .contextInputs)
        try container.encode(inputHash, forKey: .inputHash)
        try container.encode(outputHash, forKey: .outputHash)
        try container.encode(stale, forKey: .stale)
        try container.encode(isReplay, forKey: .isReplay)
        try container.encodeIfPresent(replaySourceId, forKey: .replaySourceId)
        try container.encodeIfPresent(replayProvider, forKey: .replayProvider)
        try container.encode(status, forKey: .status)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(response, forKey: .response)
        try container.encodeIfPresent(error, forKey: .error)
    }
}
