/** Structured block types supported by the documentation renderer. */
export type DocsBlock =
  | { kind: "paragraph"; text: string }
  | { kind: "list"; items: string[] }
  | { kind: "code"; language: string; code: string }
  | { kind: "table"; headers: string[]; rows: string[][] }
  | { kind: "cards"; cards: { title: string; text: string; href: string }[] };

/** One titled section in a documentation article. */
export type DocsSection = {
  title: string;
  blocks: DocsBlock[];
};

/** Data model for one generated documentation page. */
export type DocsPage = {
  slug: string;
  title: string;
  category: string;
  description: string;
  sections: DocsSection[];
};

/** Sidebar group used to render the documentation navigation. */
export type DocsNavGroup = {
  title: string;
  links: { slug: string; label: string }[];
};

/** Stable sidebar hierarchy for the documentation section. */
export const DOCS_NAV_GROUPS: DocsNavGroup[] = [
  {
    title: "Getting Started",
    links: [
      { slug: "overview", label: "Overview" },
      { slug: "install", label: "Install" },
      { slug: "routing-provider-calls", label: "Route provider calls" },
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
    title: "Architecture",
    links: [
      { slug: "architecture-overview", label: "System overview" },
      { slug: "architecture-proxy", label: "Rust proxy" },
      { slug: "architecture-app", label: "macOS app" },
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

/** Generated documentation pages shown under /docs. */
export const DOCS_PAGES: DocsPage[] = [
  {
    slug: "overview",
    title: "Tether documentation",
    category: "Docs",
    description:
      "Install Tether, route local LLM traffic through the proxy, inspect traces, replay failed branches, and understand the architecture behind the desktop app.",
    sections: [
      {
        title: "What Tether does",
        blocks: [
          {
            kind: "paragraph",
            text:
              "Tether is a local-first observability tool for agent builders. It runs a Rust proxy on the developer machine, stores captured calls in SQLite, and renders the run inside a native macOS SwiftUI app.",
          },
          {
            kind: "list",
            items: [
              "Capture OpenAI-compatible and Anthropic calls through a local proxy.",
              "Inspect prompt, response, latency, tokens, cost, cache state, and errors.",
              "Replay from a selected trace node with edited or mocked model output.",
              "Keep API keys in macOS Keychain and trace data on the local machine.",
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
                text: "The desktop app, Rust proxy, SQLite stores, provider upstreams, and release pipeline in one map.",
                href: "/docs/architecture-overview",
              },
              {
                title: "Rust proxy",
                text: "Gateway, cache, trace capture, replay, auth, settings, and OpenAPI boundaries.",
                href: "/docs/architecture-proxy",
              },
              {
                title: "macOS app",
                text: "Swift package modules, graph panes, inspector panes, settings, and Codex log ingestion.",
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
      "Build the local proxy, run the macOS app, and package a DMG when you need a release artifact.",
    sections: [
      {
        title: "Local developer setup",
        blocks: [
          {
            kind: "code",
            language: "bash",
            code: "cd proxy\ncargo build\ncd ../web\nnpm install\nnpm run dev",
          },
          {
            kind: "paragraph",
            text:
              "The web app is the public site and documentation surface. The macOS app lives under ui/ and the proxy binary is built from proxy/.",
          },
        ],
      },
      {
        title: "Package the desktop app",
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
              "Creates dist/Tether.dmg and mirrors it into web/public/downloads/.",
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
              "Use the local proxy as the SDK base URL. Tether forwards the request upstream, records the response, and exposes the captured trace through the local UI API.",
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
    slug: "reading-traces",
    title: "Reading traces",
    category: "Using Tether",
    description:
      "Understand the graph, sidebar, inspector, and status metadata shown by the desktop app.",
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
              "error: upstream or network failure captured as a trace node.",
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
              ["Metadata", "Review latency, tokens, cost, cache, provider, and request ids."],
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
      "Use cached responses to keep local iteration cheap and replay a downstream branch from a selected node.",
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
              ["Provider keys", "macOS Keychain"],
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
    slug: "architecture-overview",
    title: "System overview",
    category: "Architecture",
    description:
      "A high-level map of the local-first desktop app, Rust proxy, storage layer, provider upstreams, and release automation.",
    sections: [
      {
        title: "Runtime shape",
        blocks: [
          {
            kind: "code",
            language: "text",
            code:
              "Agent SDK -> http://127.0.0.1:8080/v1\n      -> Rust proxy gateway\n      -> OpenAI / Anthropic upstream\n      -> SQLite trace + cache stores\n      -> SwiftUI macOS app",
          },
          {
            kind: "paragraph",
            text:
              "The proxy is the only network hop added to the agent path. It forwards provider calls, records request and response metadata, and serves a local REST API consumed by the macOS app.",
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
              ["proxy/src/gateway", "Provider routing, upstream forwarding, cache hit responses, stream completion."],
              ["proxy/src/trace", "Capture, summarize, persist, query, replay, and session lifecycle."],
              ["ui/Sources/Core", "Shared trace models and reducer state."],
              ["ui/Sources/Networking", "Proxy API, local launcher, Keychain, and Codex log ingestion."],
              ["ui/Tether/Features", "App shell, graph, sidebar, inspector, settings, and welcome UI."],
              ["web", "Marketing site and public documentation pages."],
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
              ["Networking", "Trace API client, proxy settings, Keychain storage, launcher, and Codex log observer."],
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
              "The OpenAPI contract lives in docs/api/openapi.json. Keep it aligned with DTOs and route behavior when the local API changes.",
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
        title: "Verification",
        blocks: [
          {
            kind: "code",
            language: "bash",
            code:
              "scripts/check-file-size.sh\ncd proxy && cargo fmt --check && cargo clippy --workspace --all-targets -- -D warnings\ncd .. && scripts/smoke-e2e.sh",
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
              "xcodebuild -project ui/Tether.xcodeproj -scheme Tether -configuration Debug -destination 'generic/platform=macOS' -derivedDataPath /tmp/TetherDerivedData build CODE_SIGNING_ALLOWED=NO",
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
