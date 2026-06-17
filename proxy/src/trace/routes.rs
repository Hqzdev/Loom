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
use crate::AppState;

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
        .route("/api/cache", delete(clear_cache))
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

async fn current_trace(
    State(state): State<AppState>,
) -> Result<Json<TraceSnapshot>, (StatusCode, String)> {
    let db = state.db.clone();
    let snapshot = tokio::task::spawn_blocking(move || fetch_snapshot(&db))
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
) -> Result<Json<TraceSnapshot>, (StatusCode, String)> {
    let db = state.db.clone();
    let snapshot = tokio::task::spawn_blocking(move || fetch_snapshot_summary(&db))
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
    axum::extract::Path(node_id): axum::extract::Path<String>,
) -> Result<Json<AgentNodeDto>, (StatusCode, String)> {
    let db = state.db.clone();
    let node = tokio::task::spawn_blocking(move || fetch_node_detail(&db, node_id))
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

async fn clear_trace(State(state): State<AppState>) -> Result<StatusCode, (StatusCode, String)> {
    let db = state.db.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db.lock().map_err(|_| "trace database lock poisoned")?;
        conn.execute("DELETE FROM trace_calls", [])
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
