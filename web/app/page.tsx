"use client";

import Image from "next/image";
import { type FormEvent, type ReactNode, useEffect, useRef, useState } from "react";
import { Icon, type IconName } from "@/components/Icon";
import { SiteFooter, SiteHeader } from "@/components/SiteChrome";
import { trackEvent } from "@/lib/analytics";
import { NODES, type NodeStatus, type TraceNode } from "@/lib/data";

const DOWNLOAD_HREF = "/downloads/Tether.dmg";

type LandingIconName = IconName;

function LandingIcon({
  name,
  className = "",
}: {
  name: LandingIconName;
  className?: string;
}) {
  return <Icon className={`ic ${className}`.trim()} name={name} strokeWidth={1.7} />;
}

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
    title: "Local Response Cache",
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

const FAQ_ITEMS: { q: string; a: ReactNode }[] = [
  {
    q: "Is Tether free?",
    a: "Yes. Tether is free during the alpha period and the core proxy is open source. No credit card or account required.",
  },
  {
    q: "Does Tether send my prompts or API keys anywhere?",
    a: "No. Tether is fully air-gapped. Your prompts, responses, and API keys never leave your Mac. API keys are stored encrypted in the macOS Keychain and are never written to disk in plain text.",
  },
  {
    q: "How does Tether intercept LLM calls without changing my code?",
    a: "Tether runs a local HTTP proxy on your machine. You point your AI client's base_url at http://localhost:8080/v1 — that's the only change. Tether transparently forwards every request to the real provider and records the full request/response pair locally.",
  },
  {
    q: "Which LLM providers and frameworks does Tether support?",
    a: "Tether supports OpenAI, Anthropic (Claude), Ollama, LM Studio, and any provider that accepts an OpenAI-compatible base_url. It works with LangChain, LangGraph, LlamaIndex, and any SDK with a configurable endpoint.",
  },
  {
    q: "How is Tether different from LangSmith or Weights & Biases?",
    a: "LangSmith and W&B send your traces to cloud servers. Tether keeps everything on your machine — there is no cloud, no account, and nothing leaves your Mac. It's designed for developers who can't or won't send production prompts to third-party services.",
  },
  {
    q: "What is time-travel mocking?",
    a: "Time-travel mocking lets you click any past node in the agent trace, edit its response JSON, and replay the entire chain from that point forward — without re-running earlier steps or spending tokens. You can test how your agent would behave with a different LLM output in seconds.",
  },
  {
    q: "Why not just use print() or logging?",
    a: (
      <>
        Logging shows you what happened. Tether shows you <em>why</em>. You see the exact point where your agent
        failed, what response broke it, and you replay with a fix in seconds—no re-running the whole chain.
      </>
    ),
  },
  {
    q: "Can I use this with production code?",
    a: "Yes. It's a local proxy—your real code doesn't change. Use it locally for debugging, or keep it running. Tether only stores traces locally, never sends anything anywhere.",
  },
  {
    q: "How much money does caching actually save?",
    a: "It depends on your agent. If you're iterating on prompt logic and re-running the same retrieval steps, caching saves you 50-90% of API spend while you debug. Each cached hit costs $0.0000.",
  },
  {
    q: "Will Tether work with my stack?",
    a: "If your SDK uses a configurable base_url (OpenAI SDK, LangChain, LangGraph, LlamaIndex, Anthropic SDK), it works. One line change. If you use a different provider (Claude API via REST, custom setup), Tether still works—it's a transparent proxy.",
  },
  {
    q: "Does Tether add latency to my agent?",
    a: "Negligible. Tether runs locally on your Mac. The only overhead is the proxy hop, which is <1ms. Real LLM calls are the bottleneck, not Tether.",
  },
  {
    q: "Can I share traces with my team?",
    a: "Not yet. Each developer runs their own Tether instance locally. Export as JSON is coming in a later release.",
  },
];

type InspectorView = "graph" | "cache" | "time" | "privacy";
type ReplayState = "idle" | "running" | "done";
type WaitlistState = "idle" | "submitting" | "done" | "error";
type FeedbackState = "idle" | "submitting" | "done" | "error";

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

