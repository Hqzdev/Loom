# Tether Local Proxy API

This folder contains the committed OpenAPI contract served by the proxy at
`GET /openapi.json`.

## Endpoint groups

- `GET /openapi.json` — returns `openapi.json`.
- `/api/sessions` — list and create trace sessions.
- `/api/traces/current` — read or clear the UI-readable trace graph.
- `/api/traces/{id}/output` — edit a node response and mark descendants stale.
- `/api/traces/{id}/downstream` — preview descendants affected by a node edit.
- `/api/traces/{id}/replay` — replay a retained node request and refresh its output.
- `/api/cache` — clear cached upstream LLM responses.
- `/api/auth/*` — local registration/login and Google OAuth.
- `/api/settings/*` — authenticated profile, app preferences, and encrypted provider keys.

## Contract source

For Phase 4 this file is the reviewable API artifact. The proxy serves the same committed
JSON with `include_str!`, so the checked-in spec and runtime endpoint stay identical.

Later `loom-contracts`/`utoipa` work can replace this static artifact with generated output
while keeping the same `docs/api/openapi.json` review target.
