//! Provider-shape helpers for request-side trace capture.

use serde_json::Value;

use super::text::{cap_text, content_to_string};

/// Splits a request into (system, user) prompt text across OpenAI/Anthropic shapes.
pub(super) fn extract_prompt(value: &Value) -> (String, String) {
    let system = value
        .get("system")
        .map(content_to_string)
        .or_else(|| system_from_messages(value))
        .unwrap_or_default();
    let user = user_prompt(value).unwrap_or_default();

    (cap_text(&system, 16_000), cap_text(&user, 32_000))
}

/// Best-effort "most recent user text" used for the one-line request preview.
pub(super) fn extract_last_text(value: &Value) -> Option<String> {
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

/// Extracts request-side tool result ids that link this call to its parent span.
pub(super) fn extract_tool_result_ids(value: &Value) -> Vec<String> {
    let mut ids = Vec::new();

    if let Some(messages) = value.get("messages").and_then(Value::as_array) {
        for message in messages {
            collect_openai_tool_id(message, &mut ids);
            collect_anthropic_tool_result_ids(message, &mut ids);
        }
    }

    if let Some(input) = value.get("input").and_then(Value::as_array) {
        for item in input {
            collect_openai_responses_tool_result_id(item, &mut ids);
        }
    }

    ids
}

/// Extracts system/developer message text from OpenAI-style messages.
fn system_from_messages(value: &Value) -> Option<String> {
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
}

/// Extracts the latest user prompt across OpenAI, Responses, and prompt shapes.
fn user_prompt(value: &Value) -> Option<String> {
    value
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
}

/// Collects OpenAI `role:"tool"` message ids.
fn collect_openai_tool_id(message: &Value, ids: &mut Vec<String>) {
    let role = message.get("role").and_then(Value::as_str);
    if role == Some("tool")
        && let Some(id) = message.get("tool_call_id").and_then(Value::as_str)
    {
        ids.push(id.to_string());
    }
}

/// Collects Anthropic `tool_result` block ids.
fn collect_anthropic_tool_result_ids(message: &Value, ids: &mut Vec<String>) {
    let Some(content) = message.get("content").and_then(Value::as_array) else {
        return;
    };

    for block in content {
        if block.get("type").and_then(Value::as_str) == Some("tool_result")
            && let Some(id) = block.get("tool_use_id").and_then(Value::as_str)
        {
            ids.push(id.to_string());
        }
    }
}

/// Collects OpenAI Responses API `function_call_output` ids.
fn collect_openai_responses_tool_result_id(item: &Value, ids: &mut Vec<String>) {
    if item.get("type").and_then(Value::as_str) == Some("function_call_output")
        && let Some(id) = item.get("call_id").and_then(Value::as_str)
    {
        ids.push(id.to_string());
    }
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::extract_tool_result_ids;

    #[test]
    fn extracts_openai_responses_function_call_outputs() {
        let value = json!({
            "input": [
                {
                    "type": "function_call_output",
                    "call_id": "call_123",
                    "output": "ok"
                }
            ]
        });

        assert_eq!(extract_tool_result_ids(&value), vec!["call_123"]);
    }
}
