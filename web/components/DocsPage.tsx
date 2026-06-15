import Link from "next/link";
import {
  DOCS_NAV_GROUPS,
  DOCS_ORDER,
  DOCS_PAGE_MAP,
  type DocsBlock,
  type DocsPage as DocsPageData,
} from "@/lib/docs-pages";
import styles from "./DocsPage.module.css";

// Renders the small product mark used in the docs top navigation.
function DocsLogo() {
  return (
    <span className={styles.logoMark} aria-hidden="true">
      <img alt="" height="28" src="/icon-1024.png" width="28" />
    </span>
  );
}

// Renders the documentation-specific top navigation.
function DocsTopNav() {
  return (
    <header className={styles.topNav}>
      <Link className={styles.brand} href="/">
        <DocsLogo />
        <span>Tether</span>
      </Link>
      <nav className={styles.topLinks} aria-label="Primary">
        <Link className={styles.activeTopLink} href="/docs">
          Docs
        </Link>
        <Link href="/download">Download</Link>
        <a href="https://github.com/Hqzdev/Loom" rel="noreferrer" target="_blank">
          GitHub
        </a>
      </nav>
    </header>
  );
}

// Renders grouped documentation navigation and marks the active page.
function DocsSidebar({ activeSlug }: { activeSlug: string }) {
  return (
    <aside className={styles.sidebar}>
      <nav aria-label="Documentation">
        {DOCS_NAV_GROUPS.map((group) => (
          <section className={styles.navGroup} key={group.title}>
            <h2>{group.title}</h2>
            <ul>
              {group.links.map((link) => {
                const active = link.slug === activeSlug;

                return (
                  <li key={link.slug}>
                    <Link
                      aria-current={active ? "page" : undefined}
                      className={active ? styles.activeLink : undefined}
                      href={link.slug === "overview" ? "/docs" : `/docs/${link.slug}`}
                    >
                      {link.label}
                    </Link>
                  </li>
                );
              })}
            </ul>
          </section>
        ))}
      </nav>
    </aside>
  );
}

// Renders a preformatted command or source example without client-side syntax highlighting.
function CodeBlock({ block }: { block: Extract<DocsBlock, { kind: "code" }> }) {
  return (
    <div className={styles.codeBlock}>
      <div className={styles.codeHeader}>{block.language}</div>
      <pre>
        <code>{block.code}</code>
      </pre>
    </div>
  );
}

// Renders tabular reference material with horizontal overflow on small screens.
function DocsTable({ block }: { block: Extract<DocsBlock, { kind: "table" }> }) {
  return (
    <div className={styles.tableWrap}>
      <table>
        <thead>
          <tr>
            {block.headers.map((header) => (
              <th key={header}>{header}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {block.rows.map((row) => (
            <tr key={row.join("|")}>
              {row.map((cell) => (
                <td key={cell}>{cell}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// Renders architecture and guide cards that link to deeper docs pages.
function DocsCards({ block }: { block: Extract<DocsBlock, { kind: "cards" }> }) {
  return (
    <div className={styles.cardGrid}>
      {block.cards.map((card) => (
        <Link className={styles.docCard} href={card.href} key={card.href}>
          <strong>{card.title}</strong>
          <span>{card.text}</span>
        </Link>
      ))}
    </div>
  );
}

// Dispatches structured docs blocks to their presentation components.
function renderBlock(block: DocsBlock) {
  switch (block.kind) {
    case "paragraph":
      return <p key={block.text}>{block.text}</p>;
    case "list":
      return (
        <ul className={styles.bullets} key={block.items.join("|")}>
          {block.items.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ul>
      );
    case "code":
      return <CodeBlock block={block} key={block.code} />;
    case "table":
      return <DocsTable block={block} key={block.headers.join("|")} />;
    case "cards":
      return <DocsCards block={block} key={block.cards.map((card) => card.href).join("|")} />;
  }
}

// Renders previous and next links based on the stable docs sidebar order.
function AdjacentDocs({ page }: { page: DocsPageData }) {
  const index = DOCS_ORDER.indexOf(page.slug);
  const previous = index > 0 ? DOCS_PAGE_MAP.get(DOCS_ORDER[index - 1]) : undefined;
  const next = index >= 0 && index < DOCS_ORDER.length - 1 ? DOCS_PAGE_MAP.get(DOCS_ORDER[index + 1]) : undefined;

  return (
    <nav className={styles.adjacent} aria-label="Adjacent documentation pages">
      {previous ? (
        <Link href={previous.slug === "overview" ? "/docs" : `/docs/${previous.slug}`}>
          <span>Previous</span>
          <strong>{previous.title}</strong>
        </Link>
      ) : <span />}
      {next ? (
        <Link href={`/docs/${next.slug}`}>
          <span>Next</span>
          <strong>{next.title}</strong>
        </Link>
      ) : <span />}
    </nav>
  );
}

/**
 * Renders a documentation article with top navigation, sidebar navigation, and typed content blocks.
 */
export function DocsPage({ page }: { page: DocsPageData }) {
  return (
    <div className={styles.docsShell}>
      <DocsTopNav />
      <div className={styles.layout}>
        <DocsSidebar activeSlug={page.slug} />
        <main className={styles.article}>
          <div className={styles.breadcrumb}>
            <Link href="/">Home</Link>
            <span>/</span>
            <Link href="/docs">Docs</Link>
          </div>
          <header className={styles.hero}>
            <span className={styles.category}>{page.category}</span>
            <h1>{page.title}</h1>
            <p>{page.description}</p>
          </header>
          <div className={styles.sections}>
            {page.sections.map((section) => (
              <section className={styles.section} key={section.title}>
                <h2>{section.title}</h2>
                {section.blocks.map(renderBlock)}
              </section>
            ))}
          </div>
          <AdjacentDocs page={page} />
        </main>
      </div>
    </div>
  );
}
