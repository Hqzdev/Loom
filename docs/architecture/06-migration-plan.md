# 6. Migration Plan

Incremental and **always-shippable**. Every phase ends with the app building and
`scripts/smoke-e2e.sh` passing. No big-bang rewrite. Order is chosen so risk drops early
(workspace + extraction) before logic moves.

> Effort labels are rough sizing (S ≈ ½ day, M ≈ 1–2 days, L ≈ 3–5 days), not commitments.

## Phase 0 — Foundations & safety net  · S
- Add `scripts/check-file-size.sh` (fails >200-line files; allowlist file) and wire into CI.
- Ensure `scripts/smoke-e2e.sh` is green and runs in CI as the migration regression gate.
- Add empty `docs/adr/`, `docs/api/`; write ADR-0001 (modular monolith) and ADR-0002
  (trait-based boundaries).
- **Exit:** CI runs file-size + smoke checks; no source changes yet.

## Phase 1 — Cargo workspace + shared crates (no behavior change)  · M
- Convert `proxy/` to a Cargo workspace.
- Extract `tether-domain` (move structs out of `trace.rs`), `tether-contracts` (DTOs + empty
  traits), `tether-storage` (the SQLite pool + repos), `tether-crypto` (move `crypto.rs`).
- Existing `main.rs`/`trace.rs` keep working by calling the new crates. Behavior identical.
- **Exit:** `cargo build` + smoke pass; models/storage/crypto now live in their own crates.

## Phase 2 — Split god files into services (logic preserved)  · L
- Carve `tether-cache`, `tether-trace`, `tether-auth`, `tether-settings`,
  `tether-gateway`, `tether-http` per [03](./03-service-catalog.md), applying the file-split
  plan in [04](./04-code-organization.md). Each service implements its `tether-contracts` trait.
- Handlers stop touching SQL; they call traits backed by `tether-storage` repos.
- `main.rs` becomes the thin composition root.
- **Exit:** every Rust file ≤200 lines; all endpoints behave as before; smoke green.
- **Status:** implemented in the current module/workspace layout. `main.rs` is now the
  composition root; gateway, auth, settings, trace, cache, crypto, and domain concerns are
  split into ≤200-line modules/crates. `tether-contracts`/`tether-storage` promotion remains a
  later boundary-hardening step.

## Phase 3 — Decouple the hot path  · M
- Introduce the `TraceSink` channel: gateway emits `CapturedCall`; `tether-trace` consumes it
  in a background worker. Forward path no longer blocks on trace writes.
- Add focused tests for summarizer, cost calc, cache-key derivation, snapshot query.
- **Exit:** measured forward latency ≤ today; trace logic unit-tested in isolation.
- **Status:** implemented in the current proxy module layout via `trace::TraceSink`,
  `trace::spawn_ingest_worker`, and ADR-0003. Phase 4 should promote the same boundary into
  public rustdoc/OpenAPI-facing documentation without changing runtime behavior.

## Phase 4 — Documentation pass  · M
- rustdoc `///` on all public items; `//!` crate docs; per-crate `README.md`.
- Generate & commit `docs/api/openapi.json` (utoipa) + serve `/openapi.json`; write the
  endpoint guide. Remaining ADRs (0003 ingestion, 0004 OpenAPI source of truth).
- **Exit:** `cargo doc --workspace` warning-free; OpenAPI spec committed and served.
- **Status:** implemented with a committed static OpenAPI artifact served by
  `GET /openapi.json`, `docs/api/README.md`, per-crate READMEs for existing workspace
  crates, ADR-0003, and ADR-0004. Generated `utoipa` output is deferred until
  `tether-contracts` owns all DTOs/routes.

## Phase 5 — SwiftUI app refactor  · L
- Split `CodexLogObserver`, `TraceStore`, `TraceModels`, `AgentTracePalette`, `InspectorPane`
  per [04](./04-code-organization.md). Reorganize into feature folders.
- Add per-product DocC catalogs (`Core.docc`, `Networking.docc`, `UI.docc`) + doc comments.
- **Exit:** every Swift file ≤200 lines; DocC builds; app builds & runs; smoke green.
- **Status:** implemented. Swift package models now live one type per file,
  `CodexLogObserver` is split into Codex database/query/event-mapping helpers, the design
  system separates palette, hex colors, and liquid glass, and SwiftUI app feature files are
  split into graph, inspector, main-layout, settings, sidebar, and welcome subviews. DocC
  catalogs are committed for `Core`, `Networking`, and `UI`.

## Phase 6 — Hardening & guardrails  · S
- CI enforces: build, smoke, file-size, `cargo doc`, DocC, `cargo clippy`/SwiftLint.
- Optional: model-drift check (generated DTOs vs Swift `Core/Models`).
- **Exit:** the conventions in this plan are mechanically enforced, not just documented.
- **Status:** implemented. CI now enforces Rust format, clippy, tests, rustdoc warnings,
  Swift package build, Xcode app build, DocC build, SwiftLint, proxy smoke, and the
  200-line file-size gate. Tag pushes matching `v*` publish `dist/Tether.dmg` through the
  release workflow. CI/CD and release operations are documented in `docs/runbooks/`.

## Sequencing diagram

```
P0 safety net ─► P1 workspace+shared ─► P2 split into services ─► P3 hot-path decouple
                                                                       │
                                            P4 backend docs ◄──────────┘
                                                   │
                                            P5 Swift refactor+DocC ─► P6 CI guardrails
```

## Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Behavior regressions while splitting | smoke-e2e gate every phase; move code before changing it |
| Crate dependency cycles | enforce direction in [02](./02-target-architecture.md); `tether-contracts` breaks cycles |
| Hot-path latency creep | Phase 3 measures forward latency before/after; channel is bounded |
| DTO drift between Rust & Swift | OpenAPI as source of truth (Phase 4) + optional drift check (Phase 6) |
| Over-fragmentation (too many tiny files) | the seam must be a real concern boundary, not a line count hack |
