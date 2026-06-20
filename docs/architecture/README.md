# Tether / Tether — Architecture & Refactor Plan

> Status: **Implemented through Phase 6** — backend service split, async ingestion,
> OpenAPI/rustdoc docs, SwiftUI refactor, DocC catalogs, and CI guardrails are in place.
> Scope: Rust proxy backend + SwiftUI macOS app. The Next.js web site is out of scope.
> Goal: a **modular monolith** — clean, independently-reasoned internal services with hard
> boundaries, all composed into a **single local process**. No network hops between services.
> Optimised for readability and maintainability, not distributed deployment.

## Why "modular monolith" and not networked microservices

Tether/Tether is a **local-first desktop debugger**. The proxy and the app run on the user's
machine. Splitting the backend into separately-deployed network services would add latency,
serialization cost, and operational complexity for zero local benefit.

Instead we apply the *valuable* part of microservices — **strong module boundaries, single
responsibility, explicit interfaces, independent testability** — while keeping everything in
one binary. Boundaries are drawn so that any single service *could* later be promoted to a
real network service (cloud/team mode) by swapping its in-process call for a transport call,
without rewriting its logic. See [02-target-architecture](./02-target-architecture.md).

## Documents

| # | Document | What it covers |
|---|----------|----------------|
| 1 | [Current state](./01-current-state.md) | Today's code, the monolith files, pain points |
| 2 | [Target architecture](./02-target-architecture.md) | Service boundaries, crate layout, data flow diagrams |
| 3 | [Service catalog](./03-service-catalog.md) | Each service: responsibility, interface, data, owner files |
| 4 | [Code organization](./04-code-organization.md) | The ≤200-line rule, file-split plan, naming conventions |
| 5 | [Documentation strategy](./05-documentation-strategy.md) | rustdoc, DocC, OpenAPI, ADRs, what gets documented and how |
| 6 | [Migration plan](./06-migration-plan.md) | Phased rollout, each phase shippable & verifiable |
| 7 | [Observability and validation](./07-observability-validation.md) | Logging, validation boundaries, privacy rules |

Operational runbooks live under `docs/runbooks/`, including CI/CD and release
publication.

## Core principles (apply to every change)

1. **One responsibility per module.** A file/crate does one thing; its name says what.
2. **≤200 lines per source file.** Larger files are split along natural seams (see doc 4).
3. **Documentation outside implementation by default.** Keep code self-documenting; use docs,
   API contracts, and ADRs for durable explanations.
4. **Explicit interfaces between services.** Services depend on *traits/protocols*, not on
   each other's internals. Transport (in-process today) is an implementation detail.
5. **Domain types live in one shared place.** No duplicated model definitions.
6. **Every phase compiles and passes `scripts/smoke-e2e.sh`.** No "big bang" rewrite.
