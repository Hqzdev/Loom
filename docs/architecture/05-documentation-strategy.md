# 5. Documentation Strategy

Documentation is produced at three levels: **in-code reference**, **API contract**, and
**design records**. All prose is English.

## 5.1 In-code reference (auto-generated)

### Rust — rustdoc
- Every crate's `lib.rs` opens with a `//!` summary: what the service does, its one
  responsibility, and how it fits the workspace.
- Every `pub` item has a `///` doc comment. Functions document `# Errors` / `# Panics`.
- Runnable examples (` ```rust ... ``` `) on key public APIs; checked by `cargo test --doc`.
- Build the site: `cargo doc --workspace --no-deps`. Output wired into CI as an artifact.

### Swift — DocC
- One **DocC catalog** per package product: `Core.docc`, `Networking.docc`, `UI.docc`.
- Each catalog has a landing article (overview + topics grouping the key types).
- `///` doc comments on public symbols with `- Parameters/Returns/Throws`.
- Build: `xcodebuild docbuild` (or Xcode Product ▸ Build Documentation).

## 5.2 API contract — OpenAPI

- `loom-contracts` DTOs and route definitions are annotated (e.g. `utoipa`) to generate an
  **OpenAPI 3 spec** served at `GET /openapi.json` and committed as
  `docs/api/openapi.json` for review diffs.
- Until every route/DTO is promoted into `loom-contracts`, Phase 4 serves a committed static
  `docs/api/openapi.json` with `include_str!` so the runtime endpoint and reviewed artifact
  are identical.
- This spec is the **single source of truth** for the wire format. The Swift `Core/Models`
  are documented as derived from it; a CI step can later diff generated models against the
  hand-written ones to catch drift.
- A short `docs/api/README.md` explains each endpoint group with example requests/responses.

## 5.3 Design records — ADRs

- `docs/adr/` holds **Architecture Decision Records**, one file per decision, numbered:
  `0001-modular-monolith.md`, `0002-trait-based-service-boundaries.md`,
  `0003-async-trace-ingestion.md`, `0004-openapi-as-dto-source-of-truth.md`, …
- Template: *Context · Decision · Consequences · Status*. ADRs are append-only; superseded
  ones are marked, not deleted.

## 5.4 Architecture docs (this folder)

- `docs/architecture/` (these files) is the human-facing system map. Diagrams are kept as
  fenced ASCII (reviewable in PRs) or `.excalidraw`/`.drawio` exported to SVG under
  `docs/architecture/assets/`.
- Each service crate also carries a 10–20 line `README.md` (responsibility, public interface,
  data owned, how to run its tests) so the doc lives next to the code.

## 5.5 Repository documentation layout

```
docs/
├── architecture/      this plan + C4-style system map + ADR index
│   ├── README.md … 06-migration-plan.md
│   └── assets/        exported diagrams (SVG)
├── adr/               numbered decision records
├── api/               openapi.json + endpoint guide
└── runbooks/          (later) operate/build/release notes

proxy/crates/<crate>/README.md     per-service doc
ui/.../*.docc                      per-module DocC catalogs
```

## 5.6 Documentation Definition of Done (per PR)

A change is "documented" when:
1. New/changed public items have `///` doc comments.
2. New endpoints appear in the OpenAPI spec and the api guide.
3. Any architectural decision is captured as an ADR.
4. `cargo doc` and DocC build with no warnings.
