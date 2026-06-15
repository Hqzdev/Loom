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

    /// Fetches the current trace snapshot, or a specific historic session when `sessionId` is provided.
    public func currentTrace(sessionId: TraceSession.ID? = nil) async throws -> TraceSnapshot {
        guard let url = traceURL(sessionId: sessionId) else {
            throw ClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw ClientError.badStatus(status)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(TraceSnapshot.self, from: data)
    }

    /// Fetches the known proxy sessions and the id of the currently live session.
    public func sessions() async throws -> TraceSessionList {
        guard let url = URL(string: "/api/sessions", relativeTo: baseURL)?.absoluteURL else {
            throw ClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw ClientError.badStatus(status)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(TraceSessionList.self, from: data)
    }

    /// Creates a fresh live proxy session and returns its server-generated metadata.
    public func createSession() async throws -> TraceSession {
        guard let url = URL(string: "/api/sessions", relativeTo: baseURL)?.absoluteURL else {
            throw ClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 2

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw ClientError.badStatus(status)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(TraceSession.self, from: data)
    }

    /// Deletes all nodes in the current live trace while keeping the proxy session alive.
    public func clearTrace() async throws {
        guard let url = URL(string: "/api/traces/current", relativeTo: baseURL)?.absoluteURL else {
            throw ClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 2

        let (_, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
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

        let (_, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw ClientError.badStatus(status)
        }
    }

    /// Builds the trace endpoint URL, adding `session_id` only for historic session reads.
    private func traceURL(sessionId: TraceSession.ID?) -> URL? {
        guard let baseTraceURL = URL(string: "/api/traces/current", relativeTo: baseURL)?.absoluteURL else {
            return nil
        }

        guard let sessionId, !sessionId.isEmpty else {
            return baseTraceURL
        }

        var components = URLComponents(url: baseTraceURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "session_id", value: sessionId)]
        return components?.url
    }
}
