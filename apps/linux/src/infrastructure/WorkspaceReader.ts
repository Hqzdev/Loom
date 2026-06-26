import { invoke } from "@tauri-apps/api/core";
import type { WorkspaceChangeFile } from "../domain/workspace";

type WorkspaceSnapshotRequest = {
  path: string;
};

export type WorkspaceSnapshotFile = WorkspaceChangeFile & {
  fingerprint: string;
};

export type WorkspaceSnapshot = {
  files: WorkspaceSnapshotFile[];
};

export class WorkspaceReader {
  async snapshot(path: string): Promise<WorkspaceSnapshot> {
    return invoke<WorkspaceSnapshot>("workspace_snapshot", {
      request: {
        path
      } satisfies WorkspaceSnapshotRequest
    });
  }
}
