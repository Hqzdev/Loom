import AppKit
import SwiftUI
import UI

/// Top-of-window banner shown when a newer GitHub release is available. It hides
/// itself once the user dismisses the current latest version (persisted so the
/// same release never nags twice).
struct UpdateBannerView: View {
    @ObservedObject var checker: UpdateChecker
    @AppStorage("dismissedVersion") private var dismissedVersion = ""

    private let palette = AgentTracePalette(light: true)

    var body: some View {
        if let release = checker.latestRelease,
           checker.updateAvailable,
           dismissedVersion != release.tagName {
            banner(for: release)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func banner(for release: GitHubRelease) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 18))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(palette.accent)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text("Update available — \(release.tagName)")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(palette.text)

                if let changelog = trimmedBody(release) {
                    Text(changelog)
                        .font(.system(size: 11))
                        .foregroundStyle(palette.textTertiary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Download") { openDownload(release) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

            Button {
                dismissedVersion = release.tagName
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textTertiary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help("Dismiss until the next release")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(palette.panelSecondary.opacity(0.92))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.border)
                .frame(height: 1)
        }
    }

    /// Returns the release notes trimmed of surrounding whitespace, or nil when empty.
    private func trimmedBody(_ release: GitHubRelease) -> String? {
        guard let body = release.body?.trimmingCharacters(in: .whitespacesAndNewlines),
              !body.isEmpty else {
            return nil
        }
        return body
    }

    /// Opens the release page in the user's browser.
    private func openDownload(_ release: GitHubRelease) {
        guard let url = URL(string: release.htmlUrl) else { return }
        NSWorkspace.shared.open(url)
    }
}
