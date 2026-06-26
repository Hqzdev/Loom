//! Tests for trace snapshot query assembly.

use std::sync::{Arc, Mutex};

use rusqlite::Connection;

use super::{
    query::{fetch_node_detail, fetch_snapshot, fetch_snapshot_summary},
    schema, store_insert,
    store_row::TraceRow,
};
use crate::workspace::DEFAULT_WORKSPACE_ID;

/// Verifies snapshot readback order and latency bar normalization.
#[test]
fn fetch_snapshot_orders_nodes_and_normalizes_latency() {
    let db = Arc::new(Mutex::new(Connection::open_in_memory().unwrap()));
    {
        let conn = db.lock().unwrap();
        schema::init_schema(&conn).unwrap();
        insert_row(&conn, "a", 1_000, 100, "miss");
        insert_row(&conn, "b", 2_000, 200, "hit");
    };

    let snapshot = fetch_snapshot(&db, DEFAULT_WORKSPACE_ID).unwrap();

    assert_eq!(snapshot.nodes.len(), 2);
    assert_eq!(snapshot.nodes[0].id, "a");
    assert_eq!(snapshot.nodes[0].bar_percent, 0.5);
    assert_eq!(snapshot.nodes[1].id, "b");
    assert_eq!(snapshot.nodes[1].status, "cached");
    assert_eq!(snapshot.nodes[1].bar_percent, 1.0);
}

/// Verifies the summary read path preserves graph fields while omitting heavy payloads.
#[test]
fn fetch_snapshot_summary_omits_prompt_and_response_payloads() {
    let db = Arc::new(Mutex::new(Connection::open_in_memory().unwrap()));
    {
        let conn = db.lock().unwrap();
        schema::init_schema(&conn).unwrap();
        insert_row(&conn, "a", 1_000, 100, "miss");
    }

    let snapshot = fetch_snapshot_summary(&db, DEFAULT_WORKSPACE_ID).unwrap();

    assert_eq!(snapshot.nodes.len(), 1);
    assert_eq!(snapshot.nodes[0].id, "a");
    assert_eq!(snapshot.nodes[0].prompt.user, "");
    assert_eq!(snapshot.nodes[0].response.text, "");
}

/// Verifies a selected node can be hydrated with full inspector payloads.
#[test]
fn fetch_node_detail_returns_full_payload_for_selected_node() {
    let db = Arc::new(Mutex::new(Connection::open_in_memory().unwrap()));
    {
        let conn = db.lock().unwrap();
        schema::init_schema(&conn).unwrap();
        insert_row(&conn, "a", 1_000, 100, "miss");
    }

    let node = fetch_node_detail(&db, DEFAULT_WORKSPACE_ID, "a".to_string())
        .unwrap()
        .unwrap();

    assert_eq!(node.prompt.user, "hello");
    assert_eq!(node.response.text, "world");
}

#[test]
fn fetch_snapshot_and_detail_filter_by_workspace() {
    let db = Arc::new(Mutex::new(Connection::open_in_memory().unwrap()));
    {
        let conn = db.lock().unwrap();
        schema::init_schema(&conn).unwrap();
        insert_row(&conn, "a", 1_000, 100, "miss");
        insert_row_in_workspace(&conn, "b", "workspace-b");
    }

    let default_snapshot = fetch_snapshot(&db, DEFAULT_WORKSPACE_ID).unwrap();
    let other_snapshot = fetch_snapshot(&db, "workspace-b").unwrap();
    let hidden_node = fetch_node_detail(&db, DEFAULT_WORKSPACE_ID, "b".to_string()).unwrap();

    assert_eq!(default_snapshot.nodes.len(), 1);
    assert_eq!(default_snapshot.nodes[0].id, "a");
    assert_eq!(other_snapshot.nodes.len(), 1);
    assert_eq!(other_snapshot.nodes[0].id, "b");
    assert!(hidden_node.is_none());
}

