import AppKit
import Combine
import Foundation

@MainActor
final class WorkspaceAccessStore: ObservableObject {
    static let shared = WorkspaceAccessStore()

    @Published private(set) var workspacePath: String?
    @Published private(set) var codexPath: String?

    private let defaults = UserDefaults.standard
    private var workspaceURL: URL?
    private var codexURL: URL?
    private var workspaceAccessing = false
    private var codexAccessing = false

    var hasWorkspaceAccess: Bool { workspaceURL != nil }
    var hasCodexAccess: Bool { codexURL != nil }

    private init() {
        restorePersistedAccess()
    }

    func restorePersistedAccess() {
        workspaceURL = Self.resolveBookmark(key: Self.workspaceBookmarkKey) ?? Self.resolveStoredURL(key: Self.workspacePathKey)
        codexURL = Self.resolveBookmark(key: Self.codexBookmarkKey) ?? Self.resolveStoredURL(key: Self.codexPathKey)
        workspacePath = workspaceURL?.path
        codexPath = codexURL?.path

        if workspaceURL != nil {
            defaults.set(true, forKey: Self.workspacePromptedKey)
        }
        if codexURL != nil {
            defaults.set(true, forKey: Self.codexPromptedKey)
        }

        if !workspaceAccessing, Self.hasBookmark(key: Self.workspaceBookmarkKey), workspaceURL?.startAccessingSecurityScopedResource() == true {
            workspaceAccessing = true
        }
        if !codexAccessing, Self.hasBookmark(key: Self.codexBookmarkKey), codexURL?.startAccessingSecurityScopedResource() == true {
            codexAccessing = true
        }
    }

    func ensureStartupAccess(codexIntegrationEnabled: Bool) {
        restorePersistedAccess()
        if workspaceURL == nil && !defaults.bool(forKey: Self.workspacePromptedKey) {
            requestWorkspaceAccess()
        }
        if codexIntegrationEnabled && codexURL == nil && !defaults.bool(forKey: Self.codexPromptedKey) {
            requestCodexAccess()
        }
    }

    func requestWorkspaceAccess() {
        defaults.set(true, forKey: Self.workspacePromptedKey)
        requestDirectory(
            title: "Grant Tether workspace access",
            message: "Choose the repository folder Tether should inspect for file changes.",
            defaultURL: Self.defaultWorkspaceURL(),
            bookmarkKey: Self.workspaceBookmarkKey,
            pathKey: Self.workspacePathKey
        ) { [weak self] url in
            self?.workspaceURL = url
            self?.workspacePath = url.path
            if self?.workspaceAccessing != true, Self.hasBookmark(key: Self.workspaceBookmarkKey), url.startAccessingSecurityScopedResource() {
                self?.workspaceAccessing = true
            }
        }
    }

    func requestCodexAccess() {
        defaults.set(true, forKey: Self.codexPromptedKey)
        requestDirectory(
            title: "Grant Tether Codex log access",
            message: "Choose your .codex folder so Tether can observe Terminal Codex runs.",
            defaultURL: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true),
            bookmarkKey: Self.codexBookmarkKey,
            pathKey: Self.codexPathKey
        ) { [weak self] url in
            self?.codexURL = url
            self?.codexPath = url.path
            if self?.codexAccessing != true, Self.hasBookmark(key: Self.codexBookmarkKey), url.startAccessingSecurityScopedResource() {
                self?.codexAccessing = true
            }
        }
    }

    func forgetWorkspaceAccess() {
        if workspaceAccessing {
            workspaceURL?.stopAccessingSecurityScopedResource()
            workspaceAccessing = false
        }
        workspaceURL = nil
        workspacePath = nil
        defaults.removeObject(forKey: Self.workspaceBookmarkKey)
        defaults.removeObject(forKey: Self.workspacePathKey)
        defaults.removeObject(forKey: Self.workspacePromptedKey)
    }

    func forgetCodexAccess() {
        if codexAccessing {
            codexURL?.stopAccessingSecurityScopedResource()
            codexAccessing = false
        }
        codexURL = nil
        codexPath = nil
        defaults.removeObject(forKey: Self.codexBookmarkKey)
        defaults.removeObject(forKey: Self.codexPathKey)
        defaults.removeObject(forKey: Self.codexPromptedKey)
    }

    nonisolated static func withWorkspaceAccess<T>(_ body: (URL) -> T) -> T? {
        let bookmarkURL = resolveBookmark(key: workspaceBookmarkKey)
        guard let url = bookmarkURL ?? resolveStoredURL(key: workspacePathKey) ?? defaultWorkspaceURL() else { return nil }
        let accessing = bookmarkURL != nil && url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return body(url)
    }

    nonisolated static func withCodexAccess<T>(_ body: (URL) -> T) -> T? {
        let bookmarkURL = resolveBookmark(key: codexBookmarkKey)
        guard let url = bookmarkURL ?? resolveStoredURL(key: codexPathKey) else { return nil }
        let accessing = bookmarkURL != nil && url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return body(url)
    }

    private func requestDirectory(
        title: String,
        message: String,
        defaultURL: URL?,
        bookmarkKey: String,
        pathKey: String,
        onGrant: @escaping (URL) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.title = title
        panel.message = message
        panel.prompt = "Grant Access"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = defaultURL

        guard panel.runModal() == .OK, let url = panel.url else { return }
        defaults.set(url.path, forKey: pathKey)
        do {
            let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            defaults.set(data, forKey: bookmarkKey)
            onGrant(url)
        } catch {
            defaults.removeObject(forKey: bookmarkKey)
            onGrant(url)
        }
    }

    nonisolated private static func hasBookmark(key: String) -> Bool {
        UserDefaults.standard.data(forKey: key) != nil
    }

    nonisolated private static func resolveBookmark(key: String) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var stale = false
        do {
            let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
            if stale {
                let refreshed = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(refreshed, forKey: key)
            }
            return url
        } catch {
            UserDefaults.standard.removeObject(forKey: key)
            return nil
        }
    }

    nonisolated private static func resolveStoredURL(key: String) -> URL? {
        guard let path = UserDefaults.standard.string(forKey: key), !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    nonisolated private static func defaultWorkspaceURL() -> URL? {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    nonisolated private static let workspaceBookmarkKey = "tether.access.workspaceBookmark"
    nonisolated private static let codexBookmarkKey = "tether.access.codexBookmark"
    nonisolated private static let workspacePathKey = "tether.access.workspacePath"
    nonisolated private static let codexPathKey = "tether.access.codexPath"
    nonisolated private static let workspacePromptedKey = "tether.access.workspacePrompted"
    nonisolated private static let codexPromptedKey = "tether.access.codexPrompted"
}
