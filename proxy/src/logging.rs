//! ANSI-colored stdout logging for the proxy's request/response trace.
//!
//! Pure presentation: these helpers format the live console output an operator
//! sees; they hold no state and never affect the proxied bytes.

use std::io::Write;

use axum::http::{Method, StatusCode};

pub(crate) const RESET: &str = "\x1b[0m";
pub(crate) const BOLD: &str = "\x1b[1m";
pub(crate) const DIM: &str = "\x1b[2m";
pub(crate) const RED: &str = "\x1b[31m";
pub(crate) const GREEN: &str = "\x1b[32m";
pub(crate) const YELLOW: &str = "\x1b[33m";
pub(crate) const CYAN: &str = "\x1b[36m";

/// Logs an inbound request line plus the resolved model and last-message preview.
pub(crate) fn log_request(
    method: &Method,
    path: &str,
    label: &str,
    base: &str,
    model: &str,
    preview: &str,
) {
    println!("{BOLD}{CYAN}▶ {method} {path}{RESET}  {DIM}→ {label} ({base}){RESET}");
    println!("  {DIM}model:{RESET} {YELLOW}{model}{RESET}");
    println!("  {DIM}last :{RESET} {preview}");
    let _ = std::io::stdout().flush();
}

/// Logs an upstream response status, content type, and stream/buffer kind.
pub(crate) fn log_response(status: StatusCode, ctype: &str) {
    let color = if status.is_success() { GREEN } else { RED };
    let kind = if ctype.contains("event-stream") {
        "streaming"
    } else {
        "buffered"
    };
    let ctype = if ctype.is_empty() { "?" } else { ctype };
    println!("{color}◀ {status}{RESET}  {DIM}{ctype} · {kind}{RESET}\n");
    let _ = std::io::stdout().flush();
}

/// Logs a cache hit (replayed locally with zero upstream latency).
pub(crate) fn log_cached(status: StatusCode, bytes: usize) {
    println!("{YELLOW}◀ {status}{RESET}  {DIM}🟡 cache hit · {bytes} bytes · 0 ms · $0{RESET}\n");
    let _ = std::io::stdout().flush();
}
