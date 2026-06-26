import { useEffect, useMemo, useRef, useState } from "react";
import type { PointerEvent as ReactPointerEvent } from "react";
import type { AgentNode } from "../../domain/trace";

type GraphPaneProps = {
  nodes: AgentNode[];
  selectedNodeId: string | null;
  selectedNode: AgentNode | null;
  onSelectNode: (node: AgentNode) => void;
};

type Point = {
  x: number;
  y: number;
};

type DragState =
  | {
      type: "canvas";
      start: Point;
      origin: Point;
    }
  | {
      type: "node";
      nodeId: string;
      start: Point;
      origin: Point;
    };

const nodeWidth = 250;
const nodeHeight = 108;

export function GraphPane({ nodes, selectedNodeId, selectedNode, onSelectNode }: GraphPaneProps) {
  const [positions, setPositions] = useState<Record<string, Point>>({});
  const surfaceRef = useRef<HTMLDivElement | null>(null);
  const dragState = useRef<DragState | null>(null);
  const initialScrollDone = useRef(false);
  const status = nodes.some((node) => node.status === "error")
    ? "Failed"
    : nodes.some((node) => node.status === "running")
      ? "Live"
      : nodes.length > 0
        ? "Ok"
        : "Idle";
  const totalLatencyMs = nodes.reduce((total, node) => total + node.latency_ms, 0);
  const agentCount = new Set(nodes.map((node) => node.agent_name)).size;
  const graphPositions = useMemo(() => mergePositions(nodes, positions), [nodes, positions]);
  const edges = useMemo(() => graphEdges(nodes), [nodes]);
  const title = selectedNode?.step_name ?? nodes.at(-1)?.step_name ?? "Trace timeline";

  useEffect(() => {
    setPositions((current) => {
      const next = { ...current };
      for (const node of nodes) {
        next[node.id] ??= defaultPosition(nodes, node);
      }
      for (const nodeId of Object.keys(next)) {
        if (!nodes.some((node) => node.id === nodeId)) {
          delete next[nodeId];
        }
      }
      return next;
    });
  }, [nodes]);

  useEffect(() => {
    const surface = surfaceRef.current;
    if (!surface || initialScrollDone.current || nodes.length === 0) {
      return;
    }
    initialScrollDone.current = true;
    surface.scrollLeft = 240;
    surface.scrollTop = 160;
  }, [nodes.length]);

  function startCanvasDrag(event: ReactPointerEvent<HTMLDivElement>) {
    if ((event.target as HTMLElement).closest(".graphNodeCard")) {
      return;
    }
    event.preventDefault();
    event.currentTarget.setPointerCapture(event.pointerId);
    dragState.current = {
      type: "canvas",
      start: pointer(event),
      origin: {
        x: event.currentTarget.scrollLeft,
        y: event.currentTarget.scrollTop
      }
    };
  }

  function startNodeDrag(event: ReactPointerEvent<HTMLButtonElement>, node: AgentNode) {
    event.stopPropagation();
    event.currentTarget.setPointerCapture(event.pointerId);
    onSelectNode(node);
    dragState.current = {
      type: "node",
      nodeId: node.id,
      start: pointer(event),
      origin: graphPositions[node.id] ?? defaultPosition(nodes, node)
    };
  }

  function moveDrag(event: ReactPointerEvent<HTMLElement>) {
    const current = dragState.current;
    if (!current) {
      return;
    }
    const delta = subtract(pointer(event), current.start);
    if (current.type === "canvas") {
      const surface = surfaceRef.current;
      if (surface) {
        surface.scrollLeft = current.origin.x - delta.x;
        surface.scrollTop = current.origin.y - delta.y;
      }
      return;
    }
    setPositions((previous) => ({
      ...previous,
      [current.nodeId]: {
        x: current.origin.x + delta.x,
        y: current.origin.y + delta.y
      }
    }));
  }

  function stopDrag(event: ReactPointerEvent<HTMLElement>) {
    if (dragState.current) {
      event.currentTarget.releasePointerCapture(event.pointerId);
    }
    dragState.current = null;
  }

  return (
    <section className="graphPane">
      <header className="traceHeader">
        <div className="traceTitleGroup">
          <span className="subtleLabel">Live trace</span>
          <h1>{title}</h1>
        </div>
        <div className="traceMetrics">
          <MetricPill label="Total time" value={formatSeconds(totalLatencyMs)} />
          <MetricPill label="Steps" value={String(nodes.length)} />
          <MetricPill label="Agents" value={String(agentCount)} />
          <MetricPill label="Status" value={status} tone={status === "Failed" ? "danger" : undefined} />
        </div>
      </header>

      <div
        className="graphSurface"
        ref={surfaceRef}
        onPointerDown={startCanvasDrag}
        onPointerMove={moveDrag}
        onPointerUp={stopDrag}
        onPointerCancel={stopDrag}
      >
        {nodes.length === 0 ? (
          <div className="emptyState">
            <strong>No trace nodes yet</strong>
            <span>Start the local proxy and run an agent to populate the graph.</span>
          </div>
        ) : (
          <div className="graphWorld">
            <svg className="graphEdges" width="2200" height="1400" viewBox="0 0 2200 1400" aria-hidden="true">
              {edges.map((edge) => {
                const from = graphPositions[edge.from];
                const to = graphPositions[edge.to];
                if (!from || !to) {
                  return null;
                }
                return <GraphEdge key={`${edge.from}:${edge.to}`} from={from} to={to} />;
              })}
            </svg>
            {nodes.map((node) => {
              const position = graphPositions[node.id] ?? defaultPosition(nodes, node);
              return (
                <button
                  className={`graphNodeCard ${selectedNodeId === node.id ? "selected" : ""}`}
                  key={node.id}
                  style={{ left: position.x, top: position.y }}
                  type="button"
                  onPointerDown={(event) => startNodeDrag(event, node)}
                  onPointerMove={moveDrag}
                  onPointerUp={stopDrag}
                  onPointerCancel={stopDrag}
                  onClick={() => onSelectNode(node)}
                >
                  <span className={`nodeDot statusDot${node.status}`} />
                  <span className="graphNodeBody">
                    <strong>{node.step_name}</strong>
                    <span>{node.prompt.user || node.context_inputs?.execution?.command_line || "Captured agent call"}</span>
                    <span className="sourcePill compact">{node.agent_name}</span>
                  </span>
                  <span className="graphNodeMeter" style={{ width: `${Math.max(18, node.bar_percent)}%` }} />
                  <span className="graphNodeStats">
                    <span>
                      <small>Latency</small>
                      <strong>{node.latency}</strong>
                    </span>
                    <span>
                      <small>Tokens</small>
                      <strong>{node.tokens_in}/{node.tokens_out}</strong>
                    </span>
                  </span>
                </button>
              );
            })}
          </div>
        )}
      </div>
    </section>
  );
}

