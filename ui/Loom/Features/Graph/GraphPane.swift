import AppKit
import Core
import SwiftUI
import UI

struct GraphPane: View {
    private let nodeSize = CGSize(width: 320, height: 112)
    private let depthSpacing: CGFloat = 380
    private let zoomRange: ClosedRange<CGFloat> = 0.5...1.8

    let session: TraceSession?
    let nodes: [AgentNode]
    let selectedNode: AgentNode?
    let totalLatencyMs: Int
    let onSelect: (AgentNode) -> Void
    let palette: AgentTracePalette

    @State private var nodeOffsets: [AgentNode.ID: CGSize] = [:]
    @State private var nodeSizes: [AgentNode.ID: CGSize] = [:]
    @State private var zoomScale: CGFloat = 1

    private var statusText: String {
        guard !nodes.isEmpty else { return "IDLE" }
        if nodes.contains(where: { $0.status == .running }) { return "LIVE" }
        return nodes.contains(where: { $0.status == .error }) ? "FAILED" : "OK"
    }

    private var statusColor: Color {
        statusText == "FAILED" ? palette.pink : statusText == "LIVE" ? palette.amber : statusText == "OK" ? palette.green : palette.textTertiary
    }

    private var agentCountText: String {
        "\(Set(nodes.map(\.agentName)).count)"
    }

    private var headerContext: String {
        let sessionTitle = session?.title ?? "No active session"
        let nodeTitle = selectedNode?.stepName ?? "Waiting for calls"
        return "\(sessionTitle) · \(nodeTitle)"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(headerContext)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(selectedNode?.stepName ?? "Trace timeline")
                        .font(.headline)
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .layoutPriority(1)
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    MetricBox(label: "Total Time", value: formatLatency(totalLatencyMs), valueColor: palette.text, palette: palette)
                    MetricBox(label: "Steps", value: "\(nodes.count)", valueColor: palette.text, palette: palette)
                    MetricBox(label: "Agents", value: agentCountText, valueColor: palette.accent, palette: palette)
                    MetricBox(label: "Status", value: statusText, valueColor: statusColor, palette: palette)
                }
                .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(palette.panelSecondary.opacity(0.48))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(palette.border)
                    .frame(height: 1)
            }

            GraphViewport(
                nodes: nodes,
                selectedNode: selectedNode,
                nodeSize: nodeSize,
                depthSpacing: depthSpacing,
                nodeOffsets: $nodeOffsets,
                nodeSizes: $nodeSizes,
                zoomScale: zoomScale,
                onSelect: onSelect,
                onZoom: { value, animated in setZoom(value, animated: animated) },
                palette: palette
            )
            .overlay(alignment: .bottomTrailing) {
                ZoomControls(
                    zoomScale: $zoomScale,
                    zoomRange: zoomRange,
                    onReset: { setZoom(1) },
                    palette: palette
                )
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
        .background(palette.window.opacity(0.48))
        .onChange(of: nodes.map(\.id)) { _, ids in
            nodeOffsets = nodeOffsets.filter { ids.contains($0.key) }
            nodeSizes = nodeSizes.filter { ids.contains($0.key) }
        }
    }

    private func formatLatency(_ milliseconds: Int) -> String {
        if milliseconds >= 1000 {
            return String(format: "%.2fs", Double(milliseconds) / 1000.0)
        }

        return "\(milliseconds)ms"
    }

    private func setZoom(_ value: CGFloat, animated: Bool = true) {
        let clampedValue = min(max(value, zoomRange.lowerBound), zoomRange.upperBound)

        if animated {
            withAnimation(.smooth(duration: 0.16)) {
                zoomScale = clampedValue
            }
        } else {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                zoomScale = clampedValue
            }
        }
    }
}

