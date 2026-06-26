import { useEffect, useMemo, useRef, useState } from "react";
import type { AgentNode, TraceReplayResult, TraceSnapshot } from "../domain/trace";
import type { AgentNodeWorkSummary, WorkspaceChangeFile } from "../domain/workspace";
import { TauriProxyProcess } from "../infrastructure/TauriProxyProcess";
import { TetherProxyClient } from "../infrastructure/TetherProxyClient";
import { WorkspaceReader, type WorkspaceSnapshot } from "../infrastructure/WorkspaceReader";

type ProxyState = {
  online: boolean;
  loading: boolean;
  error: string | null;
  snapshot: TraceSnapshot;
  selectedNodeId: string | null;
  nodeDetails: Record<string, AgentNode>;
  detailLoading: boolean;
  detailError: string | null;
  replaying: boolean;
  replayResult: TraceReplayResult | null;
  replayError: string | null;
  proxyStarting: boolean;
  proxyStartError: string | null;
  proxyStartedByApp: boolean;
  proxyControlsAvailable: boolean;
  workspacePath: string;
  workspaceError: string | null;
  workspaceSnapshot: WorkspaceSnapshot | null;
  nodeWorkSummaries: Record<string, AgentNodeWorkSummary>;
  pendingAttributionNodeIds: string[];
};

const emptySnapshot: TraceSnapshot = {
  nodes: [],
  stale_node_ids: []
};

