"use client";

import { type FormEvent, useEffect, useRef, useState } from "react";
import { NODES, SESSION, type NodeStatus, type TraceNode } from "@/lib/data";

const DOWNLOAD_HREF = "/downloads/Loom.dmg";

const ICON_PATHS = {
  "diagram-project":
    '<rect x="3" y="3" width="8" height="8" rx="2"/><rect x="13" y="13" width="8" height="8" rx="2"/><path d="M7 11v3a2 2 0 0 0 2 2h4"/>',
  bolt: '<path d="M11 2 3 14h7l-1 8 9-12h-7l1-8z"/>',
  "shield-halved":
    '<path d="M12 3 5 6v5c0 4 3 7.6 7 9 4-1.4 7-5 7-9V6l-7-3z"/><path d="M12 3v18"/>',
  "clock-rotate-left":
    '<path d="M3 12a9 9 0 1 0 2.6-6.3M3 4.5v4h4"/><path d="M12 8v4.2l3 1.8"/>',
  play: '<path d="M7 5l12 7-12 7V5z"/>',
  pause: '<path d="M7 5h3v14H7zM14 5h3v14h-3z"/>',
  "table-columns":
    '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M12 4v16"/>',
  "file-lines":
    '<path d="M14 3v5h5"/><path d="M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M8 13h8M8 17h8M8 9h2"/>',
  "arrow-down-long": '<path d="M12 4v15M7 14l5 5 5-5"/>',
  "circle-nodes":
    '<circle cx="6" cy="6" r="2.2"/><circle cx="18" cy="7" r="2.2"/><circle cx="12" cy="17.5" r="2.2"/><path d="M7.8 7.2 10.6 15.6M16.2 8.6 13.2 15.8M8.1 6.4 15.9 6.9"/>',
  spark:
    '<path d="M12 3v18M3 12h18M5.8 5.8l12.4 12.4M18.2 5.8 5.8 18.2"/>',
  flask:
    '<path d="M9 3h6M10 3v6l-5 9a2 2 0 0 0 1.8 3h10.4a2 2 0 0 0 1.8-3l-5-9V3"/><path d="M7.2 15h9.6"/>',
  link: '<path d="M10 13a5 5 0 0 0 7 0l3-3a5 5 0 0 0-7-7l-1.5 1.5"/><path d="M14 11a5 5 0 0 0-7 0l-3 3a5 5 0 0 0 7 7l1.5-1.5"/>',
  cube: '<path d="M12 2 3 7v10l9 5 9-5V7l-9-5z"/><path d="M3 7l9 5 9-5M12 12v10"/>',
  cubes:
    '<path d="M12 2 3 7v10l9 5 9-5V7l-9-5z"/><path d="M3 7l9 5 9-5M12 12v10"/>',
  microchip:
    '<rect x="6" y="6" width="12" height="12" rx="2"/><rect x="9.5" y="9.5" width="5" height="5" rx="1"/><path d="M9 2v3M15 2v3M9 19v3M15 19v3M2 9h3M2 15h3M19 9h3M19 15h3"/>',
  feather:
    '<path d="M20 4a6 6 0 0 0-8.5 0L5 10.5V19h8.5L20 12.5a6 6 0 0 0 0-8.5z"/><path d="M5 19 14 10M15 8l1.5 1.5"/>',
  lock: '<rect x="4.5" y="10.5" width="15" height="10.5" rx="2"/><path d="M8 10.5V7a4 4 0 0 1 8 0v3.5"/>',
  database:
    '<ellipse cx="12" cy="5.5" rx="7.5" ry="3"/><path d="M4.5 5.5v6c0 1.66 3.36 3 7.5 3s7.5-1.34 7.5-3v-6M4.5 11.5v6c0 1.66 3.36 3 7.5 3s7.5-1.34 7.5-3v-6"/>',
  key: '<circle cx="7.8" cy="15.7" r="4.3"/><path d="M10.8 12.7 21 2.5M16 7l3 3M14 9l2 2"/>',
  "tower-broadcast":
    '<circle cx="12" cy="8.5" r="1.6"/><path d="M12 10.2V21M9 21h6M8.6 5.1a5 5 0 0 0 0 6.8M15.4 5.1a5 5 0 0 1 0 6.8M6 3a8.5 8.5 0 0 0 0 11M18 3a8.5 8.5 0 0 1 0 11"/>',
  check: '<path d="M5 12.5l4.5 4.5L19 7"/>',
  "check-circle": '<circle cx="12" cy="12" r="9"/><path d="M8.2 12.4l2.6 2.6 5-5.4"/>',
  dot: '<circle cx="12" cy="12" r="6"/>',
  circle: '<circle cx="12" cy="12" r="8"/>',
  rotate: '<path d="M21 12a9 9 0 1 1-2.64-6.36M21 4.5V9h-4.5"/>',
  lightbulb:
    '<path d="M9.2 18h5.6M10.3 21h3.4M12 3a6 6 0 0 0-3.8 10.7c.7.6 1.1 1.4 1.2 2.3h5.2c.1-.9.5-1.7 1.2-2.3A6 6 0 0 0 12 3z"/>',
  gear: '<circle cx="12" cy="12" r="3"/><path d="M12 2.5v3M12 18.5v3M3.6 7l2.6 1.5M17.8 15.5l2.6 1.5M3.6 17l2.6-1.5M17.8 8.5l2.6-1.5"/>',
  "circle-exclamation":
    '<circle cx="12" cy="12" r="9"/><path d="M12 7.5v5.5"/><circle cx="12" cy="16.4" r="0.6" fill="currentColor" stroke="none"/>',
  github:
    '<path d="M12 2C6.48 2 2 6.48 2 12c0 4.42 2.87 8.17 6.84 9.5.5.09.68-.22.68-.48 0-.24-.01-.87-.01-1.7-2.78.6-3.37-1.34-3.37-1.34-.45-1.16-1.11-1.47-1.11-1.47-.91-.62.07-.61.07-.61 1 .07 1.53 1.03 1.53 1.03.89 1.52 2.34 1.08 2.91.83.09-.65.35-1.08.63-1.33-2.22-.25-4.55-1.11-4.55-4.94 0-1.09.39-1.98 1.03-2.68-.1-.25-.45-1.27.1-2.65 0 0 .84-.27 2.75 1.02.8-.22 1.65-.33 2.5-.34.85.01 1.7.12 2.5.34 1.91-1.29 2.75-1.02 2.75-1.02.55 1.38.2 2.4.1 2.65.64.7 1.03 1.59 1.03 2.68 0 3.84-2.34 4.69-4.57 4.94.36.31.68.92.68 1.85 0 1.34-.01 2.42-.01 2.75 0 .27.18.58.69.48A10.01 10.01 0 0 0 22 12c0-5.52-4.48-10-10-10z"/>',
  star: '<path d="M12 2l2.9 6.26L22 9.27l-5.2 4.87 1.3 6.86L12 17.77l-6.1 3.23 1.3-6.86L2 9.27l7.1-1.01L12 2z"/>',
  apple:
    '<path d="M16.37 12.78c-.02-2.2 1.8-3.26 1.88-3.31-1.03-1.5-2.62-1.71-3.19-1.73-1.36-.14-2.65.8-3.34.8-.69 0-1.75-.78-2.88-.76-1.48.02-2.85.86-3.61 2.19-1.54 2.67-.39 6.62 1.11 8.79.73 1.06 1.6 2.25 2.74 2.21 1.1-.04 1.51-.71 2.84-.71 1.32 0 1.7.71 2.86.69 1.18-.02 1.93-1.08 2.65-2.15.84-1.23 1.18-2.42 1.2-2.48-.03-.01-2.29-.88-2.31-3.49zM14.4 6.24c.61-.74 1.02-1.77.91-2.8-.88.04-1.95.59-2.58 1.33-.56.65-1.06 1.7-.93 2.7.98.08 1.99-.5 2.6-1.23z"/>',
  python:
    '<path d="M12 2c-2 0-3.5.6-3.5 2.6V7H12v.8H6.5C4.5 7.8 3.5 9 3.5 11.5S4.4 15 6.5 15h1.3v-2.2c0-1.8 1.4-3.1 3.2-3.1h3.5c1.6 0 2.5-1 2.5-2.6V4.6C20.5 2.8 19 2 17 2h-5zm-1.7 1.4a.9.9 0 1 1 0 1.8.9.9 0 0 1 0-1.8z"/><path d="M12 22c2 0 3.5-.6 3.5-2.6V17H12v-.8h5.5c2 0 3-1.2 3-3.7S19.6 9 17.5 9h-1.3v2.2c0 1.8-1.4 3.1-3.2 3.1H9.5c-1.6 0-2.5 1-2.5 2.6v2.5C7 21.2 8.5 22 10.5 22H12zm1.7-1.4a.9.9 0 1 1 0-1.8.9.9 0 0 1 0 1.8z"/>',
} as const;