private struct MetricBox: View {
    let label: String
    let value: String
    let valueColor: Color
    let palette: AgentTracePalette

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(.title3.monospacedDigit())
                .fontWeight(.semibold)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 82, height: 52, alignment: .trailing)
        .padding(.horizontal, 12)
        .liquidGlass(
            palette: palette,
            cornerRadius: palette.controlRadius,
            tint: palette.glassTint,
            strokeOpacity: 0.84
        )
    }
}

private struct ZoomControls: View {
    @Binding var zoomScale: CGFloat

    let zoomRange: ClosedRange<CGFloat>
    let onReset: () -> Void
    let palette: AgentTracePalette

    var body: some View {
        HStack(spacing: 8) {
            Button {
                zoomScale = clamped(zoomScale - 0.1)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Zoom Out")

            Slider(value: $zoomScale, in: zoomRange, step: 0.05)
                .frame(width: 92)
                .help("Canvas Zoom")

            Button {
                zoomScale = clamped(zoomScale + 0.1)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Zoom In")

            Button {
                onReset()
            } label: {
                Text("\(Int((zoomScale * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .frame(width: 42)
            }
            .help("Reset Zoom")
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .frame(height: 40)
        .liquidGlass(
            palette: palette,
            cornerRadius: palette.controlRadius,
            tint: palette.panelSecondary.opacity(0.85),
            strokeOpacity: 0.84
        )
        .shadow(color: Color(hex: 0x0f172a).opacity(0.10), radius: 14, x: 0, y: 7)
    }

    private func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, zoomRange.lowerBound), zoomRange.upperBound)
    }
}

private struct GraphViewport: View {
    private let freeformCanvasPadding: CGFloat = 360
    private let panOverscrollPadding: CGFloat = 420
    private let nodeBoundaryInset: CGFloat = 96
    private let minimumCanvasSize = CGSize(width: 2_400, height: 1_600)
    private let verticalNodeSpacing: CGFloat = 156

    let nodes: [AgentNode]
    let selectedNode: AgentNode?
    let nodeSize: CGSize
    let depthSpacing: CGFloat
    @Binding var nodeOffsets: [AgentNode.ID: CGSize]
    @Binding var nodeSizes: [AgentNode.ID: CGSize]
    let zoomScale: CGFloat
    let onSelect: (AgentNode) -> Void
    let onZoom: (CGFloat, Bool) -> Void
    let palette: AgentTracePalette

    @State private var panOffset: CGSize = .zero
    @State private var activeDrag: ActiveNodeDrag?
    @State private var activeInteraction: ActiveCanvasInteraction?

    private var contentSize: CGSize {
        let movedBounds = nodeBounds

        return CGSize(
            width: max(
                minimumCanvasSize.width,
                freeformCanvasPadding + nodeSize.width + freeformCanvasPadding,
                movedBounds.maxX + freeformCanvasPadding
            ),
            height: max(
                minimumCanvasSize.height,
                freeformCanvasPadding + CGFloat(nodes.count) * verticalNodeSpacing + nodeSize.height,
                movedBounds.maxY + freeformCanvasPadding
            )
        )
    }

