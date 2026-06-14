import AppKit
import ComposableArchitecture
import Core
import Networking
import SwiftUI
import UI
import UniformTypeIdentifiers

struct MainThreePaneLayoutView: View {
    @StateObject private var traceStore = TraceStore()
    @State private var selectedNodeId: AgentNode.ID?
    @State private var inspectorTab: InspectorTab = .prompt
    @State private var searchText = ""
    @State private var responseEdits: [AgentNode.ID: String] = [:]
    @State private var compactSection: CompactSection = .graph
    @State private var showingClearConfirmation = false
    @State private var showingConnectionHelp = false
    @State private var showingSettings = false

    private var palette: AgentTracePalette {
        AgentTracePalette(light: true)
    }

    private var session: TraceSession? {
        traceStore.session
    }

    private var nodes: [AgentNode] {
        traceStore.nodes
    }

    private var filteredNodes: [AgentNode] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nodes }

        return nodes.filter { node in
            node.stepName.localizedCaseInsensitiveContains(query)
                || node.agentName.localizedCaseInsensitiveContains(query)
                || node.model.localizedCaseInsensitiveContains(query)
                || node.requestId.localizedCaseInsensitiveContains(query)
        }
    }

    private var selectedNode: AgentNode? {
        if let selectedNodeId, let node = nodes.first(where: { $0.id == selectedNodeId }) {
            return node
        }

        return nodes.first
    }

    private var totalLatencyMs: Int {
        nodes.reduce(0) { $0 + $1.latencyMs }
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = AdaptiveWorkspaceLayout(size: geometry.size)

            ZStack {
                StageBackground(palette: palette)

                VStack(spacing: 0) {
                    TitleBar(
                        session: session,
                        palette: palette
                    )

                    workspace(layout: layout, size: geometry.size)
                        .clipShape(RoundedRectangle(cornerRadius: layout.mode == .compact ? 20 : palette.paperRadius, style: .continuous))
                        .background(
                            RoundedRectangle(cornerRadius: layout.mode == .compact ? 20 : palette.paperRadius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [palette.paperTop, palette.paperBottom],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: layout.mode == .compact ? 20 : palette.paperRadius, style: .continuous)
                                .stroke(palette.border.opacity(0.92), lineWidth: 1)
                        )
                        .shadow(color: Color(hex: 0x0f172a).opacity(0.07), radius: 28, x: 0, y: 18)
                        .padding(.horizontal, layout.mode == .compact ? 8 : 14)
                        .padding(.bottom, layout.mode == .compact ? 8 : 14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blur(radius: showingSettings ? 3 : 0)
                .saturation(showingSettings ? 0.78 : 1)
                .animation(.smooth(duration: 0.16), value: showingSettings)

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
        .preferredColorScheme(.light)
        .frame(minWidth: 800, minHeight: 520)
        .onAppear {
            _ = LocalProxyLauncher.shared.startIfAvailable()
            traceStore.startPolling()
        }
        .onDisappear {
            traceStore.stopPolling()
        }
        .onChange(of: traceStore.nodes) { _, newNodes in
            guard !newNodes.isEmpty else {
                selectedNodeId = nil
                return
            }

            if selectedNodeId == nil || !newNodes.contains(where: { $0.id == selectedNodeId }) {
                selectedNodeId = newNodes[0].id
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceNewSession)) { _ in
            startNewSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceExportTraces)) { _ in
            exportTraces()
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceCopySelection)) { _ in
            copySelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceClearAllTraces)) { _ in
            showingClearConfirmation = true
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
        .alert("Clear All Traces?", isPresented: $showingClearConfirmation) {
            Button("Clear All Traces", role: .destructive) {
                clearAllTraces()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently clears all proxy sessions and hides existing Terminal Codex events until new activity arrives.")
        }
        .sheet(isPresented: $showingConnectionHelp) {
            ConnectionHelpSheet()
        }
    }

    @ViewBuilder
    private func workspace(layout: AdaptiveWorkspaceLayout, size: CGSize) -> some View {
        switch layout.mode {
        case .wide:
            HSplitView {
                sidebarPane()
                    .frame(minWidth: 220, idealWidth: layout.sidebarWidth, maxWidth: 380)

                graphPane()
                    .frame(minWidth: 360, maxWidth: .infinity)

                inspectorPane()
                    .frame(minWidth: 280, idealWidth: layout.inspectorWidth, maxWidth: 520)
            }

        case .medium:
            HSplitView {
                sidebarPane()
                    .frame(minWidth: 220, idealWidth: layout.sidebarWidth, maxWidth: 340)

                VSplitView {
                    graphPane()
                        .frame(minHeight: 280)

                    inspectorPane()
                        .frame(minHeight: 180, idealHeight: layout.inspectorHeight, maxHeight: 360)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

        case .compact:
            VStack(spacing: 0) {
                CompactSectionPicker(selection: $compactSection, palette: palette)

                HorizontalDividerLine(palette: palette)

                switch compactSection {
                case .calls:
                    sidebarPane()
                case .graph:
                    graphPane()
                case .inspector:
                    inspectorPane()
                }
            }
        }
    }

    private func sidebarPane() -> some View {
        Sidebar(
            nodes: nodes,
            filteredNodes: filteredNodes,
            selectedNodeId: selectedNode?.id,
            searchText: $searchText,
            proxyStatus: traceStore.proxyStatus,
            sessions: traceStore.sessions,
            selectedSessionId: traceStore.selectedSessionId,
            liveSessionId: traceStore.currentSessionId,
            onSelectSession: selectSession,
            onSelect: { selectedNodeId = $0.id },
            onShowSettings: {
                withAnimation(.smooth(duration: 0.16)) {
                    showingSettings = true
                }
            },
            palette: palette
        )
    }

    private func graphPane() -> some View {
        GraphPane(
            session: session,
            nodes: nodes,
            selectedNode: selectedNode,
            totalLatencyMs: totalLatencyMs,
            onSelect: { selectedNodeId = $0.id },
            palette: palette
        )
    }

    private func inspectorPane() -> some View {
        InspectorPane(
            node: selectedNode,
            tab: $inspectorTab,
            responseEdits: $responseEdits,
            palette: palette
        )
    }

    private func startNewSession() {
        responseEdits.removeAll()
        selectedNodeId = nil
        traceStore.startNewSession()
    }

    private func clearAllTraces() {
        responseEdits.removeAll()
        selectedNodeId = nil
        traceStore.clearTrace()
    }

    private func selectSession(_ sessionId: TraceSession.ID) {
        responseEdits.removeAll()
        selectedNodeId = nil
        traceStore.selectSession(sessionId)
    }

    private func copySelection() {
        guard let text = clipboardTextForSelectedNode(), !text.isEmpty else {
            NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func clipboardTextForSelectedNode() -> String? {
        guard let node = selectedNode else { return nil }

        switch inspectorTab {
        case .prompt:
            return """
            system:
            \(node.prompt.system)

            user:
            \(node.prompt.user)
            """
        case .response:
            return responseEdits[node.id] ?? node.response.text
        case .metadata:
            return """
            id: \(node.id)
            agent: \(node.agentName)
            model: \(node.model)
            requestId: \(node.requestId)
            status: \(node.status.label)
            latency: \(node.latency)
            tokensIn: \(node.tokensIn)
            tokensOut: \(node.tokensOut)
            cacheStatus: \(node.cacheStatus)
            """
        }
    }

    private func exportTraces() {
        let snapshot = TraceSnapshot(session: session, nodes: nodes)
        let panel = NSSavePanel()
        panel.title = "Export Traces"
        panel.nameFieldStringValue = "Tether-\(exportTimestamp()).json"
        panel.allowedContentTypes = [.json, .commaSeparatedText]
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            do {
                let data = url.pathExtension.lowercased() == "csv"
                    ? csvData(for: snapshot)
                    : try jsonData(for: snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    private func jsonData(for snapshot: TraceSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }

    private func csvData(for snapshot: TraceSnapshot) -> Data {
        var rows = [
            [
                "session_id",
                "session_title",
                "node_id",
                "agent",
                "step",
                "timestamp",
                "model",
                "status",
                "latency_ms",
                "tokens_in",
                "tokens_out",
                "request_id",
                "prompt",
                "response"
            ]
        ]

        for node in snapshot.nodes {
            rows.append([
                snapshot.session?.id ?? "",
                snapshot.session?.title ?? "",
                node.id,
                node.agentName,
                node.stepName,
                node.timestamp,
                node.model,
                node.status.rawValue,
                "\(node.latencyMs)",
                "\(node.tokensIn)",
                "\(node.tokensOut)",
                node.requestId,
                node.prompt.user,
                node.response.text
            ])
        }

        let csv = rows
            .map { row in row.map(escapeCSV).joined(separator: ",") }
            .joined(separator: "\n")

        return Data(csv.utf8)
    }

    private func escapeCSV(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func exportTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

private enum WorkspaceMode {
    case wide
    case medium
    case compact
}

private struct AdaptiveWorkspaceLayout {
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

private enum CompactSection: String, CaseIterable, Identifiable {
    case calls = "Calls"
    case graph = "Graph"
    case inspector = "Inspector"

    var id: String { rawValue }
}

private struct CompactSectionPicker: View {
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

private struct WorkspaceSettingsOverlay: View {
    let palette: AgentTracePalette
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.30)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            AppSettingsView(onClose: onDismiss)
                .padding(30)
        }
    }
}

private struct ConnectionHelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let palette = AgentTracePalette(light: true)

    var body: some View {
        ZStack {
            StageBackground(palette: palette)

            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 16) {
                    Image(systemName: "terminal")
                        .font(.title)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(palette.accent)
                        .frame(width: 48, height: 48)
                        .background(palette.accentBackground)
                        .clipShape(RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous)
                                .stroke(palette.accent.opacity(0.18), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("How to Connect an Agent")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(palette.text)

                        Text("Tether watches local Codex sessions and proxy traffic on this Mac.")
                            .font(.callout)
                            .foregroundStyle(palette.textTertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HelpRow(systemImage: "1.circle", title: "Open Terminal", detail: "Run codex from any terminal session.", palette: palette)
                    HelpRow(systemImage: "2.circle", title: "Keep Tether Open", detail: "The workspace updates as new agent calls arrive.", palette: palette)
                    HelpRow(systemImage: "3.circle", title: "Use Proxy Settings", detail: "Configure port, upstream URLs, and cache from Settings.", palette: palette)
                }

                HStack {
                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .frame(width: 112, height: 38)
                    }
                    .buttonStyle(HelpPrimaryButtonStyle(palette: palette))
                }
            }
            .padding(24)
            .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: palette.paperRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: palette.paperRadius, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
            .padding(12)
        }
        .frame(width: 480)
        .preferredColorScheme(.light)
    }
}

private struct HelpRow: View {
    let systemImage: String
    let title: String
    let detail: String
    let palette: AgentTracePalette

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(palette.accent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(palette.text)

                Text(detail)
                    .font(.callout)
                    .foregroundStyle(palette.textTertiary)
            }
        }
    }
}

private struct HelpPrimaryButtonStyle: ButtonStyle {
    let palette: AgentTracePalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .background(palette.text)
            .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.86 : 1)
    }
}

struct MainThreePaneLayoutView_Previews: PreviewProvider {
    static var previews: some View {
        MainThreePaneLayoutView()
    }
}
