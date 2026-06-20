# 5. Documentation Strategy

Documentation is produced at three levels: **repository reference**, **API contract**, and
**design records**. All prose is English.

## 5.1 Repository reference

Implementation code should remain self-documenting through names, types, and small functions.
Durable explanations live in `docs/`, package READMEs, runbooks, ADRs, OpenAPI artifacts, and
DocC catalog articles.

Doc generation remains useful for navigation, but new explanatory material should not be added
as code comments.

## 5.2 API contract — OpenAPI

- `tether-contracts` DTOs and route definitions are annotated (e.g. `utoipa`) to generate an
  **OpenAPI 3 spec** served at `GET /openapi.json` and committed as
  `docs/api/openapi.json` for review diffs.
- Until every route/DTO is promoted into `tether-contracts`, Phase 4 serves a committed static
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
└── runbooks/          CI/CD, build, and release notes

proxy/crates/<crate>/README.md     per-service doc
ui/Sources/<Target>/<Target>.docc   per-target DocC catalogs
```

## 5.6 Documentation Definition of Done (per PR)

A change is "documented" when:
1. New endpoints appear in the OpenAPI spec and the API guide.
2. Any architectural decision is captured as an ADR.
3. Setup, operations, or release behavior changes are captured in runbooks.
4. User-facing or contributor-facing behavior is reflected in the relevant README or docs page.
