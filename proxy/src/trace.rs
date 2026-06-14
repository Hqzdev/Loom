use std::sync::{Arc, Mutex};

use axum::{
    Json, Router,
    extract::{Path, Query, State},
    http::{HeaderMap, HeaderName, StatusCode},
    routing::{get, patch, post},
};
use chrono::{DateTime, Local, TimeZone};
use rusqlite::{Connection, OptionalExtension, params};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

use crate::{AppState, context, pricing};

pub(crate) const MAX_CAPTURE_BYTES: usize = 256 * 1024;

/// Largest request body we retain for replay. Prompts are small; anything
/// bigger is dropped and the span is marked non-replayable (empty body).
const REPLAY_MAX_BODY: usize = 1024 * 1024;

#[derive(Clone)]
pub(crate) struct TraceCapture {
    id: String,
    created_at: i64,
    provider: String,
    method: String,
    path: String,
    pub(crate) model: String,
    pub(crate) preview: String,
    prompt_system: String,
    prompt_user: String,
    request_id: String,
    temperature: Option<f64>,
    /// `tool_use_id`s this request answers (Anthropic `tool_result`, OpenAI
    /// `role:"tool"`). Each links this call to the parent span that emitted it.
    tool_result_ids: Vec<String>,
    /// Serialized `ContextInputs` describing what went into the prompt.
    context_inputs: String,
    /// Stable fingerprint of (model, system, user) — the replay/invalidation key.
    input_hash: String,
    /// Raw request body retained for replay (empty when over `REPLAY_MAX_BODY`).
    request_body: Vec<u8>,
    /// Path + query of the original request, for replay routing.
    request_target: String,
}

#[derive(Serialize)]
struct TraceSnapshot {
    session: Option<TraceSessionDto>,
    nodes: Vec<AgentNodeDto>,
    /// Spans whose upstream output was edited and which need a replay.
    stale_node_ids: Vec<String>,
}

#[derive(Clone, Serialize)]
struct TraceSessionDto {
    id: String,
    title: String,
    trigger: String,
    started_at: String,
}

#[derive(Serialize)]
struct SessionListDto {
    sessions: Vec<TraceSessionDto>,
    current_session_id: Option<String>,
}

#[derive(Deserialize)]
struct TraceQuery {
    session_id: Option<String>,
}

#[derive(Deserialize)]
struct EditOutputRequest {
    output: String,
}

#[derive(Serialize)]
struct InvalidationResult {
    node_id: String,
    invalidated: Vec<String>,
}

#[derive(Serialize)]
struct DownstreamResult {
    node_id: String,
    downstream: Vec<String>,
}

