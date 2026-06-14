//! Loom proxy — a transparent, path-preserving reverse proxy for LLM agents,
//! now with a local SQLite response cache keyed on the prompt hash.
//!
//! Flow per request:
//!   1. read body, pick upstream by path, compute cache key = sha256(method+path+body)
//!   2. on a cacheable POST: look up SQLite. HIT → replay stored bytes (🟡, no network).
//!   3. MISS → forward upstream, *tee* the response (stream to client while
//!      accumulating a copy), and store it on clean 2xx completion.
//!
//! The macOS UI reads live captured calls through `/api/traces/current`.

mod auth;
mod context;
mod crypto;
mod error;
mod pricing;
mod settings;
mod trace;

use std::fmt::Write as _;
use std::io::Write;
use std::sync::{Arc, Mutex};
use std::time::{Instant, SystemTime, UNIX_EPOCH};

use axum::{
    Router,
    body::{Body, to_bytes},
    extract::{Request, State},
    http::{HeaderMap, HeaderName, HeaderValue, Method, StatusCode, header::CONTENT_TYPE},
    response::{IntoResponse, Response},
};
use bytes::Bytes;
use futures_util::StreamExt;
use rusqlite::{Connection, OptionalExtension, params};
use sha2::{Digest, Sha256};
use tokio_stream::wrappers::ReceiverStream;

use auth::AuthContext;

const RESET: &str = "\x1b[0m";
const BOLD: &str = "\x1b[1m";
const DIM: &str = "\x1b[2m";
const RED: &str = "\x1b[31m";
const GREEN: &str = "\x1b[32m";
const YELLOW: &str = "\x1b[33m";
const CYAN: &str = "\x1b[36m";

/// Max request body we buffer for forwarding + logging (prompts are small).
const MAX_BODY: usize = 100 * 1024 * 1024;

#[derive(Clone)]
pub(crate) struct AppState {
    client: reqwest::Client,
    openai_upstream: Arc<str>,
    anthropic_upstream: Arc<str>,
    db: Arc<Mutex<Connection>>,
    cache_enabled: bool,
    auth: Option<Arc<AuthContext>>,
}

/// A response we can replay from the cache.
struct CachedResponse {
    status: u16,
    content_type: String,
    body: Vec<u8>,
}

#[tokio::main]
async fn main() {
    let openai =
        std::env::var("OPENAI_UPSTREAM").unwrap_or_else(|_| "https://api.openai.com".to_string());
    let anthropic = std::env::var("ANTHROPIC_UPSTREAM")
        .unwrap_or_else(|_| "https://api.anthropic.com".to_string());
    let addr = std::env::var("LOOM_ADDR").unwrap_or_else(|_| "127.0.0.1:8080".to_string());
    let db_path = std::env::var("LOOM_DB").unwrap_or_else(|_| "loom-cache.sqlite".to_string());
    let cache_enabled = std::env::var("LOOM_CACHE")
        .map(|v| v != "off" && v != "0" && v != "false")
        .unwrap_or(true);

    let conn =
        Connection::open(&db_path).unwrap_or_else(|e| panic!("loom: cannot open {db_path}: {e}"));
    conn.execute_batch(
        "PRAGMA journal_mode=WAL;
         CREATE TABLE IF NOT EXISTS cache (
             key          TEXT PRIMARY KEY,
             created_at   INTEGER NOT NULL,
             provider     TEXT,
             model        TEXT,
             req_preview  TEXT,
             status       INTEGER NOT NULL,
             content_type TEXT,
             body         BLOB NOT NULL,
             hits         INTEGER NOT NULL DEFAULT 0
         );",
    )
    .expect("loom: cannot init cache schema");
    trace::init_schema(&conn).expect("loom: cannot init trace schema");

    let client = reqwest::Client::new();
    let auth = AuthContext::from_env(client.clone())
        .await
        .unwrap_or_else(|error| panic!("loom: cannot init auth context: {}", error.message))
        .map(Arc::new);

    let state = AppState {
        client,
        openai_upstream: Arc::from(openai.as_str()),
        anthropic_upstream: Arc::from(anthropic.as_str()),
        db: Arc::new(Mutex::new(conn)),
        cache_enabled,
        auth,
    };

    let app = Router::new()
        .merge(auth::router())
        .merge(settings::router())
        .merge(trace::router())
        .fallback(proxy)
        .with_state(state);

    let listener = tokio::net::TcpListener::bind(&addr)
        .await
        .unwrap_or_else(|e| panic!("loom: cannot bind {addr}: {e}"));

    let cache_label = if cache_enabled { "on" } else { "off" };
    println!("{BOLD}{CYAN}◆ Loom proxy{RESET} listening on {BOLD}http://{addr}{RESET}");
    println!("  {DIM}/v1/messages*   → {anthropic}   (Anthropic / Claude Code){RESET}");
    println!("  {DIM}everything else → {openai}   (OpenAI / Codex){RESET}");
    println!("  {DIM}cache: {BOLD}{cache_label}{RESET}{DIM}  ·  db: {db_path}{RESET}");
    println!("{DIM}Point an agent here, e.g.  ANTHROPIC_BASE_URL=http://{addr}{RESET}\n");
    let _ = std::io::stdout().flush();

    axum::serve(listener, app)
        .await
        .expect("loom: server crashed");
}

