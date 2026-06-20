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
        let databaseURL: URL
        do {
            runtimeDirectory = try Self.runtimeDirectory()
            databaseURL = try Self.databaseURL()
        } catch {
            TetherLogger.proxy.error("local_proxy_runtime_setup_failed: \(error.localizedDescription, privacy: .public)")
            return false
        }

        let process = Process()
        process.executableURL = binaryURL
        process.currentDirectoryURL = binaryURL.deletingLastPathComponent()
        process.environment = proxyEnvironment(databaseURL: databaseURL)

        do {
            let logURL = try logFileURL(in: runtimeDirectory)
            let logHandle = try FileHandle(forWritingTo: logURL)
            try logHandle.seekToEnd()
            process.standardOutput = logHandle
            process.standardError = logHandle
            try process.run()
            self.process = process
            TetherLogger.proxy.info("local_proxy_started")
            return true
        } catch {
            TetherLogger.proxy.error("local_proxy_start_failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Terminates the running proxy process, if this launcher owns one.
    public func stop() {
        guard let process, process.isRunning else { return }
        process.terminate()
        self.process = nil
        TetherLogger.proxy.info("local_proxy_stopped")
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
            repoRoot.appendingPathComponent("proxy/target/debug/tether-proxy"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/tether-proxy")
        ]

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    /// Builds the environment passed to the proxy without persisting provider secrets.
    private func proxyEnvironment(databaseURL: URL) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let settings = ProxySettingsStore.current
        environment["TETHER_ADDR"] = settings.listenAddress
        environment["TETHER_CACHE"] = settings.localCacheEnabled ? "on" : "off"
        environment["OPENAI_UPSTREAM"] = settings.openAIUpstreamURL
        environment["ANTHROPIC_UPSTREAM"] = settings.anthropicUpstreamURL
        environment["TETHER_DB"] = databaseURL.path
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

    /// Creates the cache-backed runtime directory used for the proxy logs.
    private static func runtimeDirectory() throws -> URL {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directory = root.appendingPathComponent("Tether", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Persistent on-device location for the trace database. Application
    /// Support is backed up and never purged by macOS, so trace history survives
    /// the low-disk conditions that can silently wipe the caches directory.
    private static func databaseURL() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root.appendingPathComponent("Tether", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("tether-cache.sqlite")
        migrateLegacyDatabaseIfNeeded(to: url)
        return url
    }

    /// Moves a database left in the volatile caches directory by older builds into
    /// the persistent store, preserving previously captured traces.
    private static func migrateLegacyDatabaseIfNeeded(to destination: URL) {
        let manager = FileManager.default
        guard !manager.fileExists(atPath: destination.path),
              let legacyDirectory = try? runtimeDirectory() else {
            return
        }

        let legacyBase = legacyDirectory.appendingPathComponent("tether-cache.sqlite")
        guard manager.fileExists(atPath: legacyBase.path) else { return }

        // SQLite spreads data across the main file plus its WAL/SHM sidecars.
        for suffix in ["", "-wal", "-shm"] {
            let from = URL(fileURLWithPath: legacyBase.path + suffix)
            let to = URL(fileURLWithPath: destination.path + suffix)
            guard manager.fileExists(atPath: from.path) else { continue }
            try? manager.moveItem(at: from, to: to)
        }
    }
}
