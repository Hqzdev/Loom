import Foundation

/// Structured description of what was assembled into a model call.
public struct AgentContextInputs: Hashable, Codable, Sendable {
    public let sources: [AgentContextSource]
    public let withheld: [String]
    public let inputHash: String
    public let execution: AgentExecutionContext?

    public init(
        sources: [AgentContextSource] = [],
        withheld: [String] = [],
        inputHash: String = "",
        execution: AgentExecutionContext? = nil
    ) {
        self.sources = sources
        self.withheld = withheld
        self.inputHash = inputHash
        self.execution = execution
    }

    public static let empty = AgentContextInputs()

    enum CodingKeys: String, CodingKey {
        case sources
        case withheld
        case inputHash
        case eventType
        case sessionId
        case command
        case cwd
        case startedAtMs
        case endedAtMs
        case latencyMs
        case exitCode
        case gitBaseRevision
        case gitDiffBefore
        case gitDiffAfter
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sources = (try? container.decodeIfPresent([AgentContextSource].self, forKey: .sources)) ?? []
        withheld = (try? container.decodeIfPresent([String].self, forKey: .withheld)) ?? []
        inputHash = (try? container.decodeIfPresent(String.self, forKey: .inputHash)) ?? ""
        if let eventType = try? container.decodeIfPresent(String.self, forKey: .eventType) {
            execution = AgentExecutionContext(
                eventType: eventType,
                sessionId: (try? container.decodeIfPresent(String.self, forKey: .sessionId)) ?? "",
                command: (try? container.decodeIfPresent([String].self, forKey: .command)) ?? [],
                cwd: (try? container.decodeIfPresent(String.self, forKey: .cwd)) ?? "",
                startedAtMs: (try? container.decodeIfPresent(Int.self, forKey: .startedAtMs)) ?? 0,
                endedAtMs: (try? container.decodeIfPresent(Int.self, forKey: .endedAtMs)) ?? 0,
                latencyMs: (try? container.decodeIfPresent(Int.self, forKey: .latencyMs)) ?? 0,
                exitCode: try? container.decodeIfPresent(Int.self, forKey: .exitCode),
                gitBaseRevision: try? container.decodeIfPresent(String.self, forKey: .gitBaseRevision),
                gitDiffBefore: (try? container.decodeIfPresent(String.self, forKey: .gitDiffBefore)) ?? "",
                gitDiffAfter: (try? container.decodeIfPresent(String.self, forKey: .gitDiffAfter)) ?? ""
            )
        } else {
            execution = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sources, forKey: .sources)
        try container.encode(withheld, forKey: .withheld)
        try container.encode(inputHash, forKey: .inputHash)
        try container.encodeIfPresent(execution?.eventType, forKey: .eventType)
        try container.encodeIfPresent(execution?.sessionId, forKey: .sessionId)
        try container.encodeIfPresent(execution?.command, forKey: .command)
        try container.encodeIfPresent(execution?.cwd, forKey: .cwd)
        try container.encodeIfPresent(execution?.startedAtMs, forKey: .startedAtMs)
        try container.encodeIfPresent(execution?.endedAtMs, forKey: .endedAtMs)
        try container.encodeIfPresent(execution?.latencyMs, forKey: .latencyMs)
        try container.encodeIfPresent(execution?.exitCode, forKey: .exitCode)
        try container.encodeIfPresent(execution?.gitBaseRevision, forKey: .gitBaseRevision)
        try container.encodeIfPresent(execution?.gitDiffBefore, forKey: .gitDiffBefore)
        try container.encodeIfPresent(execution?.gitDiffAfter, forKey: .gitDiffAfter)
    }
}

public struct AgentExecutionContext: Hashable, Codable, Sendable {
    public let eventType: String
    public let sessionId: String
    public let command: [String]
    public let cwd: String
    public let startedAtMs: Int
    public let endedAtMs: Int
    public let latencyMs: Int
    public let exitCode: Int?
    public let gitBaseRevision: String?
    public let gitDiffBefore: String
    public let gitDiffAfter: String

    public var commandLine: String {
        command.joined(separator: " ")
    }

    public var diffAfterSummary: String {
        diffSummary(gitDiffAfter)
    }

    public var diffBeforeSummary: String {
        diffSummary(gitDiffBefore)
    }

    private func diffSummary(_ diff: String) -> String {
        var files = Set<String>()
        var additions = 0
        var deletions = 0
        for line in diff.components(separatedBy: .newlines) {
            if line.hasPrefix("diff --git ") {
                let parts = line.components(separatedBy: " ")
                if let path = parts.last?.dropFirst(2), !path.isEmpty {
                    files.insert(String(path))
                }
            } else if line.hasPrefix("+") && !line.hasPrefix("+++") {
                additions += 1
            } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                deletions += 1
            }
        }
        if files.isEmpty && additions == 0 && deletions == 0 {
            return "no changes"
        }
        return "\(files.count) files · +\(additions) -\(deletions)"
    }
}

/// One context source shown by the boundary inspector.
public struct AgentContextSource: Hashable, Codable, Sendable, Identifiable {
    public var id: String { "\(kind):\(pathOrId):\(hash)" }

    public let kind: String
    public let pathOrId: String
    public let hash: String
    public let sizeBytes: Int
    public let body: String?

    public init(
        kind: String,
        pathOrId: String,
        hash: String,
        sizeBytes: Int,
        body: String? = nil
    ) {
        self.kind = kind
        self.pathOrId = pathOrId
        self.hash = hash
        self.sizeBytes = sizeBytes
        self.body = body
    }
}

/// Display buckets for context sources.
public enum AgentContextCategory: String, CaseIterable, Identifiable, Sendable {
    case files
    case skills
    case mcpResults
    case memorySearch
    case tools
    case inline
    case other

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .files:
            return "Files"
        case .skills:
            return "Skills"
        case .mcpResults:
            return "MCP Results"
        case .memorySearch:
            return "Memory / Search"
        case .tools:
            return "Tool Schemas"
        case .inline:
            return "Inline Segments"
        case .other:
            return "Other"
        }
    }
}

public extension AgentContextSource {
    /// Maps raw proxy source kinds to stable inspector categories.
    var category: AgentContextCategory {
        switch kind.lowercased() {
        case "file":
            return .files
        case "skill":
            return .skills
        case "mcp", "mcp_result":
            return .mcpResults
        case "memory", "search":
            return .memorySearch
        case "tool", "tool_result":
            return .tools
        case "inline":
            return .inline
        default:
            return .other
        }
    }
}
