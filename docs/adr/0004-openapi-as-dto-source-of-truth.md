# 0004 — OpenAPI as the review target for wire DTOs

**Status:** Accepted (2026-06-14)

## Context

The Rust proxy and SwiftUI app exchange trace, session, auth, and settings DTOs over the
local HTTP API. Before Phase 4, those shapes were documented mostly by implementation code,
which made API drift hard to spot in review.

The target architecture calls for generated OpenAPI from `loom-contracts`, but the current
codebase has not fully promoted every DTO and route into that crate yet.

## Decision

Commit a reviewable OpenAPI 3 document at `docs/api/openapi.json` and serve the exact same
document at `GET /openapi.json` from the local proxy.

For this phase the spec is a static artifact. Later `loom-contracts`/`utoipa` generation can
replace the static file while preserving the same committed path and runtime route.

## Consequences

- **Positive:** API changes now have a single review target.
- **Positive:** the runtime `/openapi.json` endpoint cannot drift from the committed file
  because it is served with `include_str!`.
- **Positive:** Swift DTO work in Phase 5 can reference a concrete contract.
- **Negative:** until generation lands, maintainers must update `docs/api/openapi.json` when
  handlers or DTO fields change.
- **Negative:** the static spec documents current behavior but is not yet mechanically derived
  from Rust route definitions.
