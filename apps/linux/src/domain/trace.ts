export type NodeStatus = "success" | "running" | "error" | "cached" | "stale" | "unknown";

export type AgentPrompt = {
  system: string;
  user: string;
};

export type AgentResponse = {
  language: string;
  text: string;
};

export type AgentError = {
  code: string;
  message: string;
  detail: string;
};

export type AgentContextSource = {
  kind: string;
  path_or_id: string;
  hash: string;
  size_bytes: number;
  body?: string | null;
};

export type AgentExecutionContext = {
  event_type: string;
  session_id: string;
  command: string[];
  command_line: string;
  cwd: string;
  started_at_ms: number;
  ended_at_ms: number;
  latency_ms: number;
  exit_code?: number | null;
  git_base_revision?: string | null;
  git_diff_before: string;
  git_diff_after: string;
};

export type AgentContextInputs = {
  sources: AgentContextSource[];
  withheld: string[];
  input_hash: string;
  execution?: AgentExecutionContext | null;
};

export type AgentNode = {
  id: string;
  trace_id: string;
  parent_span_id?: string | null;
  tool_use_ids: unknown;
  context_inputs: AgentContextInputs;
  input_hash: string;
  stale: boolean;
  is_replay: boolean;
  replay_source_id?: string | null;
  replay_provider?: string | null;
  agent_name: string;
  depth: number;
  step_name: string;
  timestamp: string;
  provider: string;
  model: string;
  cost: string;
  latency: string;
  latency_ms: number;
  bar_percent: number;
  tokens_in: number;
  tokens_out: number;
  request_id: string;
  cache_status: string;
  temperature?: number | null;
  status: NodeStatus;
  prompt: AgentPrompt;
  response: AgentResponse;
  output_hash: string;
  error?: AgentError | null;
};

export type TraceSnapshot = {
  nodes: AgentNode[];
  stale_node_ids: string[];
};

export type TraceInvalidationResult = {
  node_id: string;
  reason: string;
  previous_output_hash: string;
  output_hash: string;
  invalidated: string[];
};

export type TraceReplayResult = TraceInvalidationResult & {
  status_code: number;
  cost: string;
  tokens_in: number;
  tokens_out: number;
};

export type TraceDownstreamResult = {
  node_id: string;
  downstream: string[];
};
