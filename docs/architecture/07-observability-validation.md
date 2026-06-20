# 7. Observability And Validation

## 7.1 Goals

Logging exists to explain runtime behavior without exposing user data. Validation exists to
reject invalid input at the boundary closest to the source of truth.

## 7.2 Rust proxy

The proxy emits structured diagnostic events for:

- startup configuration that is safe to expose;
- server-side API errors;
- upstream request failures;
- invalid locally injected credential headers;
- dropped trace ingestion events;
- trace ingestion worker failures.

The live colored console output remains operator-facing. Structured diagnostic events are for
debugging, collection, and later filtering.

Proxy validation belongs in focused modules below the route layer. Route handlers parse the
request, call validators, perform the side effect, and return typed API errors.

## 7.3 Swift macOS app

Swift validation should make settings forms responsive, but it must not be treated as a
security boundary. Backend validation is still required for every persisted or replayed
operation.

Swift logging should use OSLog categories when introduced:

- networking;
- proxy;
- settings;
- codex;
- replay.

Logs must describe state transitions and failures, not raw payloads.

## 7.4 Next.js web

Web API routes validate public submissions before filesystem writes or email sends.

The minimum policy is:

- normalize email addresses;
- reject invalid email format;
- enforce field length limits;
- treat honeypot submissions as successful no-ops;
- avoid logging full feedback or waitlist bodies.

## 7.5 Privacy rules

Never log:

- provider API keys;
- Authorization or x-api-key headers;
- raw prompts;
- raw model responses;
- full feedback text;
- decrypted settings.

Prefer ids, status codes, durations, provider labels, endpoint names, and short error classes.