/// Catch-all handler: cache → forward+tee → store.
async fn proxy(State(state): State<AppState>, req: Request) -> Response {
    let started = Instant::now();
    let (parts, body) = req.into_parts();
    let method = parts.method;
    let uri = parts.uri;
    let path = uri.path().to_string();
    let path_and_query = uri
        .path_and_query()
        .map(|pq| pq.as_str().to_string())
        .unwrap_or_else(|| path.clone());

    let (base, label) = if path.starts_with("/v1/messages") {
        (state.anthropic_upstream.clone(), "anthropic")
    } else {
        (state.openai_upstream.clone(), "openai")
    };
    let url = format!("{base}{path_and_query}");

    let body_bytes = match to_bytes(body, MAX_BODY).await {
        Ok(b) => b,
        Err(e) => {
            eprintln!("{RED}✖ failed reading request body: {e}{RESET}\n");
            return (StatusCode::BAD_REQUEST, "loom: cannot read request body").into_response();
        }
    };

    let trace_capture =
        trace::TraceCapture::from_request(method.as_str(), &path, &path_and_query, label, &body_bytes);
    let model = trace_capture.model.clone();
    let preview = trace_capture.preview.clone();
    log_request(&method, &path, label, base.as_ref(), &model, &preview);

    // Only cache idempotent-ish POSTs (the actual LLM calls) when enabled.
    let cacheable = state.cache_enabled && method == Method::POST;
    let key = if cacheable {
        cache_key(&method, &path_and_query, &body_bytes)
    } else {
        String::new()
    };

    // ---- cache lookup ----
    if cacheable {
        let db = state.db.clone();
        let k = key.clone();
        if let Ok(Some(c)) = tokio::task::spawn_blocking(move || cache_get(&db, &k)).await {
            let latency_ms = started.elapsed().as_millis() as i64;
            let trace_db = state.db.clone();
            let cached_capture = trace_capture.clone();
            let cached_body = c.body.clone();
            let cached_content_type = c.content_type.clone();
            let cached_status = c.status;
            let _ = tokio::task::spawn_blocking(move || {
                trace::record_response(
                    &trace_db,
                    &cached_capture,
                    cached_status,
                    &cached_content_type,
                    None,
                    &cached_body,
                    "hit",
                    latency_ms,
                );
            })
            .await;
            log_cached(
                StatusCode::from_u16(c.status).unwrap_or(StatusCode::OK),
                c.body.len(),
            );
            return cached_response(c);
        }
    }

    // ---- forward request headers (verbatim minus hop-by-hop + framing) ----
    let mut headers = HeaderMap::new();
    for (name, value) in parts.headers.iter() {
        if is_hop_by_hop(name) || name == "host" || name == "content-length" {
            continue;
        }
        headers.insert(name.clone(), value.clone());
    }

    let upstream = state
        .client
        .request(method, url.as_str())
        .headers(headers)
        .body(body_bytes)
        .send()
        .await;

    let resp = match upstream {
        Ok(r) => r,
        Err(e) => {
            let latency_ms = started.elapsed().as_millis() as i64;
            let trace_db = state.db.clone();
            let failed_capture = trace_capture.clone();
            let message = e.to_string();
            let _ = tokio::task::spawn_blocking(move || {
                trace::record_upstream_error(&trace_db, &failed_capture, &message, latency_ms);
            })
            .await;
            eprintln!("{RED}◀ upstream error: {e}{RESET}\n");
            return (StatusCode::BAD_GATEWAY, format!("loom upstream error: {e}")).into_response();
        }
    };

    let status = resp.status();
    let upstream_request_id = trace::response_request_id(resp.headers());
    let ctype = resp
        .headers()
        .get(CONTENT_TYPE)
        .and_then(|v| v.to_str().ok())
        .unwrap_or("")
        .to_string();
    log_response(status, &ctype);

    let mut out_headers = HeaderMap::new();
    for (name, value) in resp.headers().iter() {
        if is_hop_by_hop(name) || name == "content-length" {
            continue;
        }
        out_headers.insert(name.clone(), value.clone());
    }
    out_headers.insert(
        HeaderName::from_static("x-loom-cache"),
        HeaderValue::from_static("miss"),
    );

    let store = cacheable && status.is_success();

    // ---- tee: stream to client while (optionally) accumulating for the cache ----
    let (tx, rx) = tokio::sync::mpsc::channel::<Result<Bytes, reqwest::Error>>(16);
    let db = state.db.clone();
    let provider = label.to_string();
    let status_code = status.as_u16();
    let ct_store = ctype.clone();
    let trace_capture_for_stream = trace_capture.clone();
    let cache_status = "miss".to_string();
    tokio::spawn(async move {
        let mut acc: Vec<u8> = Vec::new();
        let mut completed = true;
        let mut stream_error: Option<String> = None;
        let mut stream = resp.bytes_stream();
        while let Some(item) = stream.next().await {
            match item {
                Ok(chunk) => {
                    if store {
                        acc.extend_from_slice(&chunk);
                    } else if acc.len() < trace::MAX_CAPTURE_BYTES {
                        let remaining = trace::MAX_CAPTURE_BYTES - acc.len();
                        let take = chunk.len().min(remaining);
                        acc.extend_from_slice(&chunk[..take]);
                    }
                    if tx.send(Ok(chunk)).await.is_err() {
                        completed = false; // client disconnected
                        break;
                    }
                }
                Err(e) => {
                    stream_error = Some(e.to_string());
                    let _ = tx.send(Err(e)).await;
                    completed = false; // don't cache a partial/errored stream
                    break;
                }
            }
        }
        if completed {
            let latency_ms = started.elapsed().as_millis() as i64;
            let _ = tokio::task::spawn_blocking(move || {
                trace::record_response(
                    &db,
                    &trace_capture_for_stream,
                    status_code,
                    &ct_store,
                    upstream_request_id.as_deref(),
                    &acc,
                    &cache_status,
                    latency_ms,
                );

                if store {
                    cache_put(
                        &db,
                        &key,
                        &provider,
                        &model,
                        &preview,
                        status_code,
                        &ct_store,
                        &acc,
                    );
                }
            })
            .await;
        } else if let Some(message) = stream_error {
            let latency_ms = started.elapsed().as_millis() as i64;
            let _ = tokio::task::spawn_blocking(move || {
                trace::record_upstream_error(&db, &trace_capture_for_stream, &message, latency_ms);
            })
            .await;
        }
    });

    let mut response = Response::new(Body::from_stream(ReceiverStream::new(rx)));
    *response.status_mut() = status;
    *response.headers_mut() = out_headers;
    response
}

