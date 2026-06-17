//! Write path: turn a capture + outcome into a `trace_calls` row and persist it.

use std::sync::{Arc, Mutex};

use rusqlite::Connection;

use super::capture::TraceCapture;
use super::cost::estimate_cost;
use super::ingest::TraceResponse;
use super::store_insert::insert_trace_row;
use super::store_row::TraceRow;
use super::summarize::summarize_response;
use super::text::utf8_preview;

/// Records a completed (or cached) response against its originating capture.
pub(crate) fn record_response(
    db: &Arc<Mutex<Connection>>,
    capture: &TraceCapture,
    response: &TraceResponse,
) {
    let summary = summarize_response(&response.content_type, &response.body);
    let is_error = !(200..=299).contains(&response.status_code);
    let status = if response.cache_status == "hit" {
        "cached"
    } else if is_error {
        "error"
    } else {
        "success"
    };
    let request_id = response
        .header_request_id
        .as_deref()
        .map(ToOwned::to_owned)
        .or(summary.request_id)
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| capture.request_id.clone());

    let cost = estimate_cost(
        &capture.provider,
        &capture.model,
        summary.tokens_in,
        summary.tokens_out,
    );
    let tool_use_ids =
        serde_json::to_string(&summary.tool_use_ids).unwrap_or_else(|_| "[]".to_string());

    let row = TraceRow {
        id: capture.id.clone(),
        created_at: capture.created_at,
        provider: capture.provider.clone(),
        method: capture.method.clone(),
        path: capture.path.clone(),
        model: capture.model.clone(),
        status_code: i64::from(response.status_code),
        cache_status: response.cache_status.to_string(),
        latency_ms: response.latency_ms,
        request_id,
        prompt_system: capture.prompt_system.clone(),
        prompt_user: capture.prompt_user.clone(),
        response_text: summary.text,
        response_language: summary.language,
        error_code: is_error.then(|| response.status_code.to_string()),
        error_message: is_error.then(|| format!("Upstream returned HTTP {}", response.status_code)),
        error_detail: is_error.then(|| utf8_preview(&response.body)),
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

    insert_trace_row(db, row, status)
}

/// Records a failed upstream call (network error / dropped stream) as an error node.
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

    insert_trace_row(db, row, "error")
}
