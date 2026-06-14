# loom-domain

`loom-domain` contains the shared DTOs returned by the local proxy API.

## Responsibility

- Define trace/session graph response shapes consumed by the SwiftUI app.
- Carry lineage, context hash, and stale-node metadata for replay workflows.
- Keep wire-facing structs independent from storage, routing, and async runtime code.
- Provide the model source that later OpenAPI generation can derive from.

## Public interface

- `TraceSnapshot`
- `TraceSessionDto`
- `SessionListDto`
- `AgentNodeDto`
- `AgentPromptDto`
- `AgentResponseDto`
- `AgentErrorDto`

## Tests

Run from `proxy/`:

```bash
cargo test -p loom-domain
```