export function useTetherProxy() {
  const client = useMemo(() => new TetherProxyClient(), []);
  const proxyProcess = useMemo(() => new TauriProxyProcess(), []);
  const workspaceReader = useMemo(() => new WorkspaceReader(), []);
  const autoStartAttempted = useRef(false);
  const [state, setState] = useState<ProxyState>({
    online: false,
    loading: true,
    error: null,
    snapshot: emptySnapshot,
    selectedNodeId: null,
    nodeDetails: {},
    detailLoading: false,
    detailError: null,
    replaying: false,
    replayResult: null,
    replayError: null,
    proxyStarting: false,
    proxyStartError: null,
    proxyStartedByApp: false,
    proxyControlsAvailable: proxyProcess.isAvailable(),
    workspacePath: localStorage.getItem("tether-linux.workspacePath") ?? "",
    workspaceError: null,
    workspaceSnapshot: null,
    nodeWorkSummaries: {},
    pendingAttributionNodeIds: []
  });

  const selectedSummaryNode = useMemo(
    () => state.snapshot.nodes.find((node) => node.id === state.selectedNodeId) ?? null,
    [state.selectedNodeId, state.snapshot.nodes]
  );

  const selectedNode = useMemo(() => {
    if (!selectedSummaryNode) {
      return null;
    }

    return hydrateNode(selectedSummaryNode, state.nodeDetails[selectedSummaryNode.id]);
  }, [selectedSummaryNode, state.nodeDetails]);

  useEffect(() => {
    let cancelled = false;

    async function refresh() {
      try {
        const online = await client.health();
        const snapshot = online ? await client.currentTraceSummary() : emptySnapshot;
        const workspace = await readWorkspaceSnapshot(state.workspacePath, workspaceReader);

        if (!cancelled) {
          setState((current) => ({
            ...current,
            online,
            loading: false,
            error: null,
            workspaceError: workspace.error,
            snapshot,
            selectedNodeId: retainSelection(current.selectedNodeId, snapshot),
            ...attributionState(current, snapshot, workspace.snapshot)
          }));
        }
      } catch (error) {
        if (!cancelled) {
          setState((current) => ({
            ...current,
            loading: false,
            ...errorState(error)
          }));
        }
      }
    }

    void refresh();
    const interval = window.setInterval(refresh, 1800);

    return () => {
      cancelled = true;
      window.clearInterval(interval);
    };
  }, [client, state.workspacePath, workspaceReader]);

  useEffect(() => {
    if (!proxyProcess.isAvailable() || autoStartAttempted.current) {
      return;
    }
    autoStartAttempted.current = true;
    void startProxy();
  }, [proxyProcess]);

  async function selectNode(node: AgentNode) {
    setState((current) => ({
      ...current,
      selectedNodeId: node.id,
      detailError: null,
      replayResult: null,
      replayError: null
    }));

    if (!needsDetailPayload(node) || state.nodeDetails[node.id]) {
      return;
    }

    setState((current) => ({
      ...current,
      detailLoading: true,
      detailError: null
    }));

    try {
      const detail = await client.traceNodeDetail(node.id);
      setState((current) => ({
        ...current,
        nodeDetails: {
          ...current.nodeDetails,
          [node.id]: detail
        },
        detailLoading: false,
        detailError: null
      }));
    } catch (error) {
      setState((current) => ({
        ...current,
        detailLoading: false,
        detailError: error instanceof Error ? error.message : "Cannot load node detail"
      }));
    }
  }

  async function replaySelectedNode() {
    if (!selectedNode || replayUnsupportedReason(selectedNode)) {
      return;
    }

    setState((current) => ({
      ...current,
      replaying: true,
      replayResult: null,
      replayError: null
    }));

    try {
      const result = await client.replayNode(selectedNode.id);
      setState((current) => ({
        ...current,
        replaying: false,
        replayResult: result,
        replayError: null
      }));
    } catch (error) {
      setState((current) => ({
        ...current,
        replaying: false,
        replayResult: null,
        replayError: error instanceof Error ? error.message : "Replay failed"
      }));
    }
  }

  async function startProxy() {
    setState((current) => ({
      ...current,
      proxyStarting: true,
      proxyStartError: null
    }));

    try {
      const result = await proxyProcess.start();
      const online = await client.health();
      const snapshot = online ? await client.currentTraceSummary() : emptySnapshot;
      setState((current) => ({
        ...current,
        online,
        loading: false,
        error: null,
        snapshot,
        selectedNodeId: retainSelection(current.selectedNodeId, snapshot),
        proxyStarting: false,
        proxyStartError: null,
        proxyStartedByApp: result.started || current.proxyStartedByApp
      }));
    } catch (error) {
      setState((current) => ({
        ...current,
        online: false,
        loading: false,
        proxyStarting: false,
        proxyStartError: error instanceof Error ? error.message : "Cannot start proxy"
      }));
    }
  }

  async function stopProxy() {
    setState((current) => ({
      ...current,
      proxyStarting: true,
      proxyStartError: null
    }));

    try {
      const stopped = await proxyProcess.stop();
      setState((current) => ({
        ...current,
        online: stopped ? false : current.online,
        proxyStarting: false,
        proxyStartError: null,
        proxyStartedByApp: stopped ? false : current.proxyStartedByApp
      }));
    } catch (error) {
      setState((current) => ({
        ...current,
        proxyStarting: false,
        proxyStartError: error instanceof Error ? error.message : "Cannot stop proxy"
      }));
    }
  }

  function setWorkspacePath(path: string) {
    localStorage.setItem("tether-linux.workspacePath", path);
    setState((current) => ({
      ...current,
      workspacePath: path,
      workspaceError: null,
      workspaceSnapshot: null,
      nodeWorkSummaries: {},
      pendingAttributionNodeIds: []
    }));
  }

  return {
    ...state,
    selectedNode,
    selectNode,
    startProxy,
    stopProxy,
    setWorkspacePath,
    replaySelectedNode,
    replayUnsupportedReason: selectedNode ? replayUnsupportedReason(selectedNode) : null,
    client
  };
}

function attributionState(
  current: ProxyState,
  snapshot: TraceSnapshot,
  workspaceSnapshot: WorkspaceSnapshot | null
) {
  const incomingIds = new Set(snapshot.nodes.map((node) => node.id));
  const previousIds = new Set(current.snapshot.nodes.map((node) => node.id));
  const newNodeIds = snapshot.nodes.filter((node) => !previousIds.has(node.id)).map((node) => node.id);
  const summaries = { ...current.nodeWorkSummaries };
  const pending = current.pendingAttributionNodeIds.filter((nodeId) => incomingIds.has(nodeId));

  for (const node of snapshot.nodes) {
    summaries[node.id] ??= {
      promptText: workPromptText(node),
      changedFiles: []
    };
  }

  pending.push(...newNodeIds);

  if (workspaceSnapshot && current.workspaceSnapshot && pending.length > 0) {
    const changedFiles = changedSummary(current.workspaceSnapshot, workspaceSnapshot);
    if (changedFiles.length > 0) {
      const targetNodeId = pending[pending.length - 1];
      for (const nodeId of pending) {
        const summary = summaries[nodeId];
        if (!summary) {
          continue;
        }
        summaries[nodeId] = {
          promptText: summary.promptText,
          changedFiles: nodeId === targetNodeId ? changedFiles : summary.changedFiles
        };
      }
      pending.length = 0;
    }
  }

  return {
    workspaceSnapshot,
    nodeWorkSummaries: summaries,
    pendingAttributionNodeIds: pending
  };
}

