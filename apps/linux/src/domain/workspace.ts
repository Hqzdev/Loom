export type WorkspaceChangeFile = {
  path: string;
  status: string;
  additions: number;
  deletions: number;
};

export type WorkspaceChangeSummary = {
  files: WorkspaceChangeFile[];
};

export type AgentNodeWorkSummary = {
  promptText: string;
  changedFiles: WorkspaceChangeFile[];
};

export const emptyWorkspaceChangeSummary: WorkspaceChangeSummary = {
  files: []
};
