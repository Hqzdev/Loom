# 4. Code Organization

How we keep code readable: the size rule, the concrete file-split plan for every god file,
and the naming/comment conventions.

## 4.1 The ≤200-line rule

- **Hard target: every source file ≤ 200 lines** (excluding license header / blank lines is
  fine to measure loosely; the spirit is "one screen of one idea").
- When a file would exceed it, split along a **natural seam**, not an arbitrary line cut:
  one type, one route group, one algorithm, one layer per file.
- A split must not break the public API: prefer Rust `mod` submodules re-exported from
  `lib.rs`, and Swift `extension`s / separate `struct`s in the same module.
- **Enforcement:** a CI check (`scripts/check-file-size.sh`, added in Phase 1) fails the
  build on any tracked `.rs`/`.swift` file over 200 lines, with an allowlist for rare,
  justified exceptions (e.g. a generated file).

## 4.2 Rust file-split plan

### `src/trace.rs` (964) → `crates/loom-trace/src/`
```
lib.rs            //! crate doc + re-exports                         (~30)
routes.rs         Axum handlers for /api/traces/* (thin)             (~120)
ingest.rs         channel consumer worker; orchestrates the rest     (~120)
summarize.rs      extract model/tokens/prompt/response/language      (~180)
cost.rs           token → cost calculation tables + logic            (~120)
query.rs          build TraceSnapshot from stored rows               (~150)
dto.rs            (moves to loom-contracts) request/response shapes   (~80)
```

### `src/main.rs` (483) → split across crates
```
src/main.rs                       composition root (build + serve)    (~80)
loom-http/src/router.rs           mount all routes                    (~90)
loom-gateway/src/routing.rs       provider/path routing               (~90)
loom-gateway/src/forward.rs       upstream request via reqwest        (~120)
loom-gateway/src/tee.rs           response tee (stream + buffer)       (~130)
loom-cache/src/key.rs             sha256 cache-key derivation          (~50)
loom-cache/src/store.rs           get / put / clear + hit counter      (~150)
```
Current implementation keeps the gateway in-process under `proxy/src/gateway/`
(`mod.rs`, `http.rs`, `stream.rs`) while the crate promotion work continues.

### `src/auth/mod.rs` (380) → `crates/loom-auth/src/`
```
lib.rs (re-exports) · context.rs · jwt.rs · extractor.rs · routes.rs   (each ≤150)
oauth.rs            (from existing auth/oauth.rs, +doc comments)        (~180)
```
Current implementation uses `proxy/src/auth/{context,jwt,password,routes,types,google,oauth}.rs`
with the same boundaries.

### `src/settings.rs` (279) → `crates/loom-settings/src/`
```
lib.rs · profile.rs · app.rs · keys.rs · routes.rs                     (each ≤120)
```
Current implementation uses `proxy/src/settings/{profile,app,keys,types,mod}.rs`.

## 4.3 Swift file-split plan

### `Networking/CodexLogObserver.swift` (495) → `Networking/Codex/`
```
CodexLogObserver.swift     public actor; orchestrates, holds baseline   (~120)
CodexDatabase.swift        open ~/.codex/*.sqlite, run sqlite3 process   (~120)
CodexQuery.swift           the SQL strings + parameter building          (~120)
CodexEventMapper.swift     raw row → AgentNode                            (~120)
CodexSnapshotBuilder.swift assemble TraceSnapshot, layout/limit          (~80)
```

### `Loom/Features/MainLayout/TraceStore.swift` (356) → split
```
TraceStore.swift            @MainActor ObservableObject, published state  (~110)
ProxyConnectionStatus.swift the enum + title/detail/color                 (~70)
TraceRefreshCoordinator.swift  polling loop + refresh orchestration       (~120)
SessionsController.swift    create / select / clear session ops           (~90)
SnapshotCombiner.swift      pure combine of proxy + codex snapshots       (~90)
```

### `Core/Models/TraceModels.swift` (297) → `Core/Models/`
```
one file per type: AgentNode.swift · TraceSession.swift · TraceSnapshot.swift
NodeStatus.swift · AgentPrompt.swift · AgentResponse.swift · AgentError.swift
InspectorTab.swift · ResponseLanguage.swift            (each ≤80)
```

### `UI/DesignSystem/AgentTracePalette.swift` (187) → split
```
AgentTracePalette.swift   color tokens + status helpers                  (~110)
LiquidGlass.swift         LiquidGlassModifier + View.liquidGlass(...)     (~70)
Color+Hex.swift           Color(hex:) initializer                         (~15)
```

### `Inspector/InspectorPane.swift` (~430) → `Inspector/`
```
InspectorPane.swift · InspectorTabPicker.swift · InspectorBody.swift
MetadataTable.swift · InspectorEmptyState.swift · TimeTravelButtonStyle.swift
```
(`InspectorTabPicker` already exists inline — promote it to its own file.)

## 4.4 Naming conventions

- **Rust:** crates `loom-<area>`; modules `snake_case`; one primary type per file, file named
  after it (`summarizer.rs` → `Summarizer`). Route handler fns end in `_handler` or live in
  `routes.rs`.
- **Swift:** PascalCase types, camelCase members; file name == primary type name. Feature
  folders group view + subviews. Extensions for protocol conformance in `Type+Protocol.swift`.

## 4.5 Comment conventions (English, mandatory on public items)

- **What, not how-restated.** Document intent, invariants, units, and edge cases — never
  paraphrase the next line of code.
- **Rust:** crate-level `//!` in every `lib.rs`; `///` on every `pub` item. Document errors
  (`# Errors`) and panics (`# Panics`) where relevant.
- **Swift:** `///` DocC comments on every `public`/`internal` symbol that isn't trivially
  obvious; `- Parameters:` / `- Returns:` / `- Throws:` for non-trivial functions.
- **Hot paths & non-obvious logic** (tee buffering, cache-key composition, snapshot combine
  ordering) get a short paragraph explaining *why*.
- Match the surrounding file's comment density; don't over-comment self-evident code.