/// Verifies multi-call agent traces collapse to one user-request node.
#[test]
fn fetch_snapshot_collapses_trace_steps_into_one_request_node() {
    let db = Arc::new(Mutex::new(Connection::open_in_memory().unwrap()));
    {
        let conn = db.lock().unwrap();
        schema::init_schema(&conn).unwrap();
        insert_row_with_lineage(
            &conn,
            RowSpec {
                id: "root",
                trace_id: "root",
                parent_span_id: None,
                created_at: 1_000,
                latency_ms: 100,
                tokens_in: 3,
                tokens_out: 4,
                cost: "$0.0001",
                prompt_user: "make the change",
                response_text: "first step",
            },
        );
        insert_row_with_lineage(
            &conn,
            RowSpec {
                id: "child",
                trace_id: "root",
                parent_span_id: Some("root"),
                created_at: 2_000,
                latency_ms: 250,
                tokens_in: 5,
                tokens_out: 6,
                cost: "$0.0002",
                prompt_user: "make the change",
                response_text: "done",
            },
        );
    }

    let snapshot = fetch_snapshot(&db, DEFAULT_WORKSPACE_ID).unwrap();

    assert_eq!(snapshot.nodes.len(), 1);
    assert_eq!(snapshot.nodes[0].id, "root");
    assert_eq!(snapshot.nodes[0].depth, 0);
    assert_eq!(snapshot.nodes[0].latency_ms, 350);
    assert_eq!(snapshot.nodes[0].tokens_in, 8);
    assert_eq!(snapshot.nodes[0].tokens_out, 10);
    assert_eq!(snapshot.nodes[0].cost, "$0.0003");
    assert_eq!(snapshot.nodes[0].prompt.user, "make the change");
    assert_eq!(snapshot.nodes[0].response.text, "done");
}

/// Verifies inspector hydration also returns the collapsed final response.
#[test]
fn fetch_node_detail_collapses_trace_steps_into_one_request_node() {
    let db = Arc::new(Mutex::new(Connection::open_in_memory().unwrap()));
    {
        let conn = db.lock().unwrap();
        schema::init_schema(&conn).unwrap();
        insert_row_with_lineage(
            &conn,
            RowSpec {
                id: "root",
                trace_id: "root",
                parent_span_id: None,
                created_at: 1_000,
                latency_ms: 100,
                tokens_in: 3,
                tokens_out: 4,
                cost: "$0.0001",
                prompt_user: "make the change",
                response_text: "first step",
            },
        );
        insert_row_with_lineage(
            &conn,
            RowSpec {
                id: "child",
                trace_id: "root",
                parent_span_id: Some("root"),
                created_at: 2_000,
                latency_ms: 250,
                tokens_in: 5,
                tokens_out: 6,
                cost: "$0.0002",
                prompt_user: "make the change",
                response_text: "done",
            },
        );
    }

    let node = fetch_node_detail(&db, DEFAULT_WORKSPACE_ID, "root".to_string())
        .unwrap()
        .unwrap();

    assert_eq!(node.id, "root");
    assert_eq!(node.response.text, "done");
    assert_eq!(node.latency_ms, 350);
}

/// Verifies traffic is captured without creating session storage.
#[test]
fn insert_trace_row_stores_without_session() {
    let db = Arc::new(Mutex::new(Connection::open_in_memory().unwrap()));
    {
        let conn = db.lock().unwrap();
        schema::init_schema(&conn).unwrap();
    }

    store_insert::insert_trace_row(
        &db,
        trace_row(
            "new-call",
            "Summarize the quarterly roadmap before standup starts",
        ),
        "success",
    );

    let conn = db.lock().unwrap();
    let session_count: i64 = conn
        .query_row(
            "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = 'sessions'",
            [],
            |row| row.get(0),
        )
        .unwrap();
    let call_count: i64 = conn
        .query_row(
            "SELECT COUNT(*) FROM trace_calls WHERE id = 'new-call'",
            [],
            |row| row.get(0),
        )
        .unwrap();

    assert_eq!(session_count, 0);
    assert_eq!(call_count, 1);
}

