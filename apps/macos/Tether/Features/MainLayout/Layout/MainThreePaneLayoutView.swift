import Core
import Networking
import SwiftUI
import UI

struct MainThreePaneLayoutView: View {
    @ObservedObject var traceStore: TraceStore
    @State var selectedNodeId: AgentNode.ID?
    @State var inspectorTab: InspectorTab = .context
    @State var searchText = ""
    @State var responseEdits: [AgentNode.ID: String] = [:]
    @State var replayImpacts: [AgentNode.ID: TraceInvalidationResult] = [:]
    @State var compactSection: CompactSection = .graph
    @State var inspectorVisible = true
    @State var showingClearConfirmation = false
    @State var showingConnectionHelp = false
    @State var showingSettings = false
    @State var shortcutFeedback: String?
    @State var shortcutFeedbackTask: Task<Void, Never>?
    @State var notificationTokens: [NSObjectProtocol] = []
    @State var workspaceGuideVisible = false
    @State var workspaceGuideStep: WorkspaceGuideStep = .intro
    @State var graphFocusRequest = 0
    @FocusState var searchFocused: Bool
    @AppStorage("hasSeenWorkspaceGuide") var hasSeenWorkspaceGuide = false

    @EnvironmentObject var preferences: AppPreferences

    var palette: AgentTracePalette {
        AgentTracePalette(light: true)
    }

    var nodes: [AgentNode] {
        traceStore.nodes.filter { preferences.capturesProvider(of: $0) }
    }

    var historyCount: Int {
        0
    }

    var callListNodes: [AgentNode] {
        nodes
    }

