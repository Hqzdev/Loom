export type DocsBlock =
  | { kind: "paragraph"; text: string }
  | { kind: "list"; items: string[] }
  | { kind: "code"; language: string; code: string }
  | { kind: "table"; headers: string[]; rows: string[][] }
  | { kind: "cards"; cards: { title: string; text: string; href: string }[] };

export type DocsSection = {
  title: string;
  blocks: DocsBlock[];
};

export type DocsPage = {
  slug: string;
  title: string;
  category: string;
  description: string;
  sections: DocsSection[];
};

export type DocsNavGroup = {
  title: string;
  links: { slug: string; label: string }[];
};

export const DOCS_NAV_GROUPS: DocsNavGroup[] = [
  {
    title: "Getting Started",
    links: [
      { slug: "overview", label: "Overview" },
      { slug: "install", label: "Install" },
      { slug: "routing-provider-calls", label: "Route provider calls" },
      { slug: "connect-cometapi", label: "Connect CometAPI" },
    ],
  },
  {
    title: "Using Tether",
    links: [
      { slug: "reading-traces", label: "Reading traces" },
      { slug: "replay-and-cache", label: "Replay and cache" },
      { slug: "local-privacy", label: "Local privacy" },
    ],
  },
  {
    title: "Supported agents and frameworks",
    links: [
      { slug: "supported-agents-and-frameworks", label: "Supported agents" },
    ],
  },
  {
    title: "Roadmap",
    links: [
      { slug: "roadmap", label: "Product roadmap" },
    ],
  },
  {
    title: "Architecture",
    links: [
      { slug: "architecture-overview", label: "System overview" },
      { slug: "architecture-execution-graph", label: "Execution graph" },
      { slug: "architecture-proxy", label: "Rust proxy" },
      { slug: "architecture-app", label: "macOS app" },
      { slug: "architecture-linux-app", label: "Linux app" },
      { slug: "architecture-windows-app", label: "Windows status" },
      { slug: "architecture-ci-cd", label: "CI/CD and releases" },
    ],
  },
  {
    title: "Reference",
    links: [
      { slug: "api-reference", label: "API reference" },
      { slug: "commands", label: "Commands" },
      { slug: "release-workflow", label: "Release workflow" },
    ],
  },
];

