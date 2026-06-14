import ComposableArchitecture
import Core
import SwiftUI
import UI

struct Sidebar: View {
    let nodes: [AgentNode]
    let filteredNodes: [AgentNode]
    let selectedNodeId: AgentNode.ID?
    @Binding var searchText: String
    let proxyStatus: ProxyConnectionStatus
    let sessions: [TraceSession]
    let selectedSessionId: TraceSession.ID?
    let liveSessionId: TraceSession.ID?
    let onSelectSession: (TraceSession.ID) -> Void
    let onSelect: (AgentNode) -> Void
    let onShowSettings: () -> Void
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: proxyStatus.symbolName)
                        .font(.callout)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(proxyStatus.color(palette))
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(proxyStatus.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(proxyStatus.color(palette))
                        Text(proxyStatus.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .frame(height: 46)
                .liquidGlass(
                    palette: palette,
                    cornerRadius: palette.controlRadius,
                    tint: proxyStatus.backgroundTint(palette),
                    strokeOpacity: 0.84
                )
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            SessionListView(
                store: Store(initialState: sessionListState) {
                    SessionListFeature()
                } withDependencies: {
                    $0.sessionSelectionClient.select = { sessionId in
                        await MainActor.run {
                            onSelectSession(sessionId)
                        }
                    }
                },
                palette: palette
            )

            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    TextField("Filter calls...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .foregroundStyle(palette.text)
                }
                .frame(height: 30)
                .padding(.horizontal, 10)
                .liquidGlass(
                    palette: palette,
                    cornerRadius: palette.controlRadius,
                    tint: palette.glassTint,
                    interactive: true,
                    strokeOpacity: 0.72
                )
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            SidebarSectionHeader(
                title: "Calls",
                detail: "\(filteredNodes.count) of \(nodes.count)",
                palette: palette
            )

            ScrollView {
                LazyVStack(spacing: 1) {
                    if filteredNodes.isEmpty {
                        SidebarEmptyState(palette: palette)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 32)
                    } else {
                        ForEach(filteredNodes) { node in
                            CallRow(
                                node: node,
                                selected: node.id == selectedNodeId,
                                onSelect: { onSelect(node) },
                                palette: palette
                            )
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.automatic)

            VStack(spacing: 8) {
                SidebarButton(title: "Settings", palette: palette) {
                    onShowSettings()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(palette.panelSecondary.opacity(0.38))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(palette.border)
                    .frame(height: 1)
            }
        }
        .background(palette.panel.opacity(0.56))
    }

    private var sessionListState: SessionListFeature.State {
        SessionListFeature.State(
            sessions: sessions,
            selectedSessionId: selectedSessionId,
            liveSessionId: liveSessionId
        )
    }
}

private struct SidebarEmptyState: View {
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 8) {
            Text("No calls captured")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(palette.textTertiary)

            Text("Run codex in Terminal or send traffic through the proxy.")
                .font(.system(size: 11.5))
                .foregroundStyle(palette.textQuaternary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 210)
        }
    }
}

private struct SessionsEmptyState: View {
    let palette: AgentTracePalette

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

private struct CallRow: View {
    let node: AgentNode
    let selected: Bool
    let onSelect: () -> Void
    let palette: AgentTracePalette

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 9) {
                VStack {
                    StatusDot(status: node.status, palette: palette, size: 12)
                        .padding(.top, 3)
                    Spacer(minLength: 0)
                }
                .frame(width: 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text(node.stepName)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(node.status == .error ? palette.pinkText : palette.text)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        AgentBadge(name: node.agentName, palette: palette)

                        Text(node.model)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(palette.violet)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(palette.violet.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                                    .stroke(palette.violetBorder, lineWidth: 1)
                            )

                        Text(node.timestamp)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(palette.textQuaternary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(node.cost)
                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(node.cost == "$0.0000" ? palette.textQuaternary : palette.textSecondary)

                    Text(node.status == .cached ? "0ms" : node.latency.replacingOccurrences(of: " (timeout)", with: ""))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(node.status == .cached ? palette.cyan : palette.textQuaternary)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(selected ? palette.active.opacity(0.60) : palette.glassTint.opacity(0.03))
            .liquidGlass(
                palette: palette,
                cornerRadius: palette.controlRadius,
                tint: selected ? palette.accent.opacity(0.18) : palette.glassTint.opacity(0.08),
                interactive: true,
                strokeOpacity: selected ? 0.82 : 0.32
            )
            .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                    .stroke(selected ? palette.borderStrong : Color.clear, lineWidth: 1)
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

private struct SidebarButton: View {
    let title: String
    var selected = false
    let palette: AgentTracePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "gearshape")
                .font(.system(size: 12, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .foregroundStyle(selected ? palette.text : palette.textSecondary)
            .liquidGlass(
                palette: palette,
                cornerRadius: palette.controlRadius,
                tint: selected ? palette.accent.opacity(0.16) : palette.glassTint,
                interactive: true,
                strokeOpacity: 0.74
            )
        }
        .buttonStyle(.plain)
    }
}

private extension ProxyConnectionStatus {
    var symbolName: String {
        switch self {
        case .connecting:
            return "arrow.triangle.2.circlepath"
        case .online:
            return "checkmark.circle.fill"
        case .observingCodex:
            return "terminal.fill"
        case .observingAgents:
            return "rectangle.2.swap"
        case .offline:
            return "exclamationmark.triangle.fill"
        }
    }

    func backgroundTint(_ palette: AgentTracePalette) -> Color {
        switch self {
        case .connecting:
            return palette.amber.opacity(0.10)
        case .online:
            return palette.green.opacity(0.12)
        case .observingCodex, .observingAgents:
            return palette.green.opacity(0.12)
        case .offline:
            return palette.glassTint
        }
    }
}
