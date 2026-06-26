//! Request-side capture: parse an outgoing LLM request body into the metadata
//! the UI shows before the response arrives (model, prompt, a short preview).

use serde_json::Value;
use uuid::Uuid;

use super::capture_extract::{extract_last_text, extract_prompt, extract_tool_result_ids};
use super::text::{now_millis, truncate_one_line};
use crate::context;

/// Max response bytes the proxy buffers for trace previews on cache misses.
pub(crate) const MAX_CAPTURE_BYTES: usize = 256 * 1024;

/// Largest request body we retain for replay. Prompts are small; anything
/// bigger is dropped and the span is marked non-replayable.
const REPLAY_MAX_BODY: usize = 1024 * 1024;

/// Everything we learn from a request before the upstream responds.
#[derive(Clone)]
pub(crate) struct TraceCapture {
    pub(super) id: String,
    pub(super) created_at: i64,
    pub(super) provider: String,
    pub(super) method: String,
    pub(super) path: String,
    pub(crate) model: String,
    pub(crate) preview: String,
    pub(super) prompt_system: String,
    pub(super) prompt_user: String,
    pub(super) request_id: String,
    pub(super) temperature: Option<f64>,
    pub(super) tool_result_ids: Vec<String>,
    pub(super) context_inputs: String,
    pub(super) input_hash: String,
    pub(super) request_body: Vec<u8>,
    pub(super) request_target: String,
    pub(super) workspace_id: String,
}

impl TraceCapture {
    /// Parses a request body, extracting model, prompt, preview, and id.
    ///
    /// Non-JSON bodies degrade gracefully to a byte-count preview.
    pub(crate) fn from_request(
        method: &str,
        path: &str,
        target: &str,
        provider: &str,
        workspace_id: &str,
        body: &[u8],
    ) -> Self {
        let parsed = serde_json::from_slice::<Value>(body).ok();
        let model = parsed
            .as_ref()
            .and_then(|value| value.get("model"))
            .and_then(Value::as_str)
            .unwrap_or("-")
            .to_string();
        let preview = parsed
            .as_ref()
            .and_then(extract_last_text)
            .unwrap_or_else(|| {
                if body.is_empty() {
                    "-".to_string()
                } else {
                    format!("<{} bytes, non-JSON>", body.len())
                }
            });
        let (prompt_system, prompt_user) = parsed
            .as_ref()
            .map(extract_prompt)
            .unwrap_or_else(|| ("".to_string(), truncate_one_line(&preview, 4_000)));
        let request_id = parsed
            .as_ref()
            .and_then(|value| value.get("id"))
            .and_then(Value::as_str)
            .unwrap_or("-")
            .to_string();
        let temperature = parsed
            .as_ref()
            .and_then(|value| value.get("temperature"))
            .and_then(Value::as_f64);
        let tool_result_ids = parsed
            .as_ref()
            .map(extract_tool_result_ids)
            .unwrap_or_default();
        let inputs = context::from_request(parsed.as_ref(), &prompt_system, &prompt_user, &model);
        let input_hash = inputs.input_hash.clone();
        let context_inputs = serde_json::to_string(&inputs).unwrap_or_else(|_| "{}".to_string());
        let request_body = if body.len() <= REPLAY_MAX_BODY {
            body.to_vec()
        } else {
            Vec::new()
        };

        Self {
            id: Uuid::new_v4().to_string(),
            created_at: now_millis(),
            provider: provider.to_string(),
            method: method.to_string(),
            path: path.to_string(),
            model,
            preview: truncate_one_line(&preview, 300),
            prompt_system,
            prompt_user,
            request_id,
            temperature,
            tool_result_ids,
            context_inputs,
            input_hash,
            request_body,
            request_target: target.to_string(),
            workspace_id: workspace_id.to_string(),
        }
    }
}
