"use client";

import { Icon } from "./Icon";
import { SESSION, type TraceNode } from "@/lib/data";

/**
 * Renders the interactive landing-page trace graph demo.
 */
export function GraphCanvas({
  nodes,
  selId,
  onSelect,
  totalMs,
}: {
  nodes: TraceNode[];
  selId: string;
  onSelect: (id: string) => void;
  totalMs: number;
}) {
  const sel = nodes.find((n) => n.id === selId) || nodes[0];
  const fmt = (ms: number) =>
    ms >= 1000 ? (ms / 1000).toFixed(2) + "s" : ms + "ms";
  const hasError = nodes.some((n) => n.status === "error");
  return (
    <div className="pane center">
      <div className="graph-head">
        <div className="gh-main">
          <div className="crumb">
            <b>{SESSION.title}</b> &nbsp;›&nbsp; {sel.step}
          </div>
          <h2>{sel.step}</h2>
        </div>
        <div className="gh-stats">
          <div className="stat">
            <div className="l">Total Time</div>
            <div className="v">{fmt(totalMs)}</div>
          </div>
          <div className="stat">
            <div className="l">Steps</div>
            <div className="v">{nodes.length}</div>
          </div>
          <div className="stat">
            <div className="l">Status</div>
            <div className={"v " + (hasError ? "pink" : "green")}>
              {hasError ? "FAILED" : "OK"}
            </div>
          </div>
        </div>
      </div>

      <div className="canvas">
        <div className="tree">
          {nodes.map((n, i) => (
            <TreeNode
              key={n.id}
              node={n}
              first={i === 0}
              last={i === nodes.length - 1}
              selected={n.id === selId}
              onSelect={onSelect}
            />
          ))}
        </div>
      </div>
    </div>
  );
}

// Renders one node in the demo tree with indentation derived from trace depth.
function TreeNode({
  node,
  first,
  selected,
  onSelect,
}: {
  node: TraceNode;
  first: boolean;
  last: boolean;
  selected: boolean;
  onSelect: (id: string) => void;
}) {
  const indent = node.depth * 26;
  return (
    <div className="tnode-row" style={{ marginLeft: indent }}>
      {!first && (
        <div className="rail">
          <div className="vline" />
          <div className="elbow" />
          <div className="knob" />
        </div>
      )}
      <div
        className={"node " + node.status + (selected ? " sel" : "")}
        onClick={() => onSelect(node.id)}
      >
        <div className="nhead">
          <div className="nicon">
            <Icon name={node.icon} size={15} />
          </div>
          <div className="ntitle">
            <div className="nm">{node.step}</div>
            <div className="nsub">
              {node.model} · {node.requestId}
            </div>
          </div>
          <span className="nstat">{node.status}</span>
        </div>
        <div className="nbar">
          <i style={{ width: node.barPct + "%" }} />
        </div>
        <div className="nfoot">
          <span className="nf">
            <Icon name="clock" size={11} /> <b>{node.latency}</b>
          </span>
          <span className="nf">
            <Icon name="dollar" size={11} /> <b>{node.cost}</b>
          </span>
          <span className="nf grow">
            <Icon name="tokens" size={11} />{" "}
            <b>
              {node.tokensIn}↓ {node.tokensOut}↑
            </b>
          </span>
        </div>
      </div>
    </div>
  );
}