const ICON_ALIASES = {
  "mountain-sun": "spark",
  "circle-dot": "dot",
  tool: "gear",
  error: "circle-exclamation",
} as const;

type BaseIconName = keyof typeof ICON_PATHS;
type LandingIconName = BaseIconName | keyof typeof ICON_ALIASES;

const FILLED_ICONS = new Set<BaseIconName>([
  "github",
  "star",
  "apple",
  "play",
  "pause",
  "bolt",
  "dot",
]);

function LandingIcon({
  name,
  className = "",
}: {
  name: LandingIconName;
  className?: string;
}) {
  const resolved = (ICON_ALIASES as Partial<Record<LandingIconName, BaseIconName>>)[name] ?? (name as BaseIconName);
  const filled = FILLED_ICONS.has(resolved);

  return (
    <svg
      className={`ic ${className}`.trim()}
      viewBox="0 0 24 24"
      fill={filled ? "currentColor" : "none"}
      stroke={filled ? "none" : "currentColor"}
      strokeWidth={filled ? undefined : 1.7}
      strokeLinecap={filled ? undefined : "round"}
      strokeLinejoin={filled ? undefined : "round"}
      aria-hidden="true"
      dangerouslySetInnerHTML={{ __html: ICON_PATHS[resolved] }}
    />
  );
}

