import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { InfoPage } from "@/components/InfoPage";
import { SITE_PAGE_MAP, SITE_PAGES } from "@/lib/site-pages";

type PageParams = {
  slug: string;
};

/**
 * Generates static params for the data-driven marketing pages.
 */
export function generateStaticParams(): PageParams[] {
  return SITE_PAGES.map((page) => ({ slug: page.slug }));
}

/**
 * Builds SEO metadata for a generated marketing page.
 */
export async function generateMetadata({ params }: { params: Promise<PageParams> }): Promise<Metadata> {
  const { slug } = await params;
  const page = SITE_PAGE_MAP.get(slug);

  if (!page) {
    return {};
  }

  return {
    title: page.title,
    description: page.description,
    alternates: {
      canonical: `/${page.slug}`,
    },
  };
}

/**
 * Renders a generated marketing page or returns 404 for unknown slugs.
 */
export default async function FooterPage({ params }: { params: Promise<PageParams> }) {
  const { slug } = await params;
  const page = SITE_PAGE_MAP.get(slug);

  if (!page) {
    notFound();
  }

  return <InfoPage page={page} />;
}
