"use client";

import { type FormEvent, type ReactNode, useEffect, useRef, useState } from "react";
import { Icon, type IconName } from "@/components/Icon";
import { SiteFooter, SiteHeader } from "@/components/SiteChrome";
import { trackEvent } from "@/lib/analytics";
import { NODES, type NodeStatus, type TraceNode } from "@/lib/data";

const GITHUB_RELEASE_HREF = "https://github.com/Hqzdev/Tether/releases/latest";


type LandingIconName = IconName;

// Renders a landing-page icon using the shared icon map.
function LandingIcon({
  name,
  className = "",
}: {
  name: LandingIconName;
  className?: string;
}) {
  return <Icon className={`ic ${className}`.trim()} name={name} strokeWidth={1.7} />;
}

const PROOF_CARDS: {
  icon: LandingIconName;
  title: string;
  copy: ReactNode;
  meta: string;
}[] = [
  {
    icon: "diagram-project",
    title: "Trace every tool call",
    copy: (
      <>
        Nested LLM calls, tools, retries, and sub-agents land in <span className="grad">one readable graph</span>.
      </>
    ),
    meta: "Live DAG",
  },
  {
    icon: "clock-rotate-left",
    title: "Replay from the break",
    copy: (
      <>
        Mock <span className="grad">one bad response</span> and rerun only the downstream chain instead of burning tokens.
      </>
    ),
    meta: "Time travel",
  },
];

