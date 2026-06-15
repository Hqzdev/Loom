import Networking

/// App-level integration points that connect SwiftUI startup to runtime services.
public enum AgentTraceAppEnvironment {
    /// Starts the local proxy helper when a debug or bundled binary is available.
    @discardableResult
    @MainActor
    public static func startLocalProxyIfAvailable() -> Bool {
        LocalProxyLauncher.shared.startIfAvailable()
    }
}