    var filteredNodes: [AgentNode] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return callListNodes }

        return callListNodes.filter { node in
            node.stepName.localizedCaseInsensitiveContains(query)
                || node.agentName.localizedCaseInsensitiveContains(query)
                || node.model.localizedCaseInsensitiveContains(query)
                || node.requestId.localizedCaseInsensitiveContains(query)
        }
    }

    var selectedNode: AgentNode? {
        if let selectedNodeId, let node = nodes.first(where: { $0.id == selectedNodeId }) {
            return node
        }

        return nodes.first
    }

    var totalLatencyMs: Int {
        nodes.reduce(0) { $0 + $1.latencyMs }
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = AdaptiveWorkspaceLayout(size: geometry.size)

            ZStack {
                palette.stage
                    .ignoresSafeArea()

                workspace(layout: layout, size: geometry.size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .blur(radius: showingSettings || workspaceGuideVisible ? 3 : 0)
                    .saturation(showingSettings || workspaceGuideVisible ? 0.78 : 1)
                    .animation(.smooth(duration: 0.16), value: showingSettings || workspaceGuideVisible)
                    .environment(\.graphCanvasInputEnabled, !showingSettings && !workspaceGuideVisible)

                if showingSettings {
                    WorkspaceSettingsOverlay(
                        palette: palette,
                        onDismiss: {
                            withAnimation(.smooth(duration: 0.16)) {
                                showingSettings = false
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(20)
                }

                if workspaceGuideVisible {
                    WorkspaceGuideOverlay(
                        step: workspaceGuideStep,
                        layout: layout,
                        palette: palette,
                        onBack: moveWorkspaceGuideBack,
                        onNext: moveWorkspaceGuideForward,
                        onSkip: completeWorkspaceGuide
                    )
                    .transition(.opacity)
                    .zIndex(24)
                }

                if let shortcutFeedback {
                    ShortcutFeedbackBanner(text: shortcutFeedback, palette: palette)
                        .padding(.top, 18)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .zIndex(30)
                }
            }
        }
        .ignoresSafeArea()
        .environmentObject(traceStore)
        .preferredColorScheme(.light)
        .frame(minWidth: 800, minHeight: 520)
        .onAppear {
            _ = LocalProxyLauncher.shared.startIfAvailable()
            traceStore.startPolling()
            installWorkspaceObservers()
            showWorkspaceGuideIfNeeded()
        }
        .onDisappear {
            traceStore.stopPolling()
            shortcutFeedbackTask?.cancel()
            removeWorkspaceObservers()
        }
        .onChange(of: traceStore.nodes) { _, _ in
            syncSelectedNode(with: nodes)
        }
        .task(id: selectedNode?.id) {
            await loadSelectedNodeDetail()
        }
        .alert("Delete All History?", isPresented: $showingClearConfirmation) {
            Button("Delete All History", role: .destructive) {
                deleteAllHistory()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes every stored trace and hides existing Terminal Codex events until new activity arrives. This cannot be undone.")
        }
        .sheet(isPresented: $showingConnectionHelp) {
            ConnectionHelpSheet()
        }
    }

    func syncSelectedNode(with newNodes: [AgentNode]) {
        guard !newNodes.isEmpty else {
            selectedNodeId = nil
            return
        }

        let selectionIsValid = selectedNodeId.map { id in newNodes.contains { $0.id == id } } ?? false

        if preferences.autoSelectNewNode {
            selectedNodeId = newNodes[newNodes.count - 1].id
        } else if !selectionIsValid {
            selectedNodeId = newNodes[0].id
        }
    }

    func loadSelectedNodeDetail() async {
        guard let selectedNodeId = selectedNode?.id else { return }
        await traceStore.loadNodeDetailIfNeeded(selectedNodeId)
    }

    func installWorkspaceObservers() {
        guard notificationTokens.isEmpty else { return }

        let center = NotificationCenter.default
        notificationTokens = [
            center.addObserver(forName: .agentTraceNewSession, object: nil, queue: .main) { _ in resetTransientSelection() },
            center.addObserver(forName: .agentTraceExportTraces, object: nil, queue: .main) { _ in exportTraces() },
            center.addObserver(forName: .agentTraceCopyFailureAnalysisPrompt, object: nil, queue: .main) { _ in copyFailureAnalysisPrompt() },
            center.addObserver(forName: .agentTraceCopySelection, object: nil, queue: .main) { _ in copySelection() },
            center.addObserver(forName: .agentTraceClearView, object: nil, queue: .main) { _ in returnToLiveView() },
            center.addObserver(forName: .agentTraceClearAllTraces, object: nil, queue: .main) { _ in clearAllTracesFromCommand() },
            center.addObserver(forName: .agentTraceShowInspector, object: nil, queue: .main) { _ in showInspectorFromCommand() },
            center.addObserver(forName: .agentTraceShowGraph, object: nil, queue: .main) { _ in showGraphFromCommand() },
            center.addObserver(forName: .agentTraceToggleInspector, object: nil, queue: .main) { _ in toggleInspector() },
            center.addObserver(forName: .agentTraceFocusSearch, object: nil, queue: .main) { _ in focusNodeSearch() },
            center.addObserver(forName: .agentTraceSelectInspectorTab, object: nil, queue: .main) { notification in selectInspectorTab(notification.object) },
            center.addObserver(forName: .agentTraceSelectPreviousNode, object: nil, queue: .main) { _ in selectAdjacentNode(offset: -1) },
            center.addObserver(forName: .agentTraceSelectNextNode, object: nil, queue: .main) { _ in selectAdjacentNode(offset: 1) },
            center.addObserver(forName: .agentTraceReplaySelectedNode, object: nil, queue: .main) { _ in replaySelectedNodeFromShortcut() },
            center.addObserver(forName: .agentTraceReload, object: nil, queue: .main) { _ in reloadTraceFromCommand() },
            center.addObserver(forName: .agentTraceShowOnboarding, object: nil, queue: .main) { _ in showingConnectionHelp = true },
            center.addObserver(forName: .agentTraceShowSettings, object: nil, queue: .main) { _ in showSettingsFromCommand() }
        ]
    }

    func removeWorkspaceObservers() {
        let center = NotificationCenter.default
        for token in notificationTokens {
            center.removeObserver(token)
        }
        notificationTokens.removeAll()
    }

    func clearAllTracesFromCommand() {
        if preferences.confirmBeforeClearing {
            showingClearConfirmation = true
        } else {
            deleteAllHistory()
        }
    }

    func showInspectorFromCommand() {
        inspectorVisible = true
        compactSection = .inspector
        showShortcutFeedback("Inspector shown")
    }

    func showGraphFromCommand() {
        compactSection = .graph
        showShortcutFeedback("Graph shown")
    }

    func focusNodeSearch() {
        compactSection = .calls
        searchFocused = true
        showShortcutFeedback("Search nodes")
    }

    func selectInspectorTab(_ object: Any?) {
        guard let tab = object as? InspectorTab else { return }
        inspectorTab = tab
        inspectorVisible = true
        compactSection = .inspector
        showShortcutFeedback(tab.title)
    }

    func reloadTraceFromCommand() {
        traceStore.reload()
        showShortcutFeedback("Trace reloaded")
    }

    func showSettingsFromCommand() {
        withAnimation(.smooth(duration: 0.16)) {
            showingSettings = true
        }
    }

    func showWorkspaceGuideIfNeeded() {
        guard !hasSeenWorkspaceGuide else { return }

        workspaceGuideStep = .intro
        withAnimation(.smooth(duration: 0.18)) {
            workspaceGuideVisible = true
        }
    }

    func moveWorkspaceGuideBack() {
        guard let previous = workspaceGuideStep.previous else { return }

        withAnimation(.smooth(duration: 0.18)) {
            workspaceGuideStep = previous
        }
    }

    func moveWorkspaceGuideForward() {
        guard let next = workspaceGuideStep.next else {
            completeWorkspaceGuide()
            return
        }

        withAnimation(.smooth(duration: 0.18)) {
            workspaceGuideStep = next
        }
    }

    func completeWorkspaceGuide() {
        hasSeenWorkspaceGuide = true
        withAnimation(.smooth(duration: 0.18)) {
            workspaceGuideVisible = false
        }
    }

    func toggleInspector() {
        withAnimation(.smooth(duration: 0.18)) {
            if compactSection == .inspector {
                compactSection = .graph
            } else {
                inspectorVisible.toggle()
                compactSection = .inspector
            }
        }
        showShortcutFeedback(inspectorVisible || compactSection == .inspector ? "Inspector shown" : "Inspector hidden")
    }

    func selectAdjacentNode(offset: Int) {
        guard !nodes.isEmpty else {
            showShortcutFeedback("No nodes yet")
            return
        }

        let currentIndex = selectedNodeId.flatMap { id in nodes.firstIndex { $0.id == id } } ?? 0
        let nextIndex = min(max(currentIndex + offset, 0), nodes.count - 1)
        selectedNodeId = nodes[nextIndex].id
        graphFocusRequest += 1
        showShortcutFeedback(offset < 0 ? "Previous node" : "Next node")
    }

    func replaySelectedNodeFromShortcut() {
        guard let selectedNode else {
            showShortcutFeedback("No node selected")
            return
        }

        if selectedNode.provider.lowercased() == "codex-log" || selectedNode.cacheStatus == "codex-log" {
            showShortcutFeedback("Replay needs a proxy-captured request")
            return
        }

        showShortcutFeedback("Replaying selected node...")
        Task {
            do {
                _ = try await traceStore.client.replayNode(nodeId: selectedNode.id)
                await traceStore.refresh()
                await MainActor.run {
                    showShortcutFeedback("Replay complete")
                }
            } catch {
                await MainActor.run {
                    showShortcutFeedback("Replay failed")
                }
            }
        }
    }

    func showShortcutFeedback(_ text: String) {
        shortcutFeedbackTask?.cancel()
        withAnimation(.smooth(duration: 0.12)) {
            shortcutFeedback = text
        }
        shortcutFeedbackTask = Task {
            try? await Task.sleep(for: .milliseconds(950))
            await MainActor.run {
                withAnimation(.smooth(duration: 0.16)) {
                    if shortcutFeedback == text {
                        shortcutFeedback = nil
                    }
                }
            }
        }
    }
}

private struct ShortcutFeedbackBanner: View {
    let text: String
    let palette: AgentTracePalette

    var body: some View {
        Text(text)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(palette.text)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(palette.elevated.opacity(0.94), in: RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                    .stroke(palette.borderStrong, lineWidth: 1)
            }
            .shadow(color: palette.liquidShade.opacity(0.20), radius: 8, x: 0, y: 4)
    }
}