#[derive(Serialize)]
struct ReplayResult {
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

#[derive(Serialize)]
struct AgentNodeDto {
    id: String,
    trace_id: String,
    parent_span_id: Option<String>,
    tool_use_ids: Value,
    context_inputs: Value,
    input_hash: String,
    stale: bool,
    depth: i64,
    step_name: String,
    timestamp: String,
    model: String,
    cost: String,
    latency: String,
    latency_ms: i64,
    bar_percent: f64,
    tokens_in: i64,
    tokens_out: i64,
    request_id: String,
    cache_status: String,
    temperature: Option<f64>,
    status: String,
    prompt: AgentPromptDto,
    response: AgentResponseDto,
    error: Option<AgentErrorDto>,
}

#[derive(Serialize)]
struct AgentPromptDto {
    system: String,
    user: String,
}

#[derive(Serialize)]
struct AgentResponseDto {
    language: String,
    text: String,
}

#[derive(Serialize)]
struct AgentErrorDto {
    code: String,
    message: String,
    detail: String,
}

struct TraceRow {
    id: String,
    created_at: i64,
    provider: String,
    method: String,
    path: String,
    model: String,
    status_code: i64,
    cache_status: String,
    latency_ms: i64,
    request_id: String,
    prompt_system: String,
    prompt_user: String,
    response_text: String,
    response_language: String,
    error_code: Option<String>,
    error_message: Option<String>,
    error_detail: Option<String>,
    tokens_in: i64,
    tokens_out: i64,
    cost: String,
    temperature: Option<f64>,
    /// Root id shared by every span in one agent run.
    trace_id: String,
    /// Span id of the parent call (resolved from `tool_use`/`tool_result`).
    parent_span_id: Option<String>,
    /// JSON array of `tool_use_id`s this response emitted.
    tool_use_ids: String,
    /// Serialized `ContextInputs` for this call.
    context_inputs: String,
    /// Replay/invalidation fingerprint.
    input_hash: String,
    /// Whether an upstream output this call depends on was edited since capture.
    stale: bool,
    /// Raw request body retained for replay (empty when not replayable).
    request_body: Vec<u8>,
    /// Path + query for replay routing.
    request_target: String,
    /// Transient (not a column): `tool_result_id`s carried by the request, used
    /// to resolve lineage at insert time.
    tool_result_ids: Vec<String>,
}

struct ResponseSummary {
    request_id: Option<String>,
    text: String,
    language: String,
    tokens_in: i64,
    tokens_out: i64,
    tool_use_ids: Vec<String>,
}

impl TraceCapture {
    pub(crate) fn from_request(
        method: &str,
        path: &str,
        target: &str,
        provider: &str,
        body: &[u8],
    ) -> Self {
        let parsed = serde_json::from_slice::<Value>(body).ok();
        let model = parsed
            .as_ref()
            .and_then(|value| value.get("model"))
            .and_then(Value::as_str)
            .unwrap_or("-")
            .to_string();
        let preview = parsed
            .as_ref()
            .and_then(extract_last_text)
            .unwrap_or_else(|| {
                if body.is_empty() {
                    "-".to_string()
                } else {
                    format!("<{} bytes, non-JSON>", body.len())
                }
            });
        let (prompt_system, prompt_user) = parsed
            .as_ref()
            .map(extract_prompt)
            .unwrap_or_else(|| ("".to_string(), truncate_one_line(&preview, 4_000)));
        let request_id = parsed
            .as_ref()
            .and_then(|value| value.get("id"))
            .and_then(Value::as_str)
            .unwrap_or("-")
            .to_string();
        let temperature = parsed
            .as_ref()
            .and_then(|value| value.get("temperature"))
            .and_then(Value::as_f64);
        let tool_result_ids = parsed
            .as_ref()
            .map(extract_tool_result_ids)
            .unwrap_or_default();
        let inputs = context::from_request(parsed.as_ref(), &prompt_system, &prompt_user, &model);
        let input_hash = inputs.input_hash.clone();
        let context_inputs = serde_json::to_string(&inputs).unwrap_or_else(|_| "{}".to_string());
        let request_body = if body.len() <= REPLAY_MAX_BODY {
            body.to_vec()
        } else {
            Vec::new()
        };

        Self {
            id: Uuid::new_v4().to_string(),
            created_at: now_millis(),
            provider: provider.to_string(),
            method: method.to_string(),
            path: path.to_string(),
            model,
            preview: truncate_one_line(&preview, 300),
            prompt_system,
            prompt_user,
            request_id,
            temperature,
            tool_result_ids,
            context_inputs,
            input_hash,
            request_body,
            request_target: target.to_string(),
        }
    }
}

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
        .route("/api/traces/{id}/output", patch(edit_output))
        .route("/api/traces/{id}/downstream", get(list_downstream))
        .route("/api/traces/{id}/replay", post(replay_node))
        .route("/api/cache", axum::routing::delete(clear_cache))
}

