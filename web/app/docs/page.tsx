import type { Metadata } from "next";
import { DocsPage } from "@/components/DocsPage";
import { DOCS_HOME_SLUG, DOCS_PAGE_MAP } from "@/lib/docs-pages";

/** SEO metadata for the root documentation page. */
export const metadata: Metadata = {
  title: "Documentation",
  description: "Install Tether, inspect traces, and understand the local-first architecture.",
  alternates: {
    canonical: "/docs",
  },
};

/**
 * Renders the root documentation page.
 */
export default function DocsIndexPage() {
  const page = DOCS_PAGE_MAP.get(DOCS_HOME_SLUG);

  if (!page) {
    throw new Error("Missing docs home page");
  }

  return <DocsPage page={page} />;
}