/// Inserts one complete trace row for query-path tests.
fn insert_row(conn: &Connection, id: &str, created_at: i64, latency_ms: i64, cache_status: &str) {
    conn.execute(
        "INSERT INTO trace_calls
            (id, created_at, provider, method, path, model, status_code,
             cache_status, latency_ms, request_id, prompt_system, prompt_user,
             response_text, response_language, tokens_in, tokens_out, cost)
         VALUES (?1, ?2, 'openai', 'POST', '/v1/responses', 'gpt-5.5', 200,
                 ?3, ?4, 'req', '', 'hello', 'world', 'text', 3, 4, '$0.0001')",
        (id, created_at, cache_status, latency_ms),
    )
    .unwrap();
}

fn insert_row_in_workspace(conn: &Connection, id: &str, workspace_id: &str) {
    conn.execute(
        "INSERT INTO trace_calls
            (id, created_at, provider, method, path, model, status_code,
             cache_status, latency_ms, request_id, prompt_system, prompt_user,
             response_text, response_language, tokens_in, tokens_out, cost, workspace_id)
         VALUES (?1, 2_000, 'openai', 'POST', '/v1/responses', 'gpt-5.5', 200,
                 'miss', 200, 'req', '', 'hello', 'world', 'text', 3, 4, '$0.0001', ?2)",
        (id, workspace_id),
    )
    .unwrap();
}

struct RowSpec<'a> {
    id: &'a str,
    trace_id: &'a str,
    parent_span_id: Option<&'a str>,
    created_at: i64,
    latency_ms: i64,
    tokens_in: i64,
    tokens_out: i64,
    cost: &'a str,
    prompt_user: &'a str,
    response_text: &'a str,
}

/// Inserts one trace row with explicit lineage for collapsed-request tests.
fn insert_row_with_lineage(conn: &Connection, spec: RowSpec<'_>) {
    conn.execute(
        "INSERT INTO trace_calls
            (id, created_at, provider, method, path, model, status_code,
             cache_status, latency_ms, request_id, prompt_system, prompt_user,
             response_text, response_language, tokens_in, tokens_out, cost,
             trace_id, parent_span_id)
         VALUES (?1, ?2, 'openai', 'POST', '/v1/responses', 'gpt-5.5', 200,
                 'miss', ?3, 'req', '', ?4, ?5, 'text', ?6, ?7, ?8, ?9, ?10)",
        (
            spec.id,
            spec.created_at,
            spec.latency_ms,
            spec.prompt_user,
            spec.response_text,
            spec.tokens_in,
            spec.tokens_out,
            spec.cost,
            spec.trace_id,
            spec.parent_span_id,
        ),
    )
    .unwrap();
}

/// Builds one complete trace row for write-path tests.
fn trace_row(id: &str, prompt_user: &str) -> TraceRow {
    TraceRow {
        id: id.to_string(),
        created_at: 1_000,
        provider: "openai".to_string(),
        method: "POST".to_string(),
        path: "/v1/responses".to_string(),
        model: "gpt-5.5".to_string(),
        status_code: 200,
        cache_status: "miss".to_string(),
        latency_ms: 100,
        request_id: "req".to_string(),
        prompt_system: String::new(),
        prompt_user: prompt_user.to_string(),
        response_text: "world".to_string(),
        response_language: "text".to_string(),
        error_code: None,
        error_message: None,
        error_detail: None,
        tokens_in: 3,
        tokens_out: 4,
        cost: "$0.0001".to_string(),
        temperature: None,
        trace_id: String::new(),
        parent_span_id: None,
        tool_use_ids: "[]".to_string(),
        context_inputs: "{}".to_string(),
        input_hash: "input".to_string(),
        stale: false,
        is_replay: false,
        replay_source_id: None,
        replay_provider: None,
        request_body: Vec::new(),
        request_target: "https://api.openai.com/v1/responses".to_string(),
        workspace_id: DEFAULT_WORKSPACE_ID.to_string(),
        tool_result_ids: Vec::new(),
    }
}