function InspectorGraph() {
  return (
    <div className="graphview" id="graphView">
      {NODES.map((node, index) => (
        <MiniNode node={node} depth={index} key={node.id} />
      ))}
    </div>
  );
}

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
  const [waitlistEmail, setWaitlistEmail] = useState("");
  const [waitlistState, setWaitlistState] = useState<WaitlistState>("idle");
  const [waitlistMessage, setWaitlistMessage] = useState("");
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

  async function joinWaitlist(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;

    if (!form.reportValidity()) return;

    setWaitlistState("submitting");
    setWaitlistMessage("");
    trackEvent("waitlist_submitted", { form_type: "alpha_waitlist", location: "final_cta" });

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
      trackEvent("waitlist_joined", { form_type: "alpha_waitlist", location: "final_cta" });
      setWaitlistMessage("You're on the alpha list. I'll send the DMG link when the next build is ready.");
      setWaitlistEmail("");
      form.reset();
    } catch (error) {
      setWaitlistState("error");
      trackEvent("waitlist_failed", { form_type: "alpha_waitlist", location: "final_cta" });
      setWaitlistMessage(error instanceof Error ? error.message : "Could not join the waitlist.");
    }
  }

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
              Used by developers building production AI agents
            </span>
          </div>
        </div>
        <h1>
          Stop debugging AI agents <span className="grad">in the dark.</span>
        </h1>
        <p className="lead">
          Point your agent at localhost. Every LLM call becomes a node in a live trace tree -
          with caching, mocking, and zero data leaving your machine.
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
            <LandingIcon name="apple" />
            Download for macOS
          </a>
          <a
            className="btn btn-ghost"
            href="#features"
            onClick={() =>
              trackEvent("cta_clicked", {
                button_text: "See it in action",
                location: "hero",
              })
            }
          >
            <LandingIcon name="play" />
            See it in action
          </a>
        </div>
        <a
          className="urgency-link"
          href="#download"
          onClick={() =>
            trackEvent("cta_clicked", {
              button_text: "Currently alpha limited seats",
              location: "hero_urgency",
            })
          }
        >
          Currently alpha — limited seats. Get access now <span aria-hidden="true">→</span>
        </a>
        <div className="meta-row">
          <span>
            <LandingIcon name="microchip" />
            Free alpha. No signup.
          </span>
          <span>
            <LandingIcon name="feather" />
            1-minute setup.
          </span>
          <span>
            <LandingIcon name="shield-halved" />
            Everything stays on your Mac.
          </span>
        </div>

        <div className="product-shot reveal">
          <div className="product-shot-glow" />
          <div className="product-shot-frame">
            <Image
              alt="Tether showing a live AI agent trace graph with response metadata"
              className="product-shot-image"
              fetchPriority="high"
              height={2212}
              priority
              sizes="(max-width: 760px) calc(100vw - 32px), (max-width: 1280px) calc(100vw - 56px), 1160px"
              src="/image.png"
              width={3644}
            />
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
            <div className="tree-svg-wrap" ref={treeSvgWrapRef}>
              <svg id="treeSvg" width="100%" viewBox="0 0 300 470" fill="none" xmlns="http://www.w3.org/2000/svg">
                {[0, 1, 2, 3].map((line) => {
                  const sourceStatus = TREE_LAYOUT[line]?.status;
                  const statusClass =
                    sourceStatus === "success"
                      ? "tline-success"
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
              <h3>Local Response Cache</h3>
              <p>
                Identical prompts return instantly from local cache. Iterate on
                downstream logic without re-running - or re-paying for - upstream
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
              <h3>Time-Travel Mocking</h3>
              <p>
                Your agent failed at step 4. Rewrite that node&apos;s output and
                replay from there - no re-running the full chain, no wasted
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
            Tether.
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

      <section className="section-pad wrap" id="how">
        <div className="section-head reveal">
          <div className="kicker">Three lines to first trace</div>
          <h2 className="title">No SDK. Just change one base URL.</h2>
          <p className="section-sub">
            Tether is a transparent proxy. Point your client at localhost
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
            <p>
              Open the canvas, click the node that broke, rewrite its output,
              and replay forward. See exactly where your agent fails - without
              re-running the whole chain.
            </p>
            <div className="codebox">
              <span className="cm"># in Tether</span>
              <br />
              <span className="kw">opt+cmd+R</span> <span className="cm">replay from node</span>
              <br />
              <span className="kw">cmd+K</span> <span className="cm">mock response</span>
            </div>
          </div>
        </div>
      </section>

      <section className="section-pad wrap" id="faq">
        <div className="section-head reveal">
          <div className="kicker">Common questions</div>
          <h2 className="title">Everything you need to know.</h2>
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

      <section className="section-pad wrap feedback-section" id="feedback">
        <div className="feedback-card reveal">
          <div className="section-head compact">
            <div className="kicker">Feedback loop</div>
            <h2 className="title">Tell me what breaks first.</h2>
            <p className="section-sub">
              Alpha users shape the next build. Send the bug, missing workflow, or reason you would not use this yet.
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
      </section>

      <section className="section-pad wrap finalcta" id="download">
        <div className="cta-card reveal">
          <h2>
            Trace your first agent
            <br />
            in under a minute.
          </h2>
          <p>
            Free during alpha. Get the signed DMG the moment it's ready - no
            account, no cloud, no strings.
          </p>
          <p className="alpha-note">⚡ Limited alpha slots. Mac only for now.</p>
          <div className="download-actions">
            <div className="download-direct">
              <a
                className="btn btn-primary pulse"
                href={DOWNLOAD_HREF}
                download
                onClick={() =>
                  trackEvent("download_clicked", {
                    asset: "Tether.dmg",
                    location: "final_cta",
                  })
                }
              >
                <LandingIcon name="apple" />
                Download DMG
              </a>
            </div>
            <div className="download-or">or join the waitlist</div>
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
              <label className="sr-only" htmlFor="waitlist-email">Email address</label>
              <div className="waitlist-row">
                <input
                  autoComplete="email"
                  enterKeyHint="done"
                  id="waitlist-email"
                  inputMode="email"
                  name="email"
                  onChange={(event) => setWaitlistEmail(event.target.value)}
                  placeholder="you@example.com"
                  required
                  type="email"
                  value={waitlistEmail}
                />
                <button
                  className="btn btn-ghost"
                  disabled={waitlistState === "submitting"}
                  type="submit"
                >
                  <LandingIcon name={waitlistState === "done" ? "check" : "arrow-down-long"} />
                  {waitlistState === "submitting" ? "Joining..." : waitlistState === "done" ? "Joined" : "Get early access"}
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
      </section>

      <SiteFooter />
    </main>
  );
}
