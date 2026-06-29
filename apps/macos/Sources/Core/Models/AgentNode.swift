import CryptoKit
import Foundation

/// A single request, response, tool call, or replay step shown in the trace graph.
public struct AgentNode: Identifiable, Hashable, Codable, Sendable {
    /// Stable node identifier from the proxy or local agent observer.
    public let id: String

    /// Human-readable agent name, such as a terminal agent or framework agent.
    public let agentName: String

    /// Vertical graph depth assigned by the snapshot builder.
    public let depth: Int

    /// Short step title shown in the graph and sidebar.
    public let stepName: String

    /// Display timestamp for this node.
    public let timestamp: String

    /// Provider name reported by the proxy or local observer.
    public let provider: String

    /// Model identifier reported by the provider or local observer.
    public let model: String

    /// Display-ready cost string for the captured call.
    public let cost: String

    /// Display-ready latency string.
    public let latency: String

    /// Numeric latency in milliseconds for sorting and export.
    public let latencyMs: Int

    /// Relative bar width used by compact graph metrics.
    public let barPercent: Double

    /// Input token count reported for the call.
    public let tokensIn: Int

    /// Output token count reported for the call.
    public let tokensOut: Int

    /// Provider request identifier or a shortened local event id.
    public let requestId: String

    /// Cache state label, such as HIT, MISS, or codex-log.
    public let cacheStatus: String

    /// Optional sampling temperature when known.
    public let temperature: Double?

    /// Upstream trace/span identifier when the provider emits one.
    public let traceId: String

    /// Parent span id used to derive downstream invalidation boundaries.
    public let parentSpanId: String?

    /// Tool-use ids emitted by the provider for this call.
    public let toolUseIds: [String]

    /// Structured, redacted-by-default context assembly descriptor.
    public let contextInputs: AgentContextInputs

    /// Stable hash of the call input boundary.
    public let inputHash: String

    /// Stable hash of the current stored output.
    public let outputHash: String

    /// Whether this node was invalidated by an upstream output edit or replay.
    public let stale: Bool

    /// Whether this node is a generated replay branch rather than an original provider call.
    public let isReplay: Bool

    /// Original node id that produced this replay branch.
    public let replaySourceId: String?

    /// Provider used for the replay branch.
    public let replayProvider: String?

    /// Node execution status.
    public let status: NodeStatus

    /// Prompt content associated with this node.
    public let prompt: AgentPrompt

    /// Response content associated with this node.
    public let response: AgentResponse

    /// Error information when the node failed.
    public let error: AgentError?

    /// Creates a graph node and derives a legacy agent name when older payloads omit it.
    public init(
        id: String,
        agentName: String? = nil,
        depth: Int,
        stepName: String,
        timestamp: String,
        provider: String? = nil,
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
        traceId: String = "",
        parentSpanId: String? = nil,
        toolUseIds: [String] = [],
        contextInputs: AgentContextInputs? = nil,
        inputHash: String = "",
        outputHash: String = "",
        stale: Bool = false,
        isReplay: Bool = false,
        replaySourceId: String? = nil,
        replayProvider: String? = nil,
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
        self.provider = provider ?? Self.defaultProvider(model: model, stepName: stepName, cacheStatus: cacheStatus)
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
        self.traceId = traceId
        self.parentSpanId = parentSpanId
        self.toolUseIds = toolUseIds
        self.contextInputs = contextInputs ?? Self.legacyContextInputs(
            model: model,
            prompt: prompt,
            inputHash: inputHash
        )
        self.inputHash = inputHash.isEmpty ? self.contextInputs.inputHash : inputHash
        self.outputHash = outputHash.isEmpty ? Self.shortHash(response.text) : outputHash
        self.stale = stale
        self.isReplay = isReplay
        self.replaySourceId = replaySourceId
        self.replayProvider = replayProvider
        self.status = status
        self.prompt = prompt
        self.response = response
        self.error = error
    }

    /// Preserves readable agent names for trace payloads produced before `agentName` existed.
    static func defaultAgentName(
        model: String,
        stepName: String,
        cacheStatus: String
    ) -> String {
        let model = model.lowercased()
        let stepName = stepName.lowercased()
        let cacheStatus = cacheStatus.lowercased()

        if cacheStatus == "codex-log" || stepName.contains("codex") {
            return "Local Agent"
        }

        if model.contains("claude") || stepName.contains("anthropic") {
            return "Claude Code"
        }

        if stepName.contains("openai") {
            return "OpenAI Agent"
        }

        return "Agent"
    }

    /// Preserves provider labels for trace payloads produced before `provider` existed.
    static func defaultProvider(
        model: String,
        stepName: String,
        cacheStatus: String
    ) -> String {
        let model = model.lowercased()
        let stepName = stepName.lowercased()
        let cacheStatus = cacheStatus.lowercased()

        if cacheStatus == "codex-log" || stepName.contains("codex") {
            return "codex-log"
        }

        if model.contains("claude") || stepName.contains("anthropic") {
            return "anthropic"
        }

        if stepName.contains("openai") || model.hasPrefix("gpt-") || model.hasPrefix("o") {
            return "openai"
        }

        return "unknown"
    }

    /// Builds a best-effort context descriptor for old payloads that only had raw prompt fields.
    static func legacyContextInputs(
        model: String,
        prompt: AgentPrompt,
        inputHash: String
    ) -> AgentContextInputs {
        var sources: [AgentContextSource] = []
        if !prompt.system.isEmpty {
            sources.append(
                AgentContextSource(
                    kind: "inline",
                    pathOrId: "system_prompt",
                    hash: shortHash(prompt.system),
                    sizeBytes: prompt.system.utf8.count,
                    body: prompt.system
                )
            )
        }
        if !prompt.user.isEmpty {
            sources.append(
                AgentContextSource(
                    kind: "inline",
                    pathOrId: "user_prompt",
                    hash: shortHash(prompt.user),
                    sizeBytes: prompt.user.utf8.count,
                    body: prompt.user
                )
            )
        }

        let hash = inputHash.isEmpty ? shortHash("\(model)\u{0}\(prompt.system)\u{0}\(prompt.user)") : inputHash
        return AgentContextInputs(sources: sources, withheld: [], inputHash: hash)
    }

    /// UI-friendly SHA-256 prefix used for local-only nodes and replay diffs.
    public static func shortHash(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    public var isExecutionEvent: Bool {
        provider.lowercased() == "tether" && model.lowercased() == "shell"
    }

    public var isRepairCandidate: Bool {
        isExecutionEvent && status == .error
    }
}
