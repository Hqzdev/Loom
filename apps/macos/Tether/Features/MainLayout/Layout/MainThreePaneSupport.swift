import SwiftUI
import UI

enum WorkspaceMode {
    case wide
    case medium
    case compact
}

struct AdaptiveWorkspaceLayout {
    let mode: WorkspaceMode
    let sidebarWidth: CGFloat
    let inspectorWidth: CGFloat
    let inspectorHeight: CGFloat

    init(size: CGSize) {
        if size.width >= 1180, size.height >= 560 {
            mode = .wide
        } else if size.width >= 820, size.height >= 500 {
            mode = .medium
        } else {
            mode = .compact
        }

        sidebarWidth = min(max(size.width * 0.24, 240), mode == .wide ? 312 : 286)
        inspectorWidth = min(max(size.width * 0.28, 320), 432)
        inspectorHeight = min(max(size.height * 0.34, 210), 320)
    }
}

enum CompactSection: String, CaseIterable, Identifiable {
    case calls = "Calls"
    case graph = "Graph"
    case inspector = "Inspector"

    var id: String { rawValue }
}

struct CompactSectionPicker: View {
    @Binding var selection: CompactSection
    let palette: AgentTracePalette

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(CompactSection.allCases) { section in
                Text(section.rawValue)
                    .tag(section)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(palette.panelSecondary.opacity(0.70))
    }
}

struct HorizontalDividerLine: View {
    let palette: AgentTracePalette

    var body: some View {
        Rectangle()
            .fill(palette.borderSoft)
            .frame(height: 1)
    }
}

struct WorkspaceSettingsOverlay: View {
    let palette: AgentTracePalette
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.30)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            AppSettingsView(onClose: onDismiss, palette: palette)
                .padding(30)
        }
    }
}

enum WorkspaceGuideStep: Int, CaseIterable {
    case intro
    case sidebar
    case graph
    case inspector
    case quickview

    var title: String {
        switch self {
        case .intro:
            "Welcome to Tether"
        case .sidebar:
            "Captured calls"
        case .graph:
            "Trace graph"
        case .inspector:
            "Inspector"
        case .quickview:
            "Quickview"
        }
    }

    var body: String {
        switch self {
        case .intro:
            "Tether shows what your agent did, where it failed, and what changed."
        case .sidebar:
            "Use the sidebar to jump between calls, filter noisy runs, and keep the current session in view."
        case .graph:
            "Each node is an agent call. Follow the chain to see where work started, branched, or failed."
        case .inspector:
            "Click a node to inspect prompt context, response, metadata, and replay tools."
        case .quickview:
            "Press Cmd T to check the latest run without switching away from your editor or terminal."
        }
    }

    var next: WorkspaceGuideStep? {
        WorkspaceGuideStep(rawValue: rawValue + 1)
    }

    var previous: WorkspaceGuideStep? {
        WorkspaceGuideStep(rawValue: rawValue - 1)
    }

    var indexText: String {
        "\(rawValue + 1) of \(WorkspaceGuideStep.allCases.count)"
    }
}

struct WorkspaceGuideOverlay: View {
    let step: WorkspaceGuideStep
    let layout: AdaptiveWorkspaceLayout
    let palette: AgentTracePalette
    let onBack: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let frame = highlightFrame(in: geometry.size)
            let cardFrame = cardFrame(in: geometry.size, highlightFrame: frame)

