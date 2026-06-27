"use client";

import { type FormEvent, type ReactNode, useEffect, useRef, useState } from "react";
import { Icon, type IconName } from "@/components/Icon";
import { SiteFooter, SiteHeader } from "@/components/SiteChrome";
import { trackEvent } from "@/lib/analytics";
import { NODES, type NodeStatus, type TraceNode } from "@/lib/data";

const MACOS_DOWNLOAD_HREF = "https://github.com/Hqzdev/Tether/releases/latest/download/Tether.dmg";
const LINUX_DOWNLOAD_HREF = "https://github.com/Hqzdev/Tether/releases";


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
    title: "Execution graph",
    copy: (
      <>
        Follow the request, action, file diff, command, and failed test in one run.
      </>
    ),
  },
  {
    view: "cache",
    acc: "cyan",
    icon: "bolt",
    title: "File impact",
    copy: (
      <>
        See what changed, how many lines moved, and which step caused it.
      </>
    ),
  },
  {
    view: "time",
    acc: "amber",
    icon: "clock-rotate-left",
    title: "Recovery point",
    copy: (
      <>
        Replay supported branches or roll back from the exact broken node.
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
  graph: { dot: "green", title: "Agent execution graph", model: "8 events" },
  cache: { dot: "cyan", title: "File diff and command evidence", model: "+42 / -11 lines" },
  time: { dot: "amber", title: "Replay and rollback boundary", model: "supported request" },
  privacy: { dot: "violet", title: "Secrets & Storage", model: "local" },
};

const TREE_LAYOUT: {
  status: NodeStatus;
  icon: LandingIconName;
  label: string;
  sub: string;
}[] = [
  { status: "success", icon: "check-circle", label: "User request", sub: "fix failing checkout test" },
  { status: "cached", icon: "database", label: "File diff", sub: "+42 / -11 lines" },
  { status: "success", icon: "check-circle", label: "Shell command", sub: "npm test" },
  { status: "error", icon: "circle-exclamation", label: "Failed test", sub: "exit 1 - 4.10s" },
];

const FAQ_ITEMS: { q: string; a: ReactNode }[] = [
  {
    q: "We already use LangSmith or Langfuse. Why Tether?",
    a: "Hosted trace tools are useful for team observability. Tether is narrower: a local execution debugger for coding agents that shows the request, actions, file diffs, failed commands, and recovery point on the developer machine.",
  },
  {
    q: "Does Tether send prompts, responses, or API keys anywhere?",
    a: "No. Tether is local-first. Prompts, responses, and traces stay in local storage. The macOS app uses Keychain-aware secrets, and the Linux alpha keeps the same proxy-first local model. The proxy only talks to the providers you configure.",
  },
  {
    q: "How does Tether capture agent runs?",
    a: "Use tether capture -- <agent command> or route OpenAI-compatible traffic through the local proxy. Source adapters normalize Codex, Claude Code, LangChain, LangGraph, OpenAI/OpenGPT-style agents, and custom CLI events into one execution graph.",
  },
  {
    q: "Can I use this with production code?",
    a: "Yes. It is a local proxy, so your real code does not need SDK instrumentation. Use it locally while debugging sensitive flows, demos, eval runs, or production-like traces that cannot be copied into a hosted dashboard.",
  },
  {
    q: "Does Tether add latency to my agent?",
    a: "Negligible. Tether runs locally on your machine. The only overhead is the proxy hop, which is usually less than 1ms. Real LLM calls are the bottleneck, not Tether.",
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
        : "Replay supported branch";

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
          Debug what your AI coding agent <span className="grad">actually did</span>.
        </h1>
        <p className="lead">
          Tether is a local execution debugger for AI coding agents. It captures the prompt,
          action, file diff, failed command or test, and recovery point in a desktop execution graph for macOS and Linux alpha.
        </p>
        <div className="cta-row">
          <a
            className="btn btn-primary pulse"
            href="#download"
            onClick={() =>
              trackEvent("cta_clicked", {
                button_text: "Download alpha",
                location: "hero",
              })
            }
          >
            <LandingIcon name="arrow-down-long" />
            Download alpha
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
          Security review asking where prompts live? Prompts and traces stay local <span aria-hidden="true">-&gt;</span>
        </a>
        <div className="meta-row">
          <span>
            <LandingIcon name="database" />
            SQLite traces.
          </span>
          <span>
            <LandingIcon name="feather" />
            Source adapters.
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
          <div className="kicker">Prompt to recovery</div>
          <h2 className="title">
            See the request, the actions, the diff, and the breakage.
          </h2>
          <p className="section-sub">
            Tether turns one messy agent run into an execution graph: user request,
            tool calls, file reads and writes, shell commands, test results, git diff,
            errors, replay, and rollback evidence.
          </p>
        </div>

        <div className="feat-layout">
          <div className="tree-stage reveal" id="treeStage" ref={treeRef}>
            <div className="ts-head">
              <LandingIcon name="diagram-project" />
              <span className="ttl">Execution path</span>
              <span className="ts-meta">4 events / 1 failed / 1 diff</span>
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
                <span>Open recovery point</span>
              </button>
            </div>
            <div className="trace-evidence">
              <span>
                <b>request</b>
                fix checkout test
              </span>
              <span>
                <b>diff</b>
                +42 / -11
              </span>
              <span>
                <b>command</b>
                npm test
              </span>
              <span>
                <b>status</b>
                exit 1
              </span>
            </div>
          </div>

          <div className="bento">
            <div className="bcard g span2 reveal">
              <div className="bico">
                <LandingIcon name="diagram-project" />
              </div>
              <h3>Execution graph, not an LLM tree</h3>
              <p>
                Nodes represent the agent run: LLM requests, tool calls, file reads,
                file writes, shell commands, tests, diffs, errors, replay, and rollback.
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
              <h3>File and command evidence</h3>
              <p>
                Node cards keep changed files, line counts, command output, exit status,
                timing, tokens, model, and source metadata together.
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
              <h3>Replay where supported</h3>
              <p>
                Proxy-captured requests can be replayed from a selected node. Local log
                sources stay inspectable and route clearly to supported recovery flows.
              </p>
              <div className="bstat">
                <span className="metric-chip">replay boundary</span>
              </div>
            </div>
            <div className="bcard p span2 reveal">
              <div className="bico">
                <LandingIcon name="shield-halved" />
              </div>
              <h3>Local evidence vault</h3>
              <p>
                macOS secrets use Keychain-aware storage. Linux alpha keeps the
                same local proxy model. Prompts, responses, and traces stay in a
                local SQLite database that never leaves the machine.
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
          <div className="kicker">Debugger inspector</div>
          <h2 className="title">
            Inspect the debugger before you wire it into your agent.
          </h2>
          <p className="section-sub">
            The right pane mirrors the app inspector. Pick an evidence type and watch
            the node details change the way they do in a live execution graph.
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
                    diff.meta
                    <span className="grow" />
                    <span className="chip cy">CACHE HIT</span>
                    <span className="chip ok">200 OK</span>
                  </div>
                  {[
                    ["request_id", "req_3f88ab", ""],
                    ["changed_files", "3", "cyan"],
                    ["line_delta", "+42 / -11", "green"],
                    ["command", "npm test", ""],
                    ["exit_code", "1", "cyan"],
                    ["source", "custom-cli", ""],
                    ["store", "~/.Tether/traces.sqlite", ""],
                    ["recovery", "rollback or replay boundary", "green"],
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
                      recovery.patch
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
          <div className="kicker">From capture to graph</div>
          <h2 className="title">
            Wrap one run and keep the rest of your stack.
          </h2>
          <p className="section-sub">
            Run tether capture -- &lt;agent command&gt;. The wrapper starts or uses
            the local proxy, captures agent traffic plus tool, file, shell, test,
            and diff events, then stores the trace for the desktop graph.
          </p>
        </div>
        <div className="steps">
          <div className="step reveal">
            <div className="num">01 / CAPTURE</div>
            <h4>Wrap the agent command</h4>
            <p>
              Use tether capture -- with Codex, Claude Code, custom CLIs, or an adapter-backed framework run.
            </p>
          </div>
          <div className="step reveal">
            <div className="num">02 / NORMALIZE</div>
            <h4>Run your agent</h4>
            <p>
              Tether normalizes LLM requests, tool calls, file changes, shell commands, tests, and errors.
            </p>
          </div>
          <div className="step reveal">
            <div className="num">03 / RECOVER</div>
            <h4>Inspect and recover</h4>
            <p>
              Open the desktop graph, click the broken node, inspect file impact and output,
              then replay supported requests or roll back from local evidence.
            </p>
          </div>
        </div>
      </section>

      <section className="section-pad wrap deferred-section" id="sources">
        <div className="section-head reveal">
          <div className="kicker">Supported sources</div>
          <h2 className="title">Adapters for the agents engineers already run.</h2>
          <p className="section-sub">
            Tether supports Codex local logs, Claude Code and local agent logs,
            LangChain callbacks or proxy, LangGraph callbacks or proxy,
            OpenAI/OpenGPT-style base_url proxying, and custom CLI agents through
            tether capture --.
          </p>
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
              Install the local execution debugger
              <br />
              before your next agent run.
            </h2>
            <p>
              Free during alpha. Run Tether locally, point your SDK at the proxy,
              and keep the whole debugging record on your machine.
            </p>
            <p className="alpha-note">macOS is active. Linux alpha is now available from CI artifacts.</p>
            <div className="download-actions">
              <div className="download-direct">
                <a
                  className="btn btn-primary pulse"
                  href={MACOS_DOWNLOAD_HREF}
                  onClick={() =>
                    trackEvent("download_clicked", {
                      asset: "macOS DMG",
                      location: "final_cta",
                    })
                  }
                  rel="noreferrer"
                  target="_blank"
                >
                  <LandingIcon name="apple-finder" />
                  Install macOS release
                </a>
                <a
                  className="btn btn-secondary"
                  href={LINUX_DOWNLOAD_HREF}
                  onClick={() =>
                    trackEvent("download_clicked", {
                      asset: "Linux alpha artifact",
                      location: "final_cta",
                    })
                  }
                  rel="noreferrer"
                  target="_blank"
                >
                  <LandingIcon name="microchip" />
                  Download Linux alpha
                </a>
              </div>
              <p className="download-note">macOS downloads the latest DMG directly. Linux opens the GitHub Releases page for AppImage and deb builds.</p>
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
                macOS 13+ and Linux alpha
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
