import AppKit
import Combine
import Core
import SwiftUI
import UI

struct ContentView: View {
    @StateObject private var preferences = AppPreferences.shared
    @StateObject private var updateChecker = UpdateChecker()
    @StateObject private var traceStore = TraceStore()

    var body: some View {
        VStack(spacing: 0) {
            UpdateBannerView(checker: updateChecker)
            MainThreePaneLayoutView(traceStore: traceStore)
                .frame(minWidth: 800, minHeight: 520)
        }
        .background(WindowSizeConfigurator())
        .background(QuickviewPanelBridge(traceStore: traceStore, preferences: preferences))
        .environmentObject(preferences)
        .preferredColorScheme(.light)
        .animation(.smooth(duration: 0.2), value: updateChecker.updateAvailable)
        .transition(.opacity)
        .task {
            WorkspaceAccessStore.shared.ensureStartupAccess(codexIntegrationEnabled: preferences.codexIntegrationEnabled)
            await updateChecker.check()
        }
    }
}

struct QuickviewPanelBridge: NSViewRepresentable {
    @ObservedObject var traceStore: TraceStore
    @ObservedObject var preferences: AppPreferences

    func makeCoordinator() -> QuickviewPanelCoordinator {
        QuickviewPanelCoordinator(traceStore: traceStore, preferences: preferences)
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.installEventMonitors()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(traceStore: traceStore, preferences: preferences)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: QuickviewPanelCoordinator) {
        coordinator.invalidate()
    }
}

@MainActor
final class QuickviewPanelCoordinator {
    private var traceStore: TraceStore
    private var preferences: AppPreferences
    private var panel: NSPanel?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var cancellables: Set<AnyCancellable> = []

    init(traceStore: TraceStore, preferences: AppPreferences) {
        self.traceStore = traceStore
        self.preferences = preferences
        observeStore()
    }

    func update(traceStore: TraceStore, preferences: AppPreferences) {
        self.traceStore = traceStore
        self.preferences = preferences
        observeStore()
        refreshPanel()
    }

    func installEventMonitors() {
        guard localMonitor == nil, globalMonitor == nil else { return }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard Self.handles(event) else { return event }
            Task { @MainActor in
                self?.togglePanel()
            }
            return nil
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard Self.handles(event) else { return }
            Task { @MainActor in
                self?.togglePanel()
            }
        }
    }

    func invalidate() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        localMonitor = nil
        globalMonitor = nil
        panel?.close()
        panel = nil
        cancellables.removeAll()
    }

    private func observeStore() {
        cancellables.removeAll()
        traceStore.$nodes
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshPanel()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .agentTraceToggleQuickview)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.togglePanel()
            }
            .store(in: &cancellables)
    }

    private static func handles(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags.contains(.command)
            && event.charactersIgnoringModifiers?.lowercased() == "t"
    }

    private func togglePanel() {
        let panel = panel ?? makePanel()
        self.panel = panel
        refreshPanel()

        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            position(panel: panel)
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 188),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        return panel
    }

    private func refreshPanel() {
        guard let panel else { return }
        panel.contentViewController = NSHostingController(
            rootView: QuickviewPanelView(
                nodes: visibleNodes,
                palette: AgentTracePalette(light: true),
                onOpenWorkspace: { [weak self] in
                    self?.openWorkspace()
                }
            )
            .environmentObject(preferences)
        )
    }

    private var visibleNodes: [AgentNode] {
        traceStore.nodes.filter { preferences.capturesProvider(of: $0) }
    }

    private func openWorkspace() {
        panel?.orderOut(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows
            .filter { !($0 is NSPanel) }
            .forEach { $0.makeKeyAndOrderFront(nil) }
    }

    private func position(panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let origin = CGPoint(
            x: frame.midX - panel.frame.width / 2,
            y: frame.maxY - panel.frame.height - 72
        )
        panel.setFrameOrigin(origin)
    }
}

struct QuickviewPanelView: View {
    let nodes: [AgentNode]
    let palette: AgentTracePalette
    let onOpenWorkspace: () -> Void

    private var latestNode: AgentNode? {
        nodes.last
    }

    private var failedNode: AgentNode? {
        nodes.last(where: { $0.status == .error })
    }

    private var focusNode: AgentNode? {
        failedNode ?? latestNode
    }

    private var statusText: String {
        guard !nodes.isEmpty else { return "No traces yet" }
        if failedNode != nil { return "Last run failed" }
        if nodes.contains(where: { $0.status == .running }) { return "Run in progress" }
        return "Last run succeeded"
    }

    private var statusColor: Color {
        guard !nodes.isEmpty else { return palette.textTertiary }
        if failedNode != nil { return palette.pink }
        if nodes.contains(where: { $0.status == .running }) { return palette.amber }
        return palette.green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 9, height: 9)

                Text(statusText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.text)

                Spacer(minLength: 0)

                Text("CMD SHIFT T")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.textQuaternary)
            }

            if let focusNode {
                VStack(alignment: .leading, spacing: 6) {
                    Text(focusNode.stepName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        QuickviewChip(text: focusNode.model, palette: palette)
                        QuickviewChip(text: focusNode.latency, palette: palette)
                        QuickviewChip(text: focusNode.cost, palette: palette)
                    }
                }
            } else {
                Text("Run an agent. Tether will show every call.")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.textSecondary)
            }

            Button(action: onOpenWorkspace) {
                HStack {
                    Text(nodes.isEmpty ? "Open Tether" : "Open Full Trace")
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 12.5, weight: .semibold))
                .frame(height: 32)
                .padding(.horizontal, 10)
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.text)
            .background(palette.panelSecondary, in: RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            }
        }
        .padding(18)
        .frame(width: 420, height: 188)
        .background(palette.window.opacity(0.96))
    }
}

private struct QuickviewChip: View {
    let text: String
    let palette: AgentTracePalette

    var body: some View {
        Text(text.isEmpty ? "n/a" : text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(palette.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(palette.panelSecondary.opacity(0.72), in: RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

private struct WindowSizeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)

        DispatchQueue.main.async {
            configure(window: view.window)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }

        let minimumSize = CGSize(width: 800, height: 520)
        window.minSize = minimumSize
        window.maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        if window.frame.width < minimumSize.width || window.frame.height < minimumSize.height {
            window.setContentSize(CGSize(
                width: max(window.frame.width, minimumSize.width),
                height: max(window.frame.height, minimumSize.height)
            ))
        }
    }
}
