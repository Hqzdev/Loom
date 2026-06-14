# 0002 — Trait-based service boundaries

**Status:** Accepted (2026-06-14)

## Context

Following [0001](./0001-modular-monolith.md), the backend is split into service crates
(`loom-cache`, `loom-trace`, `loom-sessions`, `loom-auth`, `loom-settings`, `loom-gateway`).
These services must collaborate (e.g. the gateway needs the cache and must hand captured
calls to the trace service) without:

1. creating crate dependency cycles, or
2. hard-wiring one service to another's concrete implementation (which would block testing
   and any future transport change).

## Decision

Define each service's public surface as a **trait** in a shared `loom-contracts` crate, e.g.
`CacheService`, `TraceService`, `TraceSink`, `SessionService`. Service crates *implement*
their trait; callers depend only on the trait (held as `Arc<dyn Trait>`). The **composition
root** (`src/main.rs`) is the single place that constructs concrete implementations and injects
them.

`loom-contracts` depends only on `loom-domain` (pure types), so it breaks any potential cycle:
services depend on contracts, never on each other.

## Consequences

- **Positive:** services are unit-testable with mock/fake implementations of the traits.
- **Positive:** transport is an implementation detail. Today the binding is an in-process
  struct; a future cloud mode can supply an HTTP/gRPC client implementing the *same* trait,
  with only the composition root changing.
- **Positive:** no dependency cycles — the build graph stays a DAG rooted at `loom-domain`.
- **Negative:** an extra indirection (`dyn` dispatch) on cross-service calls; negligible
  outside the proxy hot path, and the hot path is addressed separately by async ingestion
  (planned ADR-0003).
- **Negative:** contracts and domain types must be kept stable-ish; churn there ripples to
  all implementers. Mitigated by keeping `loom-domain` minimal and DTO-focused.
