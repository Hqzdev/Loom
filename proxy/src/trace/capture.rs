//! Request-side capture: parse an outgoing LLM request body into the metadata
//! the UI shows before the response arrives (model, prompt, a short preview).

use serde_json::Value;
use uuid::Uuid;

use super::text::{cap_text, content_to_string, now_millis, truncate_one_line};

/// Max response bytes the proxy buffers for trace previews on cache misses.
pub(crate) const MAX_CAPTURE_BYTES: usize = 256 * 1024;

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
}

impl TraceCapture {
    /// Parses a request body, extracting model, prompt, preview, and id.
    ///
    /// Non-JSON bodies degrade gracefully to a byte-count preview.
    pub(crate) fn from_request(method: &str, path: &str, provider: &str, body: &[u8]) -> Self {
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
        }
    }
}

/// Splits a request into (system, user) prompt text across OpenAI/Anthropic shapes.
fn extract_prompt(value: &Value) -> (String, String) {
    let system = value
        .get("system")
        .map(content_to_string)
        .or_else(|| {
            value
                .get("messages")
                .and_then(Value::as_array)
                .map(|messages| {
                    messages
                        .iter()
                        .filter(|message| {
                            matches!(
                                message.get("role").and_then(Value::as_str),
                                Some("system" | "developer")
                            )
                        })
                        .filter_map(|message| message.get("content"))
                        .map(content_to_string)
                        .collect::<Vec<_>>()
                        .join("\n\n")
                })
        })
        .unwrap_or_default();

    let user = value
        .get("messages")
        .and_then(Value::as_array)
        .and_then(|messages| {
            messages
                .iter()
                .rev()
                .find(|message| message.get("role").and_then(Value::as_str) == Some("user"))
                .and_then(|message| message.get("content"))
                .map(content_to_string)
        })
        .or_else(|| value.get("input").map(content_to_string))
        .or_else(|| {
            value
                .get("prompt")
                .and_then(Value::as_str)
                .map(ToOwned::to_owned)
        })
        .unwrap_or_default();

    (cap_text(&system, 16_000), cap_text(&user, 32_000))
}

/// Best-effort "most recent user text" used for the one-line request preview.
fn extract_last_text(value: &Value) -> Option<String> {
    let arr = value
        .get("messages")
        .and_then(Value::as_array)
        .or_else(|| value.get("input").and_then(Value::as_array));
    if let Some(arr) = arr {
        return arr
            .last()
            .map(|last| content_to_string(last.get("content").unwrap_or(last)));
    }
    value.get("input").map(content_to_string).or_else(|| {
        value
            .get("prompt")
            .and_then(Value::as_str)
            .map(ToOwned::to_owned)
    })
}
