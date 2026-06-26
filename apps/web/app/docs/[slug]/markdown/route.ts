import { NextResponse } from "next/server";
import { DOCS_PAGE_MAP, DOCS_PAGES } from "@/lib/docs-pages";
import { docsPageToMarkdown } from "@/lib/docs-markdown";

type DocsMarkdownParams = {
  slug: string;
};

export function generateStaticParams(): DocsMarkdownParams[] {
  return DOCS_PAGES.map((page) => ({ slug: page.slug }));
}

/** Returns a plain Markdown representation of one generated docs page. */
export async function GET(_: Request, { params }: { params: Promise<DocsMarkdownParams> }) {
  const { slug } = await params;
  const page = DOCS_PAGE_MAP.get(slug);

  if (!page) {
    return new NextResponse("Not found", { status: 404 });
  }

  return new NextResponse(docsPageToMarkdown(page), {
    headers: {
      "Content-Type": "text/markdown; charset=utf-8",
      "Cache-Control": "public, max-age=300",
    },
  });
}
