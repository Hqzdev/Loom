import Link from "next/link";
import type { SitePage } from "@/lib/site-pages";
import { SiteFooter, SiteHeader } from "@/components/SiteChrome";
import styles from "./InfoPage.module.css";

type PageSignal = {
  label: string;
  value: string;
  detail: string;
};

const PAGE_SIGNALS: Record<string, PageSignal[]> = {
  product: [
    { label: "Runtime", value: "Local", detail: "desktop app, proxy, wrapper" },
    { label: "Evidence", value: "Trace", detail: "prompt, files, commands" },
    { label: "Outcome", value: "Recover", detail: "inspect, replay, rollback" },
  ],
  features: [
    { label: "Capture", value: "Events", detail: "requests, tools, files" },
    { label: "Inspect", value: "Context", detail: "status, latency, tokens" },
    { label: "Recover", value: "Actions", detail: "replay and rollback paths" },
  ],
  inspector: [
    { label: "Pane", value: "Focused", detail: "one node at a time" },
    { label: "Proof", value: "Exact", detail: "prompt and response records" },
    { label: "State", value: "Actionable", detail: "cached, failed, replayed" },
  ],
  "how-it-works": [
    { label: "1", value: "Capture", detail: "wrap the local agent run" },
    { label: "2", value: "Normalize", detail: "store events as graph nodes" },
    { label: "3", value: "Recover", detail: "debug from concrete evidence" },
  ],
  developers: [
    { label: "Sources", value: "Adapters", detail: "CLIs, frameworks, proxy" },
    { label: "Boundary", value: "Local", detail: "no hosted workspace required" },
    { label: "Loop", value: "Fast", detail: "debug before production" },
  ],
  documentation: [
    { label: "Guides", value: "19", detail: "setup, graph, proxy, clients" },
    { label: "Audience", value: "Builder", detail: "agent teams and tool makers" },
    { label: "Scope", value: "Practical", detail: "commands and architecture" },
  ],
  "cli-reference": [
    { label: "Command", value: "capture", detail: "wrap agent execution" },
    { label: "Proxy", value: "local", detail: "route compatible calls" },
    { label: "Release", value: "scripted", detail: "build and smoke checks" },
  ],
  changelog: [
    { label: "Channel", value: "Alpha", detail: "local debugger foundation" },
    { label: "Clients", value: "2", detail: "macOS and Linux" },
    { label: "Next", value: "Replay", detail: "signed builds and adapters" },
  ],
  company: [
    { label: "Standard", value: "Proof", detail: "debugging over mystery" },
    { label: "Bias", value: "Local", detail: "privacy and fast iteration" },
    { label: "Focus", value: "Craft", detail: "complex systems made clear" },
  ],
  privacy: [
    { label: "Traces", value: "Local", detail: "stored on your machine" },
    { label: "Keys", value: "OS", detail: "platform-local handling" },
    { label: "Cloud", value: "None", detail: "no hosted debug workspace" },
  ],
  contact: [
    { label: "Best path", value: "GitHub", detail: "issues and product feedback" },
    { label: "Alpha", value: "Focused", detail: "workflow-specific requests" },
    { label: "Security", value: "Direct", detail: "notes route to review" },
  ],
};

function pageSignals(page: SitePage) {
  return PAGE_SIGNALS[page.slug] ?? [
    { label: "Scope", value: page.title, detail: page.eyebrow },
    { label: "Mode", value: "Local", detail: "desktop execution debugging" },
    { label: "Evidence", value: "Graph", detail: "inspectable agent runs" },
  ];
}

function PageArtifact({ page }: { page: SitePage }) {
  const signals = pageSignals(page);

  return (
    <aside className={styles.artifact} aria-label={`${page.title} summary`}>
      <div className={styles.artifactHeader}>
        <span>{page.slug.replaceAll("-", " ")}</span>
        <strong>{page.eyebrow}</strong>
      </div>
      <div className={styles.signalStack}>
        {signals.map((signal) => (
          <div className={styles.signalRow} key={`${signal.label}-${signal.value}`}>
            <span>{signal.label}</span>
            <strong>{signal.value}</strong>
            <p>{signal.detail}</p>
          </div>
        ))}
      </div>
      <div className={styles.traceStrip}>
        <span>prompt</span>
        <span>action</span>
        <span>diff</span>
        <span>replay</span>
      </div>
    </aside>
  );
}

function SectionIndex({ page }: { page: SitePage }) {
  return (
    <section className={`wrap ${styles.indexBand}`} aria-label={`${page.title} page outline`}>
      {page.sections.map((section, index) => (
        <div className={styles.indexItem} key={section.title}>
          <span>{String(index + 1).padStart(2, "0")}</span>
          <strong>{section.title}</strong>
        </div>
      ))}
    </section>
  );
}