    private var nodeBounds: CGRect {
        guard !nodes.isEmpty else { return CGRect(origin: .zero, size: nodeSize) }

        return nodes.enumerated().reduce(CGRect.null) { bounds, indexedNode in
            let node = indexedNode.element
            let origin = position(for: node, at: indexedNode.offset)
            let size = nodeSizes[node.id] ?? nodeSize
            return bounds.union(CGRect(origin: origin, size: size))
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(palette.window.opacity(0.44))
                    .contentShape(Rectangle())

                GraphCanvas(
                    nodes: nodes,
                    selectedNode: selectedNode,
                    nodeSize: nodeSize,
                    depthSpacing: depthSpacing,
                    contentSize: contentSize,
                    nodeOffsets: nodeOffsets,
                    nodeSizes: nodeSizes,
                    activeDrag: activeDrag,
                    zoomScale: zoomScale,
                    palette: palette
                )
                .offset(panOffset)
            }
            .clipped()
            .coordinateSpace(name: "graphCanvas")
            .contentShape(Rectangle())
            .highPriorityGesture(canvasInteractionGesture(viewportSize: geometry.size))
            .background(
                MacCanvasEventBridge(
                    onScroll: { delta in panBy(delta, viewportSize: geometry.size) },
                    onMagnify: { delta in
                        onZoom(zoomScale * max(0.2, 1 + delta), false)
                    }
                )
            )
            .onChange(of: zoomScale) { _, _ in
                panOffset = clampedPan(panOffset, viewportSize: geometry.size)
            }
            .onChange(of: nodes.count) { _, _ in
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    panOffset = clampedPan(panOffset, viewportSize: geometry.size)
                }
            }
        }
    }

    private func canvasInteractionGesture(viewportSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                if activeInteraction == nil {
                    let contentPt = contentPoint(for: value.startLocation)
                    if let hit = nodeAndIndex(at: contentPt) {
                        let origin = position(for: hit.node, at: hit.index)
                        let size = nodeSizes[hit.node.id] ?? nodeSize

                        if contentPt.x >= origin.x + size.width - 20 &&
                           contentPt.y >= origin.y + size.height - 20 {
                            activeInteraction = .resize(nodeId: hit.node.id, startSize: size)
                        } else {
                            activeInteraction = .node(
                                nodeId: hit.node.id,
                                startOffset: nodeOffsets[hit.node.id] ?? .zero,
                                hasMoved: false
                            )
                        }
                    } else {
                        activeInteraction = .canvas(startOffset: panOffset)
                    }
                }

                switch activeInteraction {
                case let .node(nodeId, startOffset, hasMoved):
                    let translation = unscaledTranslation(value.translation)
                    guard hasMoved || translation.length >= 8 else { return }

                    let finalOffset = movedNodeOffset(
                        nodeId: nodeId,
                        startOffset: startOffset,
                        translation: translation
                    )

                    if !hasMoved {
                        activeInteraction = .node(nodeId: nodeId, startOffset: startOffset, hasMoved: true)
                    }

                    var transaction = Transaction()
                    transaction.animation = nil
                    withTransaction(transaction) {
                        activeDrag = ActiveNodeDrag(nodeId: nodeId, offset: finalOffset)
                    }

                case let .canvas(startOffset):
                    panOffset = clampedPan(
                        CGSize(
                            width: startOffset.width + value.translation.width,
                            height: startOffset.height + value.translation.height
                        ),
                        viewportSize: viewportSize
                    )

                case let .resize(nodeId, startSize):
                    let translation = unscaledTranslation(value.translation)
                    nodeSizes[nodeId] = CGSize(
                        width: max(180, startSize.width + translation.width),
                        height: max(80, startSize.height + translation.height)
                    )

                case nil:
                    break
                }
            }
            .onEnded { value in
                switch activeInteraction {
                case let .node(nodeId, startOffset, hasMoved):
                    if hasMoved {
                        let translation = unscaledTranslation(value.translation)
                        nodeOffsets[nodeId] = movedNodeOffset(
                            nodeId: nodeId,
                            startOffset: startOffset,
                            translation: translation
                        )
                    } else if let node = nodes.first(where: { $0.id == nodeId }) {
                        onSelect(node)
                    }

                    activeDrag = nil
                    activeInteraction = nil

                case let .canvas(startOffset):
                    panOffset = clampedPan(
                        CGSize(
                            width: startOffset.width + value.translation.width,
                            height: startOffset.height + value.translation.height
                        ),
                        viewportSize: viewportSize
                    )
                    activeInteraction = nil

                case .resize:
                    activeInteraction = nil

                case nil:
                    break
                }
            }
    }

    private func panBy(_ delta: CGSize, viewportSize: CGSize) {
        panOffset = clampedPan(
            CGSize(
                width: panOffset.width + delta.width,
                height: panOffset.height + delta.height
            ),
            viewportSize: viewportSize
        )
    }

    private func clampedPan(_ offset: CGSize, viewportSize: CGSize) -> CGSize {
        let scaledContentSize = CGSize(width: contentSize.width * zoomScale, height: contentSize.height * zoomScale)
        let minimumX = min(0, viewportSize.width - scaledContentSize.width - panOverscrollPadding)
        let minimumY = min(0, viewportSize.height - scaledContentSize.height - panOverscrollPadding)
        let maximumX = panOverscrollPadding
        let maximumY = panOverscrollPadding

        return CGSize(
            width: min(max(offset.width, minimumX), maximumX),
            height: min(max(offset.height, minimumY), maximumY)
        )
    }

    private func contentPoint(for viewportPoint: CGPoint) -> CGPoint {
        let safeZoomScale = max(zoomScale, 0.01)

        return CGPoint(
            x: (viewportPoint.x - panOffset.width) / safeZoomScale,
            y: (viewportPoint.y - panOffset.height) / safeZoomScale
        )
    }

    private func nodeAndIndex(at contentPoint: CGPoint) -> (node: AgentNode, index: Int)? {
        for indexedNode in Array(nodes.enumerated()).reversed() {
            let node = indexedNode.element
            let origin = position(for: node, at: indexedNode.offset)
            let size = nodeSizes[node.id] ?? nodeSize
            let rect = CGRect(origin: origin, size: size).insetBy(dx: -6, dy: -6)

            if rect.contains(contentPoint) {
                return (node, indexedNode.offset)
            }
        }

        return nil
    }

    private func node(at contentPoint: CGPoint) -> AgentNode? {
        nodeAndIndex(at: contentPoint)?.node
    }

    private func position(for node: AgentNode, at index: Int) -> CGPoint {
        let base = defaultPosition(for: node, at: index)
        let offset: CGSize

        if activeDrag?.nodeId == node.id {
            offset = activeDrag?.offset ?? .zero
        } else {
            offset = nodeOffsets[node.id] ?? .zero
        }

        return CGPoint(x: base.x + offset.width, y: base.y + offset.height)
    }

    private func defaultPosition(for node: AgentNode, at index: Int) -> CGPoint {
        CGPoint(
            x: nodeBoundaryInset,
            y: nodeBoundaryInset + CGFloat(index) * verticalNodeSpacing
        )
    }

    private func unscaledTranslation(_ translation: CGSize) -> CGSize {
        let safeZoomScale = max(zoomScale, 0.01)

        return CGSize(
            width: translation.width / safeZoomScale,
            height: translation.height / safeZoomScale
        )
    }

    private func movedNodeOffset(nodeId: AgentNode.ID, startOffset: CGSize, translation: CGSize) -> CGSize {
        let proposedOffset = CGSize(
            width: startOffset.width + translation.width,
            height: startOffset.height + translation.height
        )

        guard let indexedNode = nodes.enumerated().first(where: { $0.element.id == nodeId }) else {
            return proposedOffset
        }

        let basePosition = defaultPosition(for: indexedNode.element, at: indexedNode.offset)
        let size = nodeSizes[nodeId] ?? nodeSize
        let minimumOriginX = nodeBoundaryInset
        let minimumOriginY = nodeBoundaryInset
        let maximumOriginX = contentSize.width + panOverscrollPadding - size.width - nodeBoundaryInset
        let maximumOriginY = contentSize.height + panOverscrollPadding - size.height - nodeBoundaryInset
        let proposedOrigin = CGPoint(
            x: basePosition.x + proposedOffset.width,
            y: basePosition.y + proposedOffset.height
        )
        let clampedOrigin = CGPoint(
            x: min(max(proposedOrigin.x, minimumOriginX), maximumOriginX),
            y: min(max(proposedOrigin.y, minimumOriginY), maximumOriginY)
        )

        return CGSize(
            width: clampedOrigin.x - basePosition.x,
            height: clampedOrigin.y - basePosition.y
        )
    }
}