            ZStack(alignment: .topLeading) {
                WorkspaceGuideBackdrop(highlightFrame: frame)
                    .ignoresSafeArea()

                if let frame {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: frame.width, height: frame.height)
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(palette.accent.opacity(0.92), lineWidth: 2)
                        }
                        .shadow(color: palette.accent.opacity(0.20), radius: 18, x: 0, y: 8)
                        .position(x: frame.midX, y: frame.midY)
                        .transition(.opacity.combined(with: .scale(scale: 0.99)))
                }

                WorkspaceGuideCard(
                    step: step,
                    palette: palette,
                    canGoBack: step.previous != nil,
                    isLast: step.next == nil,
                    onBack: onBack,
                    onNext: onNext,
                    onSkip: onSkip
                )
                .frame(width: min(360, max(300, geometry.size.width - 40)))
                .position(x: cardFrame.midX, y: cardFrame.midY)
            }
            .animation(.smooth(duration: 0.18), value: step)
        }
    }

    private func highlightFrame(in size: CGSize) -> CGRect? {
        let safeWidth = max(size.width, 1)
        let safeHeight = max(size.height, 1)

        switch step {
        case .intro, .quickview:
            return nil
        case .sidebar:
            return CGRect(x: 12, y: 12, width: min(layout.sidebarWidth + 24, safeWidth - 24), height: safeHeight - 24)
        case .graph:
            let left = layout.mode == .compact ? 12 : layout.sidebarWidth + 18
            let right = layout.mode == .wide ? layout.inspectorWidth + 18 : 12
            return CGRect(x: left, y: 12, width: max(260, safeWidth - left - right), height: safeHeight - 24)
        case .inspector:
            if layout.mode == .compact {
                return CGRect(x: 12, y: 58, width: safeWidth - 24, height: safeHeight - 70)
            }

            if layout.mode == .medium {
                let left = layout.sidebarWidth + 18
                let top = max(220, safeHeight - layout.inspectorHeight - 18)
                return CGRect(x: left, y: top, width: safeWidth - left - 12, height: safeHeight - top - 12)
            }

            let width = min(layout.inspectorWidth + 28, safeWidth - 36)
            return CGRect(x: safeWidth - width - 12, y: 12, width: width, height: safeHeight - 24)
        }
    }

    private func cardFrame(in size: CGSize, highlightFrame: CGRect?) -> CGRect {
        let cardSize = CGSize(width: min(360, max(300, size.width - 40)), height: 236)

        guard let highlightFrame else {
            return CGRect(
                x: (size.width - cardSize.width) / 2,
                y: max(42, (size.height - cardSize.height) / 2),
                width: cardSize.width,
                height: cardSize.height
            )
        }

        let preferredX = highlightFrame.maxX + 18
        let fallbackX = highlightFrame.minX - cardSize.width - 18
        let x = preferredX + cardSize.width <= size.width - 18 ? preferredX : max(18, fallbackX)
        let y = min(max(34, highlightFrame.midY - cardSize.height / 2), max(34, size.height - cardSize.height - 24))

        return CGRect(x: x, y: y, width: cardSize.width, height: cardSize.height)
    }
}

private struct WorkspaceGuideBackdrop: View {
    let highlightFrame: CGRect?

    var body: some View {
        Rectangle()
            .fill(.black.opacity(0.24))
            .overlay {
                Canvas { context, size in
                    guard let highlightFrame else { return }

                    var path = Path(CGRect(origin: .zero, size: size))
                    path.addPath(Path(roundedRect: highlightFrame, cornerRadius: 18))
                    context.fill(path, with: .color(.black.opacity(0.30)), style: FillStyle(eoFill: true))
                }
            }
            .background(.thinMaterial.opacity(0.46))
    }
}

private struct WorkspaceGuideCard: View {
    let step: WorkspaceGuideStep
    let palette: AgentTracePalette
    let canGoBack: Bool
    let isLast: Bool
    let onBack: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(step.indexText)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(palette.textTertiary)

                Spacer()

                Button("Skip", action: onSkip)
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textTertiary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(step.title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text(step.body)
                    .font(.system(size: 13.5))
                    .lineSpacing(2)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                ForEach(WorkspaceGuideStep.allCases, id: \.self) { item in
                    Circle()
                        .fill(item == step ? palette.accent : palette.borderStrong)
                        .frame(width: 6, height: 6)
                }

                Spacer()

                Button("Back", action: onBack)
                    .buttonStyle(.plain)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(canGoBack ? palette.textSecondary : palette.textTertiary.opacity(0.45))
                    .disabled(!canGoBack)

                Button(isLast ? "Finish" : "Next", action: onNext)
                    .buttonStyle(.plain)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .frame(height: 32)
                    .background(palette.accent, in: RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
            }
        }
        .padding(18)
        .background(palette.elevated.opacity(0.96), in: RoundedRectangle(cornerRadius: palette.paperRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: palette.paperRadius, style: .continuous)
                .stroke(palette.borderStrong, lineWidth: 1)
        }
        .shadow(color: palette.liquidShade.opacity(0.24), radius: 24, x: 0, y: 16)
    }
}
