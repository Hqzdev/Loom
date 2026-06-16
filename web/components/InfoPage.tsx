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
