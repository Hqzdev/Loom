# 2. Target Architecture

A **Cargo workspace** of small, single-responsibility crates ("services"). They are wired
together at startup into **one process** (`loom-proxy`), but each is independently
compilable, testable, and — if cloud/team mode is ever needed — independently deployable.

## 2.1 Crate / service map (Rust)

```
proxy/                         ← Cargo workspace root
├── Cargo.toml                 (workspace members)
├── crates/
│   ├── loom-domain/           shared model types + error kinds (no I/O, no deps on others)
│   ├── loom-contracts/        service interface traits + DTOs (+ OpenAPI annotations)
│   ├── loom-storage/          SQLite pool, migrations, low-level row mappers
│   ├── loom-crypto/           AES-GCM helpers for stored secrets
│   ├── loom-gateway/          transparent reverse proxy: routing, forwarding, response tee
│   ├── loom-cache/            sha256-keyed response store (get / put / clear)
│   ├── loom-trace/            trace ingestion, summarization, cost calc, query API
│   ├── loom-sessions/         session lifecycle (create / list / current)
│   ├── loom-auth/             JWT issue/verify, Google OAuth
│   ├── loom-settings/         profile + app settings + encrypted API keys
│   └── loom-http/             Axum router assembly: mounts each service's routes
└── src/main.rs                bootstrap: build deps, compose services, serve (thin)
```

### Dependency direction (no cycles)

```
            loom-domain  ◄── everything depends on this (types only)
                ▲
        loom-contracts   (traits + DTOs; depends on domain)
                ▲
   ┌────────────┼─────────────┬───────────┬──────────┐
 cache        trace        sessions     auth      settings   ← service crates
   │            │             │           │          │        (each impls a contract trait,
   └──── loom-storage / loom-crypto ──────┘          │         talks to storage, never to
                ▲                                     │         a sibling's internals)
            loom-gateway  (uses cache + trace via their traits)
                ▲
            loom-http  (mounts routes from every service)
                ▲
            src/main.rs (composition root)
```

**Rule:** a service crate may depend on `loom-domain`, `loom-contracts`, `loom-storage`,
`loom-crypto` — never on another service crate's internals. Cross-service calls go through
a `loom-contracts` trait. The composition root (`main.rs`) is the only place that knows the
concrete wiring.

## 2.2 Why this enables future scale without paying for it now

Each service exposes a trait in `loom-contracts`, e.g.:

```rust
// loom-contracts/src/cache.rs
#[async_trait]
pub trait CacheService: Send + Sync {
    async fn get(&self, key: &CacheKey) -> Result<Option<CachedResponse>, DomainError>;
    async fn put(&self, key: CacheKey, value: CachedResponse) -> Result<(), DomainError>;
    async fn clear(&self) -> Result<(), DomainError>;
}
```

- **Today (local):** `loom-gateway` holds an `Arc<dyn CacheService>` that is the in-process
  `loom-cache` impl. Zero network cost.
- **Later (cloud, optional):** add a `CacheServiceHttpClient` impl of the same trait. The
  gateway is unchanged. Only the composition root swaps the binding.

This is the payoff of microservice *thinking* without microservice *operations*.

## 2.3 Hot-path decoupling: async trace ingestion

The latency-sensitive forward path must not block on trace persistence.

```
 gateway forwards request ──► tee response ──► return to client (fast path ends here)
                                   │
                                   └──► send CapturedCall to an in-process mpsc channel
                                                 │
                                   loom-trace ingestion worker (background task)
                                   summarize → cost → persist to trace_calls
```

The gateway depends on a `TraceSink` trait (`fn capture(&self, call: CapturedCall)`); the
local impl is "push to channel". This keeps forwarding fast and makes trace logic testable
in isolation.

## 2.4 SwiftUI app target architecture

Keep the existing package products, but reorganize into **feature-scoped** folders with each
file ≤200 lines and a clear layer split. The Codex observer is treated as an **ingestion
adapter** (a source of `TraceSnapshot`), mirroring the backend's "trace source" concept.

```
LoomModules/Sources/
├── Core/
│   ├── Models/           one type per file (AgentNode.swift, TraceSession.swift, …)
│   └── Features/         TCA reducers (one feature per folder)
├── Networking/
│   ├── ProxyAPI/         TraceAPIClient split by endpoint group
│   └── Codex/            CodexLogObserver split: Database / Query / Mapper / SnapshotBuilder
├── UI/
│   ├── DesignSystem/     palette, LiquidGlass modifier, theme — separate files
│   └── <Feature>/        view + subviews per feature, ≤200 lines each
└── App/                  composition root, dependency wiring
```

State (`TraceStore`) is split into: the observable store, the `ProxyConnectionStatus` model,
a `TraceRefreshCoordinator` (polling/refresh), a `SessionsController`, and a pure
`SnapshotCombiner`. See [04-code-organization](./04-code-organization.md) for the exact split.

## 2.5 Single source of truth for DTOs

`loom-contracts` carries the wire DTOs and is annotated to emit an **OpenAPI** spec
(`/openapi.json`). The Swift `Codable` models are documented as *generated/derived* from that
spec (see [05-documentation-strategy](./05-documentation-strategy.md)), eliminating the
hand-maintained drift between Rust and Swift model definitions.
