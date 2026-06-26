import type { AgentNode } from "../../domain/trace";
import type { AgentNodeWorkSummary } from "../../domain/workspace";

type InspectorPaneProps = {
  node: AgentNode | null;
  loading: boolean;
  error: string | null;
  workSummary?: AgentNodeWorkSummary;
};

export function InspectorPane({ node, loading, error, workSummary }: InspectorPaneProps) {
  if (!node) {
    return (
      <aside className="inspectorPane">
        <header className="inspectorHeader">
          <h2>No node selected</h2>
        </header>
        <div className="emptyInspector">
          <strong>Select a node</strong>
          <span>Prompt, response, metadata, file impact, and replay state will appear here.</span>
        </div>
      </aside>
    );
  }
  const sources = node.context_inputs?.sources ?? [];
  const withheld = node.context_inputs?.withheld ?? [];
  const execution = node.context_inputs?.execution ?? null;

  return (
    <aside className="inspectorPane">
      <header className="inspectorHeader">
        <div className="inspectorTitleRow">
          <h2>{node.step_name}</h2>
          <span className={`statusPill statusPill${node.status}`}>{node.status}</span>
        </div>
        <div className="inspectorChips">
          <span className="sourcePill">{node.agent_name}</span>
          <span className="modelPill">{node.provider} / {node.model}</span>
        </div>
        <div className="inspectorTabs" role="tablist" aria-label="Inspector sections">
          <button className="active" type="button">Context</button>
          <button type="button">LLM Call</button>
          <button type="button">Response</button>
          <button type="button">Metadata</button>
        </div>
      </header>

      <div className="inspectorSections">
        {loading ? (
          <section>
            <h3>loading</h3>
            <p className="mutedText">Hydrating node detail from the local proxy.</p>
          </section>
        ) : null}
        {error ? (
          <section>
            <h3>detail.error</h3>
            <p className="errorText">{error}</p>
          </section>
        ) : null}
        <section>
          <div className="sectionHeader">
            <h3>context.assembly</h3>
            <span>{sources.length} sources</span>
            <span>{withheld.length} withheld</span>
            <span>{node.cache_status || "fresh"}</span>
          </div>
          <h4>This Request</h4>
          <dl>
            <dt>Prompt</dt>
            <dd>{workSummary?.promptText ?? node.prompt.user ?? node.step_name}</dd>
            <dt>Files</dt>
            <dd>{workSummary ? fileSummary(workSummary) : "Workspace attribution unavailable"}</dd>
          </dl>
          {workSummary?.changedFiles.length ? (
            <div className="changedFileList">
              {workSummary.changedFiles.slice(0, 12).map((file) => (
                <div className="changedFileRow" key={file.path}>
                  <span>{file.status}</span>
                  <strong>{file.path}</strong>
                  <em>{`+${file.additions} -${file.deletions}`}</em>
                </div>
              ))}
            </div>
          ) : null}
        </section>
        <section>
          <h3>boundary.hashes</h3>
          <dl>
            <dt>Input Hash</dt>
            <dd>{node.input_hash || "n/a"}</dd>
            <dt>Output Hash</dt>
            <dd>{node.output_hash || "n/a"}</dd>
            <dt>Trace ID</dt>
            <dd>{node.trace_id || "n/a"}</dd>
            <dt>Parent Span</dt>
            <dd>{node.parent_span_id || "root"}</dd>
          </dl>
        </section>
        <section>
          <h3>input.sources</h3>
          <dl>
            <dt>Inline Segments</dt>
            <dd>{sources.length}</dd>
            <dt>Withheld</dt>
            <dd>{withheld.length === 0 ? "none" : withheld.join(", ")}</dd>
          </dl>
        </section>
        <section>
          <h3>prompt</h3>
          <pre>{node.prompt.user || execution?.command_line || "Prompt not retained"}</pre>
        </section>
        <section>
          <h3>response</h3>
          <pre>{node.response.text || node.error?.detail || "Response not retained"}</pre>
        </section>
        <section>
          <h3>replay.boundary</h3>
          <dl>
            <dt>Reason</dt>
            <dd>{execution ? "shell execution" : "provider request"}</dd>
            <dt>Output Hash</dt>
            <dd>{node.output_hash || "n/a"}</dd>
          </dl>
        </section>
      </div>
    </aside>
  );
}

function fileSummary(summary: AgentNodeWorkSummary) {
  if (summary.changedFiles.length === 0) {
    return "No file changes attributed to this node";
  }
  const additions = summary.changedFiles.reduce((total, file) => total + file.additions, 0);
  const deletions = summary.changedFiles.reduce((total, file) => total + file.deletions, 0);
  return `${summary.changedFiles.length} files | +${additions} -${deletions}`;
}
