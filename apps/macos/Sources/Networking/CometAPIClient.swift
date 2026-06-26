import Foundation

/// Client for CometAPI-related endpoints exposed by the local Tether proxy.
public struct CometAPIClient: Sendable {
    public enum ClientError: LocalizedError {
        case invalidURL
        case badStatus(Int, String)

        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid local proxy URL."
            case let .badStatus(status, message):
                return message.isEmpty ? "Local proxy returned HTTP \(status)." : message
            }
        }
    }

    private let overrideBaseURL: URL?
    private let session: URLSession

    private var baseURL: URL {
        overrideBaseURL ?? ProxySettingsStore.current.proxyBaseURL
    }

    public init(baseURL: URL? = nil, session: URLSession = .shared) {
        self.overrideBaseURL = baseURL
        self.session = session
    }

    public static func fetchModels() async throws -> [CometModel] {
        try await CometAPIClient().fetchModels()
    }

    public static func testConnection(apiKey: String) async throws -> Bool {
        let client = CometAPIClient()
        try await client.saveAPIKey(apiKey)
        return !(try await client.fetchModels()).isEmpty
    }

    public static func replayWithModel(traceId: String, model: String) async throws -> ReplayResult {
        try await CometAPIClient().replayWithModel(traceId: traceId, model: model)
    }

    public func fetchModels() async throws -> [CometModel] {
        guard let url = URL(string: "/api/providers/cometapi/models", relativeTo: baseURL)?.absoluteURL else {
            throw ClientError.invalidURL
        }
        return try await decode([CometModel].self, from: URLRequest(url: url))
    }

    public func cometAPIKeyStatus() async throws -> CometAPIKeyStatus {
        guard let url = URL(string: "/api/settings/cometapi-key", relativeTo: baseURL)?.absoluteURL else {
            throw ClientError.invalidURL
        }
        return try await decode(CometAPIKeyStatus.self, from: URLRequest(url: url))
    }

    public func saveAPIKey(_ apiKey: String) async throws {
        guard let url = URL(string: "/api/settings/cometapi-key", relativeTo: baseURL)?.absoluteURL else {
            throw ClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(CometAPIKeyBody(apiKey: apiKey))
        _ = try await decode(UpdateResponse.self, from: request)
    }

    public func replayWithModel(traceId: String, model: String) async throws -> ReplayResult {
        guard let encodedId = traceId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "/api/traces/\(encodedId)/replay-with", relativeTo: baseURL)?.absoluteURL
        else {
            throw ClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ReplayWithBody(model: model))
        return try await decode(ReplayResult.self, from: request)
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from request: URLRequest) async throws -> Value {
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw ClientError.badStatus(status, errorMessage(from: data))
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: data)
    }

    private func errorMessage(from data: Data) -> String {
        if let error = try? JSONDecoder().decode(ErrorBody.self, from: data) {
            return error.error
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

public struct CometModel: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let provider: String
}

public struct ReplayResult: Codable, Hashable, Sendable {
    public let newTraceId: String
    public let nodeId: String
    public let sourceNodeId: String
    public let model: String
    public let responseText: String
    public let latencyMs: Int
    public let costUsd: Double
    public let inputTokens: Int
    public let outputTokens: Int
}

public struct CometAPIKeyStatus: Codable, Hashable, Sendable {
    public let configured: Bool
}

private struct CometAPIKeyBody: Encodable {
    let apiKey: String
}

private struct ReplayWithBody: Encodable {
    let model: String
}

private struct UpdateResponse: Decodable {
    let ok: Bool
}

private struct ErrorBody: Decodable {
    let error: String
}
