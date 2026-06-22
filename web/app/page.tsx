"use client";

import { type FormEvent, type ReactNode, useEffect, useRef, useState } from "react";
import { Icon, type IconName } from "@/components/Icon";
import { SiteFooter, SiteHeader } from "@/components/SiteChrome";
import { trackEvent } from "@/lib/analytics";
import { NODES, type NodeStatus, type TraceNode } from "@/lib/data";

const GITHUB_RELEASE_HREF = "https://github.com/Hqzdev/Tether/releases/latest/download/Tether.dmg";


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
    title: "Failure path",
    copy: (
      <>
        Follow the branch, retry, and tool call that produced the bad answer.
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
        See which calls were reused, how fast they returned, and what they saved.
      </>
    ),
  },
  {
    view: "time",
    acc: "amber",
    icon: "clock-rotate-left",
    title: "Response surgery",
    copy: (
      <>
        Patch one model output and rerun the steps that depend on it.
      </>
    ),
  },
  {
    view: "privacy",
    acc: "violet",
    icon: "shield-halved",
    title: "Local evidence vault",
    copy: (
      <>
        Check where keys, prompts, traces, and outbound calls live.
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
    a: "Those tools are strong hosted observability systems. Tether is a local workbench for the moment an agent breaks on your machine and you need the exact request, response, cache state, and downstream replay path without uploading the run.",
  },
  {
    q: "Does Tether send prompts, responses, or API keys anywhere?",
    a: "No. Tether is local-first. Prompts, responses, and traces stay in local storage, while API keys are stored through macOS Keychain. The proxy only talks to the providers you configure.",
  },
  {
    q: "How does Tether intercept LLM calls without changing my app?",
    a: "Tether runs a local HTTP proxy. You point your AI client's base_url at http://localhost:8080/v1 and keep the rest of your code the same. Tether forwards requests to the real provider and records the request and response locally.",
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

  const replayFailurePath = () => {
    fitTreeView();
    setTreeStarted(false);
    setTreeStep(3);
    window.setTimeout(() => {
      setTreeStep(TREE_LAYOUT.length);
      setTreeStarted(true);
    }, 180);
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

  function replayChain() {
    trackEvent("replay_started", { location: "inspector" });
    setReplayState("running");
    window.setTimeout(() => {
      setReplayState("done");
      window.setTimeout(() => setReplayState("idle"), 1900);
    }, 1300);
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
        <div className="center-row sp-row">
          <div className="social-proof">
            <span className="sp-evidence">
              <LandingIcon name="database" />
              Local trace recorder
            </span>
            <span className="sp-evidence">
              <LandingIcon name="clock-rotate-left" />
              Replay from one node
            </span>
            <span className="sp-evidence">
              <LandingIcon name="shield-halved" />
              No cloud workspace
            </span>
          </div>
        </div>
        <h1>
          Find the exact LLM call that <span className="grad">broke your agent</span>.
        </h1>
        <p className="lead">
          Tether records the run on your Mac, shows the failed node with its request and response,
          then lets you patch that output and replay only what comes after it.
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
            Install macOS alpha
          </a>
          <a
            className="btn btn-secondary"
            href="#demo"
            onClick={() =>
              trackEvent("cta_clicked", {
                button_text: "Inspect demo trace",
                location: "hero",
              })
            }
          >
            <LandingIcon name="diagram-project" />
            Inspect demo trace
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
          Security review asking where prompts live? Open the local storage proof <span aria-hidden="true">-&gt;</span>
        </a>
        <div className="meta-row">
          <span>
            <LandingIcon name="database" />
            SQLite traces.
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
          <div className="cinematic-embed" aria-label="Tether cinematic product animation">
            <iframe
              aria-label="Tether cinematic animation"
              className="cinematic-embed-frame"
              loading="lazy"
              src="/tether-cinematic-animation/index.html"
            />
          </div>
        </div>
      </header>

      <section className="section-pad wrap deferred-section" id="features">
        <div className="section-head reveal">
          <div className="kicker">Failure replay</div>
          <h2 className="title">
            Find the node that changed the outcome.
          </h2>
          <p className="section-sub">
            Tether turns one messy agent run into a replayable path: the request
            that went in, the response that came back, the cache state, and the
            downstream branch you can rerun.
          </p>
        </div>

        <div className="feat-layout">
          <div className="tree-stage reveal" id="treeStage" ref={treeRef}>
            <div className="ts-head">
              <LandingIcon name="diagram-project" />
              <span className="ttl">Failure path</span>
              <span className="ts-meta">4 nodes / 1 failed / 1 cached</span>
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
                className="replay-path-btn"
                onClick={() => {
                  replayFailurePath();
                  trackEvent("control_clicked", { control: "replay_failed_path", location: "visual_tree_canvas" });
                }}
                aria-label="Replay failed path"
              >
                <LandingIcon name="rotate" />
                <span>Replay failed path</span>
              </button>
            </div>
            <div className="trace-evidence">
              <span>
                <b>request</b>
                req_3f88ab
              </span>
              <span>
                <b>cache</b>
                hit
              </span>
              <span>
                <b>saved</b>
                2,096 tokens
              </span>
              <span>
                <b>scope</b>
                downstream only
              </span>
            </div>
          </div>

          <div className="bento">
            <div className="bcard g span2 reveal">
              <div className="bico">
                <LandingIcon name="diagram-project" />
              </div>
              <h3>Failure-first trace canvas</h3>
              <p>
                Every LLM request becomes a node with timing, payload, cache state,
                and downstream impact. The graph is built for finding the broken
                branch, not decorating a dashboard.
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
                Repeated prompts come back from local cache. You can test downstream
                logic without paying for the same retrieval or classification step
                again.
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
                Rewrite one response and replay the steps after it. This turns
                debugging from a full rerun into a controlled experiment.
              </p>
              <div className="bstat">
                <span className="metric-chip">replay from any node</span>
              </div>
            </div>
            <div className="bcard p span2 reveal">
              <div className="bico">
                <LandingIcon name="shield-halved" />
              </div>
              <h3>Local evidence vault</h3>
              <p>
                API keys live encrypted in the macOS Keychain. Prompts,
                responses, and traces stay in a local SQLite database that never
                leaves the machine. Nothing requires a hosted Tether workspace.
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
          <div className="kicker">Replay bench</div>
          <h2 className="title">
            Inspect the interface before you wire it into your app.
          </h2>
          <p className="section-sub">
            The right pane mirrors the app inspector. Pick a capability on the left
            and watch the evidence change the way it would when you click a live trace node.
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
          <div className="kicker">From localhost to replay</div>
          <h2 className="title">
            Route one run through Tether and keep the rest of your stack.
          </h2>
          <p className="section-sub">
            Tether is a transparent proxy. Point your client at localhost
            and every call shows up in the canvas with request, response, latency,
            tokens, cache state, and replay controls.
          </p>
        </div>
        <div className="steps">
          <div className="step reveal">
            <div className="num">01 / LOG</div>
            <h4>Point the base_url</h4>
            <p>
              Swap your client&apos;s endpoint for the local proxy. Works with any OpenAI-compatible SDK.
            </p>
          </div>
          <div className="step reveal">
            <div className="num">02 / REPLAY</div>
            <h4>Run your agent</h4>
            <p>
              Run the same scenario. Every request is intercepted, cached, and streamed into the tree live.
            </p>
          </div>
          <div className="step reveal">
            <div className="num">03 / PROVE</div>
            <h4>Inspect &amp; replay</h4>
            <p>
              Open the canvas, click the node that broke, rewrite its output,
              and replay forward. See exactly where your agent fails - without
              re-running the whole chain.
            </p>
          </div>
        </div>
      </section>

      <section className="section-pad wrap deferred-section" id="faq">
        <div className="section-head reveal">
          <div className="kicker">Buying objections</div>
          <h2 className="title">
            Questions engineers ask before installing a local proxy.
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
              <div className="kicker">Alpha feedback</div>
              <h2 className="title">
                Tell me where your agent actually breaks.
              </h2>
              <p className="section-sub">
                Use this only if the alpha is missing a workflow you would need.
                Specific traces beat vague feature requests.
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
              Install the local trace workbench
              <br />
              before your next agent run.
            </h2>
            <p>
              Free during alpha. Run Tether locally, point your SDK at the proxy,
              and keep the whole debugging record on your Mac.
            </p>
            <p className="alpha-note">Release v1.6.1 is ready for local macOS testing.</p>
            <div className="download-actions">
              <div className="download-direct">
                <a
                  className="btn btn-primary pulse"
                  href={GITHUB_RELEASE_HREF}
                  onClick={() =>
                    trackEvent("download_clicked", {
                      asset: "GitHub release v1.6.1",
                      location: "final_cta",
                    })
                  }
                  rel="noreferrer"
                  target="_blank"
                >
                  <LandingIcon name="apple-finder" />
                  Install macOS alpha
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
                Send trace feedback
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
                Inspect demo trace
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