private struct MacCanvasEventBridge: NSViewRepresentable {
    let onScroll: (CGSize) -> Void
    let onMagnify: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.view = view
        context.coordinator.onScroll = onScroll
        context.coordinator.onMagnify = onMagnify
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.view = nsView
        context.coordinator.onScroll = onScroll
        context.coordinator.onMagnify = onMagnify
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator {
        weak var view: NSView?
        var onScroll: ((CGSize) -> Void)?
        var onMagnify: ((CGFloat) -> Void)?
        private var monitor: Any?

        func installMonitor() {
            guard monitor == nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify]) { [weak self] event in
                guard let self, contains(event: event) else { return event }

                switch event.type {
                case .scrollWheel:
                    let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 16
                    let dx = event.scrollingDeltaX * multiplier
                    let dy = event.scrollingDeltaY * multiplier

                    if dx == 0 && dy == 0 {
                        return event
                    }

                    onScroll?(CGSize(width: -dx, height: -dy))
                    return nil

                case .magnify:
                    if event.magnification == 0 {
                        return event
                    }

                    onMagnify?(event.magnification)
                    return nil

                default:
                    return event
                }
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }

            monitor = nil
        }

        private func contains(event: NSEvent) -> Bool {
            guard let view, event.window === view.window else { return false }
            let location = view.convert(event.locationInWindow, from: nil)
            return view.bounds.contains(location)
        }
    }
}

