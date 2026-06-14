# 0003 — Async trace ingestion to decouple the proxy hot path

**Status:** Accepted (2026-06-14)

## Context

The proxy fallback route forwards LLM traffic and tees the upstream response back to the
client. Before this decision, cache hits, upstream errors, and completed response streams
persisted trace rows by awaiting `spawn_blocking` SQLite writes from the request path or the
streaming task. That coupled user-visible forwarding latency to trace summarization and
SQLite availability.

Phase 3 of the migration plan requires the forward path to stop blocking on trace writes
while preserving the local-first modular monolith: one process, no network hop between
gateway and trace logic.

## Decision

Introduce an in-process bounded `tokio::sync::mpsc` channel behind `TraceSink`.

The gateway/proxy path now builds a captured trace event and calls `try_send`. A background
ingestion worker receives events in order and performs the existing blocking persistence
path: summarize response, estimate cost, resolve the current session, and insert into
`trace_calls`.

The channel is bounded and best-effort. If it is full or closed, the proxy drops the trace
event and keeps forwarding. Trace observability must not take priority over returning the
client's response.

## Consequences

- **Positive:** forwarding no longer awaits trace SQLite writes on cache hits, upstream
  errors, or completed response streams.
- **Positive:** trace ingestion is isolated behind a testable sink/worker boundary that can
  later become the `loom-contracts::TraceSink` trait without changing gateway behavior.
- **Positive:** bounded buffering prevents unbounded memory growth if trace persistence falls
  behind a burst of proxy traffic.
- **Negative:** trace capture becomes best-effort under overload; a saturated channel can
  drop trace events.
- **Negative:** cached response writes still run as background blocking work after a complete
  miss, because cache availability is a separate concern from trace observability.
