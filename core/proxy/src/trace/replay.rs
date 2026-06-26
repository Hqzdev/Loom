//! Trace replay and invalidation endpoints.

use axum::{
    Json,
    extract::{Path, State},
    http::{HeaderMap, StatusCode, header::CONTENT_TYPE},
};

use super::cost::estimate_cost;
use super::replay_headers::{filtered_replay_headers, inject_replay_credentials};
use super::replay_store::{
    downstream_result, edit_output_result, load_replay_spec, map_node_error, persist_replay_result,
};
use super::replay_types::{EditOutputRequest, ReplayResult, ReplayUpdate};
use super::routes::{response_request_id, workspace_id_from_headers};
use super::summarize::summarize_response;
use super::text::now_millis;
use crate::AppState;

/// Edits a span's output and marks transitive descendants stale.
pub(super) async fn edit_output(
    State(state): State<AppState>,
    Path(id): Path<String>,
    headers: HeaderMap,
    Json(payload): Json<EditOutputRequest>,
) -> Result<Json<super::replay_types::InvalidationResult>, (StatusCode, String)> {
    let db = state.db.clone();
    let workspace_id = workspace_id_from_headers(&headers)?;
    let result = tokio::task::spawn_blocking(move || {
        let conn = db
            .lock()
            .map_err(|_| "trace database lock poisoned".to_string())?;
        edit_output_result(&conn, &workspace_id, id, payload.output)
    })
    .await
    .map_err(worker_error)?
    .map_err(map_node_error)?;

    Ok(Json(result))
}

/// Returns the spans that would be invalidated if this node changed.
pub(super) async fn list_downstream(
    State(state): State<AppState>,
    Path(id): Path<String>,
    headers: HeaderMap,
) -> Result<Json<super::replay_types::DownstreamResult>, (StatusCode, String)> {
    let db = state.db.clone();
    let workspace_id = workspace_id_from_headers(&headers)?;
    let result = tokio::task::spawn_blocking(move || {
        let conn = db
            .lock()
            .map_err(|_| "trace database lock poisoned".to_string())?;
        downstream_result(&conn, &workspace_id, id)
    })
    .await
    .map_err(worker_error)?
    .map_err(map_node_error)?;

    Ok(Json(result))
}

/// Re-runs a retained request body against the original provider target.
pub(super) async fn replay_node(
    State(state): State<AppState>,
    Path(id): Path<String>,
    headers: HeaderMap,
) -> Result<Json<ReplayResult>, (StatusCode, String)> {
    let workspace_id = workspace_id_from_headers(&headers)?;
    let spec = load_spec_for_node(&state, &workspace_id, &id).await?;
    if spec.body.is_empty() {
        return Err((
            StatusCode::CONFLICT,
            "node is not replayable (request body was not retained)".to_string(),
        ));
    }

    let mut forward_headers = filtered_replay_headers(&headers);
    inject_replay_credentials(&mut forward_headers, &spec.provider, &state);

    let url = format!("{}{}", replay_base_url(&state, &spec.provider), spec.target);
    let method =
        reqwest::Method::from_bytes(spec.method.as_bytes()).unwrap_or(reqwest::Method::POST);
    let started = now_millis();
    let response = state
        .client
        .request(method, &url)
        .headers(forward_headers)
        .body(spec.body)
        .send()
        .await
        .map_err(|error| {
            (
                StatusCode::BAD_GATEWAY,
                format!("replay upstream error: {error}"),
            )
        })?;

    let status_code = response.status().as_u16();
    let content_type = response_content_type(response.headers());
    let header_request_id = response_request_id(response.headers());
    let body = response.bytes().await.map_err(|error| {
        (
            StatusCode::BAD_GATEWAY,
            format!("replay read error: {error}"),
        )
    })?;
    let latency_ms = (now_millis() - started).max(0);

    let summary = summarize_response(&content_type, &body);
    let cost = estimate_cost(
        &spec.provider,
        &spec.model,
        summary.tokens_in,
        summary.tokens_out,
    );
    let request_id = replay_request_id(header_request_id, summary.request_id.clone());
    let result = persist_replay_update(
        &state,
        ReplayUpdate::from_summary(id, status_code, latency_ms, cost, request_id, summary),
        workspace_id,
    )
    .await?;

    Ok(Json(result))
}

/// Loads replay metadata for a node on a blocking SQLite worker.
async fn load_spec_for_node(
    state: &AppState,
    workspace_id: &str,
    id: &str,
) -> Result<super::replay_types::ReplaySpec, (StatusCode, String)> {
    let db = state.db.clone();
    let lookup_id = id.to_string();
    let workspace_id = workspace_id.to_string();
    tokio::task::spawn_blocking(move || {
        let conn = db
            .lock()
            .map_err(|_| "trace database lock poisoned".to_string())?;
        load_replay_spec(&conn, &workspace_id, &lookup_id)
    })
    .await
    .map_err(worker_error)?
    .map_err(map_node_error)
}

/// Persists replay output on a blocking SQLite worker.
async fn persist_replay_update(
    state: &AppState,
    update: ReplayUpdate,
    workspace_id: String,
) -> Result<ReplayResult, (StatusCode, String)> {
    let db = state.db.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db
            .lock()
            .map_err(|_| "trace database lock poisoned".to_string())?;
        persist_replay_result(&conn, &workspace_id, update)
    })
    .await
    .map_err(worker_error)?
    .map_err(map_node_error)
}

/// Maps blocking worker join errors into API errors.
pub(super) fn worker_error(error: tokio::task::JoinError) -> (StatusCode, String) {
    (
        StatusCode::INTERNAL_SERVER_ERROR,
        format!("worker failed: {error}"),
    )
}

/// Returns the configured upstream base URL for a replay provider.
fn replay_base_url(state: &AppState, provider: &str) -> String {
    if provider == "anthropic" {
        state.anthropic_upstream.to_string()
    } else {
        state.openai_upstream.to_string()
    }
}

/// Extracts the content type from an upstream response header map.
pub(super) fn response_content_type(headers: &HeaderMap) -> String {
    headers
        .get(CONTENT_TYPE)
        .and_then(|value| value.to_str().ok())
        .unwrap_or("")
        .to_string()
}

/// Picks the replay request id from headers, body summary, or a placeholder.
pub(super) fn replay_request_id(
    header_request_id: Option<String>,
    summary_request_id: Option<String>,
) -> String {
    header_request_id
        .or(summary_request_id)
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| "-".to_string())
}