private struct GraphCanvas: View {
    private let verticalNodeSpacing: CGFloat = 156
    private let nodeBoundaryInset: CGFloat = 96

    let nodes: [AgentNode]
    let selectedNode: AgentNode?
    let nodeSize: CGSize
    let depthSpacing: CGFloat
    let contentSize: CGSize
    let nodeOffsets: [AgentNode.ID: CGSize]
    let nodeSizes: [AgentNode.ID: CGSize]
    let activeDrag: ActiveNodeDrag?
    let zoomScale: CGFloat
    let palette: AgentTracePalette

    var body: some View {
        ZStack(alignment: .topLeading) {
            if nodes.isEmpty {
                GraphEmptyState()
                    .frame(width: contentSize.width, height: contentSize.height)
            } else {
                GraphConnections(
                    nodes: nodes,
                    positions: positions,
                    contentSize: contentSize,
                    nodeSizes: nodeSizes,
                    defaultNodeSize: nodeSize,
                    palette: palette
                )

                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    MovableNodeCard(
                        node: node,
                        selected: node.id == selectedNode?.id,
                        basePosition: defaultPosition(for: node, at: index),
                        currentOffset: currentOffset(for: node),
                        nodeSize: nodeSizes[node.id] ?? nodeSize,
                        isDragging: activeDrag?.nodeId == node.id,
                        palette: palette
                    )
                }
            }
        }
        .frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
        .scaleEffect(zoomScale, anchor: .topLeading)
        .frame(width: contentSize.width * zoomScale, height: contentSize.height * zoomScale, alignment: .topLeading)
    }

    private var positions: [AgentNode.ID: CGPoint] {
        Dictionary(uniqueKeysWithValues: nodes.enumerated().map { index, node in
            let base = defaultPosition(for: node, at: index)
            let offset = currentOffset(for: node)
            return (
                node.id,
                CGPoint(x: base.x + offset.width, y: base.y + offset.height)
            )
        })
    }

    private func currentOffset(for node: AgentNode) -> CGSize {
        if activeDrag?.nodeId == node.id {
            return activeDrag?.offset ?? .zero
        }

        return nodeOffsets[node.id] ?? .zero
    }

    private func defaultPosition(for node: AgentNode, at index: Int) -> CGPoint {
        CGPoint(
            x: nodeBoundaryInset,
            y: nodeBoundaryInset + CGFloat(index) * verticalNodeSpacing
        )
    }
}

