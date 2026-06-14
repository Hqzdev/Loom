//! Read path: assemble `TraceSnapshot` / `SessionListDto` from stored rows.

use std::{
    collections::HashMap,
    sync::{Arc, Mutex},
};

use rusqlite::Connection;

use loom_domain::{SessionListDto, TraceSnapshot};

use super::node::row_to_node;
use super::sessions::{ensure_current_session, find_session, session_to_dto};
use super::store::TraceRow;

/// Loads the latest 500 calls for a session (the current one when unspecified)
/// and lays them out as graph nodes, normalizing the latency bars.
pub(super) fn fetch_snapshot(
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
                tool_use_ids: row
                    .get::<_, Option<String>>(23)?
                    .unwrap_or_else(|| "[]".to_string()),
                context_inputs: row
                    .get::<_, Option<String>>(24)?
                    .unwrap_or_else(|| "{}".to_string()),
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

/// Walks parent links to assign a tree depth (root = 0) to every span.
fn compute_depths(rows: &[TraceRow]) -> HashMap<String, i64> {
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
                break;
            }
            depth += 1;
            guard += 1;
            current = parents.get(parent).copied().flatten();
        }
        depths.insert(row.id.clone(), depth);
    }
    depths
}

/// Lists all sessions (newest first) plus the id of the current one.
pub(super) fn fetch_sessions(db: &Arc<Mutex<Connection>>) -> rusqlite::Result<SessionListDto> {
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::trace::{schema, sessions};

    /// Verifies snapshot readback order and latency bar normalization.
    #[test]
    fn fetch_snapshot_orders_nodes_and_normalizes_latency() {
        let db = Arc::new(Mutex::new(Connection::open_in_memory().unwrap()));
        let session_id = {
            let conn = db.lock().unwrap();
            schema::init_schema(&conn).unwrap();
            let session = sessions::ensure_current_session(&conn).unwrap();
            insert_row(&conn, &session.id, "a", 1_000, 100, "miss");
            insert_row(&conn, &session.id, "b", 2_000, 200, "hit");
            session.id
        };

        let snapshot = fetch_snapshot(&db, None).unwrap();

        assert_eq!(snapshot.session.as_ref().map(|s| &s.id), Some(&session_id));
        assert_eq!(snapshot.nodes.len(), 2);
        assert_eq!(snapshot.nodes[0].id, "a");
        assert_eq!(snapshot.nodes[0].bar_percent, 0.5);
        assert_eq!(snapshot.nodes[1].id, "b");
        assert_eq!(snapshot.nodes[1].status, "cached");
        assert_eq!(snapshot.nodes[1].bar_percent, 1.0);
    }

    /// Inserts one complete trace row for query-path tests.
    fn insert_row(
        conn: &Connection,
        session_id: &str,
        id: &str,
        created_at: i64,
        latency_ms: i64,
        cache_status: &str,
    ) {
        conn.execute(
            "INSERT INTO trace_calls
                (id, session_id, created_at, provider, method, path, model, status_code,
                 cache_status, latency_ms, request_id, prompt_system, prompt_user,
                 response_text, response_language, tokens_in, tokens_out, cost)
             VALUES (?1, ?2, ?3, 'openai', 'POST', '/v1/responses', 'gpt-5.5', 200,
                     ?4, ?5, 'req', '', 'hello', 'world', 'text', 3, 4, '$0.0001')",
            (id, session_id, created_at, cache_status, latency_ms),
        )
        .unwrap();
    }
}
