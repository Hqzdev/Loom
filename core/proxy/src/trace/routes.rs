//! HTTP surface for traces: the `/api/traces/current` and `/api/cache` routes
//! plus their async handlers. Handlers stay thin — they hop to a blocking worker
//! and translate errors into HTTP responses.

use axum::{
    Json, Router,
    extract::State,
    http::{HeaderMap, StatusCode},
    routing::{delete, get, patch, post},
};

use tether_domain::{AgentNodeDto, TraceSnapshot};

use super::query::{fetch_node_detail, fetch_snapshot, fetch_snapshot_summary};
use super::replay::{edit_output, list_downstream, replay_node};
use super::replay_with::replay_with_model;
use super::store_insert::insert_trace_row;
use super::store_row::TraceRow;
use crate::AppState;
use serde::Deserialize;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

/// Mounts the trace and cache routes onto the proxy router.
pub(crate) fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/traces/current",
            get(current_trace).delete(clear_trace),
        )
        .route("/api/traces/current/summary", get(current_trace_summary))
        .route("/api/traces/{id}", get(trace_node_detail))
        .route("/api/traces/{id}/output", patch(edit_output))
        .route("/api/traces/{id}/downstream", get(list_downstream))
        .route("/api/traces/{id}/replay", post(replay_node))
        .route("/api/traces/{id}/replay-with", post(replay_with_model))
        .route("/api/events", post(capture_event))
        .route("/api/events/health", get(events_health))
        .route("/api/cache", delete(clear_cache))
}

#[derive(Deserialize)]
struct CaptureEvent {
    event_id: String,
    event_type: String,
    session_id: String,
    command: Vec<String>,
    command_line: String,
    cwd: String,
    started_at_ms: i64,
    ended_at_ms: i64,
    exit_code: Option<i32>,
    stdout: String,
    stderr: String,
    git_base_revision: Option<String>,
    git_diff_before: String,
    git_diff_after: String,
}

/// Extracts the upstream request id from any of the known provider headers.
pub(crate) fn response_request_id(headers: &HeaderMap) -> Option<String> {
    [
        "x-request-id",
        "request-id",
        "openai-request-id",
        "anthropic-request-id",
    ]
    .iter()
    .find_map(|name| {
        headers
            .get(*name)
            .and_then(|value| value.to_str().ok())
            .map(ToOwned::to_owned)
    })
}

async fn capture_event(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(event): Json<CaptureEvent>,
) -> Result<StatusCode, (StatusCode, String)> {
    let workspace_id = workspace_id_from_headers(&headers)?;
    let status_code = match event.exit_code {
        Some(0) => 200,
        Some(code) => 500 + i64::from(code.clamp(0, 99)),
        None => 500,
    };
    let latency_ms = (event.ended_at_ms - event.started_at_ms).max(0);
    let response_text = command_output_text(&event.stdout, &event.stderr);
    let context_inputs = event_context(&event, latency_ms);
    let input_hash = hash_text(&format!(
        "{}\n{}\n{}",
        event.command_line, event.git_diff_before, event.git_diff_after
    ));
    let row = TraceRow {
        id: event.event_id.clone(),
        created_at: event.started_at_ms / 1000,
        provider: "tether".to_string(),
        method: "EXEC".to_string(),
        path: event.event_type.clone(),
        model: "shell".to_string(),
        status_code,
        cache_status: "captured".to_string(),
        latency_ms,
        request_id: event.session_id.clone(),
        prompt_system: "Captured by tether capture".to_string(),
        prompt_user: event.command_line.clone(),
        response_text,
        response_language: "text".to_string(),
        error_code: (status_code >= 400).then(|| event.exit_code.unwrap_or(-1).to_string()),
        error_message: (status_code >= 400).then(|| "Command failed".to_string()),
        error_detail: (status_code >= 400).then(|| event.stderr.clone()),
        tokens_in: 0,
        tokens_out: 0,
        cost: "$0.0000".to_string(),
        temperature: None,
        trace_id: event.event_id.clone(),
        parent_span_id: None,
        tool_use_ids: "[]".to_string(),
        context_inputs,
        input_hash,
        stale: false,
        is_replay: false,
        replay_source_id: None,
        replay_provider: None,
        request_body: serde_json::to_vec(&event_context_value(&event, latency_ms))
            .unwrap_or_default(),
        request_target: event.command_line.clone(),
        workspace_id,
        tool_result_ids: Vec::new(),
    };

    insert_trace_row(&state.db, row, "event");
    Ok(StatusCode::ACCEPTED)
}

async fn events_health() -> StatusCode {
    StatusCode::NO_CONTENT
}

