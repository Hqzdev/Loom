import Link from "next/link";
import type { SitePage } from "@/lib/site-pages";
import { SiteFooter, SiteHeader } from "@/components/SiteChrome";
import styles from "./InfoPage.module.css";

/**
 * Renders a data-driven marketing information page.
 */
export function InfoPage({ page }: { page: SitePage }) {
  return (
    <main className={`landing-page ${styles.page}`}>
      <SiteHeader />
      <section className={`wrap ${styles.hero}`}>
        <div className={styles.eyebrow}>{page.eyebrow}</div>
        <h1 className={styles.title}>{page.title}</h1>
        <p className={styles.description}>{page.description}</p>
        {page.cta ? (
          <div className={styles.actions}>
            <Link className="btn btn-primary" href={page.cta.href}>
              {page.cta.label}
            </Link>
            <Link className="btn btn-ghost" href="/">
              Back to product
            </Link>
          </div>
        ) : null}
      </section>

      <section className={`wrap ${styles.grid}`}>
        {page.sections.map((section) => (
          <article className={styles.panel} key={section.title}>
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
