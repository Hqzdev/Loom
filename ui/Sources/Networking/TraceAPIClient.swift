import Core
import Foundation

/// HTTP client used by the SwiftUI app to read and mutate the local proxy trace API.
public struct TraceAPIClient: Sendable {
    /// Error cases surfaced when the local proxy cannot be addressed or returns a failing status.
    public enum ClientError: LocalizedError {
        case invalidURL
        case badStatus(Int)

        /// Human-readable error text used by SwiftUI error surfaces.
        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid local proxy URL."
            case .badStatus(let status):
                return "Local proxy returned HTTP \(status)."
            }
        }
    }

    private let overrideBaseURL: URL?
    private let session: URLSession

    private var baseURL: URL {
        overrideBaseURL ?? ProxySettingsStore.current.proxyBaseURL
    }

    /// Creates a trace API client, optionally overriding the persisted proxy base URL.
    public init(
        baseURL: URL? = nil,
        session: URLSession = .shared
    ) {
        self.overrideBaseURL = baseURL
        self.session = session
    }

    /// Fetches the current trace snapshot.
    public func currentTrace() async throws -> TraceSnapshot {
        guard let url = traceURL() else {
            throw ClientError.invalidURL
        }

        return try await decode(TraceSnapshot.self, from: url)
    }

    /// Fetches the current trace summary without large prompt and response payloads.
    public func currentTraceSummary() async throws -> TraceSnapshot {
        guard let url = traceSummaryURL() else {
            throw ClientError.invalidURL
        }

        return try await decode(TraceSnapshot.self, from: url)
    }

    /// Fetches the full inspector payload for one trace node.
    public func traceNodeDetail(nodeId: AgentNode.ID) async throws -> AgentNode {
        guard let encodedId = nodeId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "/api/traces/\(encodedId)", relativeTo: baseURL)?.absoluteURL
        else {
            throw ClientError.invalidURL
        }

        return try await decode(AgentNode.self, from: url)
    }

    /// Persists a mocked node output and returns downstream invalidation evidence.
    public func editNodeOutput(
        nodeId: AgentNode.ID,
        output: String
    ) async throws -> TraceInvalidationResult {
        guard let encodedId = nodeId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "/api/traces/\(encodedId)/output", relativeTo: baseURL)?.absoluteURL
        else {
            throw ClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(EditOutputBody(output: output))

        return try await decode(TraceInvalidationResult.self, from: request)
    }

    /// Previews descendants that would become stale if a node output changes.
    public func downstreamNodes(nodeId: AgentNode.ID) async throws -> TraceDownstreamResult {
        guard let encodedId = nodeId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "/api/traces/\(encodedId)/downstream", relativeTo: baseURL)?.absoluteURL
        else {
            throw ClientError.invalidURL
        }

        return try await decode(TraceDownstreamResult.self, from: url)
    }

    /// Replays a retained node request against its provider and returns output-hash diff evidence.
    public func replayNode(nodeId: AgentNode.ID) async throws -> TraceReplayResult {
        guard let encodedId = nodeId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "/api/traces/\(encodedId)/replay", relativeTo: baseURL)?.absoluteURL
        else {
            throw ClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30

        return try await decode(TraceReplayResult.self, from: request)
    }

    /// Decodes one JSON resource from the proxy API.
    private func decode<Value: Decodable>(_ type: Value.Type, from url: URL) async throws -> Value {
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        request.cachePolicy = .reloadIgnoringLocalCacheData

        return try await decode(type, from: request)
    }

    /// Decodes one JSON resource from a prepared proxy API request.
    private func decode<Value: Decodable>(_ type: Value.Type, from request: URLRequest) async throws -> Value {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            TetherLogger.networking.error("trace_api_request_failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            TetherLogger.networking.warning("trace_api_bad_status: \(status, privacy: .public)")
            throw ClientError.badStatus(status)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: data)
    }

    /// Deletes all nodes in the current live trace.
    public func clearTrace() async throws {
        guard let url = URL(string: "/api/traces/current", relativeTo: baseURL)?.absoluteURL else {
            throw ClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 2

        let response: URLResponse
        do {
            (_, response) = try await session.data(for: request)
        } catch {
            TetherLogger.networking.error("trace_clear_request_failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            TetherLogger.networking.warning("trace_clear_bad_status: \(status, privacy: .public)")
            throw ClientError.badStatus(status)
        }
    }

    /// Clears the local response cache maintained by the proxy.
    public func clearCache() async throws {
        guard let url = URL(string: "/api/cache", relativeTo: baseURL)?.absoluteURL else {
            throw ClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 2

        let response: URLResponse
        do {
            (_, response) = try await session.data(for: request)
        } catch {
            TetherLogger.networking.error("cache_clear_request_failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            TetherLogger.networking.warning("cache_clear_bad_status: \(status, privacy: .public)")
            throw ClientError.badStatus(status)
        }
    }

    /// Builds the trace endpoint URL.
    private func traceURL() -> URL? {
        URL(string: "/api/traces/current", relativeTo: baseURL)?.absoluteURL
    }

    /// Builds the lightweight trace endpoint URL for graph polling.
    private func traceSummaryURL() -> URL? {
        URL(string: "/api/traces/current/summary", relativeTo: baseURL)?.absoluteURL
    }
}

private struct EditOutputBody: Encodable {
    let output: String
}
