//! SQLite helpers for replay and invalidation endpoints.

use std::collections::{HashMap, HashSet, VecDeque};

use axum::http::StatusCode;
use rusqlite::{Connection, OptionalExtension, params};

use super::replay_types::{
    DownstreamResult, InvalidationResult, ReplayResult, ReplaySpec, ReplayUpdate,
};
use crate::context::short_hash;

/// Maps a node lookup or storage error to an HTTP response pair.
pub(super) fn map_node_error(message: String) -> (StatusCode, String) {
    if message == "trace node not found" {
        (StatusCode::NOT_FOUND, message)
    } else {
        (StatusCode::INTERNAL_SERVER_ERROR, message)
    }
}

/// Edits a node response and marks all descendants stale.
pub(super) fn edit_output_result(
    conn: &Connection,
    id: String,
    output: String,
) -> Result<InvalidationResult, String> {
    let previous_output = node_response_text(conn, &id)?;
    let previous_output_hash = short_hash(previous_output.as_bytes());
    let output_hash = short_hash(output.as_bytes());
    conn.execute(
        "UPDATE trace_calls SET response_text = ?1 WHERE id = ?2",
        params![output, id],
    )
    .map_err(|error| error.to_string())?;
    let invalidated = descendants(conn, &id).map_err(|e| e.to_string())?;
    mark_stale(conn, &invalidated).map_err(|e| e.to_string())?;
    Ok(InvalidationResult {
        node_id: id,
        reason: "mocked-output-edited".to_string(),
        previous_output_hash,
        output_hash,
        invalidated,
    })
}

/// Returns downstream descendants for a node.
pub(super) fn downstream_result(conn: &Connection, id: String) -> Result<DownstreamResult, String> {
    let downstream = descendants(conn, &id).map_err(|e| e.to_string())?;
    Ok(DownstreamResult {
        node_id: id,
        downstream,
    })
}

/// Loads the replayable request fields for a node.
pub(super) fn load_replay_spec(conn: &Connection, id: &str) -> Result<ReplaySpec, String> {
    conn.query_row(
        "SELECT method, provider, request_target, model, request_body
         FROM trace_calls WHERE id = ?1",
        [id],
        |row| {
            Ok(ReplaySpec {
                method: row.get(0)?,
                provider: row.get(1)?,
                target: row.get::<_, Option<String>>(2)?.unwrap_or_default(),
                model: row.get(3)?,
                body: row.get::<_, Option<Vec<u8>>>(4)?.unwrap_or_default(),
            })
        },
    )
    .optional()
    .map_err(|error| error.to_string())?
    .ok_or_else(|| "trace node not found".to_string())
}

/// Persists replay output and marks descendants stale.
pub(super) fn persist_replay_result(
    conn: &Connection,
    update: ReplayUpdate,
) -> Result<ReplayResult, String> {
    let previous_output = node_response_text(conn, &update.node_id)?;
    let previous_output_hash = short_hash(previous_output.as_bytes());
    let output_hash = short_hash(update.response_text.as_bytes());
    conn.execute(
        "UPDATE trace_calls
         SET response_text = ?1, response_language = ?2, tokens_in = ?3, tokens_out = ?4,
             cost = ?5, status_code = ?6, latency_ms = ?7, cache_status = 'miss',
             tool_use_ids = ?8, request_id = ?9, stale = 0
         WHERE id = ?10",
        params![
            update.response_text,
            update.response_language,
            update.tokens_in,
            update.tokens_out,
            update.cost,
            i64::from(update.status_code),
            update.latency_ms,
            update.tool_use_ids,
            update.request_id,
            update.node_id,
        ],
    )
    .map_err(|error| error.to_string())?;
    let invalidated = descendants(conn, &update.node_id).map_err(|e| e.to_string())?;
    mark_stale(conn, &invalidated).map_err(|e| e.to_string())?;
    Ok(ReplayResult {
        node_id: update.node_id,
        reason: "upstream-replay-refreshed-output".to_string(),
        previous_output_hash,
        output_hash,
        status_code: update.status_code,
        cost: update.cost,
        tokens_in: update.tokens_in,
        tokens_out: update.tokens_out,
        invalidated,
    })
}

/// Reads the current stored response text for output-hash diffs.
fn node_response_text(conn: &Connection, id: &str) -> Result<String, String> {
    conn.query_row(
        "SELECT response_text FROM trace_calls WHERE id = ?1",
        [id],
        |row| row.get::<_, Option<String>>(0),
    )
    .optional()
    .map_err(|error| error.to_string())?
    .map(|text| text.unwrap_or_default())
    .ok_or_else(|| "trace node not found".to_string())
}

/// Returns all transitive descendants of a trace node.
fn descendants(conn: &Connection, root_id: &str) -> rusqlite::Result<Vec<String>> {
    let mut stmt = conn.prepare("SELECT id, parent_span_id FROM trace_calls")?;
    let edges = stmt
        .query_map([], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, Option<String>>(1)?))
        })?
        .collect::<rusqlite::Result<Vec<_>>>()?;

    let children = children_by_parent(&edges);
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

/// Builds parent-to-children lookup edges for descendant traversal.
fn children_by_parent(edges: &[(String, Option<String>)]) -> HashMap<String, Vec<String>> {
    let mut children: HashMap<String, Vec<String>> = HashMap::new();
    for (id, parent) in edges {
        if let Some(parent) = parent {
            children.entry(parent.clone()).or_default().push(id.clone());
        }
    }
    children
}

/// Marks trace nodes stale after an upstream edit or replay.
fn mark_stale(conn: &Connection, ids: &[String]) -> rusqlite::Result<()> {
    for id in ids {
        conn.execute("UPDATE trace_calls SET stale = 1 WHERE id = ?1", [id])?;
    }
    Ok(())
}
