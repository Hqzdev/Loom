//! Completion handling for gateway response streams.

use std::{
    sync::{Arc, Mutex},
    time::Instant,
};

use rusqlite::Connection;

use crate::trace::{TraceCapture, TraceResponse, TraceSink};

/// Owned context needed after the upstream stream finishes.
pub(super) struct StreamFinish {
    pub(super) stream_error: Option<String>,
    pub(super) started: Instant,
    pub(super) trace_sink: TraceSink,
    pub(super) cache_db: Arc<Mutex<Connection>>,
    pub(super) capture: TraceCapture,
    pub(super) status_code: u16,
    pub(super) content_type: String,
    pub(super) request_id: Option<String>,
    pub(super) store: bool,
    pub(super) cache_key: String,
    pub(super) provider: String,
    pub(super) model: String,
    pub(super) preview: String,
    pub(super) body: Vec<u8>,
}

impl StreamFinish {
    /// Records trace output and writes cache bytes after streaming completes.
    pub(super) async fn run(self) {
        let latency_ms = self.started.elapsed().as_millis() as i64;
        if let Some(message) = self.stream_error {
            self.trace_sink
                .record_upstream_error(self.capture, message, latency_ms);
            return;
        }

        let trace_body = self.body.clone();
        self.trace_sink.record_response(
            self.capture,
            TraceResponse {
                status_code: self.status_code,
                content_type: self.content_type.clone(),
                header_request_id: self.request_id,
                body: trace_body,
                cache_status: "miss",
                latency_ms,
            },
        );

        if self.store {
            let _ = tokio::task::spawn_blocking(move || {
                tether_cache::put(
                    &self.cache_db,
                    &self.cache_key,
                    &self.provider,
                    &self.model,
                    &self.preview,
                    self.status_code,
                    &self.content_type,
                    &self.body,
                );
            })
            .await;
        }
    }
}
