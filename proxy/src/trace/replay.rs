//! Trace replay and invalidation endpoints.

use axum::{
    Json,
    extract::{Path, State},
    http::{HeaderMap, HeaderName, HeaderValue, StatusCode, header::CONTENT_TYPE},
};
use rusqlite::{Connection, OptionalExtension, params};
use serde::{Deserialize, Serialize};

use super::cost::estimate_cost;
use super::routes::response_request_id;
use super::summarize::summarize_response;
use super::text::now_millis;
use crate::AppState;

#[derive(Deserialize)]
pub(super) struct EditOutputRequest {
    output: String,
}

#[derive(Serialize)]
pub(super) struct InvalidationResult {
    node_id: String,
    invalidated: Vec<String>,
}

#[derive(Serialize)]
pub(super) struct DownstreamResult {
    node_id: String,
    downstream: Vec<String>,
}

#[derive(Serialize)]
pub(super) struct ReplayResult {
    node_id: String,
    status_code: u16,
    cost: String,
    tokens_in: i64,
    tokens_out: i64,
    invalidated: Vec<String>,
}

struct ReplaySpec {
    method: String,
    provider: String,
    target: String,
    model: String,
    session_id: String,
    body: Vec<u8>,
}

/// Edits a span's output and marks transitive descendants stale.
pub(super) async fn edit_output(
    State(state): State<AppState>,
    Path(id): Path<String>,
    Json(payload): Json<EditOutputRequest>,
) -> Result<Json<InvalidationResult>, (StatusCode, String)> {
    let db = state.db.clone();
    let result = tokio::task::spawn_blocking(move || {
        let conn = db
            .lock()
            .map_err(|_| "trace database lock poisoned".to_string())?;
        let session_id = node_session_id(&conn, &id)?;
        conn.execute(
            "UPDATE trace_calls SET response_text = ?1 WHERE id = ?2",
            params![payload.output, id],
        )
        .map_err(|error| error.to_string())?;
        let invalidated = descendants(&conn, &session_id, &id).map_err(|e| e.to_string())?;
        mark_stale(&conn, &invalidated).map_err(|e| e.to_string())?;
        Ok::<_, String>(InvalidationResult {
            node_id: id,
            invalidated,
        })
    })
    .await
    .map_err(|error| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("worker failed: {error}"),
        )
    })?
    .map_err(map_node_error)?;

    Ok(Json(result))
}

/// Returns the spans that would be invalidated if this node changed.
pub(super) async fn list_downstream(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<Json<DownstreamResult>, (StatusCode, String)> {
    let db = state.db.clone();
    let result = tokio::task::spawn_blocking(move || {
        let conn = db
            .lock()
            .map_err(|_| "trace database lock poisoned".to_string())?;
        let session_id = node_session_id(&conn, &id)?;
        let downstream = descendants(&conn, &session_id, &id).map_err(|e| e.to_string())?;
        Ok::<_, String>(DownstreamResult {
            node_id: id,
            downstream,
        })
    })
    .await
    .map_err(|error| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("worker failed: {error}"),
        )
    })?
    .map_err(map_node_error)?;

    Ok(Json(result))
}

