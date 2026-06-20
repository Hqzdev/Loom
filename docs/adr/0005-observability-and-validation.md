# 0005. Observability And Validation Boundaries

## Status

Accepted

## Context

Tether has three runtime surfaces: the Rust proxy, the Swift macOS app, and the Next.js web
site. Logging and validation were present, but local to individual files. That made failures
harder to correlate and left privacy rules implicit.

The proxy is the highest-risk surface because it sees provider traffic, settings updates,
trace ingestion, cache behavior, and upstream failures.

## Decision

The Rust proxy owns the first observability boundary. It emits structured diagnostic events
for service lifecycle, server-side API failures, upstream request failures, invalid local
credential headers, and dropped trace ingestion events.

Validation is owned by the boundary that can enforce it:

- backend request handlers enforce API invariants before persistence or upstream calls;
- Swift forms may validate early for user experience, but backend validation remains the
  source of truth;
- web API routes validate public submissions before storage or email side effects.

Logs must not include provider API keys, raw prompts, raw responses, full feedback bodies, or
other user-controlled sensitive payloads by default.

## Consequences

Diagnostic events are intentionally small and structured. The current implementation avoids a
new logging dependency until the event surface proves large enough to justify one.

Validation helpers are extracted by domain, not by framework. This keeps route handlers thin
and makes future Swift/web parity easier without creating a shared cross-language dependency.
