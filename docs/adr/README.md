# Architecture Decision Records

Each ADR captures one significant decision: its context, the choice made, and the
consequences. ADRs are **append-only** — a superseded decision is marked `Superseded by
NNNN`, never deleted or rewritten.

Format per record: **Context · Decision · Consequences · Status**.

## Index

| # | Title | Status |
|---|-------|--------|
| [0001](./0001-modular-monolith.md) | Modular monolith over networked microservices | Accepted |
| [0002](./0002-trait-based-service-boundaries.md) | Trait-based service boundaries | Accepted |
| [0003](./0003-async-trace-ingestion.md) | Async trace ingestion to decouple the proxy hot path | Accepted |
| [0004](./0004-openapi-as-dto-source-of-truth.md) | OpenAPI as the review target for wire DTOs | Accepted |
