# 0001 — Modular monolith over networked microservices

**Status:** Accepted (2026-06-14)

## Context

Loom/Tether is a **local-first desktop debugger**. The Rust proxy and the SwiftUI app run on
the user's own machine. The backend has grown into a few god files (`trace.rs` 964 lines,
`main.rs` 483, `auth/mod.rs` 380) that mix routing, persistence, summarization, auth, and
settings, making the code hard to read, test, and evolve.

We want the maintainability benefits associated with microservices — single responsibility,
explicit boundaries, independent testability — but the system has **no operational need** for
network-distributed services. Splitting into separately-deployed processes would add
serialization cost, inter-process latency, and deployment complexity for a tool whose whole
value proposition is running locally and privately.

## Decision

Adopt a **modular monolith**: a Cargo workspace of small, single-responsibility crates
("services") that are composed into **one process** (`loom-proxy`) at startup. Each crate is
independently compilable and testable. The SwiftUI app receives the same treatment — feature-
scoped modules with hard boundaries, but one app.

Every source file targets **≤200 lines**, split along real concern boundaries.

## Consequences

- **Positive:** dramatically more readable code; isolated unit tests; clear ownership; no
  network/serialization overhead; faster onboarding.
- **Positive:** boundaries are drawn so a service *could* later become a network service
  (cloud/team mode) without rewriting its logic — see [0002](./0002-trait-based-service-boundaries.md).
- **Negative:** more files and crates to navigate; a workspace build graph to maintain.
- **Negative:** discipline required to keep crates from reaching into each other's internals;
  enforced via the dependency direction in `docs/architecture/02-target-architecture.md`.
- **Neutral:** the public HTTP API and on-disk SQLite schema are unchanged by this decision.
