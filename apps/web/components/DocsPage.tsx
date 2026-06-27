"use client";

import { ChatGptIcon, ClaudeIcon, PerplexityAiIcon } from "@hugeicons/core-free-icons";
import { HugeiconsIcon } from "@hugeicons/react";
import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";
import { Icon } from "@/components/Icon";
import {
  DOCS_NAV_GROUPS,
  DOCS_ORDER,
  DOCS_PAGE_MAP,
  type DocsBlock,
  type DocsPage as DocsPageData,
} from "@/lib/docs-pages";
import { docsPageToMarkdown } from "@/lib/docs-markdown";
import styles from "./DocsPage.module.css";

const GITHUB_HREF = "https://github.com/Hqzdev/Tether";
const RELEASE_HREF = "https://github.com/Hqzdev/Tether/releases/latest/download/Tether.dmg";


function docsHref(slug: string) {
  return slug === "overview" ? "/docs" : `/docs/${slug}`;
}

function docsMarkdownHref(slug: string) {
  return `/docs/${slug}/markdown`;
}

function sectionId(title: string) {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

function blockSearchText(block: DocsBlock) {
  switch (block.kind) {
    case "paragraph":
      return block.text;
    case "list":
      return block.items.join(" ");
    case "code":
      return `${block.language} ${block.code}`;
    case "table":
      return `${block.headers.join(" ")} ${block.rows.flat().join(" ")}`;
    case "cards":
      return block.cards.map((card) => `${card.title} ${card.text}`).join(" ");
  }
}

function pageSearchText(page?: DocsPageData) {
  if (!page) {
    return "";
  }

  return [
    page.title,
    page.category,
    page.description,
    ...page.sections.flatMap((section) => [
      section.title,
      ...section.blocks.map((block) => blockSearchText(block)),
    ]),
  ].join(" ");
}

async function copyToClipboard(value: string) {
  if (navigator.clipboard?.writeText) {
    try {
      await navigator.clipboard.writeText(value);
      return;
    } catch {
      // Fall back to the selection API below when clipboard permissions are blocked.
    }
  }

  const textArea = document.createElement("textarea");
  textArea.value = value;
  textArea.setAttribute("readonly", "");
  textArea.style.position = "fixed";
  textArea.style.opacity = "0";
  document.body.appendChild(textArea);
  textArea.select();
  document.execCommand("copy");
  document.body.removeChild(textArea);
}

function DocsLogo() {
  return (
    <span className={styles.logoMark} aria-hidden="true">
      <img alt="" height="28" src="/icon-1024.png" width="28" />
    </span>
  );
}

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
        <Link href="/#demo">Demo</Link>
        <Link href="/download">Download</Link>
        <a href={GITHUB_HREF} rel="noreferrer" target="_blank">
          GitHub
        </a>
      </nav>
      <a className={styles.topInstall} href={RELEASE_HREF} rel="noreferrer" target="_blank">
        <Icon name="apple-finder" />
        Download
      </a>
    </header>
  );
}

function aiQuestionHref(provider: "chatgpt" | "claude" | "perplexity", pageUrl: string, page: DocsPageData) {
  const prompt = `Read this Tether documentation page and help me understand it: ${pageUrl}\n\nPage: ${page.title}`;
  const encodedPrompt = encodeURIComponent(prompt);

  switch (provider) {
    case "chatgpt":
      return `https://chatgpt.com/?q=${encodedPrompt}`;
    case "claude":
      return `https://claude.ai/new?q=${encodedPrompt}`;
    case "perplexity":
      return `https://www.perplexity.ai/search/new?q=${encodedPrompt}`;
  }
}

