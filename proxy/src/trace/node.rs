//! Read-path mapping: turn a stored `TraceRow` into a UI `AgentNodeDto`.

use loom_domain::{AgentErrorDto, AgentNodeDto, AgentPromptDto, AgentResponseDto};
use serde_json::Value;

use super::store::TraceRow;
use super::text::{compact_path, format_latency, format_timestamp};

/// Converts a row into a graph node, deriving status, label, agent, and the
/// latency bar fraction (relative to the snapshot's slowest call).
pub(super) fn row_to_node(depth: i64, row: TraceRow, max_latency: i64) -> AgentNodeDto {
    let status = if row.cache_status == "hit" {
        "cached"
    } else if (200..=299).contains(&row.status_code) {
        "success"
    } else {
        "error"
    };
    let step_name = format!(
        "{} {}",
        row.provider.to_ascii_uppercase(),
        compact_path(&row.path)
    );
    let agent_name = agent_name_for(&row.provider, &row.model);
    let tool_use_ids =
        serde_json::from_str(&row.tool_use_ids).unwrap_or_else(|_| Value::Array(Vec::new()));
    let context_inputs = serde_json::from_str(&row.context_inputs)
        .unwrap_or_else(|_| Value::Object(Default::default()));

    AgentNodeDto {
        id: row.id,
        trace_id: row.trace_id,
        parent_span_id: row.parent_span_id,
        tool_use_ids,
        context_inputs,
        input_hash: row.input_hash,
        stale: row.stale,
        agent_name,
        depth,
        step_name,
        timestamp: format_timestamp(row.created_at),
        model: row.model,
        cost: row.cost,
        latency: format_latency(row.latency_ms),
        latency_ms: row.latency_ms,
        bar_percent: (row.latency_ms as f64 / max_latency as f64).clamp(0.06, 1.0),
        tokens_in: row.tokens_in,
        tokens_out: row.tokens_out,
        request_id: row.request_id,
        cache_status: row.cache_status,
        temperature: row.temperature,
        status: status.to_string(),
        prompt: AgentPromptDto {
            system: row.prompt_system,
            user: row.prompt_user,
        },
        response: AgentResponseDto {
            language: row.response_language,
            text: row.response_text,
        },
        error: row.error_code.map(|code| AgentErrorDto {
            code,
            message: row.error_message.unwrap_or_default(),
            detail: row.error_detail.unwrap_or_default(),
        }),
    }
}

/// Maps a provider/model pair to a friendly agent name for the UI.
fn agent_name_for(provider: &str, model: &str) -> String {
    let provider = provider.to_ascii_lowercase();
    let model = model.to_ascii_lowercase();

    if provider == "anthropic" || model.contains("claude") {
        "Claude Code".to_string()
    } else if provider == "openai" {
        "Codex".to_string()
    } else {
        "Agent".to_string()
    }
}
