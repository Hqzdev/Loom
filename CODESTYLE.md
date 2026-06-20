# Code Style

This repository contains three main surfaces:

- Swift / SwiftUI macOS app in `ui/`
- Rust local proxy in `proxy/`
- Next.js / React / TypeScript web app in `web/`

Follow the existing local style first. When the existing code is unclear, use this document as the deciding rule.

## Core Rules

- Write code that is easy to scan before it is clever.
- Keep changes scoped to the feature or bug being worked on.
- Prefer existing helpers, models, and UI patterns over new abstractions.
- Use clear names that explain domain intent, not implementation trivia.
- Do not mix formatting-only churn with behavior changes.
- Do not add new code comments. Keep contributor-facing documentation in English.
- Update documentation yourself when behavior, setup, or conventions change.

## Code Comments

New implementation code should be self-documenting through names, types, and small
single-responsibility functions. Do not add inline comments, doc comments, module comments, or
placeholder explanations in new or changed code.

When behavior, setup, contracts, or architecture need explanation, update `docs/`, `README.md`,
OpenAPI artifacts, ADRs, or runbooks in the same change.

## Documentation Ownership

The person changing code owns the documentation update. Do not leave docs for someone else unless the task explicitly says to skip docs.

Documentation updates should be made in the same patch when:

- A field is added to exported JSON.
- A route or command changes.
- A setup step changes.
- A UI label changes meaning.
- A data model or persistence format changes.
- A new contributor rule is introduced.

## Swift / SwiftUI

- Keep views small enough that layout intent remains obvious.
- Prefer computed properties or small private subviews over large nested bodies.
- Use `@MainActor` for UI state owners that mutate published UI state.
- Keep model structs `Codable`, `Hashable`, and `Sendable` when they cross UI/network boundaries.
- Avoid force unwraps outside tests and previews.
- Prefer explicit enum cases over stringly typed UI state.
- Keep UI copy concise and user-facing strings consistent with existing product language.

Formatting and verification:

```bash
xcodebuild -project ui/Tether.xcodeproj -scheme Tether -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/TetherDerivedData build CODE_SIGNING_ALLOWED=NO
```

## Rust Proxy

- Run `cargo fmt` before shipping Rust changes.
- Prefer typed structs over ad hoc `serde_json::Value` access when the shape is stable.
- Keep request/response parsing defensive because provider payloads vary.
- Do not persist secrets.
- Keep route handlers small; move parsing, summarization, and storage logic into helpers.
- Return clear errors at the boundary and keep logs useful but not noisy.

Formatting and verification:

```bash
cd proxy
cargo fmt --check
cargo check
cargo test
```

## TypeScript / React / Next.js

- Prefer typed props for every exported component.
- Keep components focused on one layout or interaction responsibility.
- Avoid client components unless state, effects, browser APIs, or interactivity require them.
- Keep API route validation explicit and return structured errors.
- Use existing CSS modules, global tokens, and component patterns before adding new styling conventions.
- Keep exported functions/components named clearly enough to understand without comments.

Verification:

```bash
cd web
npm run build
```

## UI Style

- Tether should feel like a precise developer instrument, not a generic marketing template.
- Use compact, scannable interface text.
- Preserve clear hierarchy between graph, sidebar, inspector, and settings surfaces.
- Use color for state and source identity, not decoration alone.
- Avoid nested card-heavy layouts unless the local UI already uses that pattern.
- Keep text within its container at common macOS window sizes.

## Naming

- Use domain names from the product: `trace`, `node`, `agent`, `provider`, `session`, `replay`, `cache`.
- Prefer `Codex` and `Claude Code` for UI-facing agent names.
- Prefer `OpenAI` and `Anthropic` for provider names.
- Avoid abbreviations unless they are established in the codebase.

## Commits And Reviews

Keep commits reviewable:

- One behavior change per commit when possible.
- Include docs with the behavior change.
- Mention verification commands in the PR or handoff.
- Call out migrations, compatibility risks, and privacy-sensitive changes.
