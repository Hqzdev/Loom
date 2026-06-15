import ComposableArchitecture
import Foundation

/// Dependency boundary used by feature reducers to select a trace session.
public struct SessionSelectionClient: Sendable {
    /// Sends the selected session id to the app-level owner.
    public var select: @Sendable (TraceSession.ID) async -> Void

    /// Creates a session-selection dependency from an async selection handler.
    public init(select: @escaping @Sendable (TraceSession.ID) async -> Void) {
        self.select = select
    }
}

extension SessionSelectionClient: DependencyKey {
    /// Live dependency placeholder; the app injects the real selection behavior at the edge.
    public static let liveValue = Self { _ in }

    /// Test dependency that ignores selections unless a test overrides it.
    public static let testValue = Self { _ in }
}

/// DependencyValues accessors for session-selection side effects.
public extension DependencyValues {
    /// TCA dependency slot for session selection side effects.
    var sessionSelectionClient: SessionSelectionClient {
        get { self[SessionSelectionClient.self] }
        set { self[SessionSelectionClient.self] = newValue }
    }
}