async function readWorkspaceSnapshot(path: string, workspaceReader: WorkspaceReader) {
  const trimmedPath = path.trim();
  if (!trimmedPath) {
    return {
      snapshot: null,
      error: null
    };
  }
  if (!isAbsolutePath(trimmedPath)) {
    return {
      snapshot: null,
      error: "Use an absolute workspace path, for example /home/you/project."
    };
  }
  try {
    return {
      snapshot: await workspaceReader.snapshot(trimmedPath),
      error: null
    };
  } catch (error) {
    return {
      snapshot: null,
      error: error instanceof Error ? error.message : "Workspace snapshot failed"
    };
  }
}

function isAbsolutePath(path: string) {
  return path.startsWith("/") || /^[A-Za-z]:[\\/]/.test(path);
}

function changedSummary(previous: WorkspaceSnapshot, current: WorkspaceSnapshot) {
  const previousFiles = new Map(previous.files.map((file) => [file.path, file]));
  const currentFiles = new Map(current.files.map((file) => [file.path, file]));
  const paths = new Set([...previousFiles.keys(), ...currentFiles.keys()]);
  const changed: WorkspaceChangeFile[] = [];

  for (const path of [...paths].sort()) {
    const before = previousFiles.get(path);
    const after = currentFiles.get(path);
    if (before?.fingerprint === after?.fingerprint && before?.additions === after?.additions && before?.deletions === after?.deletions) {
      continue;
    }
    if (!after) {
      changed.push({
        path,
        status: "Deleted",
        additions: 0,
        deletions: before?.deletions ?? before?.additions ?? 0
      });
      continue;
    }
    changed.push({
      path,
      status: after.status,
      additions: Math.max(0, after.additions - (before?.additions ?? 0)),
      deletions: Math.max(0, after.deletions - (before?.deletions ?? 0))
    });
  }

  return changed;
}

function workPromptText(node: AgentNode) {
  const commandLine = node.context_inputs.execution?.command_line;
  if (commandLine) {
    return commandLine;
  }
  const prompt = node.prompt.user.trim();
  if (prompt) {
    return prompt;
  }
  return node.step_name;
}

function errorState(error: unknown) {
  const message = error instanceof Error ? error.message : "Proxy request failed";
  if (message.includes("workspace") || message.includes("git") || message.includes("not a directory")) {
    return {
      workspaceError: message
    };
  }
  return {
    online: false,
    error: message,
    snapshot: emptySnapshot,
    selectedNodeId: null
  };
}

function retainSelection(selectedNodeId: string | null, snapshot: TraceSnapshot) {
  if (!selectedNodeId) {
    return null;
  }

  return snapshot.nodes.some((node) => node.id === selectedNodeId) ? selectedNodeId : null;
}

function needsDetailPayload(node: AgentNode) {
  return node.cache_status !== "codex-log"
    && node.prompt.system.length === 0
    && node.prompt.user.length === 0
    && node.response.text.length === 0;
}

function hydrateNode(summary: AgentNode, detail?: AgentNode) {
  if (!detail) {
    return summary;
  }

  return {
    ...summary,
    trace_id: detail.trace_id || summary.trace_id,
    parent_span_id: detail.parent_span_id ?? summary.parent_span_id,
    tool_use_ids: hasEmptyArray(detail.tool_use_ids) ? summary.tool_use_ids : detail.tool_use_ids,
    context_inputs: hasContextPayload(detail) ? detail.context_inputs : summary.context_inputs,
    input_hash: detail.input_hash || summary.input_hash,
    output_hash: detail.output_hash || summary.output_hash,
    stale: summary.stale || detail.stale,
    prompt: detail.prompt,
    response: detail.response,
    error: detail.error
  };
}

function hasContextPayload(node: AgentNode) {
  return node.context_inputs.sources.length > 0
    || node.context_inputs.withheld.length > 0
    || node.context_inputs.execution !== null && node.context_inputs.execution !== undefined;
}

function hasEmptyArray(value: unknown) {
  return Array.isArray(value) && value.length === 0;
}

function replayUnsupportedReason(node: AgentNode) {
  if (node.cache_status === "codex-log") {
    return "Replay needs a proxy-captured request. This node came from a local source log.";
  }

  if (node.context_inputs.execution) {
    return "Replay is for retained provider requests. This node is a captured shell command.";
  }

  return null;
}
