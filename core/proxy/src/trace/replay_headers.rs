//! Header filtering and credential injection for replay requests.

use axum::http::{HeaderMap, HeaderName, HeaderValue};

use crate::AppState;

/// Copies only replay-safe incoming headers.
pub(super) fn filtered_replay_headers(headers: &HeaderMap) -> HeaderMap {
    let mut forward_headers = HeaderMap::new();
    for (name, value) in headers.iter() {
        if is_forbidden_replay_header(name) {
            continue;
        }
        forward_headers.insert(name.clone(), value.clone());
    }
    forward_headers
}

/// Injects configured provider credentials when replay headers omitted them.
pub(super) fn inject_replay_credentials(headers: &mut HeaderMap, provider: &str, state: &AppState) {
    match provider {
        "anthropic" if !headers.contains_key("x-api-key") => {
            let Some(key) = state.anthropic_api_key.as_deref() else {
                return;
            };
            if let Ok(value) = HeaderValue::from_str(key) {
                headers.insert(HeaderName::from_static("x-api-key"), value);
            }
        }
        "openai" if !headers.contains_key("authorization") => {
            let Some(key) = state.openai_api_key.as_deref() else {
                return;
            };
            if let Ok(value) = HeaderValue::from_str(&format!("Bearer {key}")) {
                headers.insert(HeaderName::from_static("authorization"), value);
            }
        }
        _ => {}
    }
}

/// Returns whether a request header should never be forwarded during replay.
fn is_forbidden_replay_header(name: &HeaderName) -> bool {
    matches!(
        name.as_str(),
        "host"
            | "content-length"
            | "connection"
            | "keep-alive"
            | "transfer-encoding"
            | "upgrade"
            | "te"
            | "trailer"
            | "proxy-connection"
    )
}
