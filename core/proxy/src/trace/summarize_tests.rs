//! Tests for response body summarization.

use super::summarize::summarize_response;

/// Verifies OpenAI chat-completion text, request id, and token extraction.
#[test]
fn summarizes_openai_chat_completion_shape() {
    let body = br#"{
        "id":"chatcmpl-1",
        "choices":[{"message":{"content":"Hello from OpenAI"}}],
        "usage":{"prompt_tokens":11,"completion_tokens":7}
    }"#;

    let summary = summarize_response("application/json", body);

    assert_eq!(summary.request_id.as_deref(), Some("chatcmpl-1"));
    assert_eq!(summary.text, "Hello from OpenAI");
    assert_eq!(summary.language, "json");
    assert_eq!(summary.tokens_in, 11);
    assert_eq!(summary.tokens_out, 7);
    assert!(summary.tool_use_ids.is_empty());
}

/// Verifies Anthropic message text and input/output token extraction.
#[test]
fn summarizes_anthropic_message_shape() {
    let body = br#"{
        "id":"msg_1",
        "content":[{"type":"text","text":"Hello from Claude"}],
        "usage":{"input_tokens":19,"output_tokens":5}
    }"#;

    let summary = summarize_response("application/json", body);

    assert_eq!(summary.request_id.as_deref(), Some("msg_1"));
    assert_eq!(summary.text, "Hello from Claude");
    assert_eq!(summary.tokens_in, 19);
    assert_eq!(summary.tokens_out, 5);
}

/// Verifies non-JSON bodies fall back to capped text without token counts.
#[test]
fn summarizes_plain_text_fallback_without_tokens() {
    let summary = summarize_response("text/plain", b"plain response");

    assert_eq!(summary.request_id, None);
    assert_eq!(summary.text, "plain response");
    assert_eq!(summary.language, "text");
    assert_eq!(summary.tokens_in, 0);
    assert_eq!(summary.tokens_out, 0);
}
