//! Trace service: turns proxied LLM calls into stored, UI-readable traces.
//!
//! The flow splits cleanly across submodules:
//!
//! - [`capture`]  — parse a request into [`TraceCapture`] (model, prompt, preview)
//! - [`summarize`] — distill a response body into text + token counts
//! - [`store`]    — write a `trace_calls` row (success / cached / error)
//! - [`sessions`] — session lifecycle (resolve current, create, backfill)
//! - [`query`]    — read rows back into a `TraceSnapshot` / session list
//! - [`node`]     — map a stored row to a UI `AgentNodeDto`
//! - [`schema`]   — migrations / schema bootstrap
//! - [`routes`]   — the Axum HTTP surface
//! - [`text`]     — shared pure string/JSON/time helpers
//!
//! The proxy hot path uses [`TraceCapture`], [`record_response`], and
//! [`record_upstream_error`]; the binary wires routes via [`router`].

mod capture;
mod node;
mod query;
mod routes;
mod schema;
mod sessions;
mod store;
mod summarize;
mod text;

pub(crate) use capture::{MAX_CAPTURE_BYTES, TraceCapture};
pub(crate) use routes::{response_request_id, router};
pub(crate) use schema::init_schema;
pub(crate) use store::{record_response, record_upstream_error};
