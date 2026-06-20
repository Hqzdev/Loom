# 3. Service Catalog

Each backend service crate, its single responsibility, the interface it exposes (in
`tether-contracts`), the data it owns, and which of today's files it absorbs.

> Convention: every service crate has `lib.rs` (`//!` crate doc), a `routes.rs` (Axum
> handlers, thin), and internal modules for logic. Handlers never touch SQL directly — they
> call the service trait. SQL lives behind `tether-storage` repositories.

## 3.1 `tether-domain`
- **Responsibility:** shared value types and error kinds. Pure data, no I/O, no async, no
  dependency on any other tether crate.
- **Owns:** `AgentNode`, `TraceSnapshot`, `NodeStatus`, `CacheKey`,
  `CapturedCall`, `Provider`, `DomainError`.
- **Replaces:** the scattered struct definitions currently inside `trace.rs`.

## 3.2 `tether-contracts`
- **Responsibility:** the *interfaces* between services + the wire DTOs.
- **Owns:** `CacheService`, `TraceService`, `TraceSink`, `AuthService`,
  `SettingsService` traits; request/response DTOs with OpenAPI annotations.
- **Why separate:** lets services depend on each other's *contract* without a code cycle.

## 3.3 `tether-storage`
- **Responsibility:** SQLite access — pool, migrations, repositories, row↔domain mapping.
- **Owns:** `Db` (pool), `CacheRepo`, `SessionRepo`, `TraceRepo`, `SettingsRepo`, migrations.
- **Replaces:** the inline SQL spread across `main.rs`, `trace.rs`, `settings.rs`.
- **Rule:** the only crate that writes SQL. Returns `tether-domain` types.

## 3.4 `tether-crypto`
- **Responsibility:** AES-GCM encrypt/decrypt for stored API keys.
- **Replaces:** `src/crypto.rs` (already small; moved verbatim).

## 3.5 `tether-cache`
- **Responsibility:** sha256-keyed response memoization. Implements `CacheService`.
- **Owns:** cache-key derivation (`sha256(method + path + body)`), get/put/clear, hit counter.
- **Data:** `cache` table (via `CacheRepo`).
- **Replaces:** cache logic currently in `main.rs`.

## 3.6 `tether-gateway`
- **Responsibility:** the transparent reverse proxy hot path. Implements the fallback route.
- **Owns:** provider routing (path → OpenAI/Anthropic), upstream forwarding (`reqwest`),
  response **tee** (stream to client + buffer copy), cache lookup before forward, and emit
  `CapturedCall` to the `TraceSink`.
- **Depends on:** `CacheService`, `TraceSink` (traits only).
- **Replaces:** routing + forwarding + tee in `main.rs`. **Latency-critical — keep lean.**

## 3.7 `tether-trace`
- **Responsibility:** turn raw captured calls into stored, queryable traces.
- **Owns:** background ingestion worker (consumes the channel), response **summarizer**
  (extract model/tokens/prompt/response/language), **cost** calculator, trace **query** API.
- **Implements:** `TraceSink` (capture) + `TraceService` (query `/api/traces/current`).
- **Data:** `trace_calls` table (via `TraceRepo`).
- **Replaces:** the bulk of `trace.rs` (964 lines) — split into summarize / cost / query /
  ingest / routes (see [04](./04-code-organization.md)).

## 3.9 `tether-auth`
- **Responsibility:** identity. Implements `AuthService`.
- **Owns:** JWT issue/verify, auth context extraction (Axum extractor), Google OAuth flow.
- **Replaces:** `src/auth/mod.rs` + `src/auth/oauth.rs` + `src/auth/extractor.rs`, split into
  `jwt.rs`, `oauth.rs`, `extractor.rs`, `context.rs`, `routes.rs`.

## 3.10 `tether-settings`
- **Responsibility:** user profile, app settings, encrypted API key storage.
- **Implements:** `SettingsService`; uses `tether-crypto` + `SettingsRepo`.
- **Replaces:** `src/settings.rs`, split into `profile.rs`, `app.rs`, `keys.rs`, `routes.rs`.

## 3.11 `tether-http`
- **Responsibility:** assemble the Axum `Router` by mounting each service's `routes()`, plus
  the gateway fallback and `/openapi.json`. No business logic.

## 3.12 `src/main.rs` (composition root)
- **Responsibility:** read env/config, build `Db`, construct each concrete service, inject
  traits, spawn the trace ingestion worker, hand the router to the listener. Thin (~80 lines).

---

## App-side "services" (Swift)

| Module | Responsibility | Replaces / splits |
|--------|----------------|-------------------|
| `Networking/ProxyAPI` | typed client for `/api/*` | `TraceAPIClient.swift` → grouped by endpoint |
| `Networking/Codex` | local Codex log → `TraceSnapshot` ingestion adapter | `CodexLogObserver.swift` (495) → Database / Query / Mapper / SnapshotBuilder |
| `Core/State/TraceStore` | observable UI state | `TraceStore.swift` (356) → Store / Status / RefreshCoordinator / SessionsController / SnapshotCombiner |
| `Core/Models` | domain types (mirror of `tether-contracts` DTOs) | one type per file under `ui/Sources/Core/Models/` |
| `UI/DesignSystem` | palette + glass + theme | `AgentTracePalette.swift` (187) → Palette / LiquidGlass / Color+Hex |
