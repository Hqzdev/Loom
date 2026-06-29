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
  securityMetrics?: {
    label: string;
    value: string;
    detail: string;
    percent: number;
    tone: "local" | "external" | "audit";
  }[];
  securityFlow?: {
    label: string;
    detail: string;
  }[];
  securityMatrix?: {
    asset: string;
    location: string;
    leavesDevice: string;
    control: string;
  }[];
  securityRisks?: {
    area: string;
    status: string;
    owner: string;
    nextStep: string;
  }[];
  cta?: {
    label: string;
    href: string;
  };
};

export const SITE_PAGES: SitePage[] = [
  {
    slug: "product",
    title: "Product",
    eyebrow: "Local-first execution debugging",
    description:
      "Tether is a local execution debugger for AI coding agents on macOS and Linux: prompt, action, file diff, failed command, and recovery in one desktop graph.",
    sections: [
      {
        title: "Built around the real shape of agent work",
        body:
          "Agent runs are not LLM request trees. They read files, write diffs, call tools, run shell commands, break tests, retry, and recover. Tether turns that local activity into a readable execution graph.",
        bullets: ["Prompt to action", "File diff evidence", "Command and test status", "Recovery-ready traces"],
      },
      {
        title: "Private by default",
        body:
          "The product is designed for sensitive coding workflows where prompts, traces, and API keys should stay local. Tether keeps traces on your machine and uses platform-local secret handling.",
      },
    ],
    cta: { label: "Download the alpha", href: "/#download" },
  },
  {
    slug: "features",
    title: "Features",
    eyebrow: "Everything needed to recover broken AI code runs",
    description:
      "A complete loop for local AI execution debugging: capture the request, inspect actions and file diffs, see failed commands or tests, and recover quickly.",
    sections: [
      {
        title: "Execution capture",
        body:
          "Use tether capture -- <agent command>, source adapters, or OpenAI-compatible proxying to see prompts, tool calls, commands, tests, and file changes in a structured graph.",
        bullets: ["Agent CLI sources", "LangChain and LangGraph adapters", "Command output and exit status", "File diff and line counts"],
      },
      {
        title: "Recovery actions",
        body:
          "Replay supported proxy-captured requests, compare outcomes, or roll back from local evidence when a run came from source logs.",
        bullets: ["Supported replay boundaries", "Rollback evidence", "Cache-aware development", "Failure recovery"],
      },
    ],
    cta: { label: "Inspect demo trace", href: "/#demo" },
  },
  {
    slug: "inspector",
    title: "Inspector",
    eyebrow: "The right pane for every agent decision",
    description:
      "Inspect prompts, responses, file changes, metadata, timing, command status, failures, and recovery controls from one focused panel.",
    sections: [
      {
        title: "Prompt and response clarity",
        body:
          "Read exactly what the user asked, what the agent did, which files changed, and what came back from the model or tool.",
      },
      {
        title: "Operational context",
        body:
          "See whether a step was cached, how long it took, what it cost, which command failed, and where it sits in the larger execution graph.",
        bullets: ["Status chips", "Cache metadata", "Token counts", "Source and adapter details"],
      },
    ],
    cta: { label: "See how it works", href: "/how-it-works" },
  },
  {
    slug: "how-it-works",
    title: "How it works",
    eyebrow: "Capture wrapper, proxy, graph",
    description:
      "Tether wraps local agent commands, starts or uses the local proxy, captures normalized execution events, and shows the run in the macOS or Linux desktop app.",
    sections: [
      {
        title: "1. Capture the agent run",
        body:
          "Run tether capture -- <agent command>, connect a source adapter, or point OpenAI-compatible traffic at the local proxy.",
      },
      {
        title: "2. Normalize the evidence",
        body:
          "Tether records prompt, action, file diff, shell command, test run, git diff, error, replay, and rollback events into a local trace database.",
      },
      {
        title: "3. Replay the recovery point",
        body:
          "Select a failed node, inspect the evidence, then use supported replay or rollback paths instead of rerunning blindly.",
      },
    ],
    cta: { label: "Read documentation", href: "/documentation" },
  },
  {
    slug: "developers",
    title: "Developers",
    eyebrow: "For people shipping AI coding agents",
    description:
      "Tether is designed for engineers building AI products, internal tools, copilots, autonomous workflows, and agent infrastructure.",
    sections: [
      {
        title: "Use it with your existing stack",
        body:
          "Keep your agents, SDKs, models, and frameworks. Tether connects through adapters and normalized event ingestion.",
        bullets: ["Agent CLIs", "Framework agents", "LangChain", "LangGraph", "OpenAI/OpenGPT-style agents", "Custom CLI agents"],
      },
      {
        title: "Debug before production",
        body:
          "Find broken branches, file-impacting steps, and confusing model behavior while you can still recover locally.",
      },
    ],
    cta: { label: "View CLI reference", href: "/cli-reference" },
  },
  {
    slug: "documentation",
    title: "Documentation",
    eyebrow: "Setup and operating guide",
    description:
      "A practical guide to installing Tether, connecting source adapters, reading execution graphs, and recovering broken agent runs.",
    sections: [
      {
        title: "Quick setup",
        body:
          "Install from the terminal, let the script verify the machine, then capture an agent run through tether capture -- or a supported source adapter.",
        bullets: ["Run the install command", "Verify system requirements", "Open the desktop app", "Capture a local agent run"],
      },
      {
        title: "Architecture pages",
        body:
          "The docs cover supported agents and frameworks, execution graph semantics, Rust proxy modules, macOS and Linux desktop clients, local privacy, commands, and API boundaries.",
        bullets: ["Supported agents", "Execution graph", "Rust proxy", "Desktop clients"],
      },
    ],
    cta: { label: "Open docs", href: "/docs" },
  },
  {
    slug: "cli-reference",
    title: "CLI reference",
    eyebrow: "Commands for local workflows",
    description:
      "Reference material for capture, proxy operation, packaging the app, validating builds, and debugging local execution paths.",
    sections: [
      {
        title: "Common commands",
        body:
          "The installed CLI manages the desktop app and keeps developer commands discoverable from the terminal.",
        bullets: ["curl -fsSL https://tetherapp.vercel.app/install.sh | bash", "tether help", "tether doctor", "tether update", "tether uninstall", "tether uninstall --purge"],
      },
      {
        title: "Proxy operations",
        body:
          "The CLI direction centers on capture, adapter setup, trace export, cache inspection, and supported replay utilities.",
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
          "The current build focuses on local execution debugging: source logs, proxy-captured requests, dense node cards, file impact, and recovery workflows.",
        bullets: ["Next.js docs site", "macOS graph app", "Linux Tauri app", "Rust proxy foundation"],
      },
      {
        title: "Next releases",
        body:
          "Upcoming entries will track signed downloads, provider adapters, recovery replay, and documentation updates.",
      },
    ],
    cta: { label: "Download alpha", href: "/#download" },
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
      "Tether is built around the principle that prompts, responses, execution traces, and API keys should stay close to the developer.",
    sections: [
      {
        title: "Local trace storage",
        body:
          "Captured agent data is designed to live locally, so sensitive prompts and responses are not uploaded to a third-party dashboard by default.",
      },
      {
        title: "Key handling",
        body:
          "API credentials use platform-local handling instead of plain text project files: Keychain-aware storage on macOS and the local proxy settings path on Linux.",
      },
    ],
    cta: { label: "Read security", href: "/security" },
  },
  {
    slug: "security",
    title: "Security",
    eyebrow: "Trust starts at the machine",
    description:
      "Tether reduces debugging risk by keeping the recovery loop local, explicit, and inspectable.",
    sections: [
      {
        title: "Local evidence, not hosted dashboards",
        body:
          "Tether is built for debugging sensitive agent runs without turning every prompt into another SaaS data copy. The core security claim is narrow: local traces, explicit provider calls, platform-local secrets, and inspectable replay state.",
        bullets: ["Trace database stays on the developer machine", "Provider traffic follows your configured endpoints", "No hosted Tether workspace is required for local debugging"],
      },
      {
        title: "Threat model for the alpha",
        body:
          "The alpha should be evaluated as a local debugging tool, not as a compliance platform. The important questions are whether prompts are copied elsewhere, whether secrets sit in project files, and whether replay changes can be traced back to a concrete node.",
        bullets: ["No claim of SOC 2 or enterprise audit coverage yet", "Local machine compromise remains out of scope", "Provider-side data handling is governed by the provider you choose"],
      },
    ],
    securityMetrics: [
      {
        label: "Local trace artifacts",
        value: "100%",
        detail: "Prompt, response, cache, replay, and metadata records are designed for local SQLite storage.",
        percent: 100,
        tone: "local",
      },
      {
        label: "Required hosted Tether services",
        value: "0",
        detail: "Local debugging does not require a Tether account, cloud dashboard, or remote project sync.",
        percent: 4,
        tone: "local",
      },
      {
        label: "External provider boundary",
        value: "Explicit",
        detail: "Only model-provider requests leave the device, and they follow the provider endpoints you configure.",
        percent: 64,
        tone: "external",
      },
      {
        label: "Compliance posture",
        value: "Alpha",
        detail: "Security posture is architecture-led today; formal certifications are not claimed.",
        percent: 38,
        tone: "audit",
      },
    ],
    securityFlow: [
      {
        label: "Your app",
        detail: "Sends OpenAI-compatible requests to localhost.",
      },
      {
        label: "Local proxy",
        detail: "Captures request metadata and forwards the call.",
      },
      {
        label: "Provider",
        detail: "Receives only the configured model request.",
      },
      {
        label: "Local SQLite",
        detail: "Stores trace, cache, replay, and failure evidence.",
      },
      {
        label: "Inspector",
        detail: "Reads local records for debugging and replay.",
      },
    ],
    securityMatrix: [
      {
        asset: "Prompts",
        location: "Local trace database",
        leavesDevice: "Only inside configured provider requests",
        control: "Request-level inspection",
      },
      {
        asset: "Model responses",
        location: "Local trace database",
        leavesDevice: "No Tether-hosted upload",
        control: "Replay diff and node history",
      },
      {
        asset: "API keys",
        location: "Platform-local secret storage",
        leavesDevice: "Used only to call chosen providers",
        control: "OS and local proxy secret handling",
      },
      {
        asset: "Cache entries",
        location: "Local cache store",
        leavesDevice: "No remote cache sync",
        control: "Cache hit metadata",
      },
      {
        asset: "Replay edits",
        location: "Local replay state",
        leavesDevice: "No background telemetry path",
        control: "Invalidation and downstream scope",
      },
    ],
    securityRisks: [
      {
        area: "Local data at rest",
        status: "Owned by user machine",
        owner: "Developer",
        nextStep: "Use OS disk encryption and keep workspace access tight.",
      },
      {
        area: "Provider retention",
        status: "Provider-dependent",
        owner: "Configured provider",
        nextStep: "Choose provider settings and contracts that match the data sensitivity.",
      },
      {
        area: "Formal compliance",
        status: "Not claimed",
        owner: "Tether roadmap",
        nextStep: "Add published audit artifacts only when the product surface is stable.",
      },
      {
        area: "Trace export",
        status: "Requires deliberate action",
        owner: "Developer",
        nextStep: "Review exported files before sharing them outside the machine.",
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
        evidence: "Provider secrets use platform-local storage paths instead of plaintext project files.",
        proof: "macOS Keychain and local proxy settings",
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
          "Use the download section and share what kind of agent system you are building so the product can prioritize the right workflows.",
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

export const SITE_PAGE_MAP = new Map(SITE_PAGES.map((page) => [page.slug, page]));
