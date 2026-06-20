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
 │  SQLite (cache, trace_calls)              │
 └──────────────────────────────────────────┘
   ▲ REST /api/*
   │
 ┌──────────────────────────────────────────┐
 │  macOS app (SwiftUI + TCA)  —  ui/        │   ← polls /api, renders trace graph
 │  also: CodexLogObserver reads ~/.codex/*  │
 └──────────────────────────────────────────┘
```

## 1.2 Backend — `proxy/` (Rust, Axum, SQLite)

Single binary `tether-proxy`. All concerns live in a flat `src/` with a few large files.

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
GET    /api/traces/current                DELETE /api/traces/current
DELETE /api/cache
POST   /api/auth/oauth/google/callback    GET    /api/auth/status
GET    /api/settings/profile              POST   /api/settings/profile/update
GET    /api/settings/app                  POST   /api/settings/app/update
POST   /api/settings/keys
*  (fallback) → transparent proxy to OpenAI/Anthropic
```

**Storage:** SQLite — `cache` (sha256 → response blob), `trace_calls`.

## 1.3 App baseline — `ui/` (SwiftUI + Composable Architecture)

Local Swift package `TetherModules` with products **Core**, **UI**, **Networking**, **App**,
plus the Xcode `Tether` target. The table below records the pre-Phase-5 baseline that drove
the SwiftUI split; those files have since been reorganized into smaller feature and model
files.

| File | Lines | Notes |
|------|------:|-------|
| `Networking/CodexLogObserver.swift` | 495 | split into observer facade + `Networking/Codex/*` helpers |
| `Tether/Features/MainLayout/TraceStore.swift` | 356 | split into store, status, refresh operations, and snapshot combiner |
| `Core/Models/TraceModels.swift` | 297 | replaced by one file per domain model |
| `UI/DesignSystem/AgentTracePalette.swift` | 187 | split into palette, `LiquidGlass`, and `Color+Hex` |
| `UI/Shared/TraceSharedViews.swift` | 183 | multiple reusable views |
| `Networking/TraceAPIClient.swift` | 139 | HTTP client for all `/api` calls |
| `Inspector/InspectorPane.swift` | ~430 | split into header, picker, body, code view, metadata, empty state, and styles |

## 1.4 Pain points the refactor must fix

- **God files.** The original `trace.rs`, `CodexLogObserver.swift`, and `TraceStore.swift`
  mixed 4–6 concerns, making them hard to read, test, and change safely.
- **No interface seams.** Handlers talk to SQLite directly; nothing is mockable. Logic and
  persistence are entangled.
- **Duplicated DTO shapes.** Trace DTOs are defined in Rust and again, by hand, as
  `Codable` types in Swift model files with OpenAPI as the reviewed source of truth.
- **Sparse documentation.** Limited repository reference material; no generated API reference; no OpenAPI spec;
  no architecture decision records.
- **Hot path coupling.** The proxy forward path writes traces inline, coupling latency-
  sensitive forwarding to trace persistence.