/// Build an HTTP response that replays a cached payload.
fn cached_response(c: CachedResponse) -> Response {
    let mut response = Response::new(Body::from(Bytes::from(c.body)));
    *response.status_mut() = StatusCode::from_u16(c.status).unwrap_or(StatusCode::OK);
    let h = response.headers_mut();
    if !c.content_type.is_empty() {
        if let Ok(v) = HeaderValue::from_str(&c.content_type) {
            h.insert(CONTENT_TYPE, v);
        }
    }
    h.insert(
        HeaderName::from_static("x-loom-cache"),
        HeaderValue::from_static("hit"),
    );
    response
}

// ---------- cache helpers (run inside spawn_blocking) ----------

fn cache_get(db: &Mutex<Connection>, key: &str) -> Option<CachedResponse> {
    let conn = db.lock().ok()?;
    let found = conn
        .query_row(
            "SELECT status, content_type, body FROM cache WHERE key = ?1",
            [key],
            |row| {
                Ok(CachedResponse {
                    status: row.get::<_, i64>(0)? as u16,
                    content_type: row.get::<_, Option<String>>(1)?.unwrap_or_default(),
                    body: row.get(2)?,
                })
            },
        )
        .optional()
        .ok()
        .flatten();
    if found.is_some() {
        let _ = conn.execute("UPDATE cache SET hits = hits + 1 WHERE key = ?1", [key]);
    }
    found
}