export const DOCS_PAGES: DocsPage[] = [
  {
    slug: "overview",
    title: "Tether documentation",
    category: "Docs",
    description:
      "Install Tether on macOS or Linux, capture local agent runs, inspect execution steps, recover failed branches, and understand the architecture behind the desktop clients.",
    sections: [
      {
        title: "What Tether does",
        blocks: [
          {
            kind: "paragraph",
            text:
              "Tether is a local-first execution debugger for agent builders. It runs a Rust proxy on the developer machine, stores captured execution traces in SQLite, and renders the run inside desktop clients for macOS and Linux.",
          },
          {
            kind: "list",
            items: [
              "Capture supported agent CLIs, LangChain, LangGraph, OpenAI/OpenGPT-style, and custom local runs through adapters or proxy ingestion.",
              "Inspect prompt, action, command output, file changes, latency, tokens, cost, cache state, and errors.",
              "Replay supported proxy-captured requests or use local rollback evidence when replay is unavailable.",
              "Keep API keys and trace data on the local machine through platform-local storage paths.",
            ],
          },
        ],
      },
      {
        title: "Architecture pages",
        blocks: [
          {
            kind: "cards",
            cards: [
              {
                title: "System overview",
                text: "The capture wrapper, desktop clients, Rust proxy, SQLite stores, provider upstreams, and release pipeline in one map.",
                href: "/docs/architecture-overview",
              },
              {
                title: "Execution graph",
                text: "Why the graph is an agent execution graph, not an LLM request tree.",
                href: "/docs/architecture-execution-graph",
              },
              {
                title: "Rust proxy",
                text: "Gateway, cache, trace capture, replay, auth, settings, and OpenAPI boundaries.",
                href: "/docs/architecture-proxy",
              },
              {
                title: "macOS app",
                text: "Swift package modules, graph panes, inspector panes, settings, and local source ingestion.",
                href: "/docs/architecture-app",
              },
              {
                title: "CI/CD and releases",
                text: "The quality gates, tag-driven DMG release workflow, and local preflight commands.",
                href: "/docs/architecture-ci-cd",
              },
            ],
          },
        ],
      },
    ],
  },
  {
    slug: "install",
    title: "Install",
    category: "Getting Started",
    description:
      "Install the macOS or Linux desktop app from the terminal, verify the local system, and keep developer builds separate from release installs.",
    sections: [
      {
        title: "Terminal installer",
        blocks: [
          {
            kind: "code",
            language: "bash",
            code: "curl -fsSL https://tetherapp.vercel.app/install.sh | bash",
          },
          {
            kind: "list",
            items: [
              "Detects macOS or Linux and the machine architecture.",
              "Checks required system tools before changing anything.",
              "Downloads the matching release artifact from GitHub Releases.",
              "Installs or replaces the macOS app at /Applications/Tether.app, using sudo when needed, or installs the Linux package or AppImage path.",
              "Installs the tether CLI with help, update, uninstall, version, doctor, and open commands.",
              "Use --dry-run to inspect the plan or --yes for non-interactive Linux package installation.",
            ],
          },
        ],
      },
      {
        title: "Installed CLI",
        blocks: [
          {
            kind: "code",
            language: "bash",
            code: "tether help\ntether doctor\ntether open\ntether update\ntether uninstall\ntether uninstall --purge",
          },
          {
            kind: "paragraph",
            text:
              "tether update closes the desktop app if it is running, replaces /Applications/Tether.app with the newest macOS release, reopens it when it was open before the update, and shows a desktop notification when the update succeeds. The macOS app exposes the same update path through an Update Tether confirmation window that opens Terminal before running the command. tether uninstall keeps local traces and settings unless --purge is passed.",
          },
        ],
      },
      {
        title: "Local developer setup",
        blocks: [
          {
            kind: "code",
            language: "bash",
            code: "cd core/proxy\ncargo build\ncd ../../apps/web\nnpm install\nnpm run dev",
          },
          {
            kind: "paragraph",
            text:
              "The web app is the public site and documentation surface. The macOS app lives under apps/macos/, the Linux app lives under apps/linux/, and the proxy binary is built from core/proxy/.",
          },
        ],
      },
      {
        title: "Package desktop builds",
        blocks: [
          {
            kind: "code",
            language: "bash",
            code: "./scripts/package-dmg.sh",
          },
          {
            kind: "list",
            items: [
              "Builds the Rust proxy helper in release mode.",
              "Builds the Tether Xcode scheme.",
              "Copies tether-proxy into Tether.app/Contents/Helpers.",
              "Creates dist/Tether.dmg and mirrors it into apps/web/public/downloads/.",
              "Use scripts/package-linux.sh for Linux AppImage and deb packaging.",
            ],
          },
        ],
      },
    ],
  },
  {
    slug: "routing-provider-calls",
    title: "Route provider calls",
    category: "Getting Started",
    description:
      "Point an SDK at the local Tether proxy and keep the provider request shape unchanged.",
    sections: [
      {
        title: "OpenAI-compatible clients",
        blocks: [
          {
            kind: "paragraph",
            text:
              "Use the local proxy as the SDK base URL. Tether forwards the request upstream, records execution context, and exposes the captured path through the local UI API.",
          },
          {
            kind: "code",
            language: "python",
            code:
              "from openai import OpenAI\n\nclient = OpenAI(\n    api_key=\"local-placeholder\",\n    base_url=\"http://127.0.0.1:8080/v1\",\n)",
          },
        ],
      },
      {
        title: "Provider routing",
        blocks: [
          {
            kind: "table",
            headers: ["Path", "Upstream"],
            rows: [
              ["/v1/messages", "Anthropic"],
              ["/v1/chat/completions", "OpenAI-compatible"],
              ["/v1/embeddings", "OpenAI-compatible"],
            ],
          },
        ],
      },
    ],
  },
  {
    slug: "connect-cometapi",
    title: "Connect CometAPI",
    category: "Getting Started",
    description:
      "Save a CometAPI key in the local proxy and use recovery replay from the macOS inspector.",
    sections: [
      {
        title: "What CometAPI enables",
        blocks: [
          {
            kind: "paragraph",
            text:
              "Tether can replay a captured trace node through CometAPI with a different model. The original request stays in the local trace store, the proxy sends the replay to CometAPI, and the inspector shows a side-by-side diff of the original and replayed response.",
          },
          {
            kind: "list",
            items: [
              "Compare a failed or surprising response against another model without rebuilding the whole agent run.",
              "Review latency, token, and cost differences in the replay diff sheet.",
              "Keep the CometAPI key in the local proxy settings database instead of hard-coding it in scripts.",
            ],
          },
        ],
      },
      {
        title: "Save and test the key",
        blocks: [
          {
            kind: "list",
            items: [
              "Open the desktop app and go to Settings -> Extensions.",
              "In the CometAPI section, paste your CometAPI API key.",
              "Click Save & Test.",
              "A successful connection shows Connected with the number of available models.",
            ],
          },
          {
            kind: "paragraph",
            text:
              "The Save & Test action stores the key through the local proxy endpoint PUT /api/settings/cometapi-key, then fetches the model list from CometAPI. You do not need to add the key to Keychain for this workflow.",
          },
        ],
      },
      {
        title: "Run cross-model replay",
        blocks: [
          {
            kind: "list",
            items: [
              "Run an agent call through the Tether proxy so a node appears in the graph.",
              "Click the node and open the inspector footer.",
              "Use the Cross-model replay picker to choose a CometAPI model.",
              "Click Replay with selected model to open the ReplayDiffView sheet.",
            ],
          },
        ],
      },
      {
        title: "Troubleshooting",
        blocks: [
          {
            kind: "table",
            headers: ["Symptom", "Check"],
            rows: [
              ["Save & Test returns an error", "Confirm the local proxy is running and the CometAPI key is valid."],
              ["No models appear", "Retry Save & Test; the model picker depends on GET /api/providers/cometapi/models."],
              ["Replay button fails", "Confirm the selected trace node has a stored request body that can be replayed."],
            ],
          },
        ],
      },
    ],
  },
  {
    slug: "reading-traces",
    title: "Reading traces",
    category: "Using Tether",
    description:
      "Understand the graph, sidebar, inspector, and status metadata for each execution step shown by the desktop app.",
    sections: [
      {
        title: "Trace node model",
        blocks: [
          {
            kind: "paragraph",
            text:
              "Every captured call becomes an AgentNode. Nodes carry provider metadata, prompt and response text, cache state, latency, cost, token counts, and optional error details.",
          },
          {
            kind: "list",
            items: [
              "success: upstream returned a 2xx response.",
              "cached: the proxy served a local cache hit.",
              "running: reserved UI state for active work.",
              "error: upstream or command failure captured as a trace node.",
            ],
          },
        ],
      },
      {
        title: "Inspector panes",
        blocks: [
          {
            kind: "table",
            headers: ["Pane", "Use"],
            rows: [
              ["Prompt", "Read system and user input that reached the model."],
              ["Response", "Inspect or edit model output for replay workflows."],
              ["Metadata", "Review latency, tokens, cost, cache, file diffs, provider, and request ids."],
            ],
          },
        ],
      },
    ],
  },
  {
    slug: "replay-and-cache",
    title: "Replay and cache",
    category: "Using Tether",
    description:
      "Use cached execution state to keep local iteration cheap and replay a downstream branch from a selected node.",
    sections: [
      {
        title: "Cache loop",
        blocks: [
          {
            kind: "paragraph",
            text:
              "Cache keys are derived from the HTTP method, path, query, and request body. A cache hit is returned to the app and written to the trace graph as a cached node.",
          },
          {
            kind: "list",
            items: [
              "Use cache when iterating on downstream logic that repeats the same prompt.",
              "Clear cache when prompt changes should reach the provider again.",
              "Treat cached hits as local development artifacts, not production truth.",
            ],
          },
        ],
      },
      {
        title: "Replay boundary",
        blocks: [
          {
            kind: "paragraph",
            text:
              "Replay loads the selected node request, sends it to the configured provider, persists the replacement response, and marks downstream nodes stale so the graph shows which branch needs fresh execution.",
          },
        ],
      },
    ],
  },
  {
    slug: "local-privacy",
    title: "Local privacy",
    category: "Using Tether",
    description:
      "Know which data stays local, where credentials live, and what leaves the developer machine.",
    sections: [
      {
        title: "Storage boundaries",
        blocks: [
          {
            kind: "table",
            headers: ["Data", "Location"],
            rows: [
              ["Trace calls", "Local SQLite"],
              ["Cached responses", "Local SQLite"],
              ["Provider keys", "Platform-local secret storage"],
              ["Provider requests", "Configured upstream only"],
            ],
          },
        ],
      },
      {
        title: "Operational note",
        blocks: [
          {
            kind: "paragraph",
            text:
              "Tether does not require a hosted workspace for local debugging. Teams should still avoid storing production secrets in sample repositories or logs.",
          },
        ],
      },
    ],
  },
  {
    slug: "supported-agents-and-frameworks",
    title: "Supported agents and frameworks",
    category: "Supported agents and frameworks",
    description:
      "Connect supported agent CLIs, LangChain, LangGraph, OpenAI/OpenGPT-style agents, and custom CLI agents to Tether through source adapters and normalized event ingestion.",
    sections: [
      {
        title: "Source model",
        blocks: [
          {
            kind: "paragraph",
            text:
              "Tether is source-adapter based. A source can be local logs, callback events, OpenAI-compatible proxy traffic, or a wrapped CLI process. Each source is normalized into the same local execution graph.",
          },
          {
            kind: "code",
            language: "text",
            code:
              "tether capture -- <agent command>\n  -> wrapper starts or uses local proxy\n  -> agent traffic plus tool, file, shell, and test events are captured\n  -> local trace DB\n  -> macOS or Linux desktop execution graph",
          },
        ],
      },
      {
        title: "Connection paths",
        blocks: [
          {
            kind: "table",
            headers: ["Source", "How it connects"],
            rows: [
              ["Local agent logs", "Supported local logs can be ingested by a source adapter and normalized into execution events."],
              ["Agent CLIs", "Run tether capture -- <agent command> so the wrapper can collect process, shell, file, and proxy events."],
              ["LangChain", "Use callbacks for tool and chain events, or route OpenAI-compatible model traffic through the local proxy."],
              ["LangGraph", "Use graph callbacks for node transitions, or proxy model traffic through Tether when the model client supports base_url."],
              ["OpenAI/OpenGPT-style agents", "Point OpenAI-compatible base_url traffic at the local Tether proxy."],
              ["Custom CLI agents", "Connect custom local workflows through the capture wrapper or a source adapter."],
            ],
          },
        ],
      },
      {
        title: "What gets normalized",
        blocks: [
          {
            kind: "list",
            items: [
              "User request and turn-scoped prompt text.",
              "LLM requests and responses with provider metadata.",
              "Tool calls, file reads, file writes, shell commands, test runs, git diffs, and errors.",
              "Replay and rollback evidence where the selected source supports it.",
            ],
          },
        ],
      },
    ],
  },
  {
    slug: "roadmap",
    title: "Product roadmap",
    category: "Roadmap",
    description:
      "What Tether is building next across capture, recovery, desktop clients, integrations, and release quality.",
    sections: [
      {
        title: "Roadmap principle",
        blocks: [
          {
            kind: "paragraph",
            text:
              "Tether is not trying to become a hosted agent workspace. The product direction is a local execution debugger for AI coding agents: capture the real run, preserve exact evidence, show the failure path, and make recovery faster.",
          },
          {
            kind: "list",
            items: [
              "Prefer local execution evidence over generic analytics.",
              "Keep prompt, action, file diff, command, test, and recovery data connected.",
              "Ship debugger controls only when the source can support them honestly.",
              "Avoid fake replay promises for events that only have log evidence.",
            ],
          },
        ],
      },
      {
        title: "Now",
        blocks: [
          {
            kind: "table",
            headers: ["Area", "Focus", "Outcome"],
            rows: [
              ["Execution capture", "Local source logs, proxy-captured requests, local trace storage, and normalized graph nodes.", "A developer can see the prompt, model request, response, metadata, and source context for a local agent run."],
              ["Desktop debuggers", "macOS and Linux clients with graph selection, inspector panes, settings, local proxy control, and source-log ingestion.", "The desktop apps are the primary local debugging surfaces."],
              ["Recovery evidence", "Replay for supported proxy-captured requests and rollback context for file-changing nodes.", "A failed branch has enough evidence for targeted recovery instead of blind reruns."],
              ["Public docs", "Architecture, supported agents, commands, privacy, release workflow, and API reference.", "The site explains the real product shape instead of presenting Tether as a generic observability tool."],
            ],
          },
        ],
      },
      {
        title: "Next",
        blocks: [
          {
            kind: "table",
            headers: ["Area", "Planned work", "Why it matters"],
            rows: [
              ["Capture wrapper", "Harden tether capture -- <agent command> across local coding-agent workflows.", "The wrapper is the cleanest path to full prompt, process, shell, file, and test attribution."],
              ["Failure-first graph", "Make failed commands, failed tests, changed files, and stale downstream branches easier to scan.", "The graph should answer where the run broke before it asks users to inspect every node."],
              ["Replay boundaries", "Make replay availability explicit per source, request type, and provider route.", "A debugger loses trust if it shows controls that cannot actually recover the selected node."],
              ["Adapter coverage", "Deepen supported CLI, framework, OpenAI-compatible, and custom source ingestion.", "Tether should follow the agent stack developers already use instead of forcing a new runtime."],
            ],
          },
        ],
      },
      {
        title: "Later",
        blocks: [
          {
            kind: "table",
            headers: ["Area", "Direction", "Constraint"],
            rows: [
              ["Windows client", "Build a desktop client around the same local proxy and execution graph contract.", "Do not add placeholder runtime code until it can build and run."],
              ["Team evidence export", "Export traces, failure reports, and recovery context for issue trackers, pull requests, or incident notes.", "Exports must avoid leaking secrets and must preserve exact file and command attribution."],
              ["Release quality", "Tighten signing, notarization, update checks, smoke tests, and packaged helper verification.", "Distribution quality has to catch up before broad public release."],
            ],
          },
        ],
      },
      {
        title: "Not on the roadmap",
        blocks: [
          {
            kind: "list",
            items: [
              "A hosted web IDE as the main product surface.",
              "Generic LLM observability dashboards detached from local file, command, and test evidence.",
              "Provider-specific lock-in that makes Tether useful only for one model vendor.",
              "Replay buttons for sources that cannot safely replay the selected execution boundary.",
            ],
          },
        ],
      },
    ],
  },
  {
    slug: "architecture-overview",
    title: "System overview",
    category: "Architecture",
    description:
      "A high-level map of the local-first desktop clients, Rust proxy, storage layer, provider upstreams, and release automation.",
    sections: [
      {
        title: "Runtime shape",
        blocks: [
          {
            kind: "code",
            language: "text",
            code:
              "tether capture -- <agent command>\n      -> wrapper starts or uses local proxy\n      -> source adapters normalize agent events\n      -> SQLite trace database\n      -> macOS or Linux desktop execution graph",
          },
          {
            kind: "paragraph",
            text:
              "The proxy is one capture path, not the whole product. Tether also ingests local logs and adapter events, stores normalized execution evidence locally, and serves a local REST API consumed by the macOS and Linux apps.",
          },
        ],
      },
      {
        title: "Module map",
        blocks: [
          {
            kind: "table",
            headers: ["Surface", "Responsibility"],
            rows: [
              ["tether capture", "Wrap local agent commands and coordinate proxy or adapter-based capture."],
              ["core/proxy/src/gateway", "Provider routing, upstream forwarding, cache hit responses, stream completion."],
              ["core/proxy/src/trace", "Capture, summarize, persist, query, replay, rollback evidence, and session lifecycle."],
              ["apps/macos/Sources/Core", "Shared trace models and reducer state."],
              ["apps/macos/Sources/Networking", "Proxy API, local launcher, Keychain, and source-log ingestion."],
              ["apps/macos/Tether/Features", "App shell, graph, sidebar, inspector, settings, and welcome UI."],
              ["apps/linux", "Tauri shell, React graph, inspector, settings, and Linux sidecar proxy control."],
              ["apps/web", "Marketing site and public documentation pages."],
            ],
          },
        ],
      },
    ],
  },
  {
    slug: "architecture-execution-graph",
    title: "Execution graph architecture",
    category: "Architecture",
    description:
      "The Tether graph represents agent execution, not just model requests.",
    sections: [
      {
        title: "Not an LLM request tree",
        blocks: [
          {
            kind: "paragraph",
            text:
              "The graph is an agent execution graph. LLM calls are only one event type. The useful debugging question is what the agent changed, ran, broke, and can recover from.",
          },
          {
            kind: "paragraph",
            text:
              "A single user request can produce model calls, tool calls, file reads, file writes, shell commands, tests, git diffs, errors, replay attempts, and rollback evidence. Tether keeps those events connected so the desktop app can move from prompt to action to failure to recovery.",
          },
        ],
      },
      {
        title: "Event types",
        blocks: [
          {
            kind: "table",
            headers: ["Event", "Meaning"],
            rows: [
              ["llm.request", "A model request with turn-scoped prompt, provider, model, token, latency, cache, and response metadata."],
              ["tool.call", "A tool invocation made by the agent or framework."],
              ["file.read", "A file or workspace input used by the agent."],
              ["file.write", "A file creation, edit, or deletion produced by the agent."],
              ["shell.command", "A shell command, including command line, stdout, stderr, duration, and exit status."],
              ["test.run", "A test command or test-result event with pass/fail status."],
              ["git.diff", "A diff summary with changed files and line counts."],
              ["error", "A model, tool, shell, test, or adapter failure."],
              ["replay", "A supported replay attempt from a proxy-captured request boundary."],
              ["rollback", "A local recovery or revert action tied to file and diff evidence."],
            ],
          },
        ],
      },
      {
        title: "Graph node contract",
        blocks: [
          {
            kind: "list",
            items: [
              "Each node should show the actual user request or event-specific action for that turn.",
              "Node cards preserve file changes, changed line counts, command or test status, timing, token, model, source, and request metadata.",
              "Sidebar selection focuses the graph camera on the selected node.",
              "Replay controls only appear for sources that can safely replay a stored request.",
            ],
          },
        ],
      },
    ],
  },
  {
    slug: "architecture-proxy",
    title: "Rust proxy architecture",
    category: "Architecture",
    description:
      "The backend is a modular monolith: small Rust modules with explicit service boundaries and a single binary.",
    sections: [
      {
        title: "Request path",
        blocks: [
          {
            kind: "list",
            items: [
              "gateway parses the incoming path and chooses OpenAI-compatible or Anthropic upstreams.",
              "context derives model, prompt, preview, and input hashes from provider payloads.",
              "trace ingestion queues persistence work so the proxy hot path does not block on SQLite.",
              "cache stores and replays identical request bodies for local iteration.",
            ],
          },
        ],
      },
      {
        title: "Trace services",
        blocks: [
          {
            kind: "table",
            headers: ["Module", "Responsibility"],
            rows: [
              ["capture", "Build TraceCapture from request metadata and body previews."],
              ["summarize", "Extract response text, token counts, language, and tool ids."],
              ["store", "Convert captures and outcomes into trace_calls rows."],
              ["query", "Read trace snapshots and session lists for the UI API."],
              ["replay", "Replay selected nodes and invalidate downstream branches."],
            ],
          },
        ],
      },
    ],
  },
  {
    slug: "architecture-app",
    title: "macOS app architecture",
    category: "Architecture",
    description:
      "The app uses small SwiftUI views over shared Core, Networking, and UI Swift package modules.",
    sections: [
      {
        title: "Swift package modules",
        blocks: [
          {
            kind: "table",
            headers: ["Module", "Responsibility"],
            rows: [
              ["Core", "Trace models, session reducer state, and dependency contracts."],
              ["Networking", "Trace API client, proxy settings, Keychain storage, launcher, and local log observers."],
              ["UI", "Shared visual components, palette tokens, dividers, badges, and glass surfaces."],
            ],
          },
        ],
      },
      {
        title: "App feature slices",
        blocks: [
          {
            kind: "list",
            items: [
              "MainLayout owns polling, snapshot merging, trace actions, and export helpers.",
              "Graph renders nodes, anchors, connections, gestures, zoom, and drag state.",
              "Inspector renders prompt, response, metadata, error, and replay controls.",
              "Sidebar renders search, call rows, status, and settings entry points.",
              "Settings owns proxy URLs, provider keys, cache clearing, and proxy restart actions.",
            ],
          },
        ],
      },
    ],
  },
  {
    slug: "architecture-linux-app",
    title: "Linux app architecture",
    category: "Architecture",
    description:
      "The Linux desktop app is a Tauri shell over the shared local proxy, with a React graph UI and Rust desktop commands.",
    sections: [
      {
        title: "Source layout",
        blocks: [
          {
            kind: "table",
            headers: ["Path", "Responsibility"],
            rows: [
              ["apps/linux/src/app", "React app state, proxy polling, node selection, replay, and workspace attribution."],
              ["apps/linux/src/features", "Graph canvas, inspector, replay footer, settings, and sidebar surfaces."],
              ["apps/linux/src/infrastructure", "Tauri bridge clients for proxy requests, proxy process control, and workspace snapshots."],
              ["apps/linux/src-tauri/src", "Rust commands that start the sidecar proxy, bridge HTTP requests, and read workspace diffs."],
              ["core/proxy", "Shared Rust proxy binary used by macOS and Linux."],
            ],
          },
        ],
      },
      {
        title: "Runtime flow",
        blocks: [
          {
            kind: "code",
            language: "text",
            code:
              "apps/linux Tauri window\n  -> starts or finds tether-proxy\n  -> calls proxy_request through Tauri\n  -> reads /api/traces/current/summary\n  -> renders draggable graph nodes, connections, inspector, and replay controls",
          },
          {
            kind: "paragraph",
            text:
              "The Linux app does not duplicate backend logic. It owns desktop process control and UI behavior, while trace capture, replay, cache, provider routing, and SQLite storage stay in core/proxy.",
          },
        ],
      },
      {
        title: "Build commands",
        blocks: [
          {
            kind: "code",
            language: "bash",
            code:
              "npm --prefix apps/linux ci\nnpm --prefix apps/linux run build\ncargo check --manifest-path apps/linux/src-tauri/Cargo.toml\n./scripts/package-linux.sh",
          },
          {
            kind: "list",
            items: [
              "The package script builds core/proxy in release mode.",
              "The Linux bundle receives tether-proxy as a Tauri sidecar.",
              "Generated files stay out of git through the root .gitignore.",
            ],
          },
        ],
      },
      {
        title: "Current limits",
        blocks: [
          {
            kind: "list",
            items: [
              "Linux uses a Tauri desktop shell over the shared local proxy.",
              "Nodes appear only when traffic or local commands are captured through the proxy or tether capture.",
              "Browser previews cannot start the local proxy because Tauri commands are desktop-only.",
            ],
          },
        ],
      },
    ],
  },
  {
    slug: "architecture-windows-app",
    title: "Windows app status",
    category: "Architecture",
    description:
      "The Windows folder is reserved for the next desktop client and is marked as in development for the next 53 days.",
    sections: [
      {
        title: "Status",
        blocks: [
          {
            kind: "table",
            headers: ["Area", "State"],
            rows: [
              ["Path", "apps/windows"],
              ["Runtime", "Not implemented yet"],
              ["Readiness window", "53 days"],
              ["Shared backend", "core/proxy"],
            ],
          },
          {
            kind: "paragraph",
            text:
              "The folder exists to reserve the platform boundary. It should not contain placeholder runtime code until the Windows app can build and run.",
          },
        ],
      },
      {
        title: "Planned scope",
        blocks: [
          {
            kind: "list",
            items: [
              "Desktop shell for the local execution debugger.",
              "Local proxy startup and health checks.",
              "Trace graph with draggable nodes, connections, inspector, and replay controls.",
              "Packaging path for Windows installer artifacts.",
            ],
          },
        ],
      },
    ],
  },
  {
    slug: "architecture-ci-cd",
    title: "CI/CD and releases",
    category: "Architecture",
    description:
      "GitHub Actions enforce the migration guardrails and publish DMG artifacts from version tags.",
    sections: [
      {
        title: "CI jobs",
        blocks: [
          {
            kind: "table",
            headers: ["Job", "Gate"],
            rows: [
              ["file-size", "No tracked Rust or Swift source file exceeds 200 lines."],
              ["proxy-smoke", "Agent request flows through proxy, SQLite, and UI API."],
              ["rust-quality", "cargo fmt, clippy, tests, and rustdoc warnings."],
              ["macos-app", "Swift package build, Xcode build, DocC build, and SwiftLint."],
            ],
          },
        ],
      },
      {
        title: "Release automation",
        blocks: [
          {
            kind: "code",
            language: "bash",
            code: "git tag v0.1.0\ngit push origin v0.1.0",
          },
          {
            kind: "paragraph",
            text:
              "Pushing a v* tag runs the Release workflow, builds dist/Tether.dmg with scripts/package-dmg.sh, and uploads the DMG to GitHub Releases using the built-in GITHUB_TOKEN.",
          },
        ],
      },
    ],
  },
  {
    slug: "api-reference",
    title: "API reference",
    category: "Reference",
    description:
      "The local proxy exposes trace, replay, settings, auth, and OpenAPI routes for the desktop app.",
    sections: [
      {
        title: "Trace routes",
        blocks: [
          {
            kind: "table",
            headers: ["Route", "Use"],
            rows: [
              ["GET /api/trace", "Read the current trace snapshot."],
              ["DELETE /api/trace", "Clear captured traces."],
              ["POST /api/trace/:id/replay", "Replay a selected trace node."],
            ],
          },
        ],
      },
      {
        title: "Contract source",
        blocks: [
          {
            kind: "paragraph",
            text:
              "The OpenAPI contract lives in core/proxy/openapi.json. Keep it aligned with DTOs and route behavior when the local API changes.",
          },
        ],
      },
    ],
  },
  {
    slug: "commands",
    title: "Commands",
    category: "Reference",
    description:
      "Common commands for local development, verification, packaging, and release preflight.",
    sections: [
      {
        title: "Installed app",
        blocks: [
          {
            kind: "code",
            language: "bash",
            code: "tether help\ntether version\ntether doctor\ntether open\ntether update\ntether uninstall\ntether uninstall --purge",
          },
        ],
      },
      {
        title: "Verification",
        blocks: [
          {
            kind: "code",
            language: "bash",
            code:
              "scripts/check-file-size.sh\ncd core/proxy && cargo fmt --check && cargo clippy --workspace --all-targets -- -D warnings\ncd ../.. && scripts/smoke-e2e.sh",
          },
        ],
      },
      {
        title: "macOS app",
        blocks: [
          {
            kind: "code",
            language: "bash",
            code:
              "xcodebuild -project apps/macos/Tether.xcodeproj -scheme Tether -configuration Debug -destination 'generic/platform=macOS' -derivedDataPath /tmp/TetherDerivedData build CODE_SIGNING_ALLOWED=NO",
          },
        ],
      },
    ],
  },
  {
    slug: "release-workflow",
    title: "Release workflow",
    category: "Reference",
    description:
      "Ship a versioned DMG by tagging main and letting GitHub Actions create the release asset.",
    sections: [
      {
        title: "Checklist",
        blocks: [
          {
            kind: "list",
            items: [
              "Confirm main is green in GitHub Actions.",
              "Choose the next semantic version tag.",
              "Push the tag to origin.",
              "Watch the Release workflow.",
              "Confirm Tether.dmg is attached to GitHub Releases.",
            ],
          },
          {
            kind: "code",
            language: "bash",
            code: "git tag v0.1.0\ngit push origin v0.1.0",
          },
        ],
      },
      {
        title: "Signing note",
        blocks: [
          {
            kind: "paragraph",
            text:
              "The current packaging script uses ad-hoc signing. Developer ID signing and notarization should be added before a wide public release.",
          },
        ],
      },
    ],
  },
];

/** Default documentation page rendered at /docs. */
export const DOCS_HOME_SLUG = "overview";

/** Lookup map used by static routes and metadata generation. */
export const DOCS_PAGE_MAP = new Map(DOCS_PAGES.map((page) => [page.slug, page]));

/** Linear page order used by previous/next navigation. */
export const DOCS_ORDER = DOCS_NAV_GROUPS.flatMap((group) => group.links.map((link) => link.slug));
