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
- Keep comments and contributor-facing documentation in English.
- Update documentation yourself when behavior, setup, or conventions change.

## Function Comments

Every function or method added or changed in this repository must have an English comment directly above it. This includes public APIs, private helpers, SwiftUI computed helper methods, Rust route handlers, TypeScript functions, and React components.

Use doc comments where the language supports them:

- Swift: `///`
- Rust: `///` for items and `//!` for module-level docs
- TypeScript / React: `/** ... */` for exported functions/components

For small private helpers, a short `//` comment is acceptable. The comment must still explain intent, constraints, or behavior in English.

Do not place function documentation after the function body. Put it above the declaration so tools, readers, and editors can find it.

Good Swift example:

```swift
/// Combines proxy and Codex snapshots into a single live multi-agent timeline.
private func combinedSnapshot(
    proxySnapshot: TraceSnapshot?,
    codexSnapshot: TraceSnapshot?
) -> TraceSnapshot? {
    ...
}
```

Good Rust example:

```rust
/// Returns the UI-facing agent name for a captured provider/model pair.
fn agent_name_for(provider: &str, model: &str) -> String {
    ...
}
```

Good TypeScript example:

```tsx
/**
 * Renders the product chrome shared by public marketing pages.
 */
export function SiteChrome({ children }: SiteChromeProps) {
  ...
}
```

Avoid comments that repeat the code:

```swift
// Sets the title.
title = newTitle
```

Prefer comments that explain intent, constraints, or edge cases:

```swift
/// Keeps historic proxy sessions isolated while live Codex logs are merged only into the active session.
```

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
- Use `///` comments for public types and meaningful private helpers.
- Avoid force unwraps outside tests and previews.
- Prefer explicit enum cases over stringly typed UI state.
- Keep UI copy concise and user-facing strings consistent with existing product language.

Formatting and verification:

```bash
xcodebuild -project ui/Loom.xcodeproj -scheme Tether -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/LoomDerivedData build CODE_SIGNING_ALLOWED=NO
```

## Rust Proxy

- Run `cargo fmt` before shipping Rust changes.
- Prefer typed structs over ad hoc `serde_json::Value` access when the shape is stable.
- Keep request/response parsing defensive because provider payloads vary.
- Do not persist secrets.
- Keep route handlers small; move parsing, summarization, and storage logic into helpers.
- Use `///` comments for route handlers, public helpers, and non-obvious private helpers.
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
- Use English comments for exported functions/components and non-trivial helpers.

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
