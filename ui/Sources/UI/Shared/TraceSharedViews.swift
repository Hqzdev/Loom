import Core
import SwiftUI

public struct StatusDot: View {
    let status: NodeStatus
    let palette: AgentTracePalette
    let size: CGFloat

    public init(status: NodeStatus, palette: AgentTracePalette, size: CGFloat = 8) {
        self.status = status
        self.palette = palette
        self.size = size
    }

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

public struct AgentBadge: View {
    let name: String
    let palette: AgentTracePalette
    let compact: Bool

    public init(
        name: String,
        palette: AgentTracePalette,
        compact: Bool = true
    ) {
        self.name = name
        self.palette = palette
        self.compact = compact
    }

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

public struct DividerLine: View {
    let palette: AgentTracePalette

    public init(palette: AgentTracePalette) {
        self.palette = palette
    }

    public var body: some View {
        DottedDivider(palette: palette, vertical: true)
            .frame(width: 1)
    }
}

public struct HorizontalDividerLine: View {
    let palette: AgentTracePalette

    public init(palette: AgentTracePalette) {
        self.palette = palette
    }

    public var body: some View {
        DottedDivider(palette: palette, vertical: false)
            .frame(height: 1)
    }
}

private struct DottedDivider: View {
    let palette: AgentTracePalette
    let vertical: Bool

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

public struct StageBackground: View {
    let palette: AgentTracePalette

    public init(palette: AgentTracePalette) {
        self.palette = palette
    }

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
