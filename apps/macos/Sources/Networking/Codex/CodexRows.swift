import Core
import Foundation

/// Error raised when the local Codex SQLite query cannot be executed.
enum CodexLogObserverError: LocalizedError {
    case sqlite(String)

    /// User-facing description for local observer failures.
    var errorDescription: String? {
        switch self {
        case .sqlite(let message):
            return "Codex log query failed: \(message)"
        }
    }
}

/// Thread metadata row from the Codex state database.
struct CodexThreadRow: Decodable {
    let id: String
    let title: String?
    let firstUserMessage: String?
    let preview: String?
    let model: String?
    let modelProvider: String?
    let source: String?
    let createdAt: Int?
    let updatedAt: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case firstUserMessage = "first_user_message"
        case preview
        case model
        case modelProvider = "model_provider"
        case source
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Parsed response event row from the Codex feedback log database.
struct CodexResponseEventRow: Decodable {
    let id: Int
    let ts: Int
    let eventType: String?
    let responseId: String?
    let model: String?
    let responseStatus: String?
    let responseCreatedAt: Int?
    let responseCompletedAt: Int?
    let inputTokens: Int?
    let outputTokens: Int?
    let errorMessage: String?
    let outputText: String?
    let itemType: String?
    let itemId: String?
    let itemName: String?
    let itemArguments: String?
    let itemText: String?
    let turnId: String?
    let promptUser: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case ts
        case eventType = "event_type"
        case responseId = "response_id"
        case model
        case responseStatus = "response_status"
        case responseCreatedAt = "response_created_at"
        case responseCompletedAt = "response_completed_at"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case errorMessage = "error_message"
        case outputText = "output_text"
        case itemType = "item_type"
        case itemId = "item_id"
        case itemName = "item_name"
        case itemArguments = "item_arguments"
        case itemText = "item_text"
        case turnId = "turn_id"
        case promptUser = "prompt_user"
    }
}

/// Lightweight row used to record the latest Codex response event id.
struct CodexLogWatermarkRow: Decodable {
    let id: Int
}

/// Mutable response accumulator used while folding Codex websocket events.
struct CodexResponseDraft {
    var id: String
    var startedAt: Int
    var completedAt: Int?
    var model: String
    var status: NodeStatus
    var tokensIn: Int
    var tokensOut: Int
    var outputText: String
    var promptUser: String?
    var toolSummaries: [String]
    var errorMessage: String?

    /// Response latency in milliseconds, or zero for still-streaming events.
    var latencyMs: Int {
        guard let completedAt else { return 0 }
        return max(0, completedAt - startedAt) * 1_000
    }
}
