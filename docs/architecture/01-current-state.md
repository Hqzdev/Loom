# 1. Pre-migration Baseline

A snapshot of the system before the modular-monolith migration, kept so the refactor target is
grounded in the problems it was designed to fix. For current phase status, see
[06-migration-plan](./06-migration-plan.md).

## 1.1 System overview

```
 Agent (Claude Code / Codex / script)
   │  points OPENAI/ANTHROPIC base URL at 127.0.0.1:8080
   ▼
 ┌──────────────────────────────────────────┐
 │  Rust proxy (Axum)  —  proxy/             │   ← the monolith we are decomposing
 │  routing · cache · trace · auth · settings│
 │  SQLite (cache, sessions, trace_calls)    │
 └──────────────────────────────────────────┘
   ▲ REST /api/*
   │
 ┌──────────────────────────────────────────┐
 │  macOS app (SwiftUI + TCA)  —  ui/        │   ← polls /api, renders trace graph
 │  also: CodexLogObserver reads ~/.codex/*  │
 └──────────────────────────────────────────┘
```

## 1.2 Backend — `proxy/` (Rust, Axum, SQLite)

Single binary `loom-proxy`. All concerns live in a flat `src/` with a few large files.

| File | Lines | Concerns crammed together |
|------|------:|---------------------------|
| `src/trace.rs` | 964 | route handlers, response summarization, cost calc, DTOs, SQLite writes, queries |
| `src/main.rs` | 483 | bootstrap, HTTP listener, path routing, upstream forwarding, response tee, cache get/put, cache key |
| `src/auth/mod.rs` | 380 | auth context, JWT issue/verify, middleware, route handlers |
| `src/settings.rs` | 279 | profile, app settings, encrypted key storage, routes |
| `src/auth/oauth.rs` | 237 | Google OAuth flow |
| `src/error.rs` | 72 | `ApiError` → HTTP mapping |
| `src/crypto.rs` | 59 | AES-GCM for stored keys |

**HTTP surface (today):**

```
GET    /api/sessions                      POST   /api/sessions
GET    /api/traces/current                DELETE /api/traces/current
DELETE /api/cache
POST   /api/auth/oauth/google/callback    GET    /api/auth/status
GET    /api/settings/profile              POST   /api/settings/profile/update
GET    /api/settings/app                  POST   /api/settings/app/update
POST   /api/settings/keys
*  (fallback) → transparent proxy to OpenAI/Anthropic
```

**Storage:** SQLite — `cache` (sha256 → response blob), `sessions`, `trace_calls`.

## 1.3 App — `ui/` (SwiftUI + Composable Architecture)

Local Swift package `LoomModules` with products **Core**, **UI**, **Networking**, **App**,
plus the Xcode `Loom` target.

| File | Lines | Notes |
|------|------:|-------|
| `Networking/CodexLogObserver.swift` | 495 | largest file — DB open, SQL, event mapping, snapshot build all in one |
| `Loom/Features/MainLayout/TraceStore.swift` | 356 | `ObservableObject`; status enum + polling + refresh + session ops + snapshot combine |
| `Core/Models/TraceModels.swift` | 297 | every domain model in one file |
| `UI/DesignSystem/AgentTracePalette.swift` | 187 | palette + `LiquidGlassModifier` + `Color(hex:)` |
| `UI/Shared/TraceSharedViews.swift` | 183 | multiple reusable views |
| `UI/SessionList/SessionListView.swift` | 171 | list + row + empty state |
| `Networking/TraceAPIClient.swift` | 139 | HTTP client for all `/api` calls |
| `Inspector/InspectorPane.swift` | ~430 | header, picker, body, metadata table, empty state, button styles |

## 1.4 Pain points the refactor must fix

- **God files.** `trace.rs`, `CodexLogObserver.swift`, `TraceStore.swift` mix 4–6 concerns,
  making them hard to read, test, and change safely.
- **No interface seams.** Handlers talk to SQLite directly; nothing is mockable. Logic and
  persistence are entangled.
- **Duplicated DTO shapes.** Trace DTOs are defined in Rust (`trace.rs`) and again, by hand,
  as `Codable` types in Swift (`TraceModels.swift`) with no single source of truth.
- **Sparse documentation.** Few doc comments; no generated API reference; no OpenAPI spec;
  no architecture decision records.
- **Hot path coupling.** The proxy forward path writes traces inline, coupling latency-
  sensitive forwarding to trace persistence.
