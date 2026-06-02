import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { InfoPage } from "@/components/InfoPage";
import { SITE_PAGE_MAP, SITE_PAGES } from "@/lib/site-pages";

type PageParams = {
  slug: string;
};

export function generateStaticParams(): PageParams[] {
  return SITE_PAGES.map((page) => ({ slug: page.slug }));
}

export async function generateMetadata({ params }: { params: Promise<PageParams> }): Promise<Metadata> {
  const { slug } = await params;
  const page = SITE_PAGE_MAP.get(slug);

  if (!page) {
    return {};
  }

  return {
    title: `${page.title} | Loom`,
    description: page.description,
    alternates: {
      canonical: `/${page.slug}`,
    },
  };
}

export default async function FooterPage({ params }: { params: Promise<PageParams> }) {
  const { slug } = await params;
  const page = SITE_PAGE_MAP.get(slug);

  if (!page) {
    notFound();
  }

  return <InfoPage page={page} />;
}
