//! SQLite helpers for replay and invalidation endpoints.

use std::collections::{HashMap, HashSet, VecDeque};

use axum::http::StatusCode;
use rusqlite::{Connection, OptionalExtension, params};

use super::replay_types::{
    DownstreamResult, InvalidationResult, ReplayResult, ReplaySpec, ReplayUpdate, ReplayWithInsert,
    ReplayWithResult, ReplayWithSpec,
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
    workspace_id: &str,
    id: String,
    output: String,
) -> Result<InvalidationResult, String> {
    let previous_output = node_response_text(conn, workspace_id, &id)?;
    let previous_output_hash = short_hash(previous_output.as_bytes());
    let output_hash = short_hash(output.as_bytes());
    conn.execute(
        "UPDATE trace_calls SET response_text = ?1 WHERE id = ?2 AND workspace_id = ?3",
        params![output, id, workspace_id],
    )
    .map_err(|error| error.to_string())?;
    let invalidated = descendants(conn, workspace_id, &id).map_err(|e| e.to_string())?;
    mark_stale(conn, workspace_id, &invalidated).map_err(|e| e.to_string())?;
    Ok(InvalidationResult {
        node_id: id,
        reason: "mocked-output-edited".to_string(),
        previous_output_hash,
        output_hash,
        invalidated,
    })
}

/// Returns downstream descendants for a node.
pub(super) fn downstream_result(
    conn: &Connection,
    workspace_id: &str,
    id: String,
) -> Result<DownstreamResult, String> {
    ensure_node(conn, workspace_id, &id)?;
    let downstream = descendants(conn, workspace_id, &id).map_err(|e| e.to_string())?;
    Ok(DownstreamResult {
        node_id: id,
        downstream,
    })
}

