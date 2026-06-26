//! Trace service: turns proxied LLM calls into stored, UI-readable traces.
//!
//! The flow splits cleanly across submodules:
//!
//! - [`capture`]  — parse a request into [`TraceCapture`] (model, prompt, preview)
//! - [`summarize`] — distill a response body into text + token counts
//! - [`ingest`]   — queue trace events off the proxy hot path
//! - [`store`]    — write a `trace_calls` row (success / cached / error)
//! - [`query`]    — read rows back into a `TraceSnapshot`
//! - [`node`]     — map a stored row to a UI `AgentNodeDto`
//! - [`schema`]   — migrations / schema bootstrap
//! - [`routes`]   — the Axum HTTP surface
//! - [`text`]     — shared pure string/JSON/time helpers
//!
//! The proxy hot path uses [`TraceCapture`] and [`TraceSink`]; the binary wires
//! routes via [`router`] and starts the ingestion worker at boot.

mod capture;
mod capture_extract;
mod cost;
mod ingest;
mod node;
mod query;
#[cfg(test)]
mod query_tests;
mod replay;
mod replay_headers;
mod replay_store;
mod replay_types;
mod replay_with;
mod retention;
mod routes;
mod schema;
mod store;
mod store_insert;
mod store_row;
mod summarize;
#[cfg(test)]
mod summarize_tests;
mod text;

pub(crate) use capture::{MAX_CAPTURE_BYTES, TraceCapture};
pub(crate) use ingest::{
    DEFAULT_TRACE_CHANNEL_CAPACITY, TraceResponse, TraceSink, spawn_ingest_worker,
};
pub(crate) use retention::{TraceRetention, spawn_retention_worker};
pub(crate) use routes::{response_request_id, router};
pub(crate) use schema::init_schema;
