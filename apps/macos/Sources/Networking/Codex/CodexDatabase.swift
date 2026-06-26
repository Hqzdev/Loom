import Foundation

/// Locates and queries the local Codex SQLite databases.
enum CodexDatabase {
    /// Path to the local Codex state database.
    static var statePath: String {
        codexDirectory.appendingPathComponent("state_5.sqlite").path
    }

    /// Path to the local Codex feedback log database.
    static var logsPath: String {
        codexDirectory.appendingPathComponent("logs_2.sqlite").path
    }

    /// Whether both local Codex databases exist.
    static var allDatabasesExist: Bool {
        withCodexAccess {
            FileManager.default.fileExists(atPath: statePath)
                && FileManager.default.fileExists(atPath: logsPath)
        } ?? false
    }

    /// Whether the response log database exists.
    static var logsExist: Bool {
        withCodexAccess {
            FileManager.default.fileExists(atPath: logsPath)
        } ?? false
    }

    private static var codexDirectory: URL {
        codexBookmarkURL
            ?? storedCodexURL
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
    }

    private static var codexBookmarkURL: URL? {
        guard let data = UserDefaults.standard.data(forKey: "tether.access.codexBookmark") else { return nil }
        var stale = false
        return try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
    }

    private static var storedCodexURL: URL? {
        guard let path = UserDefaults.standard.string(forKey: "tether.access.codexPath"), !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private static func withCodexAccess<T>(_ body: () throws -> T) rethrows -> T? {
        guard let url = codexBookmarkURL else {
            return try? body()
        }
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try body()
    }

    /// Runs a readonly SQLite query and decodes the JSON output into rows.
    static func runJSON<Row: Decodable>(
        databasePath: String,
        query: String,
        as _: [Row].Type
    ) throws -> [Row] {
        let accessURL = codexBookmarkURL
        let accessing = accessURL?.startAccessingSecurityScopedResource() ?? false
        defer {
            if accessing {
                accessURL?.stopAccessingSecurityScopedResource()
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-readonly", "-json", databasePath, query]

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = error.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8) ?? "sqlite3 exited with status \(process.terminationStatus)"
            throw CodexLogObserverError.sqlite(message)
        }

        guard !outputData.isEmpty else { return [] }
        return try JSONDecoder().decode([Row].self, from: outputData)
    }
}