function DocsCopyMenu({
  copiedKey,
  onCopy,
  page,
}: {
  copiedKey: string | null;
  onCopy: (value: string, copyKey: string) => void;
  page: DocsPageData;
}) {
  const [open, setOpen] = useState(false);
  const [pageUrl, setPageUrl] = useState(docsHref(page.slug));
  const menuRef = useRef<HTMLDivElement>(null);
  const copyKey = `markdown-${page.slug}`;
  const markdown = useMemo(() => docsPageToMarkdown(page), [page]);

  useEffect(() => {
    setPageUrl(new URL(docsHref(page.slug), window.location.origin).toString());
  }, [page.slug]);

  useEffect(() => {
    if (!open) {
      return;
    }

    const handlePointerDown = (event: PointerEvent) => {
      if (!menuRef.current?.contains(event.target as Node)) {
        setOpen(false);
      }
    };
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setOpen(false);
      }
    };

    document.addEventListener("pointerdown", handlePointerDown);
    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("pointerdown", handlePointerDown);
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [open]);

  const copyMarkdown = () => {
    onCopy(markdown, copyKey);
    setOpen(false);
  };

  return (
    <div className={styles.copyMenu} ref={menuRef}>
      <div className={styles.copyMenuTrigger}>
        <button className={styles.copyMenuMain} onClick={copyMarkdown} type="button">
          <Icon name={copiedKey === copyKey ? "check" : "file-lines"} size={18} />
          <span>{copiedKey === copyKey ? "Copied page" : "Copy page"}</span>
        </button>
        <button
          aria-expanded={open}
          aria-label={open ? "Close page actions" : "Open page actions"}
          className={styles.copyMenuChevron}
          onClick={() => setOpen((current) => !current)}
          type="button"
        >
          <Icon name="arrow-down-long" size={15} />
        </button>
      </div>
      {open ? (
        <div className={styles.copyMenuPanel}>
          <a href={docsMarkdownHref(page.slug)} target="_blank">
            <span className={styles.copyMenuIcon}>
              <Icon name="file-lines" size={22} />
            </span>
            <span>
              <strong>
                View as Markdown <Icon name="arrow-right" size={14} />
              </strong>
              <small>View this page as plain text</small>
            </span>
          </a>
          <a href={aiQuestionHref("chatgpt", pageUrl, page)} rel="noreferrer" target="_blank">
            <span className={styles.copyMenuIcon}>
              <HugeiconsIcon aria-hidden="true" color="currentColor" icon={ChatGptIcon} size={22} strokeWidth={1.8} />
            </span>
            <span>
              <strong>
                Open in ChatGPT <Icon name="arrow-right" size={14} />
              </strong>
              <small>Ask questions about this page</small>
            </span>
          </a>
          <a href={aiQuestionHref("claude", pageUrl, page)} rel="noreferrer" target="_blank">
            <span className={styles.copyMenuIcon}>
              <HugeiconsIcon aria-hidden="true" color="currentColor" icon={ClaudeIcon} size={22} strokeWidth={1.8} />
            </span>
            <span>
              <strong>
                Open in Claude <Icon name="arrow-right" size={14} />
              </strong>
              <small>Ask questions about this page</small>
            </span>
          </a>
          <a href={aiQuestionHref("perplexity", pageUrl, page)} rel="noreferrer" target="_blank">
            <span className={styles.copyMenuIcon}>
              <HugeiconsIcon aria-hidden="true" color="currentColor" icon={PerplexityAiIcon} size={22} strokeWidth={1.8} />
            </span>
            <span>
              <strong>
                Open in Perplexity <Icon name="arrow-right" size={14} />
              </strong>
              <small>Ask questions about this page</small>
            </span>
          </a>
        </div>
      ) : null}
    </div>
  );
}