export function InfoPage({ page }: { page: SitePage }) {
  return (
    <main className={`landing-page ${styles.page}`}>
      <SiteHeader />
      <section className={`wrap ${styles.hero}`}>
        <div className={styles.heroCopy}>
          <div className={styles.eyebrow}>{page.eyebrow}</div>
          <h1 className={styles.title}>{page.title}</h1>
          <p className={styles.description}>{page.description}</p>
          <div className={styles.actions}>
            {page.cta ? (
              <Link className="btn btn-primary" href={page.cta.href}>
                {page.cta.label}
              </Link>
            ) : null}
            <Link className="btn btn-ghost" href="/">
              Back to product
            </Link>
          </div>
        </div>
        <PageArtifact page={page} />
      </section>

      <SectionIndex page={page} />

      <section className={`wrap ${styles.grid}`}>
        {page.sections.map((section, index) => (
          <article className={styles.panel} key={section.title}>
            <span className={styles.panelIndex}>{String(index + 1).padStart(2, "0")}</span>
            <h2>{section.title}</h2>
            <p>{section.body}</p>
            {section.bullets ? (
              <ul className={styles.bullets}>
                {section.bullets.map((bullet) => (
                  <li key={bullet}>{bullet}</li>
                ))}
              </ul>
            ) : null}
            {page.slug === "cli-reference" && section.title === "Common commands" ? (
              <div className={styles.terminal}>
                <div>$ npm run dev</div>
                <div>$ npm run build</div>
                <div>$ npm run package:dmg</div>
                <div>$ npm run smoke:e2e</div>
              </div>
            ) : null}
          </article>
        ))}
      </section>
      {page.securityMetrics && page.securityFlow && page.securityMatrix && page.securityRisks ? (
        <section className={`wrap ${styles.securityEvidence}`}>
          <div className={styles.metricsGrid}>
            {page.securityMetrics.map((metric) => (
              <article className={`${styles.metricCard} ${styles[metric.tone]}`} key={metric.label}>
                <span>{metric.label}</span>
                <strong>{metric.value}</strong>
                <p>{metric.detail}</p>
                <div className={styles.metricTrack}>
                  <div className={styles.metricBar} style={{ width: `${metric.percent}%` }} />
                </div>
              </article>
            ))}
          </div>

          <div className={styles.flowPanel}>
            <div className={styles.blockHead}>
              <span>Data flow</span>
              <strong>What moves, where it lands, and where Tether stops</strong>
            </div>
            <div className={styles.flowGrid}>
              {page.securityFlow.map((step, index) => (
                <div className={styles.flowStep} key={step.label}>
                  <span className={styles.flowIndex}>{String(index + 1).padStart(2, "0")}</span>
                  <strong>{step.label}</strong>
                  <p>{step.detail}</p>
                </div>
              ))}
            </div>
          </div>

          <div className={styles.securityTable}>
            <div className={styles.blockHead}>
              <span>Data boundary matrix</span>
              <strong>Concrete storage and egress rules</strong>
            </div>
            <div className={`${styles.tableRow} ${styles.tableHead}`}>
              <span>Asset</span>
              <span>Stored at</span>
              <span>Leaves device?</span>
              <span>Control</span>
            </div>
            {page.securityMatrix.map((row) => (
              <div className={styles.tableRow} key={row.asset}>
                <strong>{row.asset}</strong>
                <span>{row.location}</span>
                <span>{row.leavesDevice}</span>
                <code>{row.control}</code>
              </div>
            ))}
          </div>

          <div className={styles.riskPanel}>
            <div className={styles.blockHead}>
              <span>Risk register</span>
              <strong>What is covered, what is not, and who owns it</strong>
            </div>
            <div className={styles.riskGrid}>
              {page.securityRisks.map((risk) => (
                <article className={styles.riskCard} key={risk.area}>
                  <span>{risk.status}</span>
                  <h3>{risk.area}</h3>
                  <p>{risk.nextStep}</p>
                  <code>{risk.owner}</code>
                </article>
              ))}
            </div>
          </div>
        </section>
      ) : null}
      {page.reviewRows ? (
        <section className={`wrap ${styles.review}`}>
          <div className={styles.reviewTable}>
            <div className={`${styles.reviewRow} ${styles.reviewHead}`}>
              <span>Question</span>
              <span>Answer</span>
              <span>Proof</span>
            </div>
            {page.reviewRows.map((row) => (
              <div className={styles.reviewRow} key={row.control}>
                <span>{row.control}</span>
                <span>{row.evidence}</span>
                <code>{row.proof}</code>
              </div>
            ))}
          </div>
        </section>
      ) : null}
      <SiteFooter />
    </main>
  );
}
