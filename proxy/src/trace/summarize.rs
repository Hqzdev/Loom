//! Response-side summarization: distill an upstream response body into the text
//! and token counts stored on a trace row, across OpenAI/Anthropic shapes.

use serde_json::Value;

use super::text::{cap_text, content_to_string, pretty_json, utf8_preview};

/// The fields extracted from a response body for storage.
pub(super) struct ResponseSummary {
    pub(super) request_id: Option<String>,
    pub(super) text: String,
    pub(super) language: String,
    pub(super) tokens_in: i64,
    pub(super) tokens_out: i64,
}

/// Summarizes a response body, parsing JSON where possible and otherwise
/// falling back to a capped UTF-8 preview.
pub(super) fn summarize_response(content_type: &str, body: &[u8]) -> ResponseSummary {
    if let Ok(value) = serde_json::from_slice::<Value>(body) {
        let text = extract_response_text(&value).unwrap_or_else(|| pretty_json(&value));
        let usage = value.get("usage");
        let tokens_in = usage
            .and_then(|usage| {
                usage
                    .get("prompt_tokens")
                    .or_else(|| usage.get("input_tokens"))
                    .and_then(Value::as_i64)
            })
            .unwrap_or(0);
        let tokens_out = usage
            .and_then(|usage| {
                usage
                    .get("completion_tokens")
                    .or_else(|| usage.get("output_tokens"))
                    .and_then(Value::as_i64)
            })
            .unwrap_or(0);

        return ResponseSummary {
            request_id: value
                .get("id")
                .and_then(Value::as_str)
                .map(ToOwned::to_owned),
            text: cap_text(&text, 64_000),
            language: "json".to_string(),
            tokens_in,
            tokens_out,
        };
    }

    let text = utf8_preview(body);
    ResponseSummary {
        request_id: None,
        language: if content_type.contains("json") {
            "json".to_string()
        } else {
            "text".to_string()
        },
        text,
        tokens_in: 0,
        tokens_out: 0,
    }
}

/// Pulls the assistant's text out of the various provider response layouts.
fn extract_response_text(value: &Value) -> Option<String> {
    if let Some(text) = value.get("output_text").and_then(Value::as_str) {
        return Some(text.to_string());
    }

    if let Some(content) = value
        .get("choices")
        .and_then(Value::as_array)
        .and_then(|choices| choices.first())
        .and_then(|choice| choice.get("message"))
        .and_then(|message| message.get("content"))
    {
        return Some(content_to_string(content));
    }

    if let Some(content) = value.get("content").and_then(Value::as_array) {
        let text = content
            .iter()
            .filter_map(|item| item.get("text").and_then(Value::as_str))
            .collect::<Vec<_>>()
            .join("\n\n");
        if !text.is_empty() {
            return Some(text);
        }
    }

    if let Some(output) = value.get("output").and_then(Value::as_array) {
        let text = output
            .iter()
            .flat_map(|item| {
                item.get("content")
                    .and_then(Value::as_array)
                    .cloned()
                    .unwrap_or_default()
            })
            .filter_map(|item| {
                item.get("text")
                    .and_then(Value::as_str)
                    .map(ToOwned::to_owned)
            })
            .collect::<Vec<_>>()
            .join("\n\n");
        if !text.is_empty() {
            return Some(text);
        }
    }

    None
}
