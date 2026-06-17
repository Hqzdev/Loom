//! Leaf string/JSON/time helpers shared across the trace submodules.
//!
//! Everything here is pure (no I/O, no other trace-module dependencies), so it
//! can be reused freely and reasoned about in isolation.

use chrono::{DateTime, Local, TimeZone};
use serde_json::Value;

/// Truncates `text` to `max_chars` characters, appending `…` if it was cut.
pub(super) fn cap_text(text: &str, max_chars: usize) -> String {
    if text.chars().count() <= max_chars {
        return text.to_string();
    }

    let mut capped = text.chars().take(max_chars).collect::<String>();
    capped.push('…');
    capped
}

/// Collapses all whitespace runs to single spaces, then caps the length.
pub(super) fn truncate_one_line(text: &str, max_chars: usize) -> String {
    let one_line = text.split_whitespace().collect::<Vec<_>>().join(" ");
    cap_text(&one_line, max_chars)
}

/// Lossy UTF-8 rendering of an arbitrary byte body, capped for storage.
pub(super) fn utf8_preview(body: &[u8]) -> String {
    cap_text(&String::from_utf8_lossy(body), 64_000)
}

/// Pretty-prints a JSON value, falling back to its compact form.
pub(super) fn pretty_json(value: &Value) -> String {
    serde_json::to_string_pretty(value).unwrap_or_else(|_| value.to_string())
}

/// Flattens a message `content` field (string or array of parts) to plain text.
pub(super) fn content_to_string(content: &Value) -> String {
    match content {
        Value::String(text) => text.clone(),
        Value::Array(items) => items
            .iter()
            .map(|item| {
                item.get("text")
                    .and_then(Value::as_str)
                    .map(ToOwned::to_owned)
                    .or_else(|| item.as_str().map(ToOwned::to_owned))
                    .unwrap_or_else(|| item.to_string())
            })
            .collect::<Vec<_>>()
            .join(" "),
        other => other.to_string(),
    }
}

/// Reduces a request path to its last non-empty segment (e.g. `completions`).
pub(super) fn compact_path(path: &str) -> String {
    path.trim_start_matches('/')
        .rsplit('/')
        .next()
        .filter(|segment| !segment.is_empty())
        .unwrap_or(path)
        .to_string()
}

/// Formats a latency in milliseconds as `123ms` or `1.23s`.
pub(super) fn format_latency(milliseconds: i64) -> String {
    if milliseconds >= 1_000 {
        format!("{:.2}s", milliseconds as f64 / 1_000.0)
    } else {
        format!("{milliseconds}ms")
    }
}

/// Formats an epoch-millis instant as a local `HH:MM:SS` wall-clock string.
pub(super) fn format_timestamp(milliseconds: i64) -> String {
    local_time(milliseconds).format("%H:%M:%S").to_string()
}

fn local_time(milliseconds: i64) -> DateTime<Local> {
    let seconds = milliseconds.div_euclid(1_000);
    let nanos = milliseconds.rem_euclid(1_000) as u32 * 1_000_000;
    Local
        .timestamp_opt(seconds, nanos)
        .single()
        .unwrap_or_else(Local::now)
}

/// Current time in epoch milliseconds (0 if the clock is before the epoch).
pub(super) fn now_millis() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|duration| duration.as_millis() as i64)
        .unwrap_or(0)
}