/// Re-runs a retained request body against the original provider target.
pub(super) async fn replay_node(
    State(state): State<AppState>,
    Path(id): Path<String>,
    headers: HeaderMap,
) -> Result<Json<ReplayResult>, (StatusCode, String)> {
    let db = state.db.clone();
    let lookup_id = id.clone();
    let spec = tokio::task::spawn_blocking(move || {
        let conn = db
            .lock()
            .map_err(|_| "trace database lock poisoned".to_string())?;
        load_replay_spec(&conn, &lookup_id)
    })
    .await
    .map_err(|error| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("worker failed: {error}"),
        )
    })?
    .map_err(map_node_error)?;

    if spec.body.is_empty() {
        return Err((
            StatusCode::CONFLICT,
            "node is not replayable (request body was not retained)".to_string(),
        ));
    }

    let base = if spec.provider == "anthropic" {
        state.anthropic_upstream.clone()
    } else {
        state.openai_upstream.clone()
    };
    let url = format!("{base}{}", spec.target);
    let method =
        reqwest::Method::from_bytes(spec.method.as_bytes()).unwrap_or(reqwest::Method::POST);

    let mut forward_headers = HeaderMap::new();
    for (name, value) in headers.iter() {
        if is_forbidden_replay_header(name) {
            continue;
        }
        forward_headers.insert(name.clone(), value.clone());
    }
    inject_replay_credentials(&mut forward_headers, &spec.provider, &state);

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
    let content_type = response
        .headers()
        .get(CONTENT_TYPE)
        .and_then(|value| value.to_str().ok())
        .unwrap_or("")
        .to_string();
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
    let tool_use_ids =
        serde_json::to_string(&summary.tool_use_ids).unwrap_or_else(|_| "[]".to_string());
    let request_id = header_request_id
        .or_else(|| summary.request_id.clone())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| "-".to_string());

    let db = state.db.clone();
    let session_id = spec.session_id.clone();
    let result = tokio::task::spawn_blocking(move || {
        let conn = db
            .lock()
            .map_err(|_| "trace database lock poisoned".to_string())?;
        conn.execute(
            "UPDATE trace_calls
             SET response_text = ?1, response_language = ?2, tokens_in = ?3, tokens_out = ?4,
                 cost = ?5, status_code = ?6, latency_ms = ?7, cache_status = 'miss',
                 tool_use_ids = ?8, request_id = ?9, stale = 0
             WHERE id = ?10",
            params![
                summary.text,
                summary.language,
                summary.tokens_in,
                summary.tokens_out,
                cost,
                i64::from(status_code),
                latency_ms,
                tool_use_ids,
                request_id,
                id,
            ],
        )
        .map_err(|error| error.to_string())?;
        let invalidated = descendants(&conn, &session_id, &id).map_err(|e| e.to_string())?;
        mark_stale(&conn, &invalidated).map_err(|e| e.to_string())?;
        Ok::<_, String>(ReplayResult {
            node_id: id,
            status_code,
            cost,
            tokens_in: summary.tokens_in,
            tokens_out: summary.tokens_out,
            invalidated,
        })
    })
    .await
    .map_err(|error| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("worker failed: {error}"),
        )
    })?
    .map_err(map_node_error)?;

    Ok(Json(result))
}

fn map_node_error(message: String) -> (StatusCode, String) {
    if message == "trace node not found" {
        (StatusCode::NOT_FOUND, message)
    } else {
        (StatusCode::INTERNAL_SERVER_ERROR, message)
    }
}

fn node_session_id(conn: &Connection, id: &str) -> Result<String, String> {
    conn.query_row(
        "SELECT session_id FROM trace_calls WHERE id = ?1",
        [id],
        |row| row.get::<_, Option<String>>(0),
    )
    .optional()
    .map_err(|error| error.to_string())?
    .map(|session_id| session_id.unwrap_or_default())
    .ok_or_else(|| "trace node not found".to_string())
}

fn load_replay_spec(conn: &Connection, id: &str) -> Result<ReplaySpec, String> {
    conn.query_row(
        "SELECT method, provider, request_target, model, session_id, request_body
         FROM trace_calls WHERE id = ?1",
        [id],
        |row| {
            Ok(ReplaySpec {
                method: row.get(0)?,
                provider: row.get(1)?,
                target: row.get::<_, Option<String>>(2)?.unwrap_or_default(),
                model: row.get(3)?,
                session_id: row.get::<_, Option<String>>(4)?.unwrap_or_default(),
                body: row.get::<_, Option<Vec<u8>>>(5)?.unwrap_or_default(),
            })
        },
    )
    .optional()
    .map_err(|error| error.to_string())?
    .ok_or_else(|| "trace node not found".to_string())
}

fn descendants(
    conn: &Connection,
    session_id: &str,
    root_id: &str,
) -> rusqlite::Result<Vec<String>> {
    use std::collections::{HashMap, HashSet, VecDeque};

    let mut stmt =
        conn.prepare("SELECT id, parent_span_id FROM trace_calls WHERE session_id = ?1")?;
    let edges = stmt
        .query_map([session_id], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, Option<String>>(1)?))
        })?
        .collect::<rusqlite::Result<Vec<_>>>()?;

    let mut children: HashMap<String, Vec<String>> = HashMap::new();
    for (id, parent) in &edges {
        if let Some(parent) = parent {
            children.entry(parent.clone()).or_default().push(id.clone());
        }
    }

    let mut out = Vec::new();
    let mut seen = HashSet::new();
    let mut queue: VecDeque<String> = children
        .get(root_id)
        .cloned()
        .unwrap_or_default()
        .into_iter()
        .collect();
    while let Some(node) = queue.pop_front() {
        if !seen.insert(node.clone()) {
            continue;
        }
        out.push(node.clone());
        if let Some(kids) = children.get(&node) {
            queue.extend(kids.iter().cloned());
        }
    }

    Ok(out)
}

fn mark_stale(conn: &Connection, ids: &[String]) -> rusqlite::Result<()> {
    for id in ids {
        conn.execute("UPDATE trace_calls SET stale = 1 WHERE id = ?1", [id])?;
    }
    Ok(())
}

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

fn inject_replay_credentials(headers: &mut HeaderMap, provider: &str, state: &AppState) {
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