private struct ActiveNodeDrag {
    let nodeId: AgentNode.ID
    let offset: CGSize
}

private enum ActiveCanvasInteraction {
    case node(nodeId: AgentNode.ID, startOffset: CGSize, hasMoved: Bool)
    case canvas(startOffset: CGSize)
    case resize(nodeId: AgentNode.ID, startSize: CGSize)
}

private struct GraphConnections: View {
    let nodes: [AgentNode]
    let positions: [AgentNode.ID: CGPoint]
    let contentSize: CGSize
    let nodeSizes: [AgentNode.ID: CGSize]
    let defaultNodeSize: CGSize
    let palette: AgentTracePalette

    var body: some View {
        Canvas { context, _ in
            guard nodes.count > 1 else { return }

            for index in 1..<nodes.count {
                let previous = nodes[index - 1]
                let current = nodes[index]

                guard let from = positions[previous.id], let to = positions[current.id] else {
                    continue
                }

                let fromSize = nodeSizes[previous.id] ?? defaultNodeSize
                let toSize = nodeSizes[current.id] ?? defaultNodeSize
                let anchors = bestAnchorPair(from: from, sourceSize: fromSize, to: to, targetSize: toSize)
                let controlPoints = controlPoints(for: anchors)

                var path = Path()
                path.move(to: anchors.start)
                path.addCurve(
                    to: anchors.end,
                    control1: controlPoints.first,
                    control2: controlPoints.second
                )

                let edgeColor = palette.color(for: current.status)
                let strokeStyle = StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)

                context.stroke(path, with: .color(edgeColor), style: strokeStyle)
                context.fill(
                    Path(ellipseIn: CGRect(x: anchors.end.x - 5.5, y: anchors.end.y - 5.5, width: 11, height: 11)),
                    with: .color(palette.window)
                )
                context.stroke(
                    Path(ellipseIn: CGRect(x: anchors.end.x - 5.5, y: anchors.end.y - 5.5, width: 11, height: 11)),
                    with: .color(edgeColor),
                    lineWidth: 2
                )
            }
        }
        .frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func bestAnchorPair(from sourceOrigin: CGPoint, sourceSize: CGSize, to targetOrigin: CGPoint, targetSize: CGSize) -> NodeAnchorPair {
        let sourceCenter = sourceOrigin.center(in: sourceSize)
        let targetCenter = targetOrigin.center(in: targetSize)
        let centerDelta = CGSize(width: targetCenter.x - sourceCenter.x, height: targetCenter.y - sourceCenter.y)
        let preferredSides = preferredAnchorSides(for: centerDelta)

        var bestPair: NodeAnchorPair?
        var bestScore = CGFloat.infinity

        for startSide in NodeAnchorSide.allCases {
            for endSide in NodeAnchorSide.allCases {
                let start = startSide.point(for: sourceOrigin, nodeSize: sourceSize)
                let end = endSide.point(for: targetOrigin, nodeSize: targetSize)
                let delta = CGSize(width: end.x - start.x, height: end.y - start.y)
                let distance = delta.length
                let direction = delta.normalized

                let startsAgainstFlow = max(0, -direction.dot(startSide.normal)) * 120
                let endsAgainstFlow = max(0, direction.dot(endSide.normal)) * 120
                let readabilityPenalty: CGFloat = startSide == preferredSides.start && endSide == preferredSides.end ? 0 : 24
                let score = distance + startsAgainstFlow + endsAgainstFlow + readabilityPenalty

                if score < bestScore {
                    bestScore = score
                    bestPair = NodeAnchorPair(
                        start: start,
                        end: end,
                        startSide: startSide,
                        endSide: endSide,
                        distance: distance
                    )
                }
            }
        }

        return bestPair ?? NodeAnchorPair(
            start: .zero,
            end: .zero,
            startSide: .right,
            endSide: .left,
            distance: 0
        )
    }

