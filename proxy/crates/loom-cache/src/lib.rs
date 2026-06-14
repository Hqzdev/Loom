//! SHA-256-keyed response cache for the Loom proxy.
//!
//! The proxy memoizes upstream LLM responses so identical requests replay
//! instantly with no network call. The cache key is a stable digest of
//! `method + path_and_query + body`, so re-issuing the same request hits.
//!
//! This crate owns the `cache` SQLite table (schema, reads, writes) and is
//! transport-agnostic: it speaks `rusqlite`, not HTTP. The blocking calls here
//! are meant to run inside `spawn_blocking` on the proxy's async runtime.

use std::fmt::Write as _;
use std::sync::Mutex;
use std::time::{SystemTime, UNIX_EPOCH};

use rusqlite::{Connection, OptionalExtension, params};
use sha2::{Digest, Sha256};

/// A stored response ready to be replayed to a client.
pub struct CachedResponse {
    pub status: u16,
    pub content_type: String,
    pub body: Vec<u8>,
}

/// Creates the `cache` table if it does not already exist.
///
/// # Errors
/// Returns any `rusqlite` error raised while executing the schema batch.
pub fn init_schema(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS cache (
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
}

/// Computes the cache key for a request: `sha256(method \n path_and_query \n body)`.
///
/// Newline separators keep the components unambiguous so distinct requests
/// cannot collide by concatenation.
pub fn cache_key(method: &str, path_and_query: &str, body: &[u8]) -> String {
    let mut h = Sha256::new();
    h.update(method.as_bytes());
    h.update(b"\n");
    h.update(path_and_query.as_bytes());
    h.update(b"\n");
    h.update(body);
    to_hex(&h.finalize())
}

/// Looks up a cached response and, on a hit, increments its hit counter.
///
/// Returns `None` on a miss or if the database lock/query fails (the proxy
/// treats any lookup failure as a miss and forwards upstream).
pub fn get(db: &Mutex<Connection>, key: &str) -> Option<CachedResponse> {
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

/// Inserts or replaces a cached response, preserving any existing hit count.
///
/// Failures are silently ignored: a cache write is best-effort and must never
/// break the request it is observing.
#[allow(clippy::too_many_arguments)]
pub fn put(
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cache_key_is_stable_and_path_sensitive() {
        let a = cache_key("POST", "/v1/chat", b"{\"x\":1}");
        let b = cache_key("POST", "/v1/chat", b"{\"x\":1}");
        let c = cache_key("POST", "/v1/other", b"{\"x\":1}");
        assert_eq!(a, b);
        assert_ne!(a, c);
        assert_eq!(a.len(), 64); // sha256 hex
    }

    #[test]
    fn round_trips_through_sqlite() {
        let db = Mutex::new(Connection::open_in_memory().unwrap());
        init_schema(&db.lock().unwrap()).unwrap();
        put(&db, "k1", "openai", "gpt", "hi", 200, "application/json", b"body");
        let got = get(&db, "k1").expect("hit");
        assert_eq!(got.status, 200);
        assert_eq!(got.body, b"body");
        assert!(get(&db, "missing").is_none());
    }
}