fn command_output_text(stdout: &str, stderr: &str) -> String {
    match (stdout.is_empty(), stderr.is_empty()) {
        (true, true) => String::new(),
        (false, true) => stdout.to_string(),
        (true, false) => stderr.to_string(),
        (false, false) => format!("{stdout}\n\nSTDERR:\n{stderr}"),
    }
}

fn event_context(event: &CaptureEvent, latency_ms: i64) -> String {
    serde_json::to_string(&event_context_value(event, latency_ms)).unwrap_or_else(|_| "{}".into())
}

fn event_context_value(event: &CaptureEvent, latency_ms: i64) -> Value {
    json!({
        "event_type": &event.event_type,
        "session_id": &event.session_id,
        "command": &event.command,
        "cwd": &event.cwd,
        "started_at_ms": event.started_at_ms,
        "ended_at_ms": event.ended_at_ms,
        "latency_ms": latency_ms,
        "exit_code": event.exit_code,
        "git_base_revision": &event.git_base_revision,
        "git_diff_before": &event.git_diff_before,
        "git_diff_after": &event.git_diff_after
    })
}

fn hash_text(value: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(value.as_bytes());
    format!("{:x}", hasher.finalize())
}

async fn current_trace(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<TraceSnapshot>, (StatusCode, String)> {
    let db = state.db.clone();
    let workspace_id = workspace_id_from_headers(&headers)?;
    let snapshot = tokio::task::spawn_blocking(move || fetch_snapshot(&db, &workspace_id))
        .await
        .map_err(|error| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("trace worker failed: {error}"),
            )
        })?
        .map_err(|error| trace_query_error("cannot load trace calls", error))?;

    Ok(Json(snapshot))
}

async fn current_trace_summary(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<TraceSnapshot>, (StatusCode, String)> {
    let db = state.db.clone();
    let workspace_id = workspace_id_from_headers(&headers)?;
    let snapshot = tokio::task::spawn_blocking(move || fetch_snapshot_summary(&db, &workspace_id))
        .await
        .map_err(|error| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("trace summary worker failed: {error}"),
            )
        })?
        .map_err(|error| trace_query_error("cannot load trace summary", error))?;

    Ok(Json(snapshot))
}

async fn trace_node_detail(
    State(state): State<AppState>,
    headers: HeaderMap,
    axum::extract::Path(node_id): axum::extract::Path<String>,
) -> Result<Json<AgentNodeDto>, (StatusCode, String)> {
    let db = state.db.clone();
    let workspace_id = workspace_id_from_headers(&headers)?;
    let node = tokio::task::spawn_blocking(move || fetch_node_detail(&db, &workspace_id, node_id))
        .await
        .map_err(|error| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("trace detail worker failed: {error}"),
            )
        })?
        .map_err(|error| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("cannot load trace node detail: {error}"),
            )
        })?
        .ok_or_else(|| (StatusCode::NOT_FOUND, "trace node not found".to_string()))?;

    Ok(Json(node))
}

/// Converts query errors into the HTTP surface.
fn trace_query_error(context: &str, error: rusqlite::Error) -> (StatusCode, String) {
    (
        StatusCode::INTERNAL_SERVER_ERROR,
        format!("{context}: {error}"),
    )
}

async fn clear_trace(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<StatusCode, (StatusCode, String)> {
    let db = state.db.clone();
    let workspace_id = workspace_id_from_headers(&headers)?;
    tokio::task::spawn_blocking(move || {
        let conn = db.lock().map_err(|_| "trace database lock poisoned")?;
        conn.execute(
            "DELETE FROM trace_calls WHERE workspace_id = ?1",
            [workspace_id],
        )
        .map_err(|_| "cannot clear trace calls")?;
        Ok::<_, &'static str>(())
    })
    .await
    .map_err(|error| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("trace worker failed: {error}"),
        )
    })?
    .map_err(|error| (StatusCode::INTERNAL_SERVER_ERROR, error.to_string()))?;

    Ok(StatusCode::NO_CONTENT)
}

pub(super) fn workspace_id_from_headers(
    headers: &HeaderMap,
) -> Result<String, (StatusCode, String)> {
    crate::workspace::from_headers(headers).map_err(|message| (StatusCode::UNAUTHORIZED, message))
}

async fn clear_cache(State(state): State<AppState>) -> Result<StatusCode, (StatusCode, String)> {
    let db = state.db.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db.lock().map_err(|_| "cache database lock poisoned")?;
        conn.execute("DELETE FROM cache", [])
            .map_err(|_| "cannot clear cache")?;
        Ok::<_, &'static str>(())
    })
    .await
    .map_err(|error| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("cache worker failed: {error}"),
        )
    })?
    .map_err(|error| (StatusCode::INTERNAL_SERVER_ERROR, error.to_string()))?;

    Ok(StatusCode::NO_CONTENT)
}