    private func preferredAnchorSides(for delta: CGSize) -> (start: NodeAnchorSide, end: NodeAnchorSide) {
        if abs(delta.width) >= abs(delta.height) {
            return delta.width >= 0 ? (.right, .left) : (.left, .right)
        }

        return delta.height >= 0 ? (.bottom, .top) : (.top, .bottom)
    }

    private func controlPoints(for anchors: NodeAnchorPair) -> (first: CGPoint, second: CGPoint) {
        if anchors.startSide.isVertical && anchors.endSide.isVertical {
            let distance = abs(anchors.end.y - anchors.start.y) * 0.5
            let direction: CGFloat = anchors.end.y >= anchors.start.y ? 1 : -1

            return (
                CGPoint(x: anchors.start.x, y: anchors.start.y + distance * direction),
                CGPoint(x: anchors.end.x, y: anchors.end.y - distance * direction)
            )
        }

        let controlDistance = max(28, min(160, anchors.distance * 0.45))

        return (
            anchors.start.offset(by: anchors.startSide.normal, distance: controlDistance),
            anchors.end.offset(by: anchors.endSide.normal, distance: controlDistance)
        )
    }
}

private enum NodeAnchorSide: CaseIterable {
    case top
    case bottom
    case left
    case right

    var normal: CGSize {
        switch self {
        case .top:
            return CGSize(width: 0, height: -1)
        case .bottom:
            return CGSize(width: 0, height: 1)
        case .left:
            return CGSize(width: -1, height: 0)
        case .right:
            return CGSize(width: 1, height: 0)
        }
    }

    var isVertical: Bool {
        self == .top || self == .bottom
    }

    func point(for origin: CGPoint, nodeSize: CGSize) -> CGPoint {
        switch self {
        case .top:
            return CGPoint(x: origin.x + nodeSize.width / 2, y: origin.y)
        case .bottom:
            return CGPoint(x: origin.x + nodeSize.width / 2, y: origin.y + nodeSize.height)
        case .left:
            return CGPoint(x: origin.x, y: origin.y + nodeSize.height / 2)
        case .right:
            return CGPoint(x: origin.x + nodeSize.width, y: origin.y + nodeSize.height / 2)
        }
    }

    func markerPosition(in size: CGSize) -> CGPoint {
        switch self {
        case .top:
            return CGPoint(x: size.width / 2, y: 0)
        case .bottom:
            return CGPoint(x: size.width / 2, y: size.height)
        case .left:
            return CGPoint(x: 0, y: size.height / 2)
        case .right:
            return CGPoint(x: size.width, y: size.height / 2)
        }
    }
}

private struct NodeAnchorPair {
    let start: CGPoint
    let end: CGPoint
    let startSide: NodeAnchorSide
    let endSide: NodeAnchorSide
    let distance: CGFloat
}

private extension CGSize {
    var length: CGFloat {
        (width * width + height * height).squareRoot()
    }

    var normalized: CGSize {
        let safeLength = max(length, 0.001)
        return CGSize(width: width / safeLength, height: height / safeLength)
    }

    func dot(_ other: CGSize) -> CGFloat {
        width * other.width + height * other.height
    }
}

private extension CGPoint {
    func center(in size: CGSize) -> CGPoint {
        CGPoint(x: x + size.width / 2, y: y + size.height / 2)
    }

    func offset(by direction: CGSize, distance: CGFloat) -> CGPoint {
        CGPoint(x: x + direction.width * distance, y: y + direction.height * distance)
    }
}

private struct GraphEmptyState: View {
    var body: some View {
        ContentUnavailableView(
            "No Traces Yet",
            systemImage: "network",
            description: Text("Run codex in Terminal or send traffic through the proxy")
        )
    }
}

