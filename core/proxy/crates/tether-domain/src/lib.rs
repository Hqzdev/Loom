//! Shared domain types for the Tether proxy workspace.
//!
//! These are the wire-facing data transfer objects (DTOs) that the macOS UI
//! consumes via `/api/*`. They are pure data: no I/O, no async, and no
//! dependency on any other workspace crate. Keeping them here gives every
//! service a single, authoritative definition of the model and is the basis
//! for the generated OpenAPI contract (see apps/web docs).
//!
//! Field names serialize as-is (snake_case), which the UI relies on
//! (e.g. `step_name`, `request_id`).

use serde::Serialize;
use serde_json::Value;

/// A full trace view: ordered captured nodes plus replay invalidation state.
#[derive(Serialize)]
pub struct TraceSnapshot {
    pub nodes: Vec<AgentNodeDto>,
    /// Spans whose upstream output was edited and whose descendants need replay.
    pub stale_node_ids: Vec<String>,
}

/// One captured LLM call, laid out for the UI's trace graph.
///
/// `bar_percent` is the call's latency normalized against the slowest call in
/// the snapshot (0.0–1.0), used to size the timeline bar.
#[derive(Serialize)]
pub struct AgentNodeDto {
    pub id: String,
    pub trace_id: String,
    pub parent_span_id: Option<String>,
    pub tool_use_ids: Value,
    pub context_inputs: Value,
    pub input_hash: String,
    pub stale: bool,
    pub is_replay: bool,
    pub replay_source_id: Option<String>,
    pub replay_provider: Option<String>,
    pub agent_name: String,
    pub depth: i64,
    pub step_name: String,
    pub timestamp: String,
    pub provider: String,
    pub model: String,
    pub cost: String,
    pub latency: String,
    pub latency_ms: i64,
    pub bar_percent: f64,
    pub tokens_in: i64,
    pub tokens_out: i64,
    pub request_id: String,
    pub cache_status: String,
    pub temperature: Option<f64>,
    pub status: String,
    pub prompt: AgentPromptDto,
    pub response: AgentResponseDto,
    pub output_hash: String,
    pub error: Option<AgentErrorDto>,
}

/// The system and user portions of a captured prompt.
#[derive(Serialize)]
pub struct AgentPromptDto {
    pub system: String,
    pub user: String,
}

/// A captured response body and the language it was detected as (`json`/`text`).
#[derive(Serialize)]
pub struct AgentResponseDto {
    pub language: String,
    pub text: String,
}

/// Structured error detail attached to a failed call.
#[derive(Serialize)]
pub struct AgentErrorDto {
    pub code: String,
    pub message: String,
    pub detail: String,
}
