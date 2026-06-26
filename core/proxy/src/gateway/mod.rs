//! Transparent reverse proxy gateway for OpenAI/Anthropic-compatible traffic.

mod credentials;
mod http;
mod relay;
mod stream;

use std::time::Instant;

use axum::{
    body::{Body, to_bytes},
    extract::{Request, State},
    http::{Method, StatusCode, header::CONTENT_TYPE},
    response::{IntoResponse, Response},
};
use bytes::Bytes;
use futures_util::StreamExt;
use tokio_stream::wrappers::ReceiverStream;

use crate::{
    AppState, diagnostics,
    logging::{RED, RESET, log_cached, log_request, log_response},
    trace,
};

/// Max request body we buffer for forwarding + logging.
const MAX_BODY: usize = 100 * 1024 * 1024;

/// Catch-all handler: cache, forward, tee, enqueue trace, then optionally store.
pub(crate) async fn proxy(State(state): State<AppState>, req: Request) -> Response {
    let started = Instant::now();
    let (parts, body) = req.into_parts();
    let method = parts.method;
    let uri = parts.uri;
    let path = uri.path().to_string();
    let workspace = match crate::workspace::from_gateway(&parts.headers, &path, uri.query()) {
        Ok(workspace) => workspace,
        Err(message) => return (StatusCode::UNAUTHORIZED, message).into_response(),
    };
    let path_and_query = workspace.path_and_query;

    let (base, label) = if path.starts_with("/v1/messages") {
        (state.anthropic_upstream.clone(), "anthropic")
    } else {
        (state.openai_upstream.clone(), "openai")
    };
    let url = format!("{base}{path_and_query}");
    let body_bytes = match to_bytes(body, MAX_BODY).await {
        Ok(bytes) => bytes,
        Err(error) => {
            diagnostics::warn(
                "request_body_read_failed",
                serde_json::json!({
                    "method": method.as_str(),
                    "path": path,
                    "error": error.to_string()
                }),
            );
            eprintln!("{RED}x failed reading request body: {error}{RESET}\n");
            return (StatusCode::BAD_REQUEST, "tether: cannot read request body").into_response();
        }
    };

    let capture = trace::TraceCapture::from_request(
        method.as_str(),
        &path,
        &path_and_query,
        label,
        &workspace.id,
        &body_bytes,
    );
    let model = capture.model.clone();
    let preview = capture.preview.clone();
    log_request(&method, &path, label, base.as_ref(), &model, &preview);

    let cacheable = state.cache_enabled && method == Method::POST;
    let key = if cacheable {
        tether_cache::cache_key(
            method.as_str(),
            &format!("{}:{path_and_query}", workspace.id),
            &body_bytes,
        )
    } else {
        String::new()
    };

    if cacheable {
        let db = state.db.clone();
        let cache_key = key.clone();
        if let Ok(Some(cached)) =
            tokio::task::spawn_blocking(move || tether_cache::get(&db, &cache_key)).await
        {
            let latency_ms = started.elapsed().as_millis() as i64;
            state.trace_sink.record_response(
                capture.clone(),
                trace::TraceResponse {
                    status_code: cached.status,
                    content_type: cached.content_type.clone(),
                    header_request_id: None,
                    body: cached.body.clone(),
                    cache_status: "hit",
                    latency_ms,
                },
            );
            log_cached(
                StatusCode::from_u16(cached.status).unwrap_or(StatusCode::OK),
                cached.body.len(),
            );
            return http::cached_response(cached);
        }
    }

    let mut headers = http::upstream_headers(&parts.headers);
    credentials::inject(&mut headers, label, &state);

    let upstream = state
        .client
        .request(method, url.as_str())
        .headers(headers)
        .body(body_bytes)
        .send()
        .await;
    let resp = match upstream {
        Ok(response) => response,
        Err(error) => {
            let latency_ms = started.elapsed().as_millis() as i64;
            let message = error.to_string();
            state
                .trace_sink
                .record_upstream_error(capture.clone(), message.clone(), latency_ms);
            diagnostics::warn(
                "upstream_request_failed",
                serde_json::json!({
                    "provider": label,
                    "path": path,
                    "latency_ms": latency_ms,
                    "error": message
                }),
            );
            eprintln!("{RED}< upstream error: {error}{RESET}\n");
            return (
                StatusCode::BAD_GATEWAY,
                format!("tether upstream error: {error}"),
            )
                .into_response();
        }
    };

    let status = resp.status();
    let request_id = trace::response_request_id(resp.headers());
    let content_type = resp
        .headers()
        .get(CONTENT_TYPE)
        .and_then(|value| value.to_str().ok())
        .unwrap_or("")
        .to_string();
    log_response(status, &content_type);

    let out_headers = http::miss_response_headers(resp.headers());
    let store = cacheable && status.is_success();
    let (tx, rx) = tokio::sync::mpsc::channel::<Result<Bytes, reqwest::Error>>(16);
    let cache_db = state.db.clone();
    let trace_sink = state.trace_sink.clone();
    let provider = label.to_string();
    let status_code = status.as_u16();
    let capture_for_stream = capture.clone();

    tokio::spawn(async move {
        let mut acc = Vec::new();
        let mut stream_error = None;
        let mut stream = resp.bytes_stream();
        while let Some(item) = stream.next().await {
            if let Err(message) = relay::chunk(item, &tx, store, &mut acc).await {
                stream_error = message;
                break;
            }
        }
        drop(tx);
        stream::StreamFinish {
            stream_error,
            started,
            trace_sink,
            cache_db,
            capture: capture_for_stream,
            status_code,
            content_type,
            request_id,
            store,
            cache_key: key,
            provider,
            model,
            preview,
            body: acc,
        }
        .run()
        .await;
    });

    let mut response = Response::new(Body::from_stream(ReceiverStream::new(rx)));
    *response.status_mut() = status;
    *response.headers_mut() = out_headers;
    response
}