type MetricPillProps = {
  label: string;
  value: string;
  tone?: "danger";
};

type GraphEdgeProps = {
  from: Point;
  to: Point;
};

function GraphEdge({ from, to }: GraphEdgeProps) {
  const start = {
    x: from.x + nodeWidth,
    y: from.y + nodeHeight / 2
  };
  const end = {
    x: to.x,
    y: to.y + nodeHeight / 2
  };
  const middle = Math.max(40, (end.x - start.x) / 2);
  const path = `M ${start.x} ${start.y} C ${start.x + middle} ${start.y}, ${end.x - middle} ${end.y}, ${end.x} ${end.y}`;

  return (
    <g>
      <path className="graphEdgeShadow" d={path} />
      <path className="graphEdge" d={path} />
      <circle className="graphEdgePort" cx={start.x} cy={start.y} r="4" />
      <circle className="graphEdgePort" cx={end.x} cy={end.y} r="4" />
    </g>
  );
}

function MetricPill({ label, value, tone }: MetricPillProps) {
  return (
    <span className={`metricPill ${tone === "danger" ? "danger" : ""}`}>
      <span>{label}</span>
      <strong>{value}</strong>
    </span>
  );
}

function mergePositions(nodes: AgentNode[], positions: Record<string, Point>) {
  const next: Record<string, Point> = {};
  for (const node of nodes) {
    next[node.id] = positions[node.id] ?? defaultPosition(nodes, node);
  }
  return next;
}

function defaultPosition(nodes: AgentNode[], node: AgentNode) {
  const index = Math.max(0, nodes.findIndex((candidate) => candidate.id === node.id));
  const column = index % 3;
  const row = Math.floor(index / 3);
  return {
    x: 360 + column * 330,
    y: 260 + row * 190 + column * 18
  };
}

function graphEdges(nodes: AgentNode[]) {
  return nodes.slice(1).map((node, index) => {
    const explicitParent = node.parent_span_id ? nodes.find((candidate) => candidate.id === node.parent_span_id) : null;
    const parent = explicitParent ?? nodes[index];
    return {
      from: parent.id,
      to: node.id
    };
  });
}

function formatSeconds(milliseconds: number) {
  if (milliseconds <= 0) {
    return "0s";
  }
  return `${(milliseconds / 1000).toFixed(2)}s`;
}

function pointer(event: ReactPointerEvent<HTMLElement>) {
  return {
    x: event.clientX,
    y: event.clientY
  };
}

function subtract(point: Point, origin: Point) {
  return {
    x: point.x - origin.x,
    y: point.y - origin.y
  };
}
