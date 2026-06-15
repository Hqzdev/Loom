import ComposableArchitecture
import Foundation

/// Reducer that renders and selects proxy capture sessions in the sidebar.
@Reducer
public struct SessionListFeature: Sendable {
    @Dependency(\.sessionSelectionClient) var sessionSelectionClient

    /// State backing the visible session picker.
    @ObservableState
    public struct State: Equatable, Sendable {
        /// Display row derived from a session plus selection/live flags.
        public struct Row: Equatable, Identifiable, Sendable {
            public let session: TraceSession
            public let selected: Bool
            public let live: Bool

            /// Mirrors the session id so rows stay stable across refreshes.
            public var id: TraceSession.ID {
                session.id
            }
        }

        public var sessions: [TraceSession]
        public var selectedSessionId: TraceSession.ID?
        public var liveSessionId: TraceSession.ID?

        /// Creates sidebar session state from API session data and current selection.
        public init(
            sessions: [TraceSession] = [],
            selectedSessionId: TraceSession.ID? = nil,
            liveSessionId: TraceSession.ID? = nil
        ) {
            self.sessions = sessions
            self.selectedSessionId = selectedSessionId
            self.liveSessionId = liveSessionId
        }

        /// Compact count label shown in the session section header.
        public var countText: String {
            sessions.isEmpty ? "0" : "\(sessions.count)"
        }

        /// Indicates whether the sidebar should show the empty state.
        public var isEmpty: Bool {
            sessions.isEmpty
        }

        /// Produces stable rows annotated with selection and live-session state.
        public var rows: [Row] {
            sessions.map { session in
                Row(
                    session: session,
                    selected: session.id == selectedSessionId,
                    live: session.id == liveSessionId
                )
            }
        }
    }

    /// User actions emitted by the session sidebar.
    public enum Action: Equatable, Sendable {
        case sessionTapped(TraceSession.ID)
    }

    /// Creates the reducer with dependencies resolved from TCA.
    public init() {}

    /// Handles session selection and notifies the app-level selection client.
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .sessionTapped(sessionId):
                guard state.sessions.contains(where: { $0.id == sessionId }) else {
                    return .none
                }

                state.selectedSessionId = sessionId
                return .run { [sessionSelectionClient, sessionId] _ in
                    await sessionSelectionClient.select(sessionId)
                }
            }
        }
    }
}