/// Loads the replayable request fields for a node.
pub(super) fn load_replay_spec(
    conn: &Connection,
    workspace_id: &str,
    id: &str,
) -> Result<ReplaySpec, String> {
    conn.query_row(
        "SELECT method, provider, request_target, model, request_body
         FROM trace_calls WHERE id = ?1 AND workspace_id = ?2",
        params![id, workspace_id],
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

/// Loads source request fields for a cross-model replay.
pub(super) fn load_replay_with_spec(
    conn: &Connection,
    workspace_id: &str,
    id: &str,
) -> Result<ReplayWithSpec, String> {
    conn.query_row(
        "SELECT id, COALESCE(trace_id, ''), parent_span_id, prompt_system, prompt_user,
                COALESCE(context_inputs, '{}'), COALESCE(input_hash, ''), temperature,
                request_body
         FROM trace_calls WHERE id = ?1 AND workspace_id = ?2",
        params![id, workspace_id],
        |row| {
            let source_id: String = row.get(0)?;
            let trace_id: String = row.get(1)?;
            Ok(ReplayWithSpec {
                id: source_id.clone(),
                trace_id: if trace_id.is_empty() {
                    source_id
                } else {
                    trace_id
                },
                parent_span_id: row.get(2)?,
                prompt_system: row.get(3)?,
                prompt_user: row.get(4)?,
                context_inputs: row.get(5)?,
                input_hash: row.get(6)?,
                temperature: row.get(7)?,
                body: row.get::<_, Option<Vec<u8>>>(8)?.unwrap_or_default(),
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
    workspace_id: &str,
    update: ReplayUpdate,
) -> Result<ReplayResult, String> {
    let previous_output = node_response_text(conn, workspace_id, &update.node_id)?;
    let previous_output_hash = short_hash(previous_output.as_bytes());
    let output_hash = short_hash(update.response_text.as_bytes());
    conn.execute(
        "UPDATE trace_calls
         SET response_text = ?1, response_language = ?2, tokens_in = ?3, tokens_out = ?4,
             cost = ?5, status_code = ?6, latency_ms = ?7, cache_status = 'miss',
             tool_use_ids = ?8, request_id = ?9, stale = 0
         WHERE id = ?10 AND workspace_id = ?11",
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
            workspace_id,
        ],
    )
    .map_err(|error| error.to_string())?;
    let invalidated =
        descendants(conn, workspace_id, &update.node_id).map_err(|e| e.to_string())?;
    mark_stale(conn, workspace_id, &invalidated).map_err(|e| e.to_string())?;
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

/// Inserts a new trace row for a CometAPI cross-model replay.
pub(super) fn insert_replay_with_result(
    conn: &Connection,
    insert: ReplayWithInsert,
    workspace_id: &str,
) -> Result<ReplayWithResult, String> {
    conn.execute(
        "INSERT INTO trace_calls
            (id, created_at, provider, method, path, model, status_code, cache_status,
             latency_ms, request_id, prompt_system, prompt_user, response_text,
             response_language, error_code, error_message, error_detail, tokens_in,
             tokens_out, cost, temperature, trace_id, parent_span_id, tool_use_ids,
             context_inputs, input_hash, stale, request_body, request_target,
             is_replay, replay_source_id, replay_provider, workspace_id)
         VALUES (?1, strftime('%s','now') * 1000, 'cometapi', 'POST', '/v1/chat/completions',
                 ?2, ?3, 'replay', ?4, ?5, ?6, ?7, ?8, ?9, NULL, NULL, NULL,
                 ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, 0, ?19,
                 '/chat/completions', 1, ?20, 'cometapi', ?21)",
        params![
            insert.id.as_str(),
            insert.model.as_str(),
            i64::from(insert.status_code),
            insert.latency_ms,
            insert.request_id.as_str(),
            insert.prompt_system.as_str(),
            insert.prompt_user.as_str(),
            insert.response_text.as_str(),
            insert.response_language.as_str(),
            insert.tokens_in,
            insert.tokens_out,
            insert.cost.as_str(),
            insert.temperature,
            insert.trace_id.as_str(),
            insert.parent_span_id.as_deref(),
            insert.tool_use_ids.as_str(),
            insert.context_inputs.as_str(),
            insert.input_hash.as_str(),
            insert.request_body.as_slice(),
            insert.source_node_id.as_str(),
            workspace_id,
        ],
    )
    .map_err(|error| error.to_string())?;

    let node_id = insert.id;
    Ok(ReplayWithResult {
        new_trace_id: node_id.clone(),
        node_id,
        source_node_id: insert.source_node_id,
        model: insert.model,
        response_text: insert.response_text,
        latency_ms: insert.latency_ms,
        cost_usd: cost_to_usd(&insert.cost),
        input_tokens: insert.tokens_in,
        output_tokens: insert.tokens_out,
    })
}

/// Reads the current stored response text for output-hash diffs.
fn node_response_text(conn: &Connection, workspace_id: &str, id: &str) -> Result<String, String> {
    conn.query_row(
        "SELECT response_text FROM trace_calls WHERE id = ?1 AND workspace_id = ?2",
        params![id, workspace_id],
        |row| row.get::<_, Option<String>>(0),
    )
    .optional()
    .map_err(|error| error.to_string())?
    .map(|text| text.unwrap_or_default())
    .ok_or_else(|| "trace node not found".to_string())
}

/// Returns all transitive descendants of a trace node.
fn descendants(
    conn: &Connection,
    workspace_id: &str,
    root_id: &str,
) -> rusqlite::Result<Vec<String>> {
    let mut stmt =
        conn.prepare("SELECT id, parent_span_id FROM trace_calls WHERE workspace_id = ?1")?;
    let edges = stmt
        .query_map([workspace_id], |row| {
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
fn mark_stale(conn: &Connection, workspace_id: &str, ids: &[String]) -> rusqlite::Result<()> {
    for id in ids {
        conn.execute(
            "UPDATE trace_calls SET stale = 1 WHERE id = ?1 AND workspace_id = ?2",
            params![id, workspace_id],
        )?;
    }
    Ok(())
}

fn ensure_node(conn: &Connection, workspace_id: &str, id: &str) -> Result<(), String> {
    let exists: Option<i64> = conn
        .query_row(
            "SELECT 1 FROM trace_calls WHERE id = ?1 AND workspace_id = ?2",
            params![id, workspace_id],
            |row| row.get(0),
        )
        .optional()
        .map_err(|error| error.to_string())?;
    exists
        .map(|_| ())
        .ok_or_else(|| "trace node not found".to_string())
}

fn cost_to_usd(cost: &str) -> f64 {
    cost.trim_start_matches('$').parse::<f64>().unwrap_or(0.0)
}