function DocsSidebar({
  activeSlug,
  searchQuery,
  onClearSearch,
  onSearchChange,
}: {
  activeSlug: string;
  searchQuery: string;
  onClearSearch: () => void;
  onSearchChange: (value: string) => void;
}) {
  const filteredGroups = useMemo(() => {
    const normalizedQuery = searchQuery.trim().toLowerCase();

    return DOCS_NAV_GROUPS.map((group) => {
      const links = group.links.filter((link) => {
        if (!normalizedQuery) {
          return true;
        }

        const page = DOCS_PAGE_MAP.get(link.slug);
        const haystack = `${group.title} ${link.label} ${pageSearchText(page)}`.toLowerCase();
        return haystack.includes(normalizedQuery);
      });

      return { ...group, links };
    }).filter((group) => group.links.length > 0);
  }, [searchQuery]);

  const resultCount = filteredGroups.reduce((total, group) => total + group.links.length, 0);

  return (
    <aside className={styles.sidebar}>
      <div className={styles.sidebarIntro}>
        <span>Documentation</span>
        <strong>{DOCS_ORDER.length} guides</strong>
      </div>
      <search className={styles.searchBox}>
        <label htmlFor="docs-search">Search docs</label>
        <div className={styles.searchControl}>
          <Icon name="search" />
          <input
            id="docs-search"
            onChange={(event) => onSearchChange(event.target.value)}
            placeholder="Search guides, routes, commands"
            type="search"
            value={searchQuery}
          />
          {searchQuery ? (
            <button type="button" onClick={onClearSearch}>
              Clear
            </button>
          ) : null}
        </div>
      </search>
      <nav className={styles.sidebarNav} aria-label="Documentation">
        {filteredGroups.map((group) => (
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
                      href={docsHref(link.slug)}
                    >
                      <span>{link.label}</span>
                      {active ? <Icon name="arrow-right" /> : null}
                    </Link>
                  </li>
                );
              })}
            </ul>
          </section>
        ))}
        {resultCount === 0 ? (
          <p className={styles.emptySearch}>No matching docs. Clear search to see every guide.</p>
        ) : null}
      </nav>
    </aside>
  );
}

function CodeBlock({
  block,
  copiedKey,
  copyKey,
  onCopy,
}: {
  block: Extract<DocsBlock, { kind: "code" }>;
  copiedKey: string | null;
  copyKey: string;
  onCopy: (value: string, key: string) => void;
}) {
  const copied = copiedKey === copyKey;

  return (
    <figure className={styles.codeBlock}>
      <figcaption className={styles.codeHeader}>
        <span>{block.language}</span>
        <button type="button" onClick={() => onCopy(block.code, copyKey)}>
          <Icon name={copied ? "check" : "file-lines"} />
          {copied ? "Copied" : "Copy"}
        </button>
      </figcaption>
      <pre tabIndex={0}>
        <code>{block.code}</code>
      </pre>
    </figure>
  );
}

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

function DocsCards({ block }: { block: Extract<DocsBlock, { kind: "cards" }> }) {
  return (
    <div className={styles.cardGrid}>
      {block.cards.map((card) => (
        <Link className={styles.docCard} href={card.href} key={card.href}>
          <strong>{card.title}</strong>
          <span>{card.text}</span>
          <small>
            Open guide
            <Icon name="arrow-right" />
          </small>
        </Link>
      ))}
    </div>
  );
}

