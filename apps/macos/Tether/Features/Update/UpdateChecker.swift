import Combine
import Foundation

/// Subset of a GitHub release payload used to surface update notifications.
struct GitHubRelease: Codable, Equatable, Identifiable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlUrl: String

    var id: String { tagName }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
    }

    /// The release version without a leading "v" (e.g. "v1.4.6" -> "1.4.6").
    var version: String {
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }
}

/// Polls the project's GitHub releases once on launch and publishes whether a
/// newer build is available. Failures (offline, rate-limited) are silent so the
/// banner simply stays hidden.
@MainActor
final class UpdateChecker: ObservableObject {
    @Published private(set) var latestRelease: GitHubRelease?
    @Published private(set) var updateAvailable = false

    private let releasesURL = URL(
        string: "https://api.github.com/repos/Hqzdev/Tether/releases/latest"
    )!
    private let session: URLSession

    /// Creates a checker backed by the shared session, overridable for tests.
    init(session: URLSession = .shared) {
        self.session = session
    }

    /// The running app's `CFBundleShortVersionString` (e.g. "1.4.5").
    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Fetches the latest release and flags it when newer than the running build.
    func check() async {
        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            latestRelease = release
            updateAvailable = Self.isNewer(release.version, than: currentVersion)
        } catch {
            // Offline or rate-limited: keep the previous (typically empty) state.
        }
    }

    /// Numeric version comparison: true when `candidate` is strictly newer.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        candidate.compare(current, options: .numeric) == .orderedDescending
    }
}