#[allow(clippy::too_many_arguments)]
fn cache_put(
    db: &Mutex<Connection>,
    key: &str,
    provider: &str,
    model: &str,
    preview: &str,
    status: u16,
    content_type: &str,
    body: &[u8],
) {
    if let Ok(conn) = db.lock() {
        let _ = conn.execute(
            "INSERT OR REPLACE INTO cache
                (key, created_at, provider, model, req_preview, status, content_type, body, hits)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8,
                COALESCE((SELECT hits FROM cache WHERE key = ?1), 0))",
            params![
                key,
                now_unix(),
                provider,
                model,
                preview,
                status as i64,
                content_type,
                body
            ],
        );
    }
}

fn cache_key(method: &Method, path_and_query: &str, body: &[u8]) -> String {
    let mut h = Sha256::new();
    h.update(method.as_str().as_bytes());
    h.update(b"\n");
    h.update(path_and_query.as_bytes());
    h.update(b"\n");
    h.update(body);
    to_hex(&h.finalize())
}

fn to_hex(bytes: &[u8]) -> String {
    let mut s = String::with_capacity(bytes.len() * 2);
    for b in bytes {
        let _ = write!(s, "{b:02x}");
    }
    s
}

fn now_unix() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

/// Headers that must not be forwarded across a proxy hop (RFC 9110 §7.6.1).
fn is_hop_by_hop(name: &HeaderName) -> bool {
    matches!(
        name.as_str(),
        "connection"
            | "keep-alive"
            | "proxy-authenticate"
            | "proxy-authorization"
            | "proxy-connection"
            | "te"
            | "trailer"
            | "transfer-encoding"
            | "upgrade"
    )
}

// ---------- logging ----------

fn log_request(method: &Method, path: &str, label: &str, base: &str, model: &str, preview: &str) {
    println!("{BOLD}{CYAN}▶ {method} {path}{RESET}  {DIM}→ {label} ({base}){RESET}");
    println!("  {DIM}model:{RESET} {YELLOW}{model}{RESET}");
    println!("  {DIM}last :{RESET} {preview}");
    let _ = std::io::stdout().flush();
}

fn log_response(status: StatusCode, ctype: &str) {
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

fn log_cached(status: StatusCode, bytes: usize) {
    println!("{YELLOW}◀ {status}{RESET}  {DIM}🟡 cache hit · {bytes} bytes · 0 ms · $0{RESET}\n");
    let _ = std::io::stdout().flush();
}