pub(crate) fn init_schema(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute_batch(include_str!(
        "../sqlite_migrations/20260601000000_sessions.sql"
    ))?;
    if !table_has_column(conn, "trace_calls", "session_id")? {
        conn.execute("ALTER TABLE trace_calls ADD COLUMN session_id TEXT", [])?;
    }
    add_column_if_missing(conn, "trace_calls", "trace_id", "TEXT")?;
    add_column_if_missing(conn, "trace_calls", "parent_span_id", "TEXT")?;
    add_column_if_missing(conn, "trace_calls", "tool_use_ids", "TEXT")?;
    add_column_if_missing(conn, "trace_calls", "context_inputs", "TEXT")?;
    add_column_if_missing(conn, "trace_calls", "input_hash", "TEXT")?;
    add_column_if_missing(conn, "trace_calls", "stale", "INTEGER NOT NULL DEFAULT 0")?;
    add_column_if_missing(conn, "trace_calls", "request_body", "BLOB")?;
    add_column_if_missing(conn, "trace_calls", "request_target", "TEXT")?;
    conn.execute_batch(
        "CREATE INDEX IF NOT EXISTS idx_trace_calls_trace_id
             ON trace_calls(trace_id);",
    )?;
    ensure_current_session(conn)?;
    backfill_missing_session_ids(conn)
}

fn add_column_if_missing(
    conn: &Connection,
    table: &str,
    column: &str,
    decl_type: &str,
) -> rusqlite::Result<()> {
    if !table_has_column(conn, table, column)? {
        conn.execute(
            &format!("ALTER TABLE {table} ADD COLUMN {column} {decl_type}"),
            [],
        )?;
    }
    Ok(())
}

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

    let cost = pricing::estimate_cost(&capture.model, summary.tokens_in, summary.tokens_out);
    let tool_use_ids = serde_json::to_string(&summary.tool_use_ids).unwrap_or_else(|_| "[]".to_string());

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

