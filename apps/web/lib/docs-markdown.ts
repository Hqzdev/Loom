import type { DocsBlock, DocsPage } from "@/lib/docs-pages";

function blockToMarkdown(block: DocsBlock): string {
  switch (block.kind) {
    case "paragraph":
      return block.text;
    case "list":
      return block.items.map((item) => `- ${item}`).join("\n");
    case "code":
      return ["```" + block.language, block.code, "```"].join("\n");
    case "table": {
      const header = `| ${block.headers.join(" | ")} |`;
      const divider = `| ${block.headers.map(() => "---").join(" | ")} |`;
      const rows = block.rows.map((row) => `| ${row.join(" | ")} |`);
      return [header, divider, ...rows].join("\n");
    }
    case "cards":
      return block.cards.map((card) => `- [${card.title}](${card.href}) - ${card.text}`).join("\n");
  }
}

/** Serializes one documentation page to Markdown for copy/export surfaces. */
export function docsPageToMarkdown(page: DocsPage): string {
  const sections = page.sections.map((section) => {
    const blocks = section.blocks.map(blockToMarkdown).join("\n\n");
    return `## ${section.title}\n\n${blocks}`;
  });

  return [`# ${page.title}`, page.description, `Category: ${page.category}`, ...sections].join("\n\n");
}
