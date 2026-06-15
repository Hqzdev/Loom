import Foundation

/// Starts and owns the local Rust proxy process for the macOS app runtime.
@MainActor
public final class LocalProxyLauncher {
    /// Shared launcher used by app startup and settings actions.
    public static let shared = LocalProxyLauncher()

    private var process: Process?

    /// Restricts process ownership to the shared launcher instance.
    private init() {}

    /// Starts the proxy when an executable is available and returns whether it is running.
    @discardableResult
    public func startIfAvailable() -> Bool {
        if process?.isRunning == true {
            return true
        }

        guard let binaryURL = findProxyBinary() else {
            return false
        }

        let runtimeDirectory: URL
        do {
            runtimeDirectory = try Self.runtimeDirectory()
        } catch {
            return false
        }

        let process = Process()
        process.executableURL = binaryURL
        process.currentDirectoryURL = binaryURL.deletingLastPathComponent()
        process.environment = proxyEnvironment(runtimeDirectory: runtimeDirectory)

        do {
            let logURL = try logFileURL(in: runtimeDirectory)
            let logHandle = try FileHandle(forWritingTo: logURL)
            try logHandle.seekToEnd()
            process.standardOutput = logHandle
            process.standardError = logHandle
            try process.run()
            self.process = process
            return true
        } catch {
            return false
        }
    }

    /// Terminates the running proxy process, if this launcher owns one.
    public func stop() {
        guard let process, process.isRunning else { return }
        process.terminate()
        self.process = nil
    }

    /// Restarts the proxy process using the latest persisted proxy settings.
    @discardableResult
    public func restart() -> Bool {
        stop()
        return startIfAvailable()
    }

    /// Searches first for a local development binary, then for the bundled release helper.
    private func findProxyBinary() -> URL? {
        let fileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = fileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let candidates = [
            repoRoot.appendingPathComponent("proxy/target/debug/loom-proxy"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/loom-proxy")
        ]

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    /// Builds the environment passed to the proxy without persisting provider secrets.
    private func proxyEnvironment(runtimeDirectory: URL) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let settings = ProxySettingsStore.current
        environment["LOOM_ADDR"] = settings.listenAddress
        environment["LOOM_CACHE"] = settings.localCacheEnabled ? "on" : "off"
        environment["OPENAI_UPSTREAM"] = settings.openAIUpstreamURL
        environment["ANTHROPIC_UPSTREAM"] = settings.anthropicUpstreamURL
        environment["LOOM_DB"] = runtimeDirectory
            .appendingPathComponent("loom-cache.sqlite")
            .path
        if let openAIKey = KeychainStore.read(.openAIAPIKey) {
            environment["OPENAI_API_KEY"] = openAIKey
        }
        if let anthropicKey = KeychainStore.read(.anthropicAPIKey) {
            environment["ANTHROPIC_API_KEY"] = anthropicKey
        }
        return environment
    }

    /// Returns an appendable proxy log file inside the app cache directory.
    private func logFileURL(in runtimeDirectory: URL) throws -> URL {
        let url = runtimeDirectory.appendingPathComponent("proxy.log")
        if !FileManager.default.fileExists(atPath: url.path) {
            guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        return url
    }

    /// Creates the cache-backed runtime directory used for the proxy database and logs.
    private static func runtimeDirectory() throws -> URL {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directory = root.appendingPathComponent("Loom", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
