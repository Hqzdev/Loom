/** Marketing page data rendered by the generic footer-page route. */
export type SitePage = {
  slug: string;
  title: string;
  eyebrow: string;
  description: string;
  sections: {
    title: string;
    body: string;
    bullets?: string[];
  }[];
  reviewRows?: {
    control: string;
    evidence: string;
    proof: string;
  }[];
  cta?: {
    label: string;
    href: string;
  };
};

/** Static marketing and company pages exposed by /[slug]. */
export const SITE_PAGES: SitePage[] = [
  {
    slug: "product",
    title: "Product",
    eyebrow: "Local-first agent observability",
    description:
      "Tether gives AI builders a single Mac-native workspace for tracing, inspecting, caching, and replaying LLM calls.",
    sections: [
      {
        title: "Built around the real shape of agent work",
        body:
          "Agent runs are not linear logs. They branch, retry, call tools, hit caches, fail in strange places, and recover in ways that are hard to see from a terminal. Tether turns those runs into a readable product surface.",
        bullets: ["Visual call trees", "Provider metadata", "Prompt and response inspection", "Replay-ready traces"],
      },
      {
        title: "Private by default",
        body:
          "The product is designed for sensitive workflows where prompts, customer data, and API keys should stay local. Tether keeps traces on your machine and puts secrets in macOS Keychain.",
      },
    ],
    cta: { label: "Download the alpha", href: "/download" },
  },
  {
    slug: "features",
    title: "Features",
    eyebrow: "Everything needed to debug modern agents",
    description:
      "A complete debugging loop for local AI development: capture calls, inspect state, replay branches, and understand cost.",
    sections: [
      {
        title: "Trace capture",
        body:
          "Route OpenAI-compatible calls through the local proxy and see every request become a structured node in the Tether interface.",
        bullets: ["Request and response bodies", "Latency and status", "Model metadata", "Nested tool-call context"],
      },
      {
        title: "Replay and mocking",
        body:
          "Edit a response, replay from a node, and test downstream behavior without burning tokens on every upstream call.",
        bullets: ["Mock JSON responses", "Replay selected branches", "Cache-aware development", "Deterministic iteration"],
      },
    ],
    cta: { label: "Open inspector page", href: "/inspector" },
  },
  {
    slug: "inspector",
    title: "Inspector",
    eyebrow: "The right pane for every agent decision",
    description:
      "Inspect prompts, responses, metadata, timing, cache state, failures, and replay controls from one focused panel.",
    sections: [
      {
        title: "Prompt and response clarity",
        body:
          "Read exactly what went into a model and what came back out, formatted for scanning instead of buried in raw terminal output.",
      },
      {
        title: "Operational context",
        body:
          "See whether a call was cached, how long it took, what it cost, and where it sits in the larger agent tree.",
        bullets: ["Status chips", "Cache metadata", "Token counts", "Provider and model details"],
      },
    ],
    cta: { label: "See how it works", href: "/how-it-works" },
  },
  {
    slug: "how-it-works",
    title: "How it works",
    eyebrow: "One proxy, full visibility",
    description:
      "Tether runs a local HTTP proxy. Point your SDK at localhost, run your agent, and inspect the trace.",
    sections: [
      {
        title: "1. Route calls through Tether",
        body:
          "Change the SDK base URL to the local Tether endpoint. Your application keeps using the same request shape.",
      },
      {
        title: "2. Capture the run",
        body:
          "The proxy forwards requests to your configured provider while recording the call tree, metadata, timings, and responses locally.",
      },
      {
        title: "3. Replay the interesting part",
        body:
          "Select a node, edit or mock the response, then rerun downstream logic from that point forward.",
      },
    ],
    cta: { label: "Read documentation", href: "/documentation" },
  },
  {
    slug: "download",
    title: "Download",
    eyebrow: "Alpha for macOS",
    description:
      "Get the Mac build, connect the local proxy, and trace your first AI agent workflow in minutes.",
    sections: [
      {
        title: "macOS-first",
        body:
          "Tether is crafted for local development on the Mac, with Keychain-aware secrets, a native-feeling interface, and local trace storage.",
        bullets: ["macOS 13+", "Local proxy included", "No account required for local tracing", "Free during alpha"],
      },
      {
        title: "What you get",
        body:
          "The alpha includes the web landing, local proxy, trace capture, cache metadata, and the evolving Mac interface.",
      },
    ],
    cta: { label: "Join the waitlist", href: "/#download" },
  },
  {
    slug: "developers",
    title: "Developers",
    eyebrow: "For people shipping agent systems",
    description:
      "Tether is designed for engineers building AI products, internal tools, copilots, autonomous workflows, and agent infrastructure.",
    sections: [
      {
        title: "Use it with your existing stack",
        body:
          "Keep your SDKs, models, and frameworks. Tether sits in front of provider calls and gives you a better debugging surface.",
        bullets: ["OpenAI-compatible clients", "LangChain", "LangGraph", "LlamaIndex", "Ollama and LM Studio"],
      },
      {
        title: "Debug before production",
        body:
          "Find slow calls, broken branches, retry loops, and confusing model behavior while you can still fix the workflow locally.",
      },
    ],
    cta: { label: "View CLI reference", href: "/cli-reference" },
  },
  {
    slug: "documentation",
    title: "Documentation",
    eyebrow: "Setup and operating guide",
    description:
      "A practical guide to installing Tether, routing provider calls, reading traces, using cache, and replaying responses.",
    sections: [
      {
        title: "Quick setup",
        body:
          "Install dependencies, start the web app, run the local proxy, then point your SDK base URL at Tether.",
        bullets: ["Clone the repo", "Run npm install", "Start the web app", "Configure the local proxy"],
      },
      {
        title: "Architecture pages",
        body:
          "The generated docs section now covers the system overview, Rust proxy modules, macOS app modules, CI/CD, releases, local privacy, commands, and API boundaries.",
        bullets: ["System overview", "Rust proxy", "macOS app", "CI/CD and releases"],
      },
    ],
    cta: { label: "Open docs", href: "/docs" },
  },
  {
    slug: "cli-reference",
    title: "CLI reference",
    eyebrow: "Commands for local workflows",
    description:
      "Reference material for running the proxy, packaging the app, validating builds, and debugging local traces.",
    sections: [
      {
        title: "Common commands",
        body:
          "The CLI surface is evolving with the proxy. These commands document the local development workflow.",
        bullets: ["npm run dev", "npm run build", "npm run package:dmg", "npm run smoke:e2e"],
      },
      {
        title: "Proxy operations",
        body:
          "Future CLI commands will expose provider setup, cache inspection, trace export, and replay utilities.",
      },
    ],
    cta: { label: "Read changelog", href: "/changelog" },
  },
  {
    slug: "changelog",
    title: "Changelog",
    eyebrow: "Product progress",
    description:
      "A running record of Tether releases, proxy improvements, UI updates, and developer workflow changes.",
    sections: [
      {
        title: "Current alpha",
        body:
          "The current build focuses on the landing experience, waitlist flow, trace UI direction, local proxy skeleton, and response caching.",
        bullets: ["Next.js product site", "macOS app structure", "Rust proxy foundation", "Local cache and trace models"],
      },
      {
        title: "Next releases",
        body:
          "Upcoming entries will track signed downloads, provider adapters, replay workbench, and documentation updates.",
      },
    ],
    cta: { label: "Download alpha", href: "/download" },
  },
  {
    slug: "company",
    title: "Company",
    eyebrow: "Built by Hqz.dev",
    description:
      "Tether is created for developers who need AI systems to feel inspectable, reliable, and worthy of user trust.",
    sections: [
      {
        title: "Our belief",
        body:
          "AI tools should not ask teams to accept mystery as part of the workflow. Great agent products need great debugging surfaces.",
      },
      {
        title: "Our standard",
        body:
          "We care about product craft, local privacy, fast iteration, and interfaces that make complex systems feel understandable.",
      },
    ],
    cta: { label: "Contact us", href: "/contact" },
  },
  {
    slug: "privacy",
    title: "Privacy",
    eyebrow: "Local-first by design",
    description:
      "Tether is built around the principle that prompts, responses, traces, and API keys should stay close to the developer.",
    sections: [
      {
        title: "Local trace storage",
        body:
          "Captured agent data is designed to live locally, so sensitive prompts and responses are not uploaded to a third-party dashboard by default.",
      },
      {
        title: "Key handling",
        body:
          "API credentials are handled with macOS Keychain-aware storage patterns instead of plain text project files.",
      },
    ],
    cta: { label: "Read security", href: "/security" },
  },
  {
    slug: "security",
    title: "Security",
    eyebrow: "Trust starts at the machine",
    description:
      "Tether reduces debugging risk by keeping the observability loop local, explicit, and inspectable.",
    sections: [
      {
        title: "No hidden telemetry promise",
        body:
          "The product is designed so developers can verify what leaves the machine and what stays in local storage.",
      },
      {
        title: "Provider boundaries",
        body:
          "Requests are forwarded only to the providers you configure. Tether should be a debugging layer, not another place where secrets drift.",
      },
    ],
    reviewRows: [
      {
        control: "Prompt and response storage",
        evidence: "Trace data is written to local SQLite on the developer machine.",
        proof: "~/.Tether/traces.sqlite",
      },
      {
        control: "API key handling",
        evidence: "Provider secrets are stored through macOS Keychain, not in plaintext project files.",
        proof: "macOS Keychain",
      },
      {
        control: "Telemetry posture",
        evidence: "The app does not require a hosted Tether account for local debugging.",
        proof: "No cloud workspace",
      },
      {
        control: "Reproducible failures",
        evidence: "Failed runs can be replayed from a selected node with mocked outputs.",
        proof: "Replay chain",
      },
    ],
    cta: { label: "Contact security", href: "/contact" },
  },
  {
    slug: "contact",
    title: "Contact",
    eyebrow: "Talk to the builder",
    description:
      "Reach out for alpha access, product feedback, security notes, partnerships, or developer workflow questions.",
    sections: [
      {
        title: "Alpha access",
        body:
          "Join through the download page and share what kind of agent system you are building so the product can prioritize the right workflows.",
      },
      {
        title: "Direct feedback",
        body:
          "For now, GitHub is the best place to open issues, track changes, and follow the product as it moves toward a public alpha.",
      },
    ],
    cta: { label: "Open GitHub", href: "https://github.com/Hqzdev/Tether" },
  },
];

/** Lookup map used by the generic static page route. */
export const SITE_PAGE_MAP = new Map(SITE_PAGES.map((page) => [page.slug, page]));