/// Edit a span's output. Every transitive descendant depended on that output
/// (via the `tool_use`→`tool_result` edge), so they are marked stale and
/// returned as the replay queue.
async fn edit_output(
    State(state): State<AppState>,
    Path(id): Path<String>,
    Json(payload): Json<EditOutputRequest>,
) -> Result<Json<InvalidationResult>, (StatusCode, String)> {
    let db = state.db.clone();
    let result = tokio::task::spawn_blocking(move || {
        let conn = db.lock().map_err(|_| "trace database lock poisoned".to_string())?;
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
    .map_err(|error| (StatusCode::INTERNAL_SERVER_ERROR, format!("worker failed: {error}")))?
    .map_err(map_node_error)?;

    Ok(Json(result))
}

/// Dry run: which spans would be invalidated if this one's output changed.
async fn list_downstream(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<Json<DownstreamResult>, (StatusCode, String)> {
    let db = state.db.clone();
    let result = tokio::task::spawn_blocking(move || {
        let conn = db.lock().map_err(|_| "trace database lock poisoned".to_string())?;
        let session_id = node_session_id(&conn, &id)?;
        let downstream = descendants(&conn, &session_id, &id).map_err(|e| e.to_string())?;
        Ok::<_, String>(DownstreamResult {
            node_id: id,
            downstream,
        })
    })
    .await
    .map_err(|error| (StatusCode::INTERNAL_SERVER_ERROR, format!("worker failed: {error}")))?
    .map_err(map_node_error)?;

    Ok(Json(result))
}

/// Re-run a stale span against its upstream and refresh its recorded output.
/// Upstream auth is taken from the caller's headers — never persisted — so this
/// works for passthrough key mode without storing secrets. Replaying changes
/// the output, so this span's descendants are re-marked stale.
async fn replay_node(
    State(state): State<AppState>,
    Path(id): Path<String>,
    headers: HeaderMap,
) -> Result<Json<ReplayResult>, (StatusCode, String)> {
    let db = state.db.clone();
    let lookup_id = id.clone();
    let spec = tokio::task::spawn_blocking(move || {
        let conn = db.lock().map_err(|_| "trace database lock poisoned".to_string())?;
        load_replay_spec(&conn, &lookup_id)
    })
    .await
    .map_err(|error| (StatusCode::INTERNAL_SERVER_ERROR, format!("worker failed: {error}")))?
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
    let method = reqwest::Method::from_bytes(spec.method.as_bytes())
        .unwrap_or(reqwest::Method::POST);

    let mut forward_headers = HeaderMap::new();
    for (name, value) in headers.iter() {
        if is_forbidden_replay_header(name) {
            continue;
        }
        forward_headers.insert(name.clone(), value.clone());
    }

    let started = now_millis();
    let response = state
        .client
        .request(method, &url)
        .headers(forward_headers)
        .body(spec.body)
        .send()
        .await
        .map_err(|error| (StatusCode::BAD_GATEWAY, format!("replay upstream error: {error}")))?;

    let status_code = response.status().as_u16();
    let content_type = response
        .headers()
        .get(axum::http::header::CONTENT_TYPE)
        .and_then(|value| value.to_str().ok())
        .unwrap_or("")
        .to_string();
    let header_request_id = response_request_id(response.headers());
    let body = response
        .bytes()
        .await
        .map_err(|error| (StatusCode::BAD_GATEWAY, format!("replay read error: {error}")))?;
    let latency_ms = (now_millis() - started).max(0);

    let summary = summarize_response(&content_type, &body);
    let cost = pricing::estimate_cost(&spec.model, summary.tokens_in, summary.tokens_out);
    let tool_use_ids =
        serde_json::to_string(&summary.tool_use_ids).unwrap_or_else(|_| "[]".to_string());
    let request_id = header_request_id
        .or_else(|| summary.request_id.clone())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| "-".to_string());

    let db = state.db.clone();
    let session_id = spec.session_id.clone();
    let result = tokio::task::spawn_blocking(move || {
        let conn = db.lock().map_err(|_| "trace database lock poisoned".to_string())?;
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
    .map_err(|error| (StatusCode::INTERNAL_SERVER_ERROR, format!("worker failed: {error}")))?
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

/// Transitive descendants of `root_id` within a session, via `parent_span_id`.
fn descendants(conn: &Connection, session_id: &str, root_id: &str) -> rusqlite::Result<Vec<String>> {
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

fn fetch_snapshot(
    db: &Arc<Mutex<Connection>>,
    requested_session_id: Option<String>,
) -> rusqlite::Result<TraceSnapshot> {
    let conn = db.lock().expect("trace database lock poisoned");
    let session = match requested_session_id {
        Some(session_id) => {
            find_session(&conn, &session_id)?.unwrap_or(ensure_current_session(&conn)?)
        }
        None => ensure_current_session(&conn)?,
    };
    let mut stmt = conn.prepare(
        "SELECT id, created_at, provider, method, path, model, status_code, cache_status,
                latency_ms, request_id, prompt_system, prompt_user, response_text,
                response_language, error_code, error_message, error_detail, tokens_in,
                tokens_out, cost, temperature, trace_id, parent_span_id,
                tool_use_ids, context_inputs, input_hash, stale
         FROM trace_calls
         WHERE session_id = ?1
         ORDER BY created_at ASC
         LIMIT 500",
    )?;
    let rows = stmt
        .query_map([session.id.as_str()], |row| {
            Ok(TraceRow {
                id: row.get(0)?,
                created_at: row.get(1)?,
                provider: row.get(2)?,
                method: row.get(3)?,
                path: row.get(4)?,
                model: row.get(5)?,
                status_code: row.get(6)?,
                cache_status: row.get(7)?,
                latency_ms: row.get(8)?,
                request_id: row.get(9)?,
                prompt_system: row.get(10)?,
                prompt_user: row.get(11)?,
                response_text: row.get(12)?,
                response_language: row.get(13)?,
                error_code: row.get(14)?,
                error_message: row.get(15)?,
                error_detail: row.get(16)?,
                tokens_in: row.get(17)?,
                tokens_out: row.get(18)?,
                cost: row.get(19)?,
                temperature: row.get(20)?,
                trace_id: row.get::<_, Option<String>>(21)?.unwrap_or_default(),
                parent_span_id: row.get(22)?,
                tool_use_ids: row.get::<_, Option<String>>(23)?.unwrap_or_else(|| "[]".to_string()),
                context_inputs: row.get::<_, Option<String>>(24)?.unwrap_or_else(|| "{}".to_string()),
                input_hash: row.get::<_, Option<String>>(25)?.unwrap_or_default(),
                stale: row.get::<_, Option<i64>>(26)?.unwrap_or(0) != 0,
                request_body: Vec::new(),
                request_target: String::new(),
                tool_result_ids: Vec::new(),
            })
        })?
        .collect::<rusqlite::Result<Vec<_>>>()?;

    let max_latency = rows
        .iter()
        .map(|row| row.latency_ms)
        .max()
        .unwrap_or(1)
        .max(1);
    let depths = compute_depths(&rows);
    let stale_node_ids = rows
        .iter()
        .filter(|row| row.stale)
        .map(|row| row.id.clone())
        .collect();
    let nodes = rows
        .into_iter()
        .map(|row| {
            let depth = depths.get(&row.id).copied().unwrap_or(0);
            row_to_node(depth, row, max_latency)
        })
        .collect();

    Ok(TraceSnapshot {
        session: Some(session),
        nodes,
        stale_node_ids,
    })
}

fn fetch_sessions(db: &Arc<Mutex<Connection>>) -> rusqlite::Result<SessionListDto> {
    let conn = db.lock().expect("trace database lock poisoned");
    let current = ensure_current_session(&conn)?;
    let mut stmt = conn.prepare(
        "SELECT id, created_at, name
         FROM sessions
         ORDER BY created_at DESC",
    )?;
    let sessions = stmt
        .query_map([], |row| {
            Ok(session_to_dto(
                row.get::<_, String>(0)?,
                row.get::<_, i64>(1)?,
                row.get::<_, String>(2)?,
            ))
        })?
        .collect::<rusqlite::Result<Vec<_>>>()?;

    Ok(SessionListDto {
        sessions,
        current_session_id: Some(current.id),
    })
}

fn ensure_current_session(conn: &Connection) -> rusqlite::Result<TraceSessionDto> {
    if let Some(session) = latest_session(conn)? {
        return Ok(session);
    }

    create_session(conn, Some("Live Session"))
}

fn latest_session(conn: &Connection) -> rusqlite::Result<Option<TraceSessionDto>> {
    conn.query_row(
        "SELECT id, created_at, name
         FROM sessions
         ORDER BY created_at DESC
         LIMIT 1",
        [],
        |row| {
            Ok(session_to_dto(
                row.get::<_, String>(0)?,
                row.get::<_, i64>(1)?,
                row.get::<_, String>(2)?,
            ))
        },
    )
    .optional()
}

fn find_session(conn: &Connection, id: &str) -> rusqlite::Result<Option<TraceSessionDto>> {
    conn.query_row(
        "SELECT id, created_at, name
         FROM sessions
         WHERE id = ?1",
        [id],
        |row| {
            Ok(session_to_dto(
                row.get::<_, String>(0)?,
                row.get::<_, i64>(1)?,
                row.get::<_, String>(2)?,
            ))
        },
    )
    .optional()
}

fn create_session(conn: &Connection, name: Option<&str>) -> rusqlite::Result<TraceSessionDto> {
    let created_at = now_millis();
    let id = Uuid::new_v4().to_string();
    let name = name
        .map(ToOwned::to_owned)
        .unwrap_or_else(|| format!("Session {}", format_time_for_name(created_at)));

    conn.execute(
        "INSERT INTO sessions (id, created_at, name)
         VALUES (?1, ?2, ?3)",
        params![id, created_at, name],
    )?;

    Ok(session_to_dto(id, created_at, name))
}

fn session_to_dto(id: String, created_at: i64, name: String) -> TraceSessionDto {
    TraceSessionDto {
        id,
        title: name,
        trigger: "AgentTrace proxy".to_string(),
        started_at: format_timestamp(created_at),
    }
}

fn backfill_missing_session_ids(conn: &Connection) -> rusqlite::Result<()> {
    let session = ensure_current_session(conn)?;
    conn.execute(
        "UPDATE trace_calls
         SET session_id = ?1
         WHERE session_id IS NULL OR session_id = ''",
        [session.id],
    )?;
    Ok(())
}

fn table_has_column(conn: &Connection, table: &str, column: &str) -> rusqlite::Result<bool> {
    let mut stmt = conn.prepare(&format!("PRAGMA table_info({table})"))?;
    let mut rows = stmt.query([])?;

    while let Some(row) = rows.next()? {
        let name: String = row.get(1)?;
        if name == column {
            return Ok(true);
        }
    }

    Ok(false)
}

fn row_to_node(depth: i64, row: TraceRow, max_latency: i64) -> AgentNodeDto {
    let status = if row.cache_status == "hit" {
        "cached"
    } else if (200..=299).contains(&row.status_code) {
        "success"
    } else {
        "error"
    };
    let step_name = format!(
        "{} {}",
        row.provider.to_ascii_uppercase(),
        compact_path(&row.path)
    );
    let tool_use_ids =
        serde_json::from_str(&row.tool_use_ids).unwrap_or_else(|_| Value::Array(Vec::new()));
    let context_inputs =
        serde_json::from_str(&row.context_inputs).unwrap_or_else(|_| Value::Object(Default::default()));

    AgentNodeDto {
        id: row.id,
        trace_id: row.trace_id,
        parent_span_id: row.parent_span_id,
        tool_use_ids,
        context_inputs,
        input_hash: row.input_hash,
        stale: row.stale,
        depth,
        step_name,
        timestamp: format_timestamp(row.created_at),
        model: row.model,
        cost: row.cost,
        latency: format_latency(row.latency_ms),
        latency_ms: row.latency_ms,
        bar_percent: (row.latency_ms as f64 / max_latency as f64).clamp(0.06, 1.0),
        tokens_in: row.tokens_in,
        tokens_out: row.tokens_out,
        request_id: row.request_id,
        cache_status: row.cache_status,
        temperature: row.temperature,
        status: status.to_string(),
        prompt: AgentPromptDto {
            system: row.prompt_system,
            user: row.prompt_user,
        },
        response: AgentResponseDto {
            language: row.response_language,
            text: row.response_text,
        },
        error: row.error_code.map(|code| AgentErrorDto {
            code,
            message: row.error_message.unwrap_or_default(),
            detail: row.error_detail.unwrap_or_default(),
        }),
    }
}

fn insert_trace_row(db: &Arc<Mutex<Connection>>, row: TraceRow, status: &str) {
    if let Ok(conn) = db.lock() {
        let session = match ensure_current_session(&conn) {
            Ok(session) => session,
            Err(error) => {
                eprintln!("  cannot resolve trace session: {error}");
                return;
            }
        };

        // Resolve lineage: if this request answered a prior `tool_use`, the span
        // that emitted it is our parent and we inherit its trace root. Otherwise
        // this call starts a new trace rooted at its own id.
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

/// Find the parent span for a request by matching the `tool_use_id`s it answers
/// against prior spans' emitted `tool_use_ids`. Returns `(trace_id, parent)`.
/// A call with no matching parent roots a new trace at its own id.
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

/// Walk parent links to assign each span a real tree depth (root = 0). Falls
/// back to 0 if a parent is missing or a cycle is detected.
fn compute_depths(rows: &[TraceRow]) -> std::collections::HashMap<String, i64> {
    use std::collections::HashMap;
    let parents: HashMap<&str, Option<&str>> = rows
        .iter()
        .map(|row| (row.id.as_str(), row.parent_span_id.as_deref()))
        .collect();
    let mut depths = HashMap::new();
    for row in rows {
        let mut depth = 0;
        let mut current = row.parent_span_id.as_deref();
        let mut guard = 0;
        while let Some(parent) = current {
            if guard > rows.len() {
                break; // defensive: broken/cyclic chain
            }
            depth += 1;
            guard += 1;
            current = parents.get(parent).copied().flatten();
        }
        depths.insert(row.id.clone(), depth);
    }
    depths
}

fn summarize_response(content_type: &str, body: &[u8]) -> ResponseSummary {
    if let Ok(value) = serde_json::from_slice::<Value>(body) {
        let text = extract_response_text(&value).unwrap_or_else(|| pretty_json(&value));
        let usage = value.get("usage");
        let tokens_in = usage
            .and_then(|usage| {
                usage
                    .get("prompt_tokens")
                    .or_else(|| usage.get("input_tokens"))
                    .and_then(Value::as_i64)
            })
            .unwrap_or(0);
        let tokens_out = usage
            .and_then(|usage| {
                usage
                    .get("completion_tokens")
                    .or_else(|| usage.get("output_tokens"))
                    .and_then(Value::as_i64)
            })
            .unwrap_or(0);

        return ResponseSummary {
            request_id: value
                .get("id")
                .and_then(Value::as_str)
                .map(ToOwned::to_owned),
            text: cap_text(&text, 64_000),
            language: "json".to_string(),
            tokens_in,
            tokens_out,
            tool_use_ids: extract_tool_use_ids(&value),
        };
    }

    let text = utf8_preview(body);
    ResponseSummary {
        request_id: None,
        language: if content_type.contains("json") {
            "json".to_string()
        } else {
            "text".to_string()
        },
        text,
        tokens_in: 0,
        tokens_out: 0,
        tool_use_ids: Vec::new(),
    }
}

/// `tool_use_id`s a response emits — Anthropic `content[].type=="tool_use"` and
/// OpenAI `choices[].message.tool_calls[].id`. These are what a later request's
/// `tool_result` points back at, giving us the parent→child edge.
fn extract_tool_use_ids(value: &Value) -> Vec<String> {
    let mut ids = Vec::new();

    if let Some(content) = value.get("content").and_then(Value::as_array) {
        for block in content {
            if block.get("type").and_then(Value::as_str) == Some("tool_use")
                && let Some(id) = block.get("id").and_then(Value::as_str)
            {
                ids.push(id.to_string());
            }
        }
    }

    if let Some(choices) = value.get("choices").and_then(Value::as_array) {
        for choice in choices {
            let tool_calls = choice
                .get("message")
                .and_then(|message| message.get("tool_calls"))
                .and_then(Value::as_array);
            for call in tool_calls.into_iter().flatten() {
                if let Some(id) = call.get("id").and_then(Value::as_str) {
                    ids.push(id.to_string());
                }
            }
        }
    }

    ids
}

/// `tool_use_id`s a request answers — Anthropic `tool_result` blocks and OpenAI
/// `role:"tool"` messages (`tool_call_id`). Each links this call to its parent.
fn extract_tool_result_ids(value: &Value) -> Vec<String> {
    let mut ids = Vec::new();
    let Some(messages) = value.get("messages").and_then(Value::as_array) else {
        return ids;
    };

    for message in messages {
        let role = message.get("role").and_then(Value::as_str);

        // OpenAI: a tool message carries the id it answers.
        if role == Some("tool")
            && let Some(id) = message.get("tool_call_id").and_then(Value::as_str)
        {
            ids.push(id.to_string());
        }

        // Anthropic: user-role messages embed tool_result content blocks.
        if let Some(content) = message.get("content").and_then(Value::as_array) {
            for block in content {
                if block.get("type").and_then(Value::as_str) == Some("tool_result")
                    && let Some(id) = block.get("tool_use_id").and_then(Value::as_str)
                {
                    ids.push(id.to_string());
                }
            }
        }
    }

    ids
}

fn extract_prompt(value: &Value) -> (String, String) {
    let system = value
        .get("system")
        .map(content_to_string)
        .or_else(|| {
            value
                .get("messages")
                .and_then(Value::as_array)
                .map(|messages| {
                    messages
                        .iter()
                        .filter(|message| {
                            matches!(
                                message.get("role").and_then(Value::as_str),
                                Some("system" | "developer")
                            )
                        })
                        .filter_map(|message| message.get("content"))
                        .map(content_to_string)
                        .collect::<Vec<_>>()
                        .join("\n\n")
                })
        })
        .unwrap_or_default();

    let user = value
        .get("messages")
        .and_then(Value::as_array)
        .and_then(|messages| {
            messages
                .iter()
                .rev()
                .find(|message| message.get("role").and_then(Value::as_str) == Some("user"))
                .and_then(|message| message.get("content"))
                .map(content_to_string)
        })
        .or_else(|| value.get("input").map(content_to_string))
        .or_else(|| {
            value
                .get("prompt")
                .and_then(Value::as_str)
                .map(ToOwned::to_owned)
        })
        .unwrap_or_default();

    (cap_text(&system, 16_000), cap_text(&user, 32_000))
}

fn extract_last_text(value: &Value) -> Option<String> {
    let arr = value
        .get("messages")
        .and_then(Value::as_array)
        .or_else(|| value.get("input").and_then(Value::as_array));
    if let Some(arr) = arr {
        return arr
            .last()
            .map(|last| content_to_string(last.get("content").unwrap_or(last)));
    }
    value.get("input").map(content_to_string).or_else(|| {
        value
            .get("prompt")
            .and_then(Value::as_str)
            .map(ToOwned::to_owned)
    })
}

fn extract_response_text(value: &Value) -> Option<String> {
    if let Some(text) = value.get("output_text").and_then(Value::as_str) {
        return Some(text.to_string());
    }

    if let Some(content) = value
        .get("choices")
        .and_then(Value::as_array)
        .and_then(|choices| choices.first())
        .and_then(|choice| choice.get("message"))
        .and_then(|message| message.get("content"))
    {
        return Some(content_to_string(content));
    }

    if let Some(content) = value.get("content").and_then(Value::as_array) {
        let text = content
            .iter()
            .filter_map(|item| item.get("text").and_then(Value::as_str))
            .collect::<Vec<_>>()
            .join("\n\n");
        if !text.is_empty() {
            return Some(text);
        }
    }

    if let Some(output) = value.get("output").and_then(Value::as_array) {
        let text = output
            .iter()
            .flat_map(|item| {
                item.get("content")
                    .and_then(Value::as_array)
                    .cloned()
                    .unwrap_or_default()
            })
            .filter_map(|item| {
                item.get("text")
                    .and_then(Value::as_str)
                    .map(ToOwned::to_owned)
            })
            .collect::<Vec<_>>()
            .join("\n\n");
        if !text.is_empty() {
            return Some(text);
        }
    }

    None
}

fn content_to_string(content: &Value) -> String {
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

fn pretty_json(value: &Value) -> String {
    serde_json::to_string_pretty(value).unwrap_or_else(|_| value.to_string())
}

fn utf8_preview(body: &[u8]) -> String {
    cap_text(&String::from_utf8_lossy(body), 64_000)
}

fn cap_text(text: &str, max_chars: usize) -> String {
    if text.chars().count() <= max_chars {
        return text.to_string();
    }

    let mut capped = text.chars().take(max_chars).collect::<String>();
    capped.push('…');
    capped
}

fn truncate_one_line(text: &str, max_chars: usize) -> String {
    let one_line = text.split_whitespace().collect::<Vec<_>>().join(" ");
    cap_text(&one_line, max_chars)
}

fn compact_path(path: &str) -> String {
    path.trim_start_matches('/')
        .rsplit('/')
        .next()
        .filter(|segment| !segment.is_empty())
        .unwrap_or(path)
        .to_string()
}

fn format_latency(milliseconds: i64) -> String {
    if milliseconds >= 1_000 {
        format!("{:.2}s", milliseconds as f64 / 1_000.0)
    } else {
        format!("{milliseconds}ms")
    }
}

fn format_timestamp(milliseconds: i64) -> String {
    let seconds = milliseconds.div_euclid(1_000);
    let millis = milliseconds.rem_euclid(1_000) as u32;
    let nanos = millis * 1_000_000;
    let local: DateTime<Local> = Local
        .timestamp_opt(seconds, nanos)
        .single()
        .unwrap_or_else(Local::now);

    local.format("%H:%M:%S").to_string()
}

fn format_time_for_name(milliseconds: i64) -> String {
    let seconds = milliseconds.div_euclid(1_000);
    let millis = milliseconds.rem_euclid(1_000) as u32;
    let nanos = millis * 1_000_000;
    let local: DateTime<Local> = Local
        .timestamp_opt(seconds, nanos)
        .single()
        .unwrap_or_else(Local::now);

    local.format("%H:%M").to_string()
}

fn now_millis() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|duration| duration.as_millis() as i64)
        .unwrap_or(0)
}
