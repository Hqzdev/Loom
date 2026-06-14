//! Async trace ingestion: the proxy hot path enqueues captured outcomes while
//! a background worker performs blocking SQLite persistence.

use std::sync::{Arc, Mutex};

use rusqlite::Connection;
use tokio::sync::mpsc;

use super::capture::TraceCapture;
use super::store::{record_response, record_upstream_error};

/// Default bounded channel size for in-process trace ingestion.
pub(crate) const DEFAULT_TRACE_CHANNEL_CAPACITY: usize = 1_024;

/// Non-blocking sink used by the proxy path to hand trace work to the worker.
#[derive(Clone)]
pub(crate) struct TraceSink {
    tx: mpsc::Sender<TraceEvent>,
}

impl TraceSink {
    /// Creates a bounded sink plus the receiver consumed by the ingestion worker.
    pub(crate) fn bounded(capacity: usize) -> (Self, mpsc::Receiver<TraceEvent>) {
        let (tx, rx) = mpsc::channel(capacity);
        (Self { tx }, rx)
    }

    /// Enqueues a completed upstream or cached response without awaiting SQLite.
    pub(crate) fn record_response(
        &self,
        capture: TraceCapture,
        status_code: u16,
        content_type: String,
        header_request_id: Option<String>,
        body: Vec<u8>,
        cache_status: &'static str,
        latency_ms: i64,
    ) {
        self.enqueue(
            TraceEvent::Response {
                capture,
                status_code,
                content_type,
                header_request_id,
                body,
                cache_status,
                latency_ms,
            },
            "trace response",
        );
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
            if let Err(error) = tokio::task::spawn_blocking(move || event.persist(&db)).await {
                eprintln!("  trace ingestion worker failed: {error}");
            }
        }
    })
}

/// An owned trace persistence command sent across the bounded channel.
pub(crate) enum TraceEvent {
    Response {
        capture: TraceCapture,
        status_code: u16,
        content_type: String,
        header_request_id: Option<String>,
        body: Vec<u8>,
        cache_status: &'static str,
        latency_ms: i64,
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
            Self::Response {
                capture,
                status_code,
                content_type,
                header_request_id,
                body,
                cache_status,
                latency_ms,
            } => record_response(
                db,
                &capture,
                status_code,
                &content_type,
                header_request_id.as_deref(),
                &body,
                cache_status,
                latency_ms,
            ),
            Self::UpstreamError {
                capture,
                message,
                latency_ms,
            } => record_upstream_error(db, &capture, &message, latency_ms),
        }
    }
}
