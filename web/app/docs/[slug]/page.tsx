import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { DocsPage } from "@/components/DocsPage";
import { DOCS_HOME_SLUG, DOCS_PAGE_MAP, DOCS_PAGES } from "@/lib/docs-pages";

type DocsPageParams = {
  slug: string;
};

/**
 * Generates static params for every documentation page except the /docs index.
 */
export function generateStaticParams(): DocsPageParams[] {
  return DOCS_PAGES
    .filter((page) => page.slug !== DOCS_HOME_SLUG)
    .map((page) => ({ slug: page.slug }));
}

/**
 * Builds per-page SEO metadata for generated documentation routes.
 */
export async function generateMetadata({ params }: { params: Promise<DocsPageParams> }): Promise<Metadata> {
  const { slug } = await params;
  const page = DOCS_PAGE_MAP.get(slug);

  if (!page) {
    return {};
  }

  return {
    title: `${page.title} | Docs`,
    description: page.description,
    alternates: {
      canonical: `/docs/${page.slug}`,
    },
  };
}

/**
 * Renders a generated documentation page or returns 404 for unknown slugs.
 */
export default async function DocsSlugPage({ params }: { params: Promise<DocsPageParams> }) {
  const { slug } = await params;
  const page = DOCS_PAGE_MAP.get(slug);

  if (!page || page.slug === DOCS_HOME_SLUG) {
    notFound();
  }

  return <DocsPage page={page} />;
}
