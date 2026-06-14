//! Write path: turn a capture + outcome into a `trace_calls` row and persist it.

use std::sync::{Arc, Mutex};

use rusqlite::{Connection, OptionalExtension, params};

use super::capture::TraceCapture;
use super::cost::estimate_cost;
use super::sessions::ensure_current_session;
use super::summarize::summarize_response;
use super::text::utf8_preview;

/// One persisted trace call — the in-memory mirror of a `trace_calls` row.
pub(super) struct TraceRow {
    pub(super) id: String,
    pub(super) created_at: i64,
    pub(super) provider: String,
    pub(super) method: String,
    pub(super) path: String,
    pub(super) model: String,
    pub(super) status_code: i64,
    pub(super) cache_status: String,
    pub(super) latency_ms: i64,
    pub(super) request_id: String,
    pub(super) prompt_system: String,
    pub(super) prompt_user: String,
    pub(super) response_text: String,
    pub(super) response_language: String,
    pub(super) error_code: Option<String>,
    pub(super) error_message: Option<String>,
    pub(super) error_detail: Option<String>,
    pub(super) tokens_in: i64,
    pub(super) tokens_out: i64,
    pub(super) cost: String,
    pub(super) temperature: Option<f64>,
    pub(super) trace_id: String,
    pub(super) parent_span_id: Option<String>,
    pub(super) tool_use_ids: String,
    pub(super) context_inputs: String,
    pub(super) input_hash: String,
    pub(super) stale: bool,
    pub(super) request_body: Vec<u8>,
    pub(super) request_target: String,
    pub(super) tool_result_ids: Vec<String>,
}

/// Records a completed (or cached) response against its originating capture.
pub(crate) fn record_response(
    db: &Arc<Mutex<Connection>>,
    capture: &TraceCapture,
    status_code: u16,
    content_type: &str,
    header_request_id: Option<&str>,
    body: &[u8],
    cache_status: &str,
    latency_ms: i64,
) {
    let summary = summarize_response(content_type, body);
    let is_error = !(200..=299).contains(&status_code);
    let status = if cache_status == "hit" {
        "cached"
    } else if is_error {
        "error"
    } else {
        "success"
    };
    let request_id = header_request_id
        .map(ToOwned::to_owned)
        .or(summary.request_id)
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| capture.request_id.clone());

    let cost = estimate_cost(
        &capture.provider,
        &capture.model,
        summary.tokens_in,
        summary.tokens_out,
    );
    let tool_use_ids =
        serde_json::to_string(&summary.tool_use_ids).unwrap_or_else(|_| "[]".to_string());

    let row = TraceRow {
        id: capture.id.clone(),
        created_at: capture.created_at,
        provider: capture.provider.clone(),
        method: capture.method.clone(),
        path: capture.path.clone(),
        model: capture.model.clone(),
        status_code: i64::from(status_code),
        cache_status: cache_status.to_string(),
        latency_ms,
        request_id,
        prompt_system: capture.prompt_system.clone(),
        prompt_user: capture.prompt_user.clone(),
        response_text: summary.text,
        response_language: summary.language,
        error_code: is_error.then(|| status_code.to_string()),
        error_message: is_error.then(|| format!("Upstream returned HTTP {status_code}")),
        error_detail: is_error.then(|| utf8_preview(body)),
        tokens_in: summary.tokens_in,
        tokens_out: summary.tokens_out,
        cost,
        temperature: capture.temperature,
        trace_id: String::new(),
        parent_span_id: None,
        tool_use_ids,
        context_inputs: capture.context_inputs.clone(),
        input_hash: capture.input_hash.clone(),
        stale: false,
        request_body: capture.request_body.clone(),
        request_target: capture.request_target.clone(),
        tool_result_ids: capture.tool_result_ids.clone(),
    };

    insert_trace_row(db, row, status);
}

