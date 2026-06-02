"use client";

import { useEffect, useState } from "react";
import { Icon } from "./Icon";
import { CodeBlock } from "./CodeBlock";
import type { TraceNode } from "@/lib/data";

export type Tab = "prompt" | "response" | "metadata";

export function Inspector({
  node,
  tab,
  setTab,
  edits,
  setEdit,
}: {
  node: TraceNode;
  tab: Tab;
  setTab: (t: Tab) => void;
  edits: Record<string, string>;
  setEdit: (id: string, val: string) => void;
}) {
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState("");
  useEffect(() => {
    setEditing(false);
  }, [node.id, tab]);

  const isError = node.status === "error";
  const editedResp = edits[node.id];
  const respText = editedResp != null ? editedResp : node.response.text;
  const respLang = editedResp != null ? "json" : node.response.lang;

  const startEdit = () => {
    setDraft(respText);
    setEditing(true);
    setTab("response");
  };
  const saveEdit = () => {
    setEdit(node.id, draft);
    setEditing(false);
  };

  return (
    <div className="pane right">
      <div className="insp-head">
        <div className="insp-title">
          <span className={"idot " + node.status} />
          <span className="it">{node.step}</span>
          <span className="imodel">{node.model}</span>
        </div>
        <div className="segmented">
          {(["prompt", "response", "metadata"] as Tab[]).map((t) => (
            <button
              key={t}
              className={"seg" + (tab === t ? " on" : "")}
              onClick={() => setTab(t)}
            >
              {t[0].toUpperCase() + t.slice(1)}
            </button>
          ))}
        </div>
      </div>

      <div className="insp-body">
        {tab === "prompt" && (
          <>
            <div className="editor-toolbar">
              <span>request.prompt</span>
              <span className="grow" />
              <span className="chip">
                temp {node.temperature == null ? "—" : node.temperature.toFixed(1)}
              </span>
              <span className="chip">{node.tokensIn} tдok</span>
            </div>
            <div className="code">
              <table>
                <tbody>
                  <PromptRows role="system" body={node.prompt.system} start={1} />
                  <PromptRows
                    role="user"
                    body={node.prompt.user}
                    start={node.prompt.system.split("\n").length + 2}
                  />
                </tbody>
              </table>
            </div>
          </>
        )}

        {tab === "response" && (
          <>
            <div className="editor-toolbar">
              <span>response.{respLang === "json" ? "json" : "txt"}</span>
              <span className="grow" />
              {editedResp != null && (
                <span
                  className="chip"
                  style={{ color: "var(--amber)", borderColor: "#5a4a24" }}
                >
                  edited
                </span>
              )}
              <span className={"chip " + (isError ? "err" : "ok")}>
                {isError ? "✗ " + node.error!.code : "✓ 200 OK"}
              </span>
            </div>
            {isError && !editing && node.error && (
              <div className="err-banner">
                <span className="x">✗</span>
                <span>
                  <b>{node.error.code}</b> — {node.error.message}
                  <br />
                  <span style={{ color: "var(--text-4)" }}>{node.error.detail}</span>
                </span>
              </div>
            )}
            {editing ? (
              <textarea
                className="edit-area"
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                spellCheck={false}
                autoFocus
              />
            ) : (
              <CodeBlock
                text={respText}
                lang={respLang}
                broken={isError && editedResp == null}
              />
            )}
          </>
        )}

        {tab === "metadata" && <Metadata node={node} edited={editedResp != null} />}
      </div>

      <div className="insp-foot">
        {editing ? (
          <>
            <button className="tt-btn active" onClick={saveEdit}>
              <Icon name="save" size={14} /> Save Mocked Response &amp; Replay
            </button>
            <div className="tt-sub">
              downstream steps will re-run against your edit ·{" "}
              <b onClick={() => setEditing(false)} style={{ cursor: "pointer" }}>
                cancel
              </b>
            </div>
          </>
        ) : (
          <>
            <button className="tt-btn" onClick={startEdit}>
              <Icon name="timeTravel" size={14} /> Time-Travel · Edit Response
            </button>
            <div className="tt-sub">
              intercept &amp; rewrite this node&apos;s output, then replay the chain
            </div>
          </>
        )}
      </div>
    </div>
  );
}

function PromptRows({
  role,
  body,
  start,
}: {
  role: string;
  body: string;
  start: number;
}) {
  const lines = body.split("\n");
  return (
    <>
      <tr>
        <td className="ln">{start - 1}</td>
        <td className="cl">
          <span className="role">{role}</span>
        </td>
      </tr>
      {lines.map((ln, i) => (
        <tr key={i}>
          <td className="ln">{start + i}</td>
          <td className="cl">{ln || " "}</td>
        </tr>
      ))}
    </>
  );
}

function Metadata({ node, edited }: { node: TraceNode; edited: boolean }) {
  const rows: [string, string, string][] = [
    ["Request ID", node.requestId, ""],
    [
      "Status",
      node.status === "error" && node.error
        ? node.error.code
        : node.status.toUpperCase(),
      node.status === "error" ? "pink" : node.status === "cached" ? "cyan" : "green",
    ],
    ["Model", node.model, ""],
    [
      "Exact Latency",
      node.latency,
      node.status === "cached" ? "cyan" : node.status === "error" ? "pink" : "",
    ],
    ["Tokens In", node.tokensIn.toLocaleString(), ""],
    ["Tokens Out", node.tokensOut.toLocaleString(), ""],
    ["Cost", node.cost, ""],
    ["Cache Status", node.cacheStatus, node.cacheStatus === "HIT" ? "cyan" : ""],
    [
      "Temperature",
      node.temperature == null ? "n/a" : node.temperature.toFixed(2),
      "",
    ],
    ["Timestamp", node.timestamp + ".184", ""],
    ["Mock Override", edited ? "ACTIVE" : "none", edited ? "pink" : ""],
  ];
  return (
    <div className="meta-table">
      {rows.map(([k, v, cls]) => (
        <div className="kv" key={k}>
          <div className="k">{k}</div>
          <div className={"v " + cls}>{v}</div>
        </div>
      ))}
    </div>
  );
}
