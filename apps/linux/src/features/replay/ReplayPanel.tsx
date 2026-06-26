import type { AgentNode, TraceReplayResult } from "../../domain/trace";

type ReplayPanelProps = {
  node: AgentNode | null;
  replaying: boolean;
  result: TraceReplayResult | null;
  error: string | null;
  unsupportedReason: string | null;
  onReplay: () => void;
};

export function ReplayPanel({ node, replaying, result, error, unsupportedReason, onReplay }: ReplayPanelProps) {
  return (
    <section className="replayPanel">
      <span className="eyebrow">Replay</span>
      {node ? (
        <div className="replayStack">
          {unsupportedReason ? (
            <p>{unsupportedReason}</p>
          ) : (
            <>
              <button className="primaryButton" type="button" disabled={replaying} onClick={onReplay}>
                {replaying ? "Replaying..." : "Time-travel - edit response"}
              </button>
            </>
          )}
          {result ? (
            <dl className="resultGrid">
              <dt>Status</dt>
              <dd>{result.status_code}</dd>
              <dt>Output</dt>
              <dd>{`${result.previous_output_hash} -> ${result.output_hash}`}</dd>
              <dt>Invalidated</dt>
              <dd>{result.invalidated.length === 0 ? "none" : result.invalidated.join(", ")}</dd>
            </dl>
          ) : null}
          {error ? <p className="errorText">{error}</p> : null}
        </div>
      ) : (
        <p>Select a node to inspect replay availability.</p>
      )}
    </section>
  );
}
