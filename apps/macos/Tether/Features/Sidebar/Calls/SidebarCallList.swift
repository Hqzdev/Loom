import Core
import SwiftUI
import UI

struct SidebarCallList: View {
    let filteredNodes: [AgentNode]
    let selectedNodeId: AgentNode.ID?
    let onSelect: (AgentNode) -> Void
    let palette: AgentTracePalette

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                if filteredNodes.isEmpty {
                    SidebarEmptyState(palette: palette)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 32)
                } else {
                    ForEach(filteredNodes) { node in
                        CallRow(
                            node: CallRowModel(node: node),
                            selected: node.id == selectedNodeId,
                            onSelect: { onSelect(node) },
                            palette: palette
                        )
                        .equatable()
                    }
                }
            }
            .padding(.horizontal, 7)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.automatic)
    }
}