/// Records a failed upstream call (network error / dropped stream) as an error node.
pub(crate) fn record_upstream_error(
    db: &Arc<Mutex<Connection>>,
    capture: &TraceCapture,
    message: &str,
    latency_ms: i64,
) {
    let row = TraceRow {
        id: capture.id.clone(),
        created_at: capture.created_at,
        provider: capture.provider.clone(),
        method: capture.method.clone(),
        path: capture.path.clone(),
        model: capture.model.clone(),
        status_code: 502,
        cache_status: "miss".to_string(),
        latency_ms,
        request_id: capture.request_id.clone(),
        prompt_system: capture.prompt_system.clone(),
        prompt_user: capture.prompt_user.clone(),
        response_text: String::new(),
        response_language: "text".to_string(),
        error_code: Some("UPSTREAM_ERROR".to_string()),
        error_message: Some(message.to_string()),
        error_detail: Some(message.to_string()),
        tokens_in: 0,
        tokens_out: 0,
        cost: "$0.0000".to_string(),
        temperature: capture.temperature,
        trace_id: String::new(),
        parent_span_id: None,
        tool_use_ids: "[]".to_string(),
        context_inputs: capture.context_inputs.clone(),
        input_hash: capture.input_hash.clone(),
        stale: false,
        request_body: capture.request_body.clone(),
        request_target: capture.request_target.clone(),
        tool_result_ids: capture.tool_result_ids.clone(),
    };

    insert_trace_row(db, row, "error");
}

/// Inserts a row under the current session. Best-effort: logs and returns on failure.
fn insert_trace_row(db: &Arc<Mutex<Connection>>, row: TraceRow, status: &str) {
    if let Ok(conn) = db.lock() {
        let session = match ensure_current_session(&conn) {
            Ok(session) => session,
            Err(error) => {
                eprintln!("  cannot resolve trace session: {error}");
                return;
            }
        };

        let (trace_id, parent_span_id) = resolve_lineage(&conn, &row.id, &row.tool_result_ids);

        let _ = conn.execute(
            "INSERT OR REPLACE INTO trace_calls
                (id, session_id, created_at, provider, method, path, model, status_code, cache_status,
                 latency_ms, request_id, prompt_system, prompt_user, response_text,
                 response_language, error_code, error_message, error_detail, tokens_in,
                 tokens_out, cost, temperature, trace_id, parent_span_id, tool_use_ids,
                 context_inputs, input_hash, stale, request_body, request_target)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14,
                     ?15, ?16, ?17, ?18, ?19, ?20, ?21, ?22, ?23, ?24, ?25, ?26,
                     ?27, ?28, ?29, ?30)",
            params![
                row.id,
                session.id,
                row.created_at,
                row.provider,
                row.method,
                row.path,
                row.model,
                row.status_code,
                row.cache_status,
                row.latency_ms,
                row.request_id,
                row.prompt_system,
                row.prompt_user,
                row.response_text,
                row.response_language,
                row.error_code,
                row.error_message,
                row.error_detail,
                row.tokens_in,
                row.tokens_out,
                row.cost,
                row.temperature,
                trace_id,
                parent_span_id,
                row.tool_use_ids,
                row.context_inputs,
                row.input_hash,
                row.stale as i64,
                row.request_body,
                row.request_target,
            ],
        );
        println!("  captured trace node: {status}");
    }
}

/// Finds the parent span by matching request `tool_result` ids to prior
/// response `tool_use` ids. Missing matches root a new trace at `own_id`.
fn resolve_lineage(
    conn: &Connection,
    own_id: &str,
    tool_result_ids: &[String],
) -> (String, Option<String>) {
    for tool_use_id in tool_result_ids {
        if let Some((parent_id, parent_trace_id)) = find_parent_span(conn, tool_use_id) {
            let trace_id = if parent_trace_id.is_empty() {
                parent_id.clone()
            } else {
                parent_trace_id
            };
            return (trace_id, Some(parent_id));
        }
    }
    (own_id.to_string(), None)
}

fn find_parent_span(conn: &Connection, tool_use_id: &str) -> Option<(String, String)> {
    conn.query_row(
        "SELECT id, COALESCE(trace_id, '')
         FROM trace_calls
         WHERE tool_use_ids LIKE ?1
         ORDER BY created_at DESC
         LIMIT 1",
        [format!("%\"{tool_use_id}\"%")],
        |row| Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?)),
    )
    .optional()
    .ok()
    .flatten()
}