const CODE_LINES: { t: string; c?: string }[][] = [
  [
    { t: "from", c: "tk-bool" },
    { t: " openai " },
    { t: "import", c: "tk-bool" },
    { t: " OpenAI" },
  ],
  [],
  [{ t: "# route every call through Loom", c: "tk-comment" }],
  [
    { t: "client " },
    { t: "=", c: "tk-punc" },
    { t: " OpenAI(" },
  ],
  [
    { t: "    base_url" },
    { t: "=", c: "tk-punc" },
    { t: ' "http://localhost:8080/v1"', c: "tk-str" },
  ],
  [{ t: ")" }],
  [],
  [
    { t: "agent" },
    { t: ".", c: "tk-punc" },
    { t: "run(" },
    { t: '"Order #4471 - where is my package?"', c: "tk-str" },
    { t: ")" },
  ],
];

const TRUST_PROVIDERS: { icon: LandingIconName; label: string }[] = [
  { icon: "circle-nodes", label: "OpenAI" },
  { icon: "mountain-sun", label: "Anthropic" },
  { icon: "cubes", label: "Ollama" },
  { icon: "flask", label: "LM Studio" },
  { icon: "link", label: "LangChain" },
  { icon: "diagram-project", label: "LangGraph" },
  { icon: "cube", label: "LlamaIndex" },
];

const FEATURES: {
  view: InspectorView;
  acc: "green" | "cyan" | "amber" | "violet";
  icon: LandingIconName;
  title: string;
  copy: string;
}[] = [
  {
    view: "graph",
    acc: "green",
    icon: "diagram-project",
    title: "Visual Tree",
    copy: "Render the full call graph, node by node.",
  },
  {
    view: "cache",
    acc: "cyan",
    icon: "bolt",
    title: "Smart Caching",
    copy: "Inspect cache metadata: is_cached, 0ms latency, $0.",
  },
  {
    view: "time",
    acc: "amber",
    icon: "clock-rotate-left",
    title: "Time-Travel Mocking",
    copy: "Edit a past response and replay the chain.",
  },
  {
    view: "privacy",
    acc: "violet",
    icon: "shield-halved",
    title: "Air-Gapped Privacy",
    copy: "Keys in Keychain, traces in local SQLite.",
  },
];

const VIEW_META: Record<InspectorView, { dot: string; title: string; model: string }> = {
  graph: { dot: "green", title: "Customer Support Agent", model: "5 nodes" },
  cache: { dot: "cyan", title: "2. Vector DB Retrieval", model: "text-embedding-3-lg" },
  time: { dot: "amber", title: "1. Intent Classification", model: "gpt-4o" },
  privacy: { dot: "violet", title: "Secrets & Storage", model: "local" },
};

const TREE_LAYOUT: {
  status: NodeStatus;
  icon: LandingIconName;
  label: string;
  sub: string;
}[] = [
  { status: "success", icon: "check-circle", label: "Intent Classification", sub: "gpt-4o" },
  { status: "cached", icon: "bolt", label: "Vector DB Retrieval", sub: "cached - 0ms" },
  { status: "success", icon: "check-circle", label: "Context Synthesis", sub: "claude-3.5-sonnet" },
  { status: "error", icon: "circle-exclamation", label: "Response Generation", sub: "timeout - 4.10s" },
];

type InspectorView = "graph" | "cache" | "time" | "privacy";
type ReplayState = "idle" | "running" | "done";
type WaitlistState = "idle" | "submitting" | "done" | "error";

function usePrefersReducedMotion() {
  const [reduce, setReduce] = useState(false);

  useEffect(() => {
    const media = window.matchMedia("(prefers-reduced-motion: reduce)");
    setReduce(media.matches);
    const handleChange = () => setReduce(media.matches);
    media.addEventListener("change", handleChange);
    return () => media.removeEventListener("change", handleChange);
  }, []);

  return reduce;
}

function useRevealOnScroll() {
  useEffect(() => {
    const els = Array.from(document.querySelectorAll<HTMLElement>(".reveal"));

    if (!("IntersectionObserver" in window)) {
      els.forEach((el) => el.classList.add("in"));
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("in");
            observer.unobserve(entry.target);
          }
        });
      },
      { rootMargin: "0px 0px -6% 0px", threshold: 0.12 },
    );

    els.forEach((el) => observer.observe(el));
    return () => observer.disconnect();
  }, []);
}

function nodeIconName(node: TraceNode): LandingIconName {
  if (node.status === "cached") return "database";
  if (node.status === "error") return "circle-exclamation";
  if (node.icon === "tool") return "gear";
  return node.icon as LandingIconName;
}

function nodeLatencyClass(status: NodeStatus) {
  if (status === "cached") return "cy";
  if (status === "error") return "pk";
  return "ok";
}

function statusLabel(status: NodeStatus) {
  return status === "cached" ? "CACHED" : status === "error" ? "ERROR" : "SUCCESS";
}

function MiniNode({
  node,
  depth,
  visible = true,
  shake = false,
}: {
  node: TraceNode;
  depth: number;
  visible?: boolean;
  shake?: boolean;
}) {
  return (
    <div
      className={`mini-node ${node.status} ${visible ? "in" : ""} ${shake ? "shake" : ""}`.trim()}
      data-depth={Math.min(depth, 4)}
    >
      <div className="mhead">
        <span className="mn-ico">
          <LandingIcon name={nodeIconName(node)} />
        </span>
        <span className="mn-name">{node.step}</span>
        <span className="mn-stat">{statusLabel(node.status)}</span>
      </div>
      <div className="mn-foot">
        <span className={nodeLatencyClass(node.status)}>{node.latency}</span>
        <span>{node.cost}</span>
        <span>
          {node.tokensIn} in / {node.tokensOut} out
        </span>
      </div>
    </div>
  );
}