private struct MovableNodeCard: View {
    let node: AgentNode
    let selected: Bool
    let basePosition: CGPoint
    let currentOffset: CGSize
    let nodeSize: CGSize
    let isDragging: Bool
    let palette: AgentTracePalette

    var body: some View {
        NodeCard(node: node, selected: selected, size: nodeSize, palette: palette)
            .position(
                x: basePosition.x + currentOffset.width + nodeSize.width / 2,
                y: basePosition.y + currentOffset.height + nodeSize.height / 2
            )
            .scaleEffect(isDragging ? 1.008 : 1)
            .zIndex(isDragging ? 30 : selected ? 10 : 1)
            .contentShape(RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous))
            .allowsHitTesting(false)
            .transaction { transaction in
                if isDragging {
                    transaction.animation = nil
                }
            }
    }
}

private struct NodeCard: View {
    let node: AgentNode
    let selected: Bool
    let size: CGSize
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                StatusDot(status: node.status, palette: palette)
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(node.stepName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.text)
                        .lineLimit(nil)

                    HStack(spacing: 6) {
                        AgentBadge(name: node.agentName, palette: palette)

                        Text("\(node.model) - \(node.requestId)")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(palette.textQuaternary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(node.status.label)
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(palette.color(for: node.status))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(palette.background(for: node.status))
                    .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
            }

            ProgressBar(value: node.barPercent, status: node.status, palette: palette)
                .padding(.top, 9)

            HStack(spacing: 10) {
                NodeFootnote(label: "lat", text: node.latency, palette: palette)
                NodeFootnote(label: "cost", text: node.cost, palette: palette)

                Spacer(minLength: 0)

                Text("\(node.tokensIn) down \(node.tokensOut) up tok")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(palette.textTertiary)
                    .lineLimit(nil)
            }
            .padding(.top, 10)
            .overlay(alignment: .top) {
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(palette.border)
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
        .background(
            ZStack {
                LinearGradient(
                    colors: [palette.nodeTop.opacity(0.62), palette.nodeBottom.opacity(0.42)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if selected {
                    palette.accentBackground.opacity(0.85)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(palette.color(for: node.status))
                .frame(width: 3)
                .padding(.vertical, 10)
        }
        .overlay(
            RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous)
                .stroke(
                    selected ? palette.accent : palette.borderStrong,
                    lineWidth: selected ? 2 : 1
                )
        )
        .shadow(color: selected ? Color(hex: 0x0f172a).opacity(0.10) : .clear, radius: 12, x: 0, y: 6)
        .overlay {
            NodeAnchorMarkers(palette: palette)
        }
        .contentShape(RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .padding(6)
        }
    }
}

private struct NodeAnchorMarkers: View {
    let palette: AgentTracePalette

    var body: some View {
        GeometryReader { geometry in
            ForEach(NodeAnchorSide.allCases, id: \.self) { side in
                Circle()
                    .fill(palette.window.opacity(0.96))
                    .frame(width: 10, height: 10)
                    .overlay {
                        Circle()
                            .stroke(palette.borderStrong, lineWidth: 1.4)
                    }
                    .position(side.markerPosition(in: geometry.size))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ProgressBar: View {
    let value: Double
    let status: NodeStatus
    let palette: AgentTracePalette

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(palette.panelSecondary)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [palette.dimColor(for: status), palette.color(for: status)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * min(max(value, 0), 100) / 100)
            }
        }
        .frame(height: 3)
    }
}

private struct NodeFootnote: View {
    let label: String
    let text: String
    let palette: AgentTracePalette

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(palette.textQuaternary)
            Text(text)
                .fontWeight(.semibold)
                .foregroundStyle(palette.textSecondary)
        }
        .font(.system(size: 10.5, design: .monospaced))
        .foregroundStyle(palette.textTertiary)
        .lineLimit(1)
    }
}
