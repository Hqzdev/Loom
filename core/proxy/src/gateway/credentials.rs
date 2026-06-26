//! Provider credential injection for proxied requests.

use axum::http::{HeaderMap, HeaderName, HeaderValue};

use crate::{
    AppState, diagnostics,
    logging::{RED, RESET},
};

/// Injects local provider credentials only when the incoming request omitted them.
pub(super) fn inject(headers: &mut HeaderMap, label: &str, state: &AppState) {
    match label {
        "anthropic" if !headers.contains_key("x-api-key") => {
            insert_anthropic_key(headers, state);
        }
        "openai" if !headers.contains_key("authorization") => {
            insert_openai_key(headers, state);
        }
        _ => {}
    }
}

/// Inserts the Anthropic key header when a local key is configured.
fn insert_anthropic_key(headers: &mut HeaderMap, state: &AppState) {
    let Some(key) = state.anthropic_api_key.as_deref() else {
        return;
    };

    match HeaderValue::from_str(key) {
        Ok(value) => {
            headers.insert(HeaderName::from_static("x-api-key"), value);
        }
        Err(error) => {
            diagnostics::error(
                "provider_key_header_invalid",
                serde_json::json!({
                    "provider": "anthropic",
                    "error": error.to_string()
                }),
            );
            eprintln!("{RED}x invalid ANTHROPIC_API_KEY: {error}{RESET}\n");
        }
    }
}

/// Inserts the OpenAI authorization header when a local key is configured.
fn insert_openai_key(headers: &mut HeaderMap, state: &AppState) {
    let Some(key) = state.openai_api_key.as_deref() else {
        return;
    };

    match HeaderValue::from_str(&format!("Bearer {key}")) {
        Ok(value) => {
            headers.insert(HeaderName::from_static("authorization"), value);
        }
        Err(error) => {
            diagnostics::error(
                "provider_key_header_invalid",
                serde_json::json!({
                    "provider": "openai",
                    "error": error.to_string()
                }),
            );
            eprintln!("{RED}x invalid OPENAI_API_KEY: {error}{RESET}\n");
        }
    }
}
