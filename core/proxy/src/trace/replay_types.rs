//! DTOs and persistence values for replay endpoints.

use serde::{Deserialize, Serialize};

use super::summarize::ResponseSummary;

/// Request body for editing the stored output of a captured node.
#[derive(Deserialize)]
pub(super) struct EditOutputRequest {
    pub(super) output: String,
}

/// Request body for replaying a retained request through CometAPI.
#[derive(Deserialize)]
pub(super) struct ReplayWithRequest {
    pub(super) model: String,
    pub(super) provider_key: Option<String>,
    #[allow(dead_code)]
    pub(super) base_url: Option<String>,
}

/// Result returned after editing a node and marking stale descendants.
#[derive(Serialize)]
pub(super) struct InvalidationResult {
    pub(super) node_id: String,
    pub(super) reason: String,
    pub(super) previous_output_hash: String,
    pub(super) output_hash: String,
    pub(super) invalidated: Vec<String>,
}

/// Result listing the downstream descendants of a node.
#[derive(Serialize)]
pub(super) struct DownstreamResult {
    pub(super) node_id: String,
    pub(super) downstream: Vec<String>,
}

/// Result returned after replaying a retained request body upstream.
#[derive(Serialize)]
pub(super) struct ReplayResult {
    pub(super) node_id: String,
    pub(super) reason: String,
    pub(super) previous_output_hash: String,
    pub(super) output_hash: String,
    pub(super) status_code: u16,
    pub(super) cost: String,
    pub(super) tokens_in: i64,
    pub(super) tokens_out: i64,
    pub(super) invalidated: Vec<String>,
}

/// Result returned after creating a cross-model replay node.
#[derive(Serialize)]
pub(super) struct ReplayWithResult {
    pub(super) new_trace_id: String,
    pub(super) node_id: String,
    pub(super) source_node_id: String,
    pub(super) model: String,
    pub(super) response_text: String,
    pub(super) latency_ms: i64,
    pub(super) cost_usd: f64,
    pub(super) input_tokens: i64,
    pub(super) output_tokens: i64,
}

/// Persisted request fields needed to replay a node.
pub(super) struct ReplaySpec {
    pub(super) method: String,
    pub(super) provider: String,
    pub(super) target: String,
    pub(super) model: String,
    pub(super) body: Vec<u8>,
}

/// Persisted source fields needed to create a cross-model replay node.
pub(super) struct ReplayWithSpec {
    pub(super) id: String,
    pub(super) trace_id: String,
    pub(super) parent_span_id: Option<String>,
    pub(super) prompt_system: String,
    pub(super) prompt_user: String,
    pub(super) context_inputs: String,
    pub(super) input_hash: String,
    pub(super) temperature: Option<f64>,
    pub(super) body: Vec<u8>,
}

/// Insert payload for a cross-model replay row.
pub(super) struct ReplayWithInsert {
    pub(super) id: String,
    pub(super) source_node_id: String,
    pub(super) trace_id: String,
    pub(super) parent_span_id: Option<String>,
    pub(super) model: String,
    pub(super) status_code: u16,
    pub(super) latency_ms: i64,
    pub(super) request_id: String,
    pub(super) prompt_system: String,
    pub(super) prompt_user: String,
    pub(super) response_text: String,
    pub(super) response_language: String,
    pub(super) tokens_in: i64,
    pub(super) tokens_out: i64,
    pub(super) cost: String,
    pub(super) temperature: Option<f64>,
    pub(super) tool_use_ids: String,
    pub(super) context_inputs: String,
    pub(super) input_hash: String,
    pub(super) request_body: Vec<u8>,
}

/// Database update payload produced after a replay succeeds.
pub(super) struct ReplayUpdate {
    pub(super) node_id: String,
    pub(super) status_code: u16,
    pub(super) latency_ms: i64,
    pub(super) cost: String,
    pub(super) request_id: String,
    pub(super) response_text: String,
    pub(super) response_language: String,
    pub(super) tokens_in: i64,
    pub(super) tokens_out: i64,
    pub(super) tool_use_ids: String,
}

impl ReplayUpdate {
    /// Builds a database update payload from replay response summary fields.
    pub(super) fn from_summary(
        node_id: String,
        status_code: u16,
        latency_ms: i64,
        cost: String,
        request_id: String,
        summary: ResponseSummary,
    ) -> Self {
        let tool_use_ids =
            serde_json::to_string(&summary.tool_use_ids).unwrap_or_else(|_| "[]".to_string());

        Self {
            node_id,
            status_code,
            latency_ms,
            cost,
            request_id,
            response_text: summary.text,
            response_language: summary.language,
            tokens_in: summary.tokens_in,
            tokens_out: summary.tokens_out,
            tool_use_ids,
        }
    }
}