const FEATURES: {
  view: InspectorView;
  acc: "green" | "cyan" | "amber" | "violet";
  icon: LandingIconName;
  title: string;
  copy: ReactNode;
}[] = [
  {
    view: "graph",
    acc: "green",
    icon: "diagram-project",
    title: "Call graph",
    copy: (
      <>
        See the <span className="grad">exact branch</span>, retry, and tool call path.
      </>
    ),
  },
  {
    view: "cache",
    acc: "cyan",
    icon: "bolt",
    title: "Cache ledger",
    copy: (
      <>
        Verify <span className="grad">is_cached</span>, 0ms latency, and token savings.
      </>
    ),
  },
  {
    view: "time",
    acc: "amber",
    icon: "clock-rotate-left",
    title: "Replay editor",
    copy: (
      <>
        Patch a past response and <span className="grad">rerun downstream</span> steps.
      </>
    ),
  },
  {
    view: "privacy",
    acc: "violet",
    icon: "shield-halved",
    title: "Local evidence",
    copy: (
      <>
        Confirm keys, traces, and prompts <span className="grad">stay on-device</span>.
      </>
    ),
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
  { status: "cached", icon: "database", label: "Vector DB Retrieval", sub: "cached - 0ms" },
  { status: "success", icon: "check-circle", label: "Context Synthesis", sub: "claude-3.5-sonnet" },
  { status: "error", icon: "circle-exclamation", label: "Response Generation", sub: "timeout - 4.10s" },
];

const FAQ_ITEMS: { q: string; a: ReactNode }[] = [
  {
    q: "We already use LangSmith or Langfuse. Why Tether?",
    a: "Those tools are strong for hosted observability and team workflows. Tether is for local debugging when prompts, API keys, customer data, or unreleased agent behavior should not leave the Mac. It also focuses on replaying from a failed node, not just storing traces.",
  },
  {
    q: "Does Tether send prompts, responses, or API keys anywhere?",
    a: "No. Tether is local-first. Prompts, responses, and traces stay in local storage, while API keys are stored through macOS Keychain. The proxy only talks to the providers you configure.",
  },
  {
    q: "How does Tether intercept LLM calls without changing my app?",
    a: "Tether runs a local HTTP proxy. You point your AI client's base_url at http://localhost:8080/v1 and keep the rest of your code the same. Tether forwards requests to the real provider and records the full request/response pair locally.",
  },
  {
    q: "Can I use this with production code?",
    a: "Yes. It is a local proxy, so your real code does not need SDK instrumentation. Use it locally while debugging sensitive flows, demos, eval runs, or production-like traces that cannot be copied into a hosted dashboard.",
  },
  {
    q: "Does Tether add latency to my agent?",
    a: "Negligible. Tether runs locally on your Mac. The only overhead is the proxy hop, which is usually less than 1ms. Real LLM calls are the bottleneck, not Tether.",
  },
];

type InspectorView = "graph" | "cache" | "time" | "privacy";
type ReplayState = "idle" | "running" | "done";
type FeedbackState = "idle" | "submitting" | "done" | "error";

// Tracks the user's reduced-motion preference for demo animation controls.
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

// Reveals marked sections when they enter the viewport, with a no-observer fallback.
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

// Returns the icon shown for one demo trace node.
function nodeIconName(node: TraceNode): LandingIconName {
  if (node.status === "cached") return "database";
  if (node.status === "error") return "circle-exclamation";
  if (node.icon === "tool") return "gear";
  return node.icon as LandingIconName;
}

// Returns the latency badge class for one demo trace status.
function nodeLatencyClass(status: NodeStatus) {
  if (status === "cached") return "cy";
  if (status === "error") return "pk";
  return "ok";
}

// Returns the compact status label shown in the demo graph.
function statusLabel(status: NodeStatus) {
  return status === "cached" ? "CACHED" : status === "error" ? "ERROR" : "SUCCESS";
}

// Renders one compact node inside the animated landing-page demo.
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

// Renders the small graph preview used inside the landing-page inspector.
function InspectorGraph() {
  return (
    <div className="graphview" id="graphView">
      {NODES.map((node, index) => (
        <MiniNode node={node} depth={index} key={node.id} />
      ))}
    </div>
  );
}

/**
 * Renders the public Tether landing page.
 */
export default function TetherLanding() {
  const reduce = usePrefersReducedMotion();
  const treeRef = useRef<HTMLDivElement>(null);
  const treeSvgWrapRef = useRef<HTMLDivElement>(null);

  const fitTreeView = () => {
    const el = treeSvgWrapRef.current;
    if (!el) return;
    el.scrollTo({ top: 0, left: 0, behavior: "smooth" });
  };
  const [treeStarted, setTreeStarted] = useState(false);
  const [treeStep, setTreeStep] = useState(0);
  const [activeView, setActiveView] = useState<InspectorView>("graph");
  const [replayState, setReplayState] = useState<ReplayState>("idle");
  const [feedbackEmail, setFeedbackEmail] = useState("");
  const [feedbackContext, setFeedbackContext] = useState("");
  const [feedbackText, setFeedbackText] = useState("");
  const [feedbackState, setFeedbackState] = useState<FeedbackState>("idle");
  const [feedbackMessage, setFeedbackMessage] = useState("");

  useRevealOnScroll();

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

  useEffect(() => {
    fitTreeView();
  }, []);

  function handleFeatureHover(view: InspectorView) {
    if (!window.matchMedia("(hover: none)").matches) setActiveView(view);
  }

  function replayChain() {
    trackEvent("replay_started", { location: "inspector" });
    setReplayState("running");
    window.setTimeout(() => {
      setReplayState("done");
      window.setTimeout(() => setReplayState("idle"), 1900);
    }, 1300);
  }

  // Sends structured landing-page feedback through the API route without leaving the page.
  async function sendFeedback(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;

    if (!form.reportValidity()) return;

    setFeedbackState("submitting");
    setFeedbackMessage("");
    trackEvent("feedback_submitted", { form_type: "site_feedback", location: "feedback_section" });

    try {
      const formData = new FormData(form);
      const response = await fetch(form.action, {
        method: "POST",
        body: formData,
      });
      const result = (await response.json()) as { ok?: boolean; error?: string };

      if (!response.ok || !result.ok) {
        throw new Error(result.error || "Could not send feedback.");
      }

      setFeedbackState("done");
      trackEvent("feedback_received", { form_type: "site_feedback", location: "feedback_section" });
      setFeedbackMessage("Got it. Thanks — this goes straight into the feedback log.");
      setFeedbackEmail("");
      setFeedbackContext("");
      setFeedbackText("");
      form.reset();
    } catch (error) {
      setFeedbackState("error");
      trackEvent("feedback_failed", { form_type: "site_feedback", location: "feedback_section" });
      setFeedbackMessage(error instanceof Error ? error.message : "Could not send feedback.");
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
      <SiteHeader />

      <header className="hero wrap" id="top">
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
              One base_url change. No code rewrites. Every LLM call, tool execution, and failure
              mapped live on your Mac.
            </span>
          </div>
        </div>
        <h1>
          Your agent failed at step 3. <span className="grad">You have no idea why.</span>
        </h1>
        <p className="lead">
          Tether shows you the <span className="grad">exact call</span>, the exact response, and
          lets you <span className="grad">replay from there</span>. One base_url change. No code
          rewrites.
        </p>
        <div className="cta-row">
          <a
            className="btn btn-primary pulse"
            href="#download"
            onClick={() =>
              trackEvent("cta_clicked", {
                button_text: "Download for macOS",
                location: "hero",
              })
            }
          >
            <LandingIcon name="apple-finder" />
            Download for macOS
          </a>

        </div>
        <a
          className="urgency-link"
          href="/security"
          onClick={() =>
            trackEvent("cta_clicked", {
              button_text: "See privacy proof",
              location: "hero_urgency",
            })
          }
        >
          Security review asking where traces live? See the proof layer <span aria-hidden="true">-&gt;</span>
        </a>
        <div className="meta-row">
          <span>
            <LandingIcon name="database" />
            Local SQLite traces.
          </span>
          <span>
            <LandingIcon name="feather" />
            One base_url change.
          </span>
          <span>
            <LandingIcon name="shield-halved" />
            Keys stay in Keychain.
          </span>
        </div>

        <div className="product-shot reveal">
          <div className="product-shot-glow" />
          <div className="product-shot-frame">
            <video
              aria-label="Tether showing a live AI agent trace graph with response metadata"
              autoPlay
              className="product-shot-image"
              height={1080}
              loop
              muted
              playsInline
              preload="metadata"
              width={1728}
            >
              <source src="/video.mp4" type="video/mp4" />
            </video>
          </div>
        </div>
      </header>

      <section className="proof-strip wrap reveal">
        <div className="proof-grid">
          {PROOF_CARDS.map((card) => (
            <article className="proof-card" key={card.title}>
              <span className="proof-icon">
                <LandingIcon name={card.icon} />
              </span>
              <div>
                <div className="proof-meta">{card.meta}</div>
                <h2>{card.title}</h2>
                <p>{card.copy}</p>
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="section-pad wrap deferred-section" id="features">
        <div className="section-head reveal">
          <div className="kicker">Product proof</div>
          <h2 className="title">
            Every agent run, drawn as <span className="grad">evidence you can read</span>.
          </h2>
          <p className="section-sub">
            Messy terminal logs become a hierarchical trace in real time. Each LLM request,
            tool call, retry, cache hit, and failure is color-coded by <span className="grad">what actually happened</span>.
          </p>
        </div>

        <div className="feat-layout">
          <div className="tree-stage reveal" id="treeStage" ref={treeRef}>
            <div className="ts-head">
              <LandingIcon name="diagram-project" />
              <span className="ttl">Visual Tree Canvas</span> - live render
            </div>
            <div className="tree-svg-wrap" ref={treeSvgWrapRef}>
              <svg id="treeSvg" width="100%" viewBox="0 0 300 470" fill="none" xmlns="http://www.w3.org/2000/svg">
                {[0, 1, 2, 3].map((line) => {
                  const sourceStatus = TREE_LAYOUT[line]?.status;
                  const statusClass =
                    sourceStatus === "success"
                      ? "tline-success"
                      : sourceStatus === "cached"
                        ? "tline-cached"
                      : sourceStatus === "error"
                        ? "tline-error"
                        : "tline-default";
                  return (
                    <path
                      className={`tline ${statusClass} ${treeStep > line ? "draw" : ""}`}
                      d={`M40 ${70 + line * 100} V${150 + line * 100}`}
                      key={line}
                      strokeWidth="3"
                    />
                  );
                })}
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
                      <span className="s2-label" title={node.label}>
                        {node.label}
                      </span>
                      <span className="s2-sub" title={node.sub}>
                        {node.sub}
                      </span>
                    </span>
                    <span className="s2-status">{node.status}</span>
                  </div>
                ))}
              </div>
              <button
                type="button"
                className="fit-view-btn"
                onClick={() => {
                  fitTreeView();
                  trackEvent("control_clicked", { control: "fit_to_screen", location: "visual_tree_canvas" });
                }}
                aria-label="Fit to screen"
              >
                <LandingIcon name="layout" />
                <span>Fit to screen</span>
              </button>
            </div>
          </div>

          <div className="bento">
            <div className="bcard g span2 reveal">
              <div className="bico">
                <LandingIcon name="diagram-project" />
              </div>
              <h3>Visual trace canvas</h3>
              <p>
                Every LLM request becomes a node in a graph. Nested tool calls,
                retries, and sub-agents nest automatically, so the shape of
                your agent&apos;s behavior is finally <span className="grad">something you can inspect</span>,
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
              <h3>Local response cache</h3>
              <p>
                Identical prompts return <span className="grad">instantly from local cache</span>. Iterate on
                downstream logic without re-running or re-paying for upstream
                calls. $0.0000 per cached hit.
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
              <h3>Time-travel mocking</h3>
              <p>
                Your agent failed at step 4. Rewrite that node&apos;s output and
                <span className="grad">replay from there</span>. No re-running the full chain, no wasted
                tokens. Fix the exact break, not the whole pipeline.
              </p>
              <div className="bstat">
                <span className="metric-chip">replay from any node</span>
              </div>
            </div>
            <div className="bcard p span2 reveal">
              <div className="bico">
                <LandingIcon name="shield-halved" />
              </div>
              <h3>Air-gapped privacy</h3>
              <p>
                API keys live encrypted in the macOS Keychain. Prompts,
                responses, and traces stay in a local SQLite database that never
                <span className="grad">leaves the machine</span>. Nothing requires a hosted Tether workspace.
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

        <div className="section-head reveal feature-demo-head" id="demo">
          <div className="kicker">Embedded sample trace</div>
          <h2 className="title">
            Try the debugger before you <span className="grad">wire it into your app</span>.
          </h2>
          <p className="section-sub">
            The right pane mirrors the app inspector. Pick a capability on the left
            and the trace evidence changes like <span className="grad">clicking a live node</span> in Tether.
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
                onClick={() => {
                  setActiveView(feature.view);
                  trackEvent("feature_selected", {
                    feature: feature.view,
                    location: "inspector_feature_list",
                    title: feature.title,
                  });
                }}
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
                    ["store", "~/.Tether/cache.sqlite", ""],
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
                      ["database", "Trace database", "~/.Tether/traces.sqlite - 0 bytes sent", "LOCAL"],
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

      <section className="section-pad wrap deferred-section" id="how">
        <div className="section-head reveal">
          <div className="kicker">From localhost to proof in three steps</div>
          <h2 className="title">
            No SDK rewrite. Just route the run <span className="grad">through Tether</span>.
          </h2>
          <p className="section-sub">
            Tether is a <span className="grad">transparent proxy</span>. Point your client at localhost
            and every call shows up in the canvas with request, response, latency,
            tokens, cache state, and replay controls.
          </p>
        </div>
        <div className="steps">
          <div className="step reveal">
            <div className="num">01 / LOG</div>
            <h4>Point the base_url</h4>
            <p>
              Swap your client&apos;s endpoint for the <span className="grad">local proxy</span>. Works with any OpenAI-compatible SDK.
            </p>
          </div>
          <div className="step reveal">
            <div className="num">02 / REPLAY</div>
            <h4>Run your agent</h4>
            <p>
              Run the same scenario. Every request is <span className="grad">intercepted, cached, and streamed</span> into the tree live.
            </p>
          </div>
          <div className="step reveal">
            <div className="num">03 / PROVE</div>
            <h4>Inspect &amp; replay</h4>
            <p>
              Open the canvas, click the node that broke, rewrite its output,
              and replay forward. See <span className="grad">exactly where your agent fails</span> - without
              re-running the whole chain.
            </p>
          </div>
        </div>
      </section>

      <section className="section-pad wrap deferred-section" id="faq">
        <div className="section-head reveal">
          <div className="kicker">Objections</div>
          <h2 className="title">
            Questions buyers and engineers <span className="grad">ask first</span>.
          </h2>
        </div>
        <div className="faq-list">
          {FAQ_ITEMS.map(({ q, a }) => (
            <details className="faq-item reveal" key={q}>
              <summary className="faq-q">{q}</summary>
              <p className="faq-a">{a}</p>
            </details>
          ))}
        </div>
      </section>

      <section className="section-pad wrap feedback-section download-section deferred-section" id="download">
        <div className="feedback-download-card reveal">
          <div className="feedback-pane" id="feedback">
            <div className="section-head compact">
              <div className="kicker">Feedback loop</div>
              <h2 className="title">
                Tell me which trace would <span className="grad">make this useful</span>.
              </h2>
              <p className="section-sub">
                Alpha users <span className="grad">shape the next build</span>. Send the bug, missing workflow, or security objection that would
                stop you from using Tether.
              </p>
            </div>
            <form
              action="/api/feedback"
              className="feedback-form"
              method="post"
              onSubmit={sendFeedback}
            >
              <input
                aria-hidden="true"
                autoComplete="off"
                className="honeypot"
                name="company"
                tabIndex={-1}
                type="text"
              />
              <input name="source" type="hidden" value="landing-feedback" />
              <div className="feedback-grid">
                <label className="field">
                  <span>Email</span>
                  <input
                    autoComplete="email"
                    enterKeyHint="next"
                    inputMode="email"
                    name="email"
                    onChange={(event) => setFeedbackEmail(event.target.value)}
                    placeholder="you@example.com"
                    required
                    type="email"
                    value={feedbackEmail}
                  />
                </label>
                <label className="field">
                  <span>What are you building?</span>
                  <input
                    autoComplete="off"
                    name="context"
                    onChange={(event) => setFeedbackContext(event.target.value)}
                    placeholder="support agent, internal copilot, eval harness..."
                    type="text"
                    value={feedbackContext}
                  />
                </label>
              </div>
              <label className="field">
                <span>Feedback</span>
                <textarea
                  minLength={10}
                  name="feedback"
                  onChange={(event) => setFeedbackText(event.target.value)}
                  placeholder="What confused you, what would stop you from trying it, or what should be added first?"
                  required
                  rows={5}
                  value={feedbackText}
                />
              </label>
              <div className="feedback-actions">
                <button
                  className="btn btn-primary"
                  disabled={feedbackState === "submitting"}
                  type="submit"
                >
                  <LandingIcon name={feedbackState === "done" ? "check" : "arrow-right"} />
                  {feedbackState === "submitting" ? "Sending..." : feedbackState === "done" ? "Sent" : "Send feedback"}
                </button>
                <p
                  aria-live="polite"
                  className={`feedback-message ${feedbackState === "error" ? "error" : ""}`.trim()}
                >
                  {feedbackMessage || "Structured feedback beats scattered DMs."}
                </p>
              </div>
            </form>
          </div>
          <div className="download-pane">
            <div className="kicker">Alpha access</div>
            <h2>
              Get a replayable trace
              <br />
              before the <span className="grad">next demo</span>.
            </h2>
            <p>
              Free during alpha. Open the source on GitHub, <span className="grad">run it locally</span>, or send feedback about
              the workflow that should ship next.
            </p>
            <p className="alpha-note">Release v1.4.5 is ready for local macOS testing.</p>
            <div className="download-actions">
              <div className="download-direct">
                <a
                  className="btn btn-primary pulse"
                  href={GITHUB_RELEASE_HREF}
                  onClick={() =>
                    trackEvent("download_clicked", {
                      asset: "GitHub release v1.4.5",
                      location: "final_cta",
                    })
                  }
                  rel="noreferrer"
                  target="_blank"
                >
                  <LandingIcon name="apple-finder" />
                  Install Tether
                </a>
              </div>
              <p className="download-note">Opens the GitHub release page with the latest alpha build.</p>
            </div>
            <div className="cta-row secondary-downloads">
              <a
                className="btn btn-ghost"
                href="#feedback"
                onClick={() =>
                  trackEvent("cta_clicked", {
                    button_text: "Write feedback",
                    location: "final_cta",
                  })
                }
              >
                <LandingIcon name="arrow-right" />
                Write feedback
              </a>
              <a
                className="btn btn-ghost"
                href="#how"
                onClick={() =>
                  trackEvent("cta_clicked", {
                    button_text: "Setup steps",
                    location: "final_cta",
                  })
                }
              >
                <LandingIcon name="file-lines" />
                Setup steps
              </a>
              <a
                className="btn btn-ghost"
                href="#features"
                onClick={() =>
                  trackEvent("cta_clicked", {
                    button_text: "See product",
                    location: "final_cta",
                  })
                }
              >
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
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