function renderBlock(
  block: DocsBlock,
  key: string,
  copiedKey: string | null,
  onCopy: (value: string, copyKey: string) => void,
) {
  switch (block.kind) {
    case "paragraph":
      return <p key={key}>{block.text}</p>;
    case "list":
      return (
        <ul className={styles.bullets} key={key}>
          {block.items.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ul>
      );
    case "code":
      return <CodeBlock block={block} copiedKey={copiedKey} copyKey={key} key={key} onCopy={onCopy} />;
    case "table":
      return <DocsTable block={block} key={key} />;
    case "cards":
      return <DocsCards block={block} key={key} />;
  }
}

function AdjacentDocs({ page }: { page: DocsPageData }) {
  const index = DOCS_ORDER.indexOf(page.slug);
  const previous = index > 0 ? DOCS_PAGE_MAP.get(DOCS_ORDER[index - 1]) : undefined;
  const next = index >= 0 && index < DOCS_ORDER.length - 1 ? DOCS_PAGE_MAP.get(DOCS_ORDER[index + 1]) : undefined;

  return (
    <nav className={styles.adjacent} aria-label="Adjacent documentation pages">
      {previous ? (
        <Link href={docsHref(previous.slug)}>
          <span>Previous</span>
          <strong>{previous.title}</strong>
        </Link>
      ) : (
        <span />
      )}
      {next ? (
        <Link href={docsHref(next.slug)}>
          <span>Next</span>
          <strong>{next.title}</strong>
        </Link>
      ) : (
        <span />
      )}
    </nav>
  );
}

function PageToc({
  activeSectionId,
  copiedKey,
  onSectionSelect,
  onCopy,
  page,
}: {
  activeSectionId: string;
  copiedKey: string | null;
  onSectionSelect: (sectionId: string) => void;
  onCopy: (value: string, copyKey: string) => void;
  page: DocsPageData;
}) {
  const copyMarkdownPage = () => {
    onCopy(docsPageToMarkdown(page), `resource-page-${page.slug}`);
  };

  const copyPageLink = () => {
    const href = new URL(docsHref(page.slug), window.location.origin).toString();
    onCopy(href, `page-link-${page.slug}`);
  };

  return (
    <aside className={styles.toc}>
      <nav aria-label="On this page">
        <h2>On this page</h2>
        <ul>
          {page.sections.map((section) => {
            const id = sectionId(section.title);

            return (
              <li key={section.title}>
                <a
                  aria-current={activeSectionId === id ? "true" : undefined}
                  className={activeSectionId === id ? styles.activeTocLink : undefined}
                  href={`#${id}`}
                  onClick={() => onSectionSelect(id)}
                >
                  {section.title}
                </a>
              </li>
            );
          })}
        </ul>
      </nav>
      <div className={styles.resourcePanel}>
        <span>Resources</span>
        <button type="button" onClick={copyMarkdownPage}>
          <Icon name={copiedKey === `resource-page-${page.slug}` ? "check" : "file-lines"} />
          {copiedKey === `resource-page-${page.slug}` ? "Copied page" : "Copy page"}
        </button>
        <a href={RELEASE_HREF} rel="noreferrer" target="_blank">
          <Icon name="apple-finder" />
          Download
        </a>
        <Link href="/docs/api-reference">
          <Icon name="file-lines" />
          API reference
        </Link>
        <a href={GITHUB_HREF} rel="noreferrer" target="_blank">
          <Icon name="github" />
          GitHub repository
        </a>
        <button type="button" onClick={copyPageLink}>
          <Icon name={copiedKey === `page-link-${page.slug}` ? "check" : "link"} />
          {copiedKey === `page-link-${page.slug}` ? "Copied page link" : "Copy page link"}
        </button>
      </div>
    </aside>
  );
}

export function DocsPage({ page }: { page: DocsPageData }) {
  const [copiedKey, setCopiedKey] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState("");
  const sectionIds = useMemo(() => page.sections.map((section) => sectionId(section.title)), [page.sections]);
  const [activeSectionId, setActiveSectionId] = useState(sectionIds[0] ?? "");

  useEffect(() => {
    setActiveSectionId(sectionIds[0] ?? "");
  }, [sectionIds]);

  useEffect(() => {
    if (sectionIds.length === 0) {
      return;
    }

    const visibleSections = new Map<string, number>();
    const sections = sectionIds
      .map((id) => document.getElementById(id))
      .filter((element): element is HTMLElement => element !== null);

    const setNearestSection = () => {
      const viewportAnchor = 136;
      const lastSection = sections.at(-1);

      if (lastSection && window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 8) {
        setActiveSectionId(lastSection.id);
        return;
      }

      const visibleId = Array.from(visibleSections.entries())
        .sort((first, second) => second[1] - first[1])
        .at(0)?.[0];

      if (visibleId) {
        setActiveSectionId(visibleId);
        return;
      }

      const nearestSection = sections
        .map((element) => ({
          id: element.id,
          distance: Math.abs(element.getBoundingClientRect().top - viewportAnchor),
        }))
        .sort((first, second) => first.distance - second.distance)
        .at(0);

      setActiveSectionId(nearestSection?.id ?? sectionIds[0]);
    };

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            visibleSections.set(entry.target.id, entry.intersectionRatio);
          } else {
            visibleSections.delete(entry.target.id);
          }
        });
        setNearestSection();
      },
      {
        rootMargin: "-112px 0px -58% 0px",
        threshold: [0, 0.1, 0.25, 0.5, 0.75, 1],
      },
    );

    sections.forEach((section) => observer.observe(section));

    const handleScrollEnd = () => setNearestSection();
    window.addEventListener("scroll", handleScrollEnd, { passive: true });
    window.addEventListener("resize", handleScrollEnd);
    setNearestSection();

    return () => {
      observer.disconnect();
      window.removeEventListener("scroll", handleScrollEnd);
      window.removeEventListener("resize", handleScrollEnd);
    };
  }, [sectionIds]);

  const handleCopy = async (value: string, key: string) => {
    await copyToClipboard(value);
    setCopiedKey(key);
    window.setTimeout(() => {
      setCopiedKey((currentKey) => (currentKey === key ? null : currentKey));
    }, 1600);
  };

  const copyPageLink = () => {
    const href = new URL(docsHref(page.slug), window.location.origin).toString();
    handleCopy(href, `hero-page-link-${page.slug}`);
  };

  return (
    <div className={styles.docsShell}>
      <DocsTopNav />
      <div className={styles.layout}>
        <DocsSidebar
          activeSlug={page.slug}
          onClearSearch={() => setSearchQuery("")}
          onSearchChange={setSearchQuery}
          searchQuery={searchQuery}
        />
        <main className={styles.article}>
          <div className={styles.breadcrumb}>
            <Link href="/">Home</Link>
            <span>/</span>
            <Link href="/docs">Docs</Link>
            <span>/</span>
            <span>{page.title}</span>
          </div>
          <header className={styles.hero}>
            <div className={styles.heroTopline}>
              <span className={styles.category}>{page.category}</span>
              <DocsCopyMenu copiedKey={copiedKey} onCopy={handleCopy} page={page} />
            </div>
            <h1>{page.title}</h1>
            <p>{page.description}</p>
            <div className={styles.heroActions}>
              <a className={styles.primaryAction} href={RELEASE_HREF} rel="noreferrer" target="_blank">
                <Icon name="apple-finder" />
                Download
              </a>
              <Link className={styles.secondaryAction} href="/docs/install">
                Setup steps
              </Link>
              <button className={styles.secondaryAction} type="button" onClick={copyPageLink}>
                <Icon name={copiedKey === `hero-page-link-${page.slug}` ? "check" : "link"} />
                {copiedKey === `hero-page-link-${page.slug}` ? "Copied" : "Copy link"}
              </button>
            </div>
            <dl className={styles.metaStrip}>
              <div>
                <dt>Release</dt>
                <dd>Alpha channel</dd>
              </div>
              <div>
                <dt>Runtime</dt>
                <dd>macOS + local proxy</dd>
              </div>
              <div>
                <dt>Docs</dt>
                <dd>{DOCS_ORDER.length} guides</dd>
              </div>
            </dl>
          </header>
          <div className={styles.sections}>
            {page.sections.map((section, sectionIndex) => {
              const id = sectionIds[sectionIndex] ?? sectionId(section.title);

              return (
                <section className={styles.section} id={id} key={section.title}>
                  <h2>
                    <a href={`#${id}`}>{section.title}</a>
                  </h2>
                  {section.blocks.map((block, blockIndex) =>
                    renderBlock(block, `${page.slug}-${sectionIndex}-${blockIndex}`, copiedKey, handleCopy),
                  )}
                </section>
              );
            })}
          </div>
          <AdjacentDocs page={page} />
        </main>
        <PageToc
          activeSectionId={activeSectionId}
          copiedKey={copiedKey}
          onCopy={handleCopy}
          onSectionSelect={setActiveSectionId}
          page={page}
        />
      </div>
    </div>
  );
}
