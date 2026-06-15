import ComposableArchitecture
import Core
import SwiftUI

/// Sidebar view that displays historic proxy sessions and the active live session.
public struct SessionListView: View {
    let store: StoreOf<SessionListFeature>
    let palette: AgentTracePalette

    /// Creates the session list view from a TCA store and design-system palette.
    public init(store: StoreOf<SessionListFeature>, palette: AgentTracePalette) {
        self.store = store
        self.palette = palette
    }

    /// Renders the compact, scrollable session picker.
    public var body: some View {
        VStack(spacing: 0) {
            SidebarSectionHeader(
                title: "Sessions",
                detail: store.countText,
                palette: palette
            )

            ScrollView {
                LazyVStack(spacing: 1) {
                    if store.isEmpty {
                        SessionsEmptyState(palette: palette)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(store.rows) { row in
                            SessionRow(
                                session: row.session,
                                selected: row.selected,
                                live: row.live,
                                onSelect: { store.send(.sessionTapped(row.id)) },
                                palette: palette
                            )
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 154)
            .scrollIndicators(.automatic)
        }
        .background(palette.panelSecondary.opacity(0.52))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.border)
                .frame(height: 1)
        }
    }
}

private struct SessionsEmptyState: View {
    let palette: AgentTracePalette

    /// Renders the empty state shown before proxy traffic creates sessions.
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 22, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(palette.textQuaternary)

            VStack(spacing: 3) {
                Text("No proxy sessions")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textTertiary)

                Text("Sessions appear here once traffic flows through the proxy.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.textQuaternary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(1.5)
                    .frame(maxWidth: 200)
            }
        }
        .padding(.horizontal, 12)
    }
}

private struct SidebarSectionHeader: View {
    let title: String
    let detail: String
    let palette: AgentTracePalette

    /// Renders the session section title and count label.
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)

            Spacer()

            Text(detail)
                .font(.caption2.monospacedDigit())
        }
        .textCase(nil)
        .foregroundStyle(.secondary)
        .fontDesign(.monospaced)
        .padding(.leading, 18)
        .padding(.trailing, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
}

private struct SessionRow: View {
    let session: TraceSession
    let selected: Bool
    let live: Bool
    let onSelect: () -> Void
    let palette: AgentTracePalette

    /// Renders one selectable session row with live and selected states.
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 9) {
                Image(systemName: live ? "record.circle.fill" : "clock")
                    .font(.system(size: 13))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(live ? palette.green : palette.textTertiary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)

                    Text(session.startedAt)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(palette.textQuaternary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if live {
                    Text("Live")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(palette.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(palette.green.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .liquidGlass(
                palette: palette,
                cornerRadius: palette.controlRadius,
                tint: selected ? palette.accent.opacity(0.16) : palette.glassTint.opacity(0.08),
                interactive: true,
                strokeOpacity: selected ? 0.82 : 0.32
            )
            .overlay(alignment: .leading) {
                if selected {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(palette.accent)
                        .frame(width: 2.5)
                        .padding(.vertical, 8)
                        .offset(x: -8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
