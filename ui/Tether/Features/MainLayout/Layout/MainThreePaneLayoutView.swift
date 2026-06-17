import Core
import Networking
import SwiftUI
import UI

/// Main desktop workspace containing sidebar, graph canvas, inspector, and settings overlay.
struct MainThreePaneLayoutView: View {
    @StateObject var traceStore = TraceStore()
    @State var selectedNodeId: AgentNode.ID?
    @State var inspectorTab: InspectorTab = .context
    @State var searchText = ""
    @State var responseEdits: [AgentNode.ID: String] = [:]
    @State var replayImpacts: [AgentNode.ID: TraceInvalidationResult] = [:]
    @State var compactSection: CompactSection = .graph
    @State var showingClearConfirmation = false
    @State var showingConnectionHelp = false
    @State var showingSettings = false

    @EnvironmentObject var preferences: AppPreferences

    var palette: AgentTracePalette {
        AgentTracePalette(light: true)
    }

    /// Captured calls, provider-filtered.
    var nodes: [AgentNode] {
        traceStore.nodes.filter { preferences.capturesProvider(of: $0) }
    }

    /// Historical trace groups are removed; all nodes belong to the single live stream.
    var historyCount: Int {
        0
    }

    /// Nodes for the sidebar Calls list — the same set shown in the graph for the
    /// current view, so the count never disagrees with what's on the canvas.
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
                    .blur(radius: showingSettings ? 3 : 0)
                    .saturation(showingSettings ? 0.78 : 1)
                    .animation(.smooth(duration: 0.16), value: showingSettings)
                    .environment(\.graphCanvasInputEnabled, !showingSettings)

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
            }
        }
        .ignoresSafeArea()
        .environmentObject(traceStore)
        .preferredColorScheme(preferences.appearance.preferredColorScheme)
        .frame(minWidth: 800, minHeight: 520)
        .onAppear {
            _ = LocalProxyLauncher.shared.startIfAvailable()
            traceStore.startPolling()
        }
        .onDisappear {
            traceStore.stopPolling()
        }
        .onChange(of: traceStore.nodes) { _, _ in
            syncSelectedNode(with: nodes)
        }
        .task(id: selectedNode?.id) {
            guard let selectedNodeId = selectedNode?.id else { return }
            await traceStore.loadNodeDetailIfNeeded(selectedNodeId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceNewSession)) { _ in
            resetTransientSelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceExportTraces)) { _ in
            exportTraces()
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceCopySelection)) { _ in
            copySelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceClearView)) { _ in
            returnToLiveView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceClearAllTraces)) { _ in
            if preferences.confirmBeforeClearing {
                showingClearConfirmation = true
            } else {
                deleteAllHistory()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceShowInspector)) { _ in
            compactSection = .inspector
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceShowGraph)) { _ in
            compactSection = .graph
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceReload)) { _ in
            traceStore.reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceShowOnboarding)) { _ in
            showingConnectionHelp = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceShowSettings)) { _ in
            withAnimation(.smooth(duration: 0.16)) {
                showingSettings = true
            }
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

    /// Keeps the selected node valid as trace snapshots refresh.
    ///
    /// When `autoSelectNewNode` is enabled the selection follows the most recent node
    /// so live traces stay in view; otherwise the current selection is preserved and
    /// only repaired when it disappears from the snapshot.
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
}
