import Core
import SwiftUI
import UI

/// Left pane listing proxy status, filters, and captured calls.
struct Sidebar: View {
    let nodes: [AgentNode]
    let filteredNodes: [AgentNode]
    let selectedNodeId: AgentNode.ID?
    @Binding var searchText: String
    let proxyStatus: ProxyConnectionStatus
    let onSelect: (AgentNode) -> Void
    let onShowSettings: () -> Void
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 0) {
            SidebarStatusHeader(proxyStatus: proxyStatus, palette: palette)

            SidebarSearchField(searchText: $searchText, palette: palette)
            SidebarSectionHeader(title: "Calls", detail: "\(filteredNodes.count) of \(nodes.count)", palette: palette)
            SidebarCallList(filteredNodes: filteredNodes, selectedNodeId: selectedNodeId, onSelect: onSelect, palette: palette)
            SidebarFooter(onShowSettings: onShowSettings, palette: palette)
        }
        .background(palette.panel.opacity(0.56))
    }
}
