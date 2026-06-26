import Core

struct GraphConnectionNode: Equatable {
    let id: AgentNode.ID
    let graphGroupId: String
    let status: NodeStatus
    let isReplay: Bool
    let replaySourceId: AgentNode.ID?
}

enum GraphConnectionScope: Equatable {
    case all
    case excluding(nodeId: AgentNode.ID)
    case only(nodeId: AgentNode.ID)

    func includes(previousId: AgentNode.ID, currentId: AgentNode.ID) -> Bool {
        switch self {
        case .all:
            return true
        case let .excluding(nodeId):
            return previousId != nodeId && currentId != nodeId
        case let .only(nodeId):
            return previousId == nodeId || currentId == nodeId
        }
    }
}
