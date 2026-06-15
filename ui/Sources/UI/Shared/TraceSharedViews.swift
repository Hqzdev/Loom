import Core
import SwiftUI

/// Small colored indicator that mirrors a trace node status.
public struct StatusDot: View {
    let status: NodeStatus
    let palette: AgentTracePalette
    let size: CGFloat

    /// Creates a status indicator with the provided palette and visual size.
    public init(status: NodeStatus, palette: AgentTracePalette, size: CGFloat = 8) {
        self.status = status
        self.palette = palette
        self.size = size
    }

    /// Renders the status dot with a soft state-colored outline.
    public var body: some View {
        Circle()
            .fill(palette.color(for: status))
            .overlay(
                Circle()
                    .stroke(palette.color(for: status).opacity(0.35), lineWidth: max(1, size / 6))
                    .blur(radius: max(0.6, size / 10))
            )
            .frame(width: size, height: size)
    }
}

/// Compact badge that identifies which agent produced a trace node.
public struct AgentBadge: View {
    let name: String
    let palette: AgentTracePalette
    let compact: Bool

    /// Creates an agent badge, optionally using the denser layout for graph cards.
    public init(
        name: String,
        palette: AgentTracePalette,
        compact: Bool = true
    ) {
        self.name = name
        self.palette = palette
        self.compact = compact
    }

    /// Renders a symbol and label with source-specific tinting.
    public var body: some View {
        HStack(spacing: compact ? 3 : 5) {
            Image(systemName: symbolName)
                .font(.system(size: compact ? 8.5 : 10, weight: .semibold))

            Text(name)
                .font(.system(size: compact ? 9.5 : 10.5, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 1.5 : 2.5)
        .background(tint.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
        .help(name)
    }

    /// Chooses a compact SF Symbol that maps known local agents to recognizable icons.
    private var symbolName: String {
        let normalized = name.lowercased()
        if normalized.contains("codex") {
            return "terminal.fill"
        }
        if normalized.contains("claude") {
            return "cloud.fill"
        }
        return "cpu.fill"
    }

    /// Chooses the badge tint based on the agent identity.
    private var tint: Color {
        let normalized = name.lowercased()
        if normalized.contains("codex") {
            return palette.accent
        }
        if normalized.contains("claude") {
            return palette.cyan
        }
        return palette.textTertiary
    }
}

/// Vertical dotted divider shared by graph and settings surfaces.
public struct DividerLine: View {
    let palette: AgentTracePalette

    /// Creates a vertical divider using the active palette.
    public init(palette: AgentTracePalette) {
        self.palette = palette
    }

    /// Renders the reusable dotted divider in a one-point vertical frame.
    public var body: some View {
        DottedDivider(palette: palette, vertical: true)
            .frame(width: 1)
    }
}

/// Horizontal dotted divider shared by graph and settings surfaces.
public struct HorizontalDividerLine: View {
    let palette: AgentTracePalette

    /// Creates a horizontal divider using the active palette.
    public init(palette: AgentTracePalette) {
        self.palette = palette
    }

    /// Renders the reusable dotted divider in a one-point horizontal frame.
    public var body: some View {
        DottedDivider(palette: palette, vertical: false)
            .frame(height: 1)
    }
}

private struct DottedDivider: View {
    let palette: AgentTracePalette
    let vertical: Bool

    /// Draws a single dotted line in the requested orientation.
    var body: some View {
        Canvas { context, size in
            var path = Path()

            if vertical {
                path.move(to: CGPoint(x: size.width / 2, y: 0))
                path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            } else {
                path.move(to: CGPoint(x: 0, y: size.height / 2))
                path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            }

            context.stroke(
                path,
                with: .color(palette.borderStrong.opacity(0.82)),
                style: StrokeStyle(lineWidth: 1, dash: [4, 6])
            )
        }
    }
}

/// Full-window graph background with the active stage color and blueprint grid.
public struct StageBackground: View {
    let palette: AgentTracePalette

    /// Creates the trace stage background from the current palette.
    public init(palette: AgentTracePalette) {
        self.palette = palette
    }

    /// Renders the background and non-interactive grid behind all trace content.
    public var body: some View {
        ZStack {
            palette.stage
            BlueprintGrid(lineColor: palette.gridLine)
        }
        .ignoresSafeArea()
    }
}

private struct BlueprintGrid: View {
    let lineColor: Color

    /// Draws the blueprint grid at fixed intervals so graph movement has spatial reference.
    var body: some View {
        Canvas { context, size in
            let horizontalStep: CGFloat = 96
            let verticalStep: CGFloat = 64
            var path = Path()

            stride(from: CGFloat.zero, through: size.width, by: horizontalStep).forEach { x in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }

            stride(from: CGFloat.zero, through: size.height, by: verticalStep).forEach { y in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }

            context.stroke(path, with: .color(lineColor), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}
