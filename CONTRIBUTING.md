# Contributing

Tether is a local-first debugging tool for AI agents. Contributions must keep the product reliable, inspectable, and safe for sensitive local traces.

Before changing code, read [CODESTYLE.md](./CODESTYLE.md). Every contributor is expected to follow it for naming, comments, documentation, formatting, and verification.

## Development Setup

### Web

```bash
cd apps/web
npm install
npm run dev
```

Run a production build before shipping apps/web changes:

```bash
cd apps/web
npm run build
```

### Proxy

```bash
cd core/proxy
cargo check
cargo test
```

Run formatting checks before shipping Rust changes:

```bash
cd core/proxy
cargo fmt --check
```

### macOS App

```bash
xcodebuild -project apps/macos/Tether.xcodeproj -scheme Tether -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/TetherDerivedData build CODE_SIGNING_ALLOWED=NO
```

## Contribution Workflow

1. Start from a clean understanding of the area you are touching.
2. Read [CODESTYLE.md](./CODESTYLE.md).
3. Keep changes scoped to the requested behavior.
4. Add or update documentation as part of the same change.
5. Run the relevant verification commands.
6. Summarize what changed, what was tested, and any remaining risk.

## Documentation Requirement

Documentation is not optional follow-up work. If a change affects behavior, setup, public APIs, configuration, data shape, UI meaning, or contributor expectations, update the relevant documentation in the same patch.

At minimum, update docs when you:

- Add, remove, or rename a command.
- Change core/proxy routes, request/response shapes, or trace fields.
- Change app setup, build steps, or environment variables.
- Add a new UI concept that users or contributors need to understand.
- Introduce a new convention that future contributors must follow.

## Pull Request Checklist

Before opening or handing off a change, confirm:

- [ ] I read and followed [CODESTYLE.md](./CODESTYLE.md).
- [ ] Documentation was updated where behavior or setup changed.
- [ ] Relevant build, test, format, or lint commands passed.
- [ ] No secrets, local trace payloads, API keys, or private user data were committed.
- [ ] The change is scoped and does not include unrelated cleanup.

## Privacy And Data

Tether handles prompts, responses, provider metadata, and local debugging traces. Treat all local data as sensitive.

Do not commit:

- API keys, bearer tokens, OAuth secrets, or `.env` files.
- Real prompts, responses, customer data, or exported trace payloads.
- Local SQLite databases, cache files, generated logs, or derived build products.

Use synthetic examples in docs and tests.
