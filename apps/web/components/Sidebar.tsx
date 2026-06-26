"use client";

import { Icon } from "./Icon";
import type { TraceNode } from "@/lib/data";

/**
 * Renders the landing-page trace sidebar with local filtering and selection state.
 */
export function Sidebar({
  nodes,
  selId,
  onSelect,
  query,
  setQuery,
}: {
  nodes: TraceNode[];
  selId: string;
  onSelect: (id: string) => void;
  query: string;
  setQuery: (q: string) => void;
}) {
  const filtered = nodes.filter(
    (n) =>
      n.step.toLowerCase().includes(query.toLowerCase()) ||
      n.model.toLowerCase().includes(query.toLowerCase())
  );
  return (
    <div className="pane left">
      <div className="sb-top">
        <div className="search">
          <Icon name="search" size={13} />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Filter calls…"
          />
          <span className="kbd">⌘F</span>
        </div>
        <div className="proxy">
          <span className="dot" />
          <span className="ptext">
            Local Proxy: <b>Running</b> on port <span className="mono">8080</span>
          </span>
        </div>
      </div>

      <div className="sb-sectionhead">
        <span>Recent Calls</span>
        <span className="count">
          {filtered.length}/{nodes.length}
        </span>
      </div>

      <div className="calllist">
        {filtered.map((n) => (
          <div
            key={n.id}
            className={"call " + n.status + (n.id === selId ? " sel" : "")}
            onClick={() => onSelect(n.id)}
          >
            <div className="statwrap">
              <span className={"sdot " + n.status} />
            </div>
            <div className="main">
              <div className="step">{n.step}</div>
              <div className="meta">
                <span className="tag model">{n.model}</span>
                <span className="ts">{n.timestamp}</span>
              </div>
            </div>
            <div className="cost">
              <div className={"amt" + (n.cost === "$0.0000" ? " zero" : "")}>
                {n.cost}
              </div>
              <div className={"lat" + (n.status === "cached" ? " cached" : "")}>
                {n.status === "cached" ? "0ms" : n.latency.replace(/\s*\(.*\)/, "")}
              </div>
            </div>
          </div>
        ))}
      </div>

      <div className="sb-bottom">
        <button className="btn" onClick={() => alert("Settings · proxy config")}>
          <Icon name="settings" size={13} /> Settings
        </button>
        <button
          className="btn danger"
          onClick={() => alert("API key reset · session cleared")}
        >
          <Icon name="key" size={13} /> Reset Key
        </button>
      </div>
    </div>
  );
}
