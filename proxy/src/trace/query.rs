//! Read path: assemble `TraceSnapshot` from stored rows.

use std::{
    collections::HashMap,
    sync::{Arc, Mutex},
};

use rusqlite::Connection;

use tether_domain::{AgentNodeDto, TraceSnapshot};

use super::node::row_to_node;
use super::store_row::TraceRow;

/// Loads recent calls and lays them out as graph nodes, normalizing latency bars.
pub(super) fn fetch_snapshot(db: &Arc<Mutex<Connection>>) -> rusqlite::Result<TraceSnapshot> {
    fetch_snapshot_with_payload(db, true)
}

/// Loads a lightweight snapshot for graph polling without large prompt/response payloads.
pub(super) fn fetch_snapshot_summary(
    db: &Arc<Mutex<Connection>>,
) -> rusqlite::Result<TraceSnapshot> {
    fetch_snapshot_with_payload(db, false)
}

fn fetch_snapshot_with_payload(
    db: &Arc<Mutex<Connection>>,
    include_payload: bool,
) -> rusqlite::Result<TraceSnapshot> {
    let conn = db.lock().expect("trace database lock poisoned");
    let payload_columns = if include_payload {
        "prompt_system, prompt_user, response_text, response_language,
         error_code, error_message, error_detail, tool_use_ids, context_inputs"
    } else {
        "'' AS prompt_system, '' AS prompt_user, '' AS response_text, response_language,
         error_code, error_message, '' AS error_detail, '[]' AS tool_use_ids, '{}' AS context_inputs"
    };
    let sql = format!(
        "SELECT id, created_at, provider, method, path, model, status_code, cache_status,
                latency_ms, request_id, {payload_columns}, tokens_in, tokens_out,
                cost, temperature, trace_id, parent_span_id, input_hash, stale
         FROM trace_calls
         ORDER BY created_at ASC
         LIMIT 5000"
    );
    let mut stmt = conn.prepare(&sql)?;
    let rows = stmt
        .query_map([], trace_row_from_query)?
        .collect::<rusqlite::Result<Vec<_>>>()?;

    let rows = collapse_rows_to_requests(rows);
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
        .map(|row| row_to_node(depths.get(&row.id).copied().unwrap_or(0), row, max_latency))
        .collect();

    Ok(TraceSnapshot {
        nodes,
        stale_node_ids,
    })
}

/// Loads the full payload for a single node selected in the inspector.
pub(super) fn fetch_node_detail(
    db: &Arc<Mutex<Connection>>,
    node_id: String,
) -> rusqlite::Result<Option<AgentNodeDto>> {
    let conn = db.lock().expect("trace database lock poisoned");
    let mut stmt = conn.prepare(
        "SELECT id, created_at, provider, method, path, model, status_code, cache_status,
                latency_ms, request_id, prompt_system, prompt_user, response_text,
                response_language, error_code, error_message, error_detail, tool_use_ids,
                context_inputs, tokens_in, tokens_out, cost, temperature, trace_id,
                parent_span_id, input_hash, stale
         FROM trace_calls
         WHERE id = ?1 OR trace_id = ?1
         ORDER BY created_at ASC",
    )?;
    let rows = stmt
        .query_map([node_id.as_str()], trace_row_from_query)?
        .collect::<rusqlite::Result<Vec<_>>>()?;
    let Some(trace_row) = collapse_rows_to_requests(rows).into_iter().next() else {
        return Ok(None);
    };

    let max_latency = trace_row.latency_ms.max(1);
    Ok(Some(row_to_node(0, trace_row, max_latency)))
}

fn trace_row_from_query(row: &rusqlite::Row<'_>) -> rusqlite::Result<TraceRow> {
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
        tool_use_ids: row
            .get::<_, Option<String>>(17)?
            .unwrap_or_else(|| "[]".to_string()),
        context_inputs: row
            .get::<_, Option<String>>(18)?
            .unwrap_or_else(|| "{}".to_string()),
        tokens_in: row.get(19)?,
        tokens_out: row.get(20)?,
        cost: row.get(21)?,
        temperature: row.get(22)?,
        trace_id: row.get::<_, Option<String>>(23)?.unwrap_or_default(),
        parent_span_id: row.get(24)?,
        input_hash: row.get::<_, Option<String>>(25)?.unwrap_or_default(),
        stale: row.get::<_, Option<i64>>(26)?.unwrap_or(0) != 0,
        request_body: Vec::new(),
        request_target: String::new(),
        tool_result_ids: Vec::new(),
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

/// Collapses provider-level calls into user-request nodes. A multi-step agent
/// run shares one `trace_id`, so the UI shows it as one chat-like request even
/// when the proxy captured several underlying LLM/tool calls.
fn collapse_rows_to_requests(rows: Vec<TraceRow>) -> Vec<TraceRow> {
    let mut groups: Vec<RequestGroup> = Vec::new();

    for row in rows {
        let key = request_key(&row);
        if let Some(group) = groups.iter_mut().find(|group| group.key == key) {
            group.merge(row);
        } else {
            groups.push(RequestGroup::new(key, row));
        }
    }

    groups.into_iter().map(RequestGroup::finish).collect()
}

fn request_key(row: &TraceRow) -> String {
    if row.trace_id.is_empty() {
        row.id.clone()
    } else {
        row.trace_id.clone()
    }
}

struct RequestGroup {
    key: String,
    row: TraceRow,
    raw_call_count: usize,
}

impl RequestGroup {
    fn new(key: String, mut row: TraceRow) -> Self {
        if row.trace_id.is_empty() {
            row.trace_id = key.clone();
        }
        row.parent_span_id = None;
        Self {
            key,
            row,
            raw_call_count: 1,
        }
    }

    fn merge(&mut self, row: TraceRow) {
        self.raw_call_count += 1;
        self.row.latency_ms += row.latency_ms.max(0);
        self.row.tokens_in += row.tokens_in.max(0);
        self.row.tokens_out += row.tokens_out.max(0);
        self.row.cost = sum_costs(&self.row.cost, &row.cost);
        self.row.stale = self.row.stale || row.stale;

        if !row.response_text.is_empty() {
            self.row.response_text = row.response_text;
            self.row.response_language = row.response_language;
        }

        if row.status_code < 200 || row.status_code > 299 {
            self.row.status_code = row.status_code;
            self.row.error_code = row.error_code;
            self.row.error_message = row.error_message;
            self.row.error_detail = row.error_detail;
        }

        if self.row.cache_status == "hit" && row.cache_status != "hit" {
            self.row.cache_status = row.cache_status;
        }
    }

    fn finish(mut self) -> TraceRow {
        self.row.id = self.key.clone();
        self.row.trace_id = self.key;
        self.row.parent_span_id = None;
        if self.raw_call_count > 1 {
            self.row.path = format!("request ({} calls)", self.raw_call_count);
        }
        self.row
    }
}

fn sum_costs(lhs: &str, rhs: &str) -> String {
    let total = parse_cost(lhs) + parse_cost(rhs);
    format!("${total:.4}")
}

fn parse_cost(value: &str) -> f64 {
    value.trim_start_matches('$').parse::<f64>().unwrap_or(0.0)
}
