//! Async trace ingestion: the proxy hot path enqueues captured outcomes while
//! a background worker performs blocking SQLite persistence.

use std::sync::{Arc, Mutex};

use rusqlite::Connection;
use tokio::sync::mpsc;

use crate::diagnostics;

use super::capture::TraceCapture;
use super::store::{record_response, record_upstream_error};

/// Default bounded channel size for in-process trace ingestion.
pub(crate) const DEFAULT_TRACE_CHANNEL_CAPACITY: usize = 1_024;

/// Non-blocking sink used by the proxy path to hand trace work to the worker.
#[derive(Clone)]
pub(crate) struct TraceSink {
    tx: mpsc::Sender<TraceEvent>,
}

/// Owned response outcome queued after an upstream or cache response completes.
pub(crate) struct TraceResponse {
    pub(crate) status_code: u16,
    pub(crate) content_type: String,
    pub(crate) header_request_id: Option<String>,
    pub(crate) body: Vec<u8>,
    pub(crate) cache_status: &'static str,
    pub(crate) latency_ms: i64,
}

impl TraceSink {
    /// Creates a bounded sink plus the receiver consumed by the ingestion worker.
    pub(crate) fn bounded(capacity: usize) -> (Self, mpsc::Receiver<TraceEvent>) {
        let (tx, rx) = mpsc::channel(capacity);
        (Self { tx }, rx)
    }

    /// Enqueues a completed upstream or cached response without awaiting SQLite.
    pub(crate) fn record_response(&self, capture: TraceCapture, response: TraceResponse) {
        self.enqueue(TraceEvent::Response { capture, response }, "trace response");
    }

    /// Enqueues a network or stream failure without blocking the caller.
    pub(crate) fn record_upstream_error(
        &self,
        capture: TraceCapture,
        message: String,
        latency_ms: i64,
    ) {
        self.enqueue(
            TraceEvent::UpstreamError {
                capture,
                message,
                latency_ms,
            },
            "trace error",
        );
    }

    /// Drops trace events on overload; forwarding must never wait for tracing.
    fn enqueue(&self, event: TraceEvent, label: &str) {
        if let Err(error) = self.tx.try_send(event) {
            diagnostics::warn(
                "trace_event_dropped",
                serde_json::json!({
                    "label": label,
                    "error": error.to_string()
                }),
            );
            eprintln!("  dropped {label}: trace ingestion channel {error}");
        }
    }
}

/// Spawns the background task that persists trace events in receive order.
pub(crate) fn spawn_ingest_worker(
    db: Arc<Mutex<Connection>>,
    mut rx: mpsc::Receiver<TraceEvent>,
) -> tokio::task::JoinHandle<()> {
    tokio::spawn(async move {
        while let Some(event) = rx.recv().await {
            let db = db.clone();
            match tokio::task::spawn_blocking(move || event.persist(&db)).await {
                Ok(()) => {}
                Err(error) => {
                    diagnostics::error(
                        "trace_ingestion_worker_failed",
                        serde_json::json!({
                            "error": error.to_string()
                        }),
                    );
                    eprintln!("  trace ingestion worker failed: {error}");
                }
            }
        }
    })
}

/// An owned trace persistence command sent across the bounded channel.
pub(crate) enum TraceEvent {
    Response {
        capture: TraceCapture,
        response: TraceResponse,
    },
    UpstreamError {
        capture: TraceCapture,
        message: String,
        latency_ms: i64,
    },
}

impl TraceEvent {
    /// Persists one queued event using the existing blocking store functions.
    fn persist(self, db: &Arc<Mutex<Connection>>) {
        match self {
            Self::Response { capture, response } => record_response(db, &capture, &response),
            Self::UpstreamError {
                capture,
                message,
                latency_ms,
            } => record_upstream_error(db, &capture, &message, latency_ms),
        }
    }
}
