# Tether

Tether is a local execution debugger for AI coding agents. It captures what an agent asked, changed, ran, broke, and can replay or inspect later.

[Website](https://tetherapp.vercel.app) | [Docs](https://tetherapp.vercel.app/docs) | [GitHub](https://github.com/Hqzdev/Tether)

## Repository Layout

```text
apps/
  web/       Public site and documentation
  macos/     SwiftUI macOS desktop app
  linux/     Tauri Linux desktop app, alpha
  windows/   Windows app placeholder, in development for 53 days
core/
  proxy/     Shared Rust local proxy, capture API, cache, replay, and trace storage
scripts/     Packaging, smoke, readiness, backup, and release helper scripts
monitoring/  Production observability templates
public/      Shared root-level static assets
```

The project is a modular monolith, not a microservice system. Platform apps live under `apps/`; shared backend behavior lives under `core/proxy`.

## Product Surfaces

| Surface | Status | Path | Responsibility |
| --- | --- | --- | --- |
| Web | Active | `apps/web` | Marketing site, product docs, platform documentation, public routes. |
| macOS | Active | `apps/macos` | Native SwiftUI execution debugger, graph, inspector, replay, settings. |
| Linux | Alpha | `apps/linux` | Tauri desktop app with React graph UI and proxy sidecar control. |
| Windows | In development | `apps/windows` | Reserved platform boundary, target readiness window: 53 days. |
| Proxy | Active | `core/proxy` | Local capture proxy, SQLite traces, cache, replay, auth, settings, OpenAPI. |

## Core Capabilities

- Capture provider requests through `http://127.0.0.1:8080/v1`.
- Capture shell commands through `tether capture -- <command>`.
- Inspect prompt, response, metadata, latency, tokens, cache state, errors, and file impact.
- Render local execution as a graph of agent actions, not just a request log.
- Replay supported proxy-captured requests and mark downstream nodes stale.
- Keep traces and runtime data local by default.

## Quick Start

Install and run the web documentation site:

```bash
cd apps/web
npm install
npm run dev
```

Build the shared proxy:

```bash
cargo build --manifest-path core/proxy/Cargo.toml
```

Run a local command through Tether capture:

```bash
core/proxy/target/debug/tether capture -- /bin/echo "hello from Tether"
```

## Development Commands

| Area | Command |
| --- | --- |
| Web build | `cd apps/web && npm run build` |
| Linux UI build | `cd apps/linux && npm run build` |
| Linux Tauri check | `cargo check --manifest-path apps/linux/src-tauri/Cargo.toml` |
| Proxy check | `cargo check --manifest-path core/proxy/Cargo.toml` |
| Proxy format | `cargo fmt --check --manifest-path core/proxy/Cargo.toml` |
| macOS Swift package | `swift build --package-path apps/macos` |
| macOS app | `xcodebuild -project apps/macos/Tether.xcodeproj -scheme Tether -configuration Debug -destination 'generic/platform=macOS' -derivedDataPath /tmp/TetherDerivedData CODE_SIGNING_ALLOWED=NO build` |
| Smoke test | `scripts/smoke-e2e.sh` |

## Packaging

macOS DMG:

```bash
./scripts/package-dmg.sh
```

Linux artifacts:

```bash
./scripts/package-linux.sh
```

Linux packages are collected in `dist/linux` when built on Linux. The `Linux App` GitHub Actions workflow builds and uploads them as CI artifacts.

## CI/CD

GitHub Actions are split by responsibility:

- `CI`: file-size guardrail, proxy smoke test, Rust quality, web build, and macOS build.
- `Linux App`: Ubuntu packaging flow for `.AppImage` and `.deb` artifacts.
- `Release`: tag-driven macOS DMG release.
- P1 workflows: staging, production, rollback, canary, backup, and DR drill automation.

The main branch should not be pushed unless the relevant local checks pass.

## Documentation

The old local `docs/` tree was removed. The site documentation is now authored in:

```text
apps/web/lib/docs-pages.ts
```

Current docs include Linux architecture and Windows development status. The proxy OpenAPI source lives in:

```text
core/proxy/openapi.json
```

## Code Standards

- No comments in new code.
- Keep functions and types self-documenting through names and structure.
- Keep platform-specific UI inside its platform folder.
- Keep shared runtime behavior in `core/proxy`.
- Keep generated files, caches, local databases, and build outputs out of git.

## Privacy

Tether handles prompts, responses, provider metadata, command output, and local traces. Do not commit API keys, bearer tokens, OAuth secrets, local SQLite databases, exported traces, or private prompt data.
