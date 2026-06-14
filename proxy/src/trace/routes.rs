//! HTTP surface for traces: the `/api/sessions`, `/api/traces/current`, and
//! `/api/cache` routes plus their async handlers. Handlers stay thin — they hop
//! to a blocking worker and translate errors into HTTP responses.

use axum::{
    Json, Router,
    extract::{Query, State},
    http::{HeaderMap, StatusCode},
    routing::get,
};
use serde::Deserialize;

use loom_domain::{SessionListDto, TraceSessionDto, TraceSnapshot};

use super::query::{fetch_sessions, fetch_snapshot};
use super::sessions::create_session;
use crate::AppState;

#[derive(Deserialize)]
struct TraceQuery {
    session_id: Option<String>,
}

/// Mounts the trace/session/cache routes onto the proxy router.
pub(crate) fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/sessions",
            get(list_sessions).post(create_session_endpoint),
        )
        .route(
            "/api/traces/current",
            get(current_trace).delete(clear_trace),
        )
        .route("/api/cache", axum::routing::delete(clear_cache))
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
    Query(query): Query<TraceQuery>,
) -> Result<Json<TraceSnapshot>, (StatusCode, String)> {
    let db = state.db.clone();
    let session_id = query.session_id;
    let snapshot = tokio::task::spawn_blocking(move || fetch_snapshot(&db, session_id))
        .await
        .map_err(|error| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("trace worker failed: {error}"),
            )
        })?
        .map_err(|error| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("cannot load trace calls: {error}"),
            )
        })?;

    Ok(Json(snapshot))
}

async fn list_sessions(
    State(state): State<AppState>,
) -> Result<Json<SessionListDto>, (StatusCode, String)> {
    let db = state.db.clone();
    let response = tokio::task::spawn_blocking(move || fetch_sessions(&db))
        .await
        .map_err(|error| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("session worker failed: {error}"),
            )
        })?
        .map_err(|error| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("cannot load sessions: {error}"),
            )
        })?;

    Ok(Json(response))
}

async fn create_session_endpoint(
    State(state): State<AppState>,
) -> Result<(StatusCode, Json<TraceSessionDto>), (StatusCode, String)> {
    let db = state.db.clone();
    let session = tokio::task::spawn_blocking(move || {
        let conn = db.lock().expect("trace database lock poisoned");
        create_session(&conn, None)
    })
    .await
    .map_err(|error| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("session worker failed: {error}"),
        )
    })?
    .map_err(|error| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("cannot create session: {error}"),
        )
    })?;

    Ok((StatusCode::CREATED, Json(session)))
}

async fn clear_trace(State(state): State<AppState>) -> Result<StatusCode, (StatusCode, String)> {
    let db = state.db.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db.lock().map_err(|_| "trace database lock poisoned")?;
        conn.execute("DELETE FROM trace_calls", [])
            .map_err(|_| "cannot clear trace calls")?;
        conn.execute("DELETE FROM sessions", [])
            .map_err(|_| "cannot clear sessions")?;
        create_session(&conn, Some("Live Session")).map_err(|_| "cannot reset session")?;
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
