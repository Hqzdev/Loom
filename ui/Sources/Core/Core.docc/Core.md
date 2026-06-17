# Core

@Metadata {
    @TitleHeading("Framework")
}

Core contains the UI-facing trace domain models shared by the desktop app,
networking layer, and reusable SwiftUI components.

## Overview

The target mirrors the reviewed API contract in `docs/api/openapi.json`.
Keep model names and field semantics aligned with the OpenAPI trace
schemas so export, inspector, and graph rendering code all speak one language.

## Topics

### Trace Snapshots

- ``TraceSnapshot``

### Graph Nodes

- ``AgentNode``
- ``NodeStatus``
- ``AgentPrompt``
- ``AgentResponse``
- ``AgentError``
- ``ResponseLanguage``

### Inspector State

- ``InspectorTab``
