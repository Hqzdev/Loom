import type { MetadataRoute } from "next";
import { DOCS_HOME_SLUG, DOCS_PAGES } from "@/lib/docs-pages";
import { SITE_PAGES } from "@/lib/site-pages";

const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? "https://useTether.dev";

/**
 * Generates canonical sitemap entries for marketing and documentation pages.
 */
export default function sitemap(): MetadataRoute.Sitemap {
  const staticPages = SITE_PAGES.map((page) => ({
    url: `${SITE_URL}/${page.slug}`,
    lastModified: new Date(),
    changeFrequency: "monthly" as const,
    priority: 0.7,
  }));
  const docsPages = DOCS_PAGES.map((page) => ({
    url: page.slug === DOCS_HOME_SLUG ? `${SITE_URL}/docs` : `${SITE_URL}/docs/${page.slug}`,
    lastModified: new Date(),
    changeFrequency: "weekly" as const,
    priority: page.slug === DOCS_HOME_SLUG ? 0.9 : 0.75,
  }));

  return [
    {
      url: SITE_URL,
      lastModified: new Date(),
      changeFrequency: "weekly",
      priority: 1,
    },
    ...staticPages,
    ...docsPages,
  ];
}
