//! Tether proxy — a transparent, path-preserving reverse proxy for LLM agents,
//! now with a local SQLite response cache keyed on the prompt hash.
//!
//! Flow per request:
//!   1. read body, pick upstream by path, compute cache key = sha256(method+path+body)
//!   2. on a cacheable POST: look up SQLite. HIT -> replay stored bytes, no network.
//!   3. MISS -> forward upstream, tee the response, and store it on clean 2xx completion.
//!
//! The macOS UI reads live captured calls through `/api/traces/current`.

mod api_docs;
mod auth;
mod context;
mod error;
mod gateway;
mod logging;
mod settings;
mod trace;

use std::io::Write;
use std::sync::{Arc, Mutex};

use axum::Router;
use rusqlite::Connection;

use auth::AuthContext;
use logging::{BOLD, CYAN, DIM, RESET};

/// Shared application state injected into every proxy and API route.
#[derive(Clone)]
pub(crate) struct AppState {
    client: reqwest::Client,
    openai_upstream: Arc<str>,
    anthropic_upstream: Arc<str>,
    db: Arc<Mutex<Connection>>,
    trace_sink: trace::TraceSink,
    cache_enabled: bool,
    auth: Option<Arc<AuthContext>>,
    /// Provider credentials sourced from the local environment (the macOS app
    /// reads these out of the Keychain and passes them in at launch). When set,
    /// the proxy injects them on upstream calls that arrive without their own
    /// credential, so the agent never needs to hold the key.
    openai_api_key: Option<Arc<str>>,
    anthropic_api_key: Option<Arc<str>>,
}

/// Boots storage, trace ingestion, routes, and the proxy HTTP listener.
#[tokio::main]
async fn main() {
    let openai =
        std::env::var("OPENAI_UPSTREAM").unwrap_or_else(|_| "https://api.openai.com".to_string());
    let anthropic = std::env::var("ANTHROPIC_UPSTREAM")
        .unwrap_or_else(|_| "https://api.anthropic.com".to_string());
    let addr = std::env::var("TETHER_ADDR").unwrap_or_else(|_| "127.0.0.1:8080".to_string());
    let db_path = std::env::var("TETHER_DB").unwrap_or_else(|_| "tether-cache.sqlite".to_string());
    let cache_enabled = std::env::var("TETHER_CACHE")
        .map(|v| v != "off" && v != "0" && v != "false")
        .unwrap_or(true);
    let openai_api_key = read_api_key("OPENAI_API_KEY");
    let anthropic_api_key = read_api_key("ANTHROPIC_API_KEY");

    let conn =
        Connection::open(&db_path).unwrap_or_else(|e| panic!("tether: cannot open {db_path}: {e}"));
    conn.execute_batch("PRAGMA journal_mode=WAL;")
        .expect("tether: cannot enable WAL mode");
    tether_cache::init_schema(&conn).expect("tether: cannot init cache schema");
    trace::init_schema(&conn).expect("tether: cannot init trace schema");

    let client = reqwest::Client::new();
    let auth = AuthContext::from_env(client.clone())
        .await
        .unwrap_or_else(|error| panic!("tether: cannot init auth context: {}", error.message))
        .map(Arc::new);

    let openai_key_present = openai_api_key.is_some();
    let anthropic_key_present = anthropic_api_key.is_some();
    let (trace_sink, trace_events) =
        trace::TraceSink::bounded(trace::DEFAULT_TRACE_CHANNEL_CAPACITY);
    let state = AppState {
        client,
        openai_upstream: Arc::from(openai.as_str()),
        anthropic_upstream: Arc::from(anthropic.as_str()),
        db: Arc::new(Mutex::new(conn)),
        trace_sink,
        cache_enabled,
        auth,
        openai_api_key,
        anthropic_api_key,
    };
    trace::spawn_ingest_worker(state.db.clone(), trace_events);

    let app = Router::new()
        .merge(api_docs::router())
        .merge(auth::router())
        .merge(settings::router())
        .merge(trace::router())
        .fallback(gateway::proxy)
        .with_state(state);

    let listener = tokio::net::TcpListener::bind(&addr)
        .await
        .unwrap_or_else(|e| panic!("tether: cannot bind {addr}: {e}"));

    let cache_label = if cache_enabled { "on" } else { "off" };
    println!("{BOLD}{CYAN}◆ Tether proxy{RESET} listening on {BOLD}http://{addr}{RESET}");
    println!("  {DIM}/v1/messages*   -> {anthropic}   (Anthropic / Claude Code){RESET}");
    println!("  {DIM}everything else -> {openai}   (OpenAI / Codex){RESET}");
    println!("  {DIM}cache: {BOLD}{cache_label}{RESET}{DIM}  ·  db: {db_path}{RESET}");
    let key_label = |present: bool| {
        if present {
            "injected from env"
        } else {
            "client-supplied"
        }
    };
    println!(
        "  {DIM}openai key: {} · anthropic key: {}{RESET}",
        key_label(openai_key_present),
        key_label(anthropic_key_present)
    );
    println!("{DIM}Point an agent here, e.g. ANTHROPIC_BASE_URL=http://{addr}{RESET}\n");
    let _ = std::io::stdout().flush();

    axum::serve(listener, app)
        .await
        .expect("tether: server crashed");
}

/// Reads an API key from the environment, trimming empty values to `None`.
fn read_api_key(name: &str) -> Option<Arc<str>> {
    std::env::var(name)
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .map(Arc::from)
}