function CodeEditor({
  visibleLines,
  activeLine,
}: {
  visibleLines: number;
  activeLine: number | null;
}) {
  return (
    <div className="editor-code" id="editorCode">
      {CODE_LINES.slice(0, visibleLines).map((tokens, index) => (
        <div className={`cline ${index === 4 ? "hl" : ""}`.trim()} key={`line-${index}`}>
          <span className="gut">{index + 1}</span>
          <span className="src">
            {tokens.map((token, tokenIndex) => (
              <span className={token.c} key={`${index}-${tokenIndex}`}>
                {token.t}
              </span>
            ))}
            {activeLine === index ? <span className="caret" /> : null}
          </span>
        </div>
      ))}
    </div>
  );
}

function InspectorGraph() {
  return (
    <div className="graphview" id="graphView">
      {NODES.map((node, index) => (
        <MiniNode node={node} depth={index} key={node.id} />
      ))}
    </div>
  );
}

export default function LoomLanding() {
  const reduce = usePrefersReducedMotion();
  const treeRef = useRef<HTMLDivElement>(null);
  const [navStuck, setNavStuck] = useState(false);
  const [visibleLines, setVisibleLines] = useState(0);
  const [activeLine, setActiveLine] = useState<number | null>(null);
  const [heroTreeCount, setHeroTreeCount] = useState(0);
  const [isIntercepting, setIsIntercepting] = useState(false);
  const [runStatus, setRunStatus] = useState("listening on :8080");
  const [runFiring, setRunFiring] = useState(false);
  const [shakeError, setShakeError] = useState(false);
  const [treeStarted, setTreeStarted] = useState(false);
  const [treeStep, setTreeStep] = useState(0);
  const [activeView, setActiveView] = useState<InspectorView>("graph");
  const [replayState, setReplayState] = useState<ReplayState>("idle");
  const [waitlistEmail, setWaitlistEmail] = useState("");
  const [waitlistName, setWaitlistName] = useState("");
  const [waitlistReason, setWaitlistReason] = useState("");
  const [waitlistState, setWaitlistState] = useState<WaitlistState>("idle");
  const [waitlistMessage, setWaitlistMessage] = useState("");

  useRevealOnScroll();

  useEffect(() => {
    const onScroll = () => setNavStuck(window.scrollY > 12);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => {
    let live = true;
    const sleep = (ms: number) => new Promise((resolve) => window.setTimeout(resolve, ms));

    async function runLoop() {
      if (reduce) {
        setVisibleLines(CODE_LINES.length);
        setActiveLine(null);
        setHeroTreeCount(NODES.length);
        setIsIntercepting(true);
        setRunStatus("5 calls traced - 1 error");
        return;
      }

      while (live) {
        setVisibleLines(0);
        setActiveLine(null);
        setHeroTreeCount(0);
        setIsIntercepting(false);
        setRunStatus("listening on :8080");
        setShakeError(false);

        for (let i = 0; i < CODE_LINES.length; i += 1) {
          if (!live) return;
          setVisibleLines(i + 1);
          setActiveLine(i);
          const lineLength = CODE_LINES[i].reduce((count, token) => count + token.t.length, 0);
          await sleep(90 + Math.min(lineLength * 7, 280));
        }

        setActiveLine(null);
        await sleep(450);
        setRunFiring(true);
        setRunStatus("POST /v1/chat/completions -> intercepted");
        setIsIntercepting(true);
        await sleep(500);
        setRunFiring(false);
        await sleep(120);

        for (let i = 0; i < NODES.length; i += 1) {
          if (!live) return;
          setHeroTreeCount(i + 1);
          if (NODES[i].status === "error") {
            await sleep(260);
            setShakeError(true);
          }
          await sleep(NODES[i].status === "error" ? 520 : 360);
        }

        setRunStatus("5 calls traced - 1 error - 6.47s");
        await sleep(3600);
      }
    }

    runLoop();
    return () => {
      live = false;
    };
  }, [reduce]);

  useEffect(() => {
    if (reduce) {
      setTreeStarted(true);
      setTreeStep(TREE_LAYOUT.length);
      return;
    }

    const el = treeRef.current;
    if (!el || !("IntersectionObserver" in window)) {
      setTreeStarted(true);
      return;
    }

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setTreeStarted(true);
          observer.disconnect();
        }
      },
      { threshold: 0.35 },
    );

    observer.observe(el);
    return () => observer.disconnect();
  }, [reduce]);

  useEffect(() => {
    if (!treeStarted || reduce) return;

    let live = true;
    async function draw() {
      for (let i = 0; i < TREE_LAYOUT.length; i += 1) {
        if (!live) return;
        setTreeStep(i + 1);
        await new Promise((resolve) => window.setTimeout(resolve, 480));
      }
    }

    draw();
    return () => {
      live = false;
    };
  }, [treeStarted, reduce]);

  function handleFeatureHover(view: InspectorView) {
    if (!window.matchMedia("(hover: none)").matches) setActiveView(view);
  }

  function replayChain() {
    setReplayState("running");
    window.setTimeout(() => {
      setReplayState("done");
      window.setTimeout(() => setReplayState("idle"), 1900);
    }, 1300);
  }

  async function joinWaitlist(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;

    if (!form.reportValidity()) return;

    setWaitlistState("submitting");
    setWaitlistMessage("");

    try {
      const formData = new FormData(form);
      const response = await fetch(form.action, {
        method: "POST",
        body: formData,
      });
      const result = (await response.json()) as { ok?: boolean; error?: string };

      if (!response.ok || !result.ok) {
        throw new Error(result.error || "Could not join the waitlist.");
      }

      setWaitlistState("done");
      setWaitlistMessage("You're on the alpha list. I'll send the DMG link when the next build is ready.");
      setWaitlistEmail("");
      setWaitlistName("");
      setWaitlistReason("");
      form.reset();
    } catch (error) {
      setWaitlistState("error");
      setWaitlistMessage(error instanceof Error ? error.message : "Could not join the waitlist.");
    }
  }

  const meta = VIEW_META[activeView];
  const replayIcon = replayState === "running" ? "rotate" : replayState === "done" ? "check" : "rotate";
  const replayText =
    replayState === "running"
      ? "Replaying chain..."
      : replayState === "done"
        ? "Replayed - 4 nodes re-ran"
        : "Replay chain from this node";

  return (
    <main className="landing-page">
      <nav className={`nav ${navStuck ? "stuck" : ""}`} id="nav">
        <div className="wrap nav-inner">
          <a className="brand" href="#top">
            <span className="logo">
              <LandingIcon name="diagram-project" />
            </span>
            Loom
          </a>
          <div className="nav-links">
            <a href="#features">Features</a>
            <a href="#inspector">Inspector</a>
            <a href="#how">How it works</a>
            <a href="#download">Download</a>
          </div>
          <div className="nav-right">
            <a className="gh-pill" href="#download" aria-label="Get the Loom alpha build">
              <LandingIcon name="circle" />
              Alpha build
            </a>
            <a className="btn btn-primary btn-sm" href="#download">
              <LandingIcon name="apple" />
              Download
            </a>
          </div>
        </div>
      </nav>

      <header className="hero wrap" id="top">
        <div className="center-row">
          <span className="eyebrow">
            <span className="dot" />
            Local-first observability for <b>macOS</b>
          </span>
        </div>
        <div className="center-row sp-row">
          <div className="social-proof">
            <div className="sp-avatars">
              <span className="sp-av" style={{ background: "linear-gradient(135deg,#5fd49a,#74cfe0)" }} />
              <span className="sp-av" style={{ background: "linear-gradient(135deg,#b39cf5,#ff8aa4)" }} />
              <span className="sp-av" style={{ background: "linear-gradient(135deg,#f5cd7a,#5aa0ff)" }} />
              <span className="sp-av" style={{ background: "linear-gradient(135deg,#74e0a8,#5aa0ff)" }} />
              <span className="sp-av" style={{ background: "linear-gradient(135deg,#ff8aa4,#f5cd7a)" }} />
            </div>
            <span className="sp-text">
              <b>500+</b> developers already tracing their agents
            </span>
          </div>
        </div>
        <h1>
          Stop debugging AI agents <span className="grad">in the dark.</span>
        </h1>
        <p className="lead">
          Loom intercepts every LLM call, visualizes complex agent trees,
          and mocks responses - entirely locally, on your Mac. No SDK, no cloud,
          no token leaks.
        </p>
        <div className="cta-row">
          <a className="btn btn-primary pulse" href="#download">
            <LandingIcon name="apple" />
            Download for macOS
          </a>
          <a className="btn btn-ghost" href="#features">
            <LandingIcon name="play" />
            See it in action
          </a>
        </div>
        <div className="meta-row">
          <span>
            <LandingIcon name="microchip" />
            Alpha DMG for macOS
          </span>
          <span>
            <LandingIcon name="feather" />
            Local proxy included
          </span>
          <span>
            <LandingIcon name="shield-halved" />
            Air-gapped by default
          </span>
        </div>

        <div className="demo-wrap reveal">
          <div className="demo-glow" />
          <div className="macwin">
            <div className="macbar">
              <span className="traffic">
                <i className="r" />
                <i className="y" />
                <i className="g" />
              </span>
              <span className="wtitle">
                Loom <span className="wbadge">{SESSION.id}</span>
              </span>
              <span className="spacer" />
              <span className="wdots">
                <LandingIcon name="play" />
                <LandingIcon name="pause" />
                <LandingIcon name="table-columns" />
              </span>
            </div>
            <div className="demo-grid">
              <div className="demo-editor">
                <div className="editor-tabs">
                  <span className="etab on">
                    <LandingIcon className="python-icon" name="python" />
                    agent.py
                  </span>
                  <span className="etab">
                    <LandingIcon name="file-lines" />
                    tools.py
                  </span>
                </div>
                <CodeEditor visibleLines={visibleLines} activeLine={activeLine} />
                <div className="editor-run">
                  <span className={`run-chip ${runFiring ? "firing" : ""}`}>
                    <LandingIcon name="bolt" />
                    Proxy intercept
                  </span>
                  <span>{runStatus}</span>
                </div>
              </div>
              <div className="demo-app">
                <div className="mini-head">
                  <span className="mini-proxy">
                    <span className="pdot" />
                    Local Proxy <b>Running</b> - :8080
                  </span>
                  <span className={`intercept ${isIntercepting ? "show" : ""}`}>
                    <LandingIcon name="arrow-down-long" />
                    intercepting POST /v1/chat/completions
                  </span>
                </div>
                <div className="mini-tree" id="miniTree">
                  {NODES.slice(0, heroTreeCount).map((node, index) => (
                    <MiniNode
                      depth={index}
                      key={node.id}
                      node={node}
                      shake={shakeError && node.status === "error"}
                    />
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>
      </header>

      <section className="trust wrap reveal">
        <p>Sits transparently in front of any provider</p>
        <div className="trust-row">
          {TRUST_PROVIDERS.map((provider) => (
            <span className="prov" key={provider.label}>
              <LandingIcon name={provider.icon} />
              {provider.label}
            </span>
          ))}
        </div>
      </section>

      <section className="section-pad wrap" id="features">
        <div className="section-head reveal">
          <div className="kicker">The 3-pane blueprint</div>
          <h2 className="title">Every agent run, drawn as a tree you can read.</h2>
          <p className="section-sub">
            Messy terminal logs become a hierarchical node graph in real time.
            Each LLM request is a node - color-coded by what actually happened.
          </p>
        </div>

        <div className="feat-layout">
          <div className="tree-stage reveal" id="treeStage" ref={treeRef}>
            <div className="ts-head">
              <LandingIcon name="diagram-project" />
              <span className="ttl">Visual Tree Canvas</span> - live render
            </div>
            <div className="tree-svg-wrap">
              <svg id="treeSvg" width="100%" viewBox="0 0 300 470" fill="none" xmlns="http://www.w3.org/2000/svg">
                {[0, 1, 2, 3].map((line) => (
                  <path
                    className={`tline tline-${line} ${treeStep > line ? "draw" : ""}`}
                    d={`M40 ${70 + line * 100} V${150 + line * 100}`}
                    key={line}
                    strokeWidth="1.5"
                  />
                ))}
              </svg>
              <div id="treeNodes">
                {TREE_LAYOUT.map((node, index) => (
                  <div
                    className={`s2node ${node.status} ${treeStep > index ? "in" : ""}`.trim()}
                    data-i={index}
                    key={node.label}
                  >
                    <span className="s2-ico">
                      <LandingIcon name={node.icon} />
                    </span>
                    <span className="s2-copy">
                      <span className="s2-label">{node.label}</span>
                      <span className="s2-sub">{node.sub}</span>
                    </span>
                    <span className="s2-status">{node.status}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>

          <div className="bento">
            <div className="bcard g span2 reveal">
              <div className="bico">
                <LandingIcon name="diagram-project" />
              </div>
              <h3>The Visual Tree Canvas</h3>
              <p>
                Every LLM request becomes a node in a graph. Nested tool-calls,
                retries, and sub-agents nest automatically - so the shape of
                your agent&apos;s reasoning is finally something you can see,
                not scroll past.
              </p>
              <div className="bstat">
                <span className="metric-chip ok">success</span>
                <span className="metric-chip cy">cached</span>
                <span className="metric-chip pink">error</span>
              </div>
            </div>
            <div className="bcard c reveal">
              <div className="bico">
                <LandingIcon name="bolt" />
              </div>
              <h3>Smart Edge Caching</h3>
              <p>
                Identical prompts hit a local SQLite cache. Iterate on
                downstream logic without re-paying for upstream calls.
              </p>
              <div className="bstat">
                <span className="metric-chip cy">&lt;1ms</span>
                <span className="metric-chip ok">$0.0000</span>
              </div>
            </div>
            <div className="bcard v reveal">
              <div className="bico">
                <LandingIcon name="clock-rotate-left" />
              </div>
              <h3>Time-Travel Mocking</h3>
              <p>
                Click any node in the past, rewrite its JSON output, and replay
                the chain from that point forward.
              </p>
              <div className="bstat">
                <span className="metric-chip">replay from any node</span>
              </div>
            </div>
            <div className="bcard p span2 reveal">
              <div className="bico">
                <LandingIcon name="shield-halved" />
              </div>
              <h3>Air-Gapped Privacy</h3>
              <p>
                API keys live encrypted in the macOS Keychain. Prompts,
                responses, and traces stay in a local SQLite database that never
                leaves the machine. Nothing is phoned home - verify it yourself
                with Little Snitch.
              </p>
              <div className="bstat">
                <span className="metric-chip ok">
                  <LandingIcon name="lock" /> Keychain
                </span>
                <span className="metric-chip">SQLite - local</span>
                <span className="metric-chip">0 outbound</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="section-pad wrap" id="inspector">
        <div className="section-head reveal">
          <div className="kicker">Synced inspector</div>
          <h2 className="title">Click a capability. Watch the inspector react.</h2>
          <p className="section-sub">
            The right pane is the real app&apos;s inspector. Pick a feature on
            the left - it switches state exactly like clicking a node in
            Loom.
          </p>
        </div>

        <div className="inspect-layout">
          <div className="feature-list reveal">
            {FEATURES.map((feature) => (
              <button
                className={`flcard ${activeView === feature.view ? "on" : ""}`.trim()}
                data-acc={feature.acc}
                data-view={feature.view}
                key={feature.view}
                onClick={() => setActiveView(feature.view)}
                onMouseEnter={() => handleFeatureHover(feature.view)}
                type="button"
              >
                <span className="fl-ico" data-acc={feature.acc}>
                  <LandingIcon name={feature.icon} />
                </span>
                <div className="fl-body">
                  <h4>{feature.title}</h4>
                  <p>{feature.copy}</p>
                </div>
              </button>
            ))}
          </div>

          <div className="macwin inspector reveal">
            <div className="insp-pane">
              <div className="insp-bar" id="inspBar">
                <span className={`idot ${meta.dot}`} id="inspDot" />
                <span className="ititle" id="inspTitle">
                  {meta.title}
                </span>
                <span className="imodel" id="inspModel">
                  {meta.model}
                </span>
              </div>
              <div className="insp-content">
                <div className={`insp-view ${activeView === "graph" ? "on" : ""}`} data-view="graph">
                  <InspectorGraph />
                </div>

                <div className={`insp-view ${activeView === "cache" ? "on" : ""}`} data-view="cache">
                  <div className="ctrlhead codeview">
                    <LandingIcon name="database" />
                    response.meta
                    <span className="grow" />
                    <span className="chip cy">CACHE HIT</span>
                    <span className="chip ok">200 OK</span>
                  </div>
                  {[
                    ["request_id", "req_3f88ab", ""],
                    ["is_cached", "true", "cyan"],
                    ["latency", "0ms", "cyan"],
                    ["cost", "$0.0000", "green"],
                    ["tokens_saved", "1,840 in - 256 out", "green"],
                    ["embedding_hash", "e3b0c44298fc1c14", ""],
                    ["retrieved_from", "local_cache", "cyan"],
                    ["store", "~/.loom/cache.sqlite", ""],
                    ["hit_rate (session)", "62%", "green"],
                  ].map(([key, value, tone]) => (
                    <div className="kv" key={key}>
                      <span className="k">{key}</span>
                      <span className={`v ${tone}`.trim()}>{value}</span>
                    </div>
                  ))}
                </div>

                <div className={`insp-view ${activeView === "time" ? "on" : ""}`} data-view="time">
                  <div className="ttedit">
                    <div className="ctrlhead codeview">
                      <LandingIcon name="clock-rotate-left" />
                      editing response.json
                      <span className="grow" />
                      <span className="chip warn">UNSAVED</span>
                    </div>
                    <pre className="tt-area" id="ttArea">
{`{
  `}
<span className="json-key">&quot;intent&quot;</span>
{`: `}
<span className="json-string">&quot;order_status&quot;</span>
{`,
  `}
<span className="json-key">&quot;confidence&quot;</span>
{`: `}
<span className="json-number">0.97</span>
{`,
  `}
<span className="json-key">&quot;entities&quot;</span>
{`: {
`}
<span className="editline">    &quot;sentiment&quot;: &quot;calm&quot;,  &lt;- mocked</span>
{`
    `}
<span className="json-key">&quot;order_id&quot;</span>
{`: `}
<span className="json-string">&quot;4471&quot;</span>
{`
  }
}`}
                    </pre>
                    <div className="tt-foot">
                      <button
                        className={`tt-btn ${replayState === "done" ? "done" : ""}`.trim()}
                        disabled={replayState === "running"}
                        id="ttBtn"
                        onClick={replayChain}
                        type="button"
                      >
                        <LandingIcon className={replayState === "running" ? "spin" : ""} name={replayIcon} />
                        {replayText}
                      </button>
                    </div>
                  </div>
                </div>

                <div className={`insp-view ${activeView === "privacy" ? "on" : ""}`} data-view="privacy">
                  <div className="ctrlhead codeview">
                    <LandingIcon name="shield-halved" />
                    secrets &amp; storage
                    <span className="grow" />
                    <span className="chip ok">
                      <LandingIcon name="lock" /> encrypted
                    </span>
                  </div>
                  <div className="privacy-view">
                    {[
                      ["key", "OPENAI_API_KEY", "sk-********************7f2a - macOS Keychain", "SECURE"],
                      ["key", "ANTHROPIC_API_KEY", "sk-ant-************91be - macOS Keychain", "SECURE"],
                      ["database", "Trace database", "~/.loom/traces.sqlite - 0 bytes sent", "LOCAL"],
                      ["tower-broadcast", "Outbound connections", "only to providers you configured - telemetry off", "0 / hr"],
                    ].map(([icon, name, value, badge]) => (
                      <div className="kc-row" key={name}>
                        <span className="lock">
                          <LandingIcon name={icon as LandingIconName} />
                        </span>
                        <span className="kc-main">
                          <span className="kc-name">{name}</span>
                          <span className="kc-val">{value}</span>
                        </span>
                        <span className="kc-badge">{badge}</span>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="section-pad wrap" id="how">
        <div className="section-head reveal">
          <div className="kicker">Three lines to first trace</div>
          <h2 className="title">No SDK. Just change one base URL.</h2>
          <p className="section-sub">
            Loom is a transparent proxy. Point your client at localhost
            and every call shows up in the canvas - no code instrumentation, no
            decorators.
          </p>
        </div>
        <div className="steps">
          <div className="step reveal">
            <div className="num">01 -</div>
            <h4>Point the base_url</h4>
            <p>Swap your client&apos;s endpoint for the local proxy. Works with any OpenAI-compatible SDK.</p>
            <div className="codebox">
              <span className="cm"># your existing code</span>
              <br />
              client = <span className="fn">OpenAI</span>(
              <br />
              &nbsp;&nbsp;base_url=<span className="st">&quot;http://localhost:8080/v1&quot;</span>
              <br />)
            </div>
          </div>
          <div className="step reveal">
            <div className="num">02 -</div>
            <h4>Run your agent</h4>
            <p>Run anything as usual. Every request is intercepted, cached, and streamed into the tree live.</p>
            <div className="codebox">
              <span className="cm"># nothing else changes</span>
              <br />
              <span className="kw">$</span> python agent.py
              <br />
              <span className="cm"># -&gt; 5 calls traced</span>
            </div>
          </div>
          <div className="step reveal">
            <div className="num">03 -</div>
            <h4>Inspect &amp; replay</h4>
            <p>Open the canvas, click a node, rewrite its output, and replay the chain to test the fix.</p>
            <div className="codebox">
              <span className="cm"># in Loom</span>
              <br />
              <span className="kw">opt+cmd+R</span> <span className="cm">replay from node</span>
              <br />
              <span className="kw">cmd+K</span> <span className="cm">mock response</span>
            </div>
          </div>
        </div>
      </section>

      <section className="section-pad wrap finalcta" id="download">
        <div className="cta-card reveal">
          <h2>
            Trace your first agent
            <br />
            in under a minute.
          </h2>
          <p>
            Free during alpha. Join the waitlist and get the signed download
            the moment it's ready. Your keys and prompts never leave your Mac.
          </p>
          <div className="download-actions">
            <div className="download-direct">
              <a className="btn btn-primary pulse" href={DOWNLOAD_HREF} download>
                <LandingIcon name="apple" />
                Download DMG
              </a>
            </div>
            <form
              action="/api/waitlist"
              className="waitlist-form"
              method="post"
              onSubmit={joinWaitlist}
            >
              <input
                aria-hidden="true"
                autoComplete="off"
                className="honeypot"
                name="company"
                tabIndex={-1}
                type="text"
              />
              <input name="source" type="hidden" value="download-cta" />
              <label htmlFor="waitlist-email">Get the next alpha build</label>
              <div className="waitlist-row">
                <input
                  autoComplete="given-name"
                  enterKeyHint="next"
                  id="waitlist-name"
                  name="name"
                  onChange={(event) => setWaitlistName(event.target.value)}
                  placeholder="Your name"
                  required
                  type="text"
                  value={waitlistName}
                />
                <input
                  autoComplete="email"
                  enterKeyHint="next"
                  id="waitlist-email"
                  name="email"
                  onChange={(event) => setWaitlistEmail(event.target.value)}
                  placeholder="you@example.com"
                  required
                  type="email"
                  value={waitlistEmail}
                />
              </div>
              <div className="waitlist-row">
                <input
                  enterKeyHint="send"
                  id="waitlist-reason"
                  name="reason"
                  onChange={(event) => setWaitlistReason(event.target.value)}
                  placeholder="Why are you interested in Loom?"
                  required
                  type="text"
                  value={waitlistReason}
                />
                <button
                  className="btn btn-ghost"
                  disabled={waitlistState === "submitting"}
                  type="submit"
                >
                  <LandingIcon name={waitlistState === "done" ? "check" : "arrow-down-long"} />
                  {waitlistState === "submitting" ? "Joining..." : waitlistState === "done" ? "Joined" : "Join list"}
                </button>
              </div>
              <p
                aria-live="polite"
                className={`waitlist-message ${waitlistState === "error" ? "error" : ""}`.trim()}
              >
                {waitlistMessage || "No spam. Just the alpha DMG and setup notes."}
              </p>
            </form>
          </div>
          <div className="cta-row secondary-downloads">
            <a className="btn btn-ghost" href="#how">
              <LandingIcon name="file-lines" />
              Setup steps
            </a>
            <a className="btn btn-ghost" href="#features">
              <LandingIcon name="play" />
              See product
            </a>
          </div>
          <div className="meta-row final-meta">
            <span>
              <LandingIcon name="check" />
              macOS 13+
            </span>
            <span>
              <LandingIcon name="check" />
              No account required
            </span>
            <span>
              <LandingIcon name="check" />
              Open source core
            </span>
          </div>
        </div>
      </section>

      <footer className="footer wrap">
        <div className="foot-grid">
          <div className="foot-brand">
            <a className="brand" href="#top">
              <span className="logo">
                <LandingIcon name="diagram-project" />
              </span>
              Loom
            </a>
            <p>
              Local-first observability and mocking for LLM agents. Built for
              developers who refuse to debug in the dark.
            </p>
          </div>
          <div className="foot-col">
            <h5>Product</h5>
            <a href="#features">Features</a>
            <a href="#inspector">Inspector</a>
            <a href="#how">How it works</a>
            <a href="#download">Download</a>
          </div>
          <div className="foot-col">
            <h5>Developers</h5>
            <a href="#">Documentation</a>
            <a href="#">CLI reference</a>
            <a href="#">Changelog</a>
            <a href="#">GitHub</a>
          </div>
          <div className="foot-col">
            <h5>Company</h5>
            <a href="#">Privacy</a>
            <a href="#">Security</a>
            <a href="#">Contact</a>
          </div>
        </div>
        <div className="foot-bottom">
          <span>© 2026 Loom - Crafted for the Mac</span>
          <span>
            <LandingIcon name="circle" /> All systems local
          </span>
        </div>
      </footer>
    </main>
  );
}
