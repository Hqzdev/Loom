type SettingsPanelProps = {
  online: boolean;
  error: string | null;
  starting: boolean;
  startError: string | null;
  startedByApp: boolean;
  controlsAvailable: boolean;
  workspacePath: string;
  workspaceError: string | null;
  onStart: () => void;
  onStop: () => void;
  onWorkspacePathChange: (path: string) => void;
};

export function SettingsPanel({
  online,
  error,
  starting,
  startError,
  startedByApp,
  controlsAvailable,
  workspacePath,
  workspaceError,
  onStart,
  onStop,
  onWorkspacePathChange
}: SettingsPanelProps) {
  return (
    <section className="settingsPanel">
      <span className="eyebrow">Local proxy</span>
      <div className="settingsGrid">
        <span>URL</span>
        <strong>http://127.0.0.1:8080</strong>
        <span>Status</span>
        <strong>{online ? "online" : "offline"}</strong>
        <span>Error</span>
        <strong>{error ?? "none"}</strong>
      </div>
      <div className="settingsActions">
        <button className="secondaryButton" type="button" disabled={!controlsAvailable || starting || online} onClick={onStart}>
          {starting ? "Starting..." : "Start proxy"}
        </button>
        <button className="secondaryButton" type="button" disabled={!controlsAvailable || starting || !startedByApp} onClick={onStop}>
          Stop owned proxy
        </button>
      </div>
      {!controlsAvailable ? <p className="mutedText">Proxy controls work only in the Tether desktop window.</p> : null}
      {startError ? <p className="errorText">{startError}</p> : null}
      <label className="workspaceField">
        <span>Workspace path</span>
        <input
          type="text"
          value={workspacePath}
          placeholder="/home/you/project"
          onChange={(event) => onWorkspacePathChange(event.target.value)}
        />
      </label>
      {workspaceError ? <p className="errorText">{workspaceError}</p> : null}
    </section>
  );
}
