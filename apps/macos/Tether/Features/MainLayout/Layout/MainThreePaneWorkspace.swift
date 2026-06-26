import Core
import SwiftUI

extension MainThreePaneLayoutView {
    @ViewBuilder
    func workspace(layout: AdaptiveWorkspaceLayout, size _: CGSize) -> some View {
        switch layout.mode {
        case .wide:
            HSplitView {
                sidebarPane()
                    .frame(minWidth: 220, idealWidth: layout.sidebarWidth, maxWidth: 380)
                graphPane()
                    .frame(minWidth: 360, maxWidth: .infinity)
                if inspectorVisible {
                    inspectorPane()
                        .frame(minWidth: 280, idealWidth: layout.inspectorWidth, maxWidth: 520)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        case .medium:
            HSplitView {
                sidebarPane()
                    .frame(minWidth: 220, idealWidth: layout.sidebarWidth, maxWidth: 340)
                if inspectorVisible {
                    VSplitView {
                        graphPane()
                            .frame(minHeight: 280)
                        inspectorPane()
                            .frame(minHeight: 180, idealHeight: layout.inspectorHeight, maxHeight: 360)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    graphPane()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        case .compact:
            VStack(spacing: 0) {
                CompactSectionPicker(selection: $compactSection, palette: palette)
                HorizontalDividerLine(palette: palette)
                compactPane()
            }
        }
    }

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

    func sidebarPane() -> some View {
        Sidebar(
            nodes: callListNodes,
            filteredNodes: filteredNodes,
            selectedNodeId: selectedNode?.id,
            searchText: $searchText,
            searchFocused: $searchFocused,
            proxyStatus: traceStore.proxyStatus,
            onSelect: {
                selectedNodeId = $0.id
                graphFocusRequest += 1
            },
            onShowSettings: {
                withAnimation(.smooth(duration: 0.16)) {
                    showingSettings = true
                }
            },
            palette: palette
        )
    }

    func graphPane() -> some View {
        GraphPane(
            nodes: nodes,
            historyCount: historyCount,
            selectedNode: selectedNode,
            totalLatencyMs: totalLatencyMs,
            focusRequest: graphFocusRequest,
            onSelect: {
                selectedNodeId = $0.id
                graphFocusRequest += 1
            },
            onCopyFailureAnalysisPrompt: copyFailureAnalysisPrompt,
            onInteractionChanged: traceStore.setGraphInteractionActive,
            palette: palette
        )
    }

    func inspectorPane() -> some View {
        InspectorPane(
            node: selectedNode,
            tab: $inspectorTab,
            responseEdits: $responseEdits,
            replayImpacts: $replayImpacts,
            onSaveMockResponse: SaveMockResponseAction(saveMockResponse),
            onRunMultiple: RunMultipleAction(runMultiple),
            onReplayWithModel: ReplayWithModelAction(replayWithModel),
            palette: palette
        )
    }
}
