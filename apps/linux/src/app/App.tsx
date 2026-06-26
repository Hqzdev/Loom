import { useState } from "react";
import type { CSSProperties, PointerEvent as ReactPointerEvent } from "react";
import { GraphPane } from "../features/graph/GraphPane";
import { InspectorPane } from "../features/inspector/InspectorPane";
import { ReplayPanel } from "../features/replay/ReplayPanel";
import { SettingsPanel } from "../features/settings/SettingsPanel";
import type { AgentNode } from "../domain/trace";
import { useTetherProxy } from "./useTetherProxy";

export function App() {
  const trace = useTetherProxy();
  const nodes = trace.snapshot.nodes;
  const agentCount = new Set(nodes.map((node) => node.agent_name)).size;
  const [leftWidth, setLeftWidth] = useState(280);
  const [rightWidth, setRightWidth] = useState(380);

  return (
    <main
      className="appShell"
      style={{
        "--left-sidebar-width": `${leftWidth}px`,
        "--right-sidebar-width": `${rightWidth}px`
      } as CSSProperties}
    >
      <aside className="sidebar">
        <section className="agentSummary">
          <span className="agentSummaryIcon">T</span>
          <strong>{agentCount > 1 ? `${agentCount} Agents` : agentCount === 1 ? "One Agent" : "No Agents"}</strong>
        </section>

        <label className="callFilter">
          <span>Filter calls</span>
          <input type="search" placeholder="Filter calls..." />
        </label>

        <section className="callsPanel">
          <div className="callsHeader">
            <strong>Calls</strong>
            <span>{nodes.length === 0 ? "0 of 0" : `${nodes.length} of ${nodes.length}`}</span>
          </div>
          {nodes.length === 0 ? (
            <div className="emptyCalls">
              <strong>No calls yet</strong>
              <span>Run an agent through the local proxy.</span>
            </div>
          ) : (
            <div className="callsList">
              {nodes.map((node) => (
                <CallRow
                  key={node.id}
                  node={node}
                  selected={trace.selectedNodeId === node.id}
                  onSelect={trace.selectNode}
                />
              ))}
            </div>
          )}
        </section>

        <SettingsPanel
          online={trace.online}
          error={trace.error}
          starting={trace.proxyStarting}
          startError={trace.proxyStartError}
          startedByApp={trace.proxyStartedByApp}
          controlsAvailable={trace.proxyControlsAvailable}
          workspacePath={trace.workspacePath}
          workspaceError={trace.workspaceError}
          onStart={trace.startProxy}
          onStop={trace.stopProxy}
          onWorkspacePathChange={trace.setWorkspacePath}
        />
      </aside>

      <ResizeHandle side="left" onResize={setLeftWidth} />

      <GraphPane
        nodes={nodes}
        selectedNodeId={trace.selectedNodeId}
        selectedNode={trace.selectedNode}
        onSelectNode={trace.selectNode}
      />

      <ResizeHandle side="right" onResize={setRightWidth} />

      <div className="rightRail">
        <InspectorPane
          node={trace.selectedNode}
          loading={trace.detailLoading}
          error={trace.detailError}
          workSummary={trace.selectedNode ? trace.nodeWorkSummaries[trace.selectedNode.id] : undefined}
        />
        <ReplayPanel
          node={trace.selectedNode}
          replaying={trace.replaying}
          result={trace.replayResult}
          error={trace.replayError}
          unsupportedReason={trace.replayUnsupportedReason}
          onReplay={trace.replaySelectedNode}
        />
      </div>
    </main>
  );
}

type ResizeHandleProps = {
  side: "left" | "right";
  onResize: (width: number) => void;
};

function ResizeHandle({ side, onResize }: ResizeHandleProps) {
  function startResize(event: ReactPointerEvent<HTMLDivElement>) {
    event.preventDefault();
    const pointerId = event.pointerId;
    const target = event.currentTarget;
    target.setPointerCapture(pointerId);

    function move(pointerEvent: PointerEvent) {
      const viewportWidth = window.innerWidth;
      const rawWidth = side === "left" ? pointerEvent.clientX : viewportWidth - pointerEvent.clientX;
      onResize(clamp(rawWidth, 240, 560));
    }

    function stop() {
      target.releasePointerCapture(pointerId);
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerup", stop);
      window.removeEventListener("pointercancel", stop);
    }

    window.addEventListener("pointermove", move);
    window.addEventListener("pointerup", stop);
    window.addEventListener("pointercancel", stop);
  }

  return <div className={`resizeHandle resizeHandle${side}`} role="separator" onPointerDown={startResize} />;
}

function clamp(value: number, minimum: number, maximum: number) {
  return Math.min(maximum, Math.max(minimum, value));
}

type CallRowProps = {
  node: AgentNode;
  selected: boolean;
  onSelect: (node: AgentNode) => void;
};

function CallRow({ node, selected, onSelect }: CallRowProps) {
  return (
    <button className={`callRow ${selected ? "selected" : ""}`} type="button" onClick={() => onSelect(node)}>
      <span className={`callStatusBar statusBar${node.status}`} />
      <span className="callContent">
        <span className="callTitle">{node.step_name}</span>
        <span className="callMeta">
          <span className="sourcePill">{node.agent_name}</span>
          <span className="modelPill">{node.provider} / {node.model}</span>
        </span>
      </span>
      <span className="callLatency">{node.latency}</span>
    </button>
  );
}
