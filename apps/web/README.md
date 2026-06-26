# Tether
### The local execution debugger for AI coding agents.

Tether is a local execution debugger for AI coding agents. It tracks what the agent changed, ran, broke, and how to recover it.

[Website](https://useTether.dev) • [Docs](#quick-start) • [Discord](#) • [GitHub](https://github.com/Hqzdev/Tether)

---

## Product Vision

AI agents are becoming production systems, but the tools around them still feel like logs, guesswork, and late-night incident reports.

Tether turns each execution run into a recoverable graph: every prompt, tool action, file change, failure, and test result is traceable to the step that broke the project.

The product is local-first by design. Prompts stay on the machine. API keys stay in the Keychain. Execution traces stay in local storage. Tether is a debugger, not a hosted dashboard.

---

## Core Capabilities

### Moderation / Security

| Feature | Description |
| --- | --- |
| 🛡 Local Privacy Engine | Capture prompts, responses, metadata, and provider calls without shipping sensitive traces to a third-party backend. |
| 🔐 Keychain-Aware Secrets | Keep API credentials in macOS Keychain instead of scattering tokens across scripts, shells, and notebooks. |
| 🧭 Audit-Ready Trace History | Review what happened, when it happened, which provider was called, and how the agent moved through the flow. |

### Engagement / Growth

| Feature | Description |
| --- | --- |
| 🌱 Faster Debugging Loops | Turn unclear agent behavior into a visual story developers, founders, and product teams can discuss together. |
| 🧩 Provider-Agnostic Workflow | Work across OpenAI, Anthropic, Ollama, LM Studio, LangChain, LangGraph, LlamaIndex, and OpenAI-compatible APIs. |
| 📈 Root-Cause Recovery | Connect prompt, action, file change, failed command, and recovery path in one execution graph. |

### Automation

| Feature | Description |
| --- | --- |
| 🚀 Zero-SDK Proxy | Point your client at `http://localhost:8080/v1` and capture calls without rewriting your app. |
| ⚡ Smart Response Caching | Reuse known responses during development to cut latency, cost, and repetitive provider calls. |
| 🧪 Recovery Replay | Edit a failed step, replay from that point, and validate the affected branch without rerunning the entire run. |

### Monetization

| Feature | Description |
| --- | --- |
| 💳 Cost Visibility | See which calls cost money, which calls came from cache, and where development spend is leaking. |
| 📊 Latency-to-Value Signals | Understand whether a provider, model, cache layer, or tool step is slowing the experience down. |
| 🧮 Usage-Aware Product Decisions | Connect agent behavior to cost, reliability, and product polish before scaling usage. |

### Community Infrastructure

| Feature | Description |
| --- | --- |
| 🧱 Shared Debugging Language | Replace scattered terminal output with a clear UI your team can use to reason about agent behavior. |
| 🧪 Local Test Workbench | Mock responses, reproduce failures, and iterate on agent flows without depending on live provider state. |
| 🛰 Extensible Agent Surface | Designed to grow into a deeper infrastructure layer for local agent testing, replay, and observability. |

---

## Why This Product

1. **No-code first debugging**  
   Capture agent behavior through a local proxy instead of instrumenting every SDK call by hand.

2. **Modular system**  
   Use Tether as a local execution debugger that links prompts, file changes, failures, and replayed fixes.

3. **Recovery evidence in real time**  
   Inspect changed files, command output, failed tests, and downstream impact while the execution is still running.

4. **Built for scale**  
   Start with one local workflow, then expand into repeatable debugging patterns for larger agent systems.

5. **Privacy-first architecture**  
   Agent traces, prompts, responses, and keys stay local by default.

6. **AI-native architecture**  
   Built around prompt-driven actions, file edits, failures, tool chains, and the messy shape of real execution workflows.


---

## Tech Stack

| Layer | Stack |
| --- | --- |
| Frontend | Next.js 15 / React 19 / TypeScript |
| UI | Hugeicons / custom component system / macOS-inspired interface patterns |
| Styling | Custom CSS design tokens, adaptive layouts, dark and light theme support |
| Backend | Next.js API routes / Rust local proxy |
| Email | Resend-powered waitlist flow |
| Data | Local SQLite traces / local cache metadata |
| Hosting | Vercel-ready web deployment |

---

## Pages Overview

| Page or Route | Description |
| --- | --- |
| `/` | Product landing page with hero, product proof, sample trace inspector, setup steps, privacy review, feedback, and alpha access sections. |
| `/#features` | On-page product proof section with the Visual Tree Canvas and feature cards. |
| `/#demo` | On-page embedded sample trace inspector with graph, cache, replay, and privacy states. |
| `/#security` | On-page privacy review section with storage, key handling, telemetry, and replay evidence. |
| `/#download` | On-page feedback and alpha access section. |
| `/product`, `/features`, `/inspector`, `/how-it-works`, `/download` | Data-driven product information pages generated from `apps/web/lib/site-pages.ts`. |
| `/developers`, `/documentation`, `/cli-reference`, `/changelog`, `/company`, `/privacy`, `/security`, `/contact` | Additional generated information pages. |
| `/docs` and `/docs/[slug]` | Documentation hub and detail pages generated from `apps/web/lib/docs-pages.ts`. |
| `/api/waitlist` | Waitlist capture endpoint for early access requests. |
| `/api/feedback` | Landing-page feedback endpoint. |

---

## Visual Identity

Tether is designed like a premium developer instrument, not a marketing toy.

**Gradient system**  
Soft electric accents sit on top of dark, technical surfaces. Color is used for state, motion, and focus instead of decoration.

**Typography hierarchy**  
Large editorial headlines explain the product story, while compact interface typography keeps traces, metadata, and actions readable.

**Motion & micro-interactions**  
Subtle transitions make agent flow feel alive: nodes update, states shift, panels respond, and replay actions feel immediate.

**Capsule UI**  
Pills, segmented controls, compact status chips, and rounded command surfaces create a polished operating-system feel.

**Adaptive layouts**  
The site scales from landing-page storytelling to dense developer UI without losing rhythm, hierarchy, or scanability.

---

## Quick Start

```bash
git clone https://github.com/Hqzdev/Tether.git
cd Tether/web
npm install
npm run dev
```

The web app runs at:

```bash
http://localhost:3000
```

For a production build:

```bash
npm run build
npm start
```

---

## Roadmap

### Now

- Local proxy capture for OpenAI-compatible requests
- Visual execution graph for multi-step agent workflows
- Smart caching and replay-ready response history
- macOS-first interface with privacy-focused local storage

### Next

- Rich provider adapters for OpenAI, Anthropic, Ollama, and LM Studio
- Recovery replay for edited outputs and deterministic branch validation
- Download page, release channel, and polished DMG distribution
- Deeper docs for LangChain, LangGraph, and LlamaIndex workflows

### Future

- Platform expansion beyond local macOS workflows
- AI customization engine for trace summaries, test suggestions, and failure diagnosis
- Team-ready trace sharing with privacy controls
- Plugin ecosystem for agent frameworks, evals, and internal tools

---

## Built by Hqz.dev

Designed with obsession for community experience.
