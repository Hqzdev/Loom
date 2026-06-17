import Core
import SwiftUI

extension MainThreePaneLayoutView {
    /// Builds the adaptive workspace body for the current window size.
    @ViewBuilder
    func workspace(layout: AdaptiveWorkspaceLayout, size _: CGSize) -> some View {
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
                compactPane()
            }
        }
    }

    /// Chooses the currently selected compact pane.
    @ViewBuilder
    func compactPane() -> some View {
        switch compactSection {
        case .calls:
            sidebarPane()
        case .graph:
            graphPane()
        case .inspector:
            inspectorPane()
        }
    }

    /// Builds the left sidebar pane.
    func sidebarPane() -> some View {
        Sidebar(
            nodes: callListNodes,
            filteredNodes: filteredNodes,
            selectedNodeId: selectedNode?.id,
            searchText: $searchText,
            proxyStatus: traceStore.proxyStatus,
            onSelect: { selectedNodeId = $0.id },
            onShowSettings: {
                withAnimation(.smooth(duration: 0.16)) {
                    showingSettings = true
                }
            },
            palette: palette
        )
    }

    /// Builds the center graph pane.
    func graphPane() -> some View {
        GraphPane(
            nodes: nodes,
            historyCount: historyCount,
            selectedNode: selectedNode,
            totalLatencyMs: totalLatencyMs,
            onSelect: { selectedNodeId = $0.id },
            onInteractionChanged: traceStore.setGraphInteractionActive,
            palette: palette
        )
    }

    /// Builds the right inspector pane.
    func inspectorPane() -> some View {
        InspectorPane(
            node: selectedNode,
            tab: $inspectorTab,
            responseEdits: $responseEdits,
            replayImpacts: $replayImpacts,
            onSaveMockResponse: SaveMockResponseAction(saveMockResponse),
            onRunMultiple: RunMultipleAction(runMultiple),
            palette: palette
        )
    }
}
