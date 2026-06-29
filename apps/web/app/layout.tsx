import type { Metadata } from "next";
import type { ReactNode } from "react";
import { DM_Mono, DM_Sans, Fustat } from "next/font/google";
import "./globals.css";

const dmSans = DM_Sans({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-dm-sans",
});

const dmMono = DM_Mono({
  subsets: ["latin"],
  weight: ["400", "500"],
  display: "swap",
  variable: "--font-dm-mono",
});

const fustat = Fustat({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-fustat",
});

const fontVariables = `${dmSans.variable} ${dmMono.variable} ${fustat.variable}`;

const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? "https://useTether.dev";
const GTM_ID = "GTM-WCSRPQFF";
const YANDEX_METRIKA_ID = 109761424;
const APP_ICON_PATH = "/icon-1024.png";
const APP_ICON_URL = `${SITE_URL}${APP_ICON_PATH}`;

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  applicationName: "Tether",
  title: {
    default: "Tether - Local execution debugger for AI coding agents",
    template: "%s | Tether",
  },
  description:
    "Debug AI coding agent execution locally: prompt, action, file diff, failed command or test, and recovery. Source adapters for supported agent CLIs, LangChain, LangGraph, OpenAI/OpenGPT-style agents, and custom CLIs.",
  keywords: [
    "AI coding agent debugger",
    "execution debugger",
    "local AI proxy",
    "AI agent debugger",
    "Claude Code debugger",
    "agent tracing tool",
    "agent execution graph",
    "AI debugging macOS",
    "AI debugging Linux",
    "local execution debugging",
    "agent failure recovery",
    "AI agent recovery",
    "local LangSmith alternative",
    "LLM debugging privacy",
  ],
  authors: [{ name: "Tether" }],
  creator: "Tether",
  robots: {
    index: true,
    follow: true,
    googleBot: { index: true, follow: true, "max-image-preview": "large" },
  },
  manifest: "/manifest.webmanifest",
  icons: {
    icon: [
      { url: "/favicon.png", sizes: "32x32", type: "image/png" },
      { url: APP_ICON_PATH, sizes: "1024x1024", type: "image/png" },
    ],
    shortcut: [{ url: "/favicon.png", sizes: "32x32", type: "image/png" }],
    apple: [{ url: "/apple-touch-icon.png", sizes: "180x180", type: "image/png" }],
  },
  openGraph: {
  type: "website",
  url: SITE_URL,
  siteName: "Tether",
    title: "Tether - Local execution debugger for AI coding agents",
    description:
      "Capture prompt-to-action execution paths, command output, file changes, failed tests, and recovery evidence from AI coding agents. Local-first source adapters.",
    images: [
      {
        url: APP_ICON_PATH,
        width: 1024,
        height: 1024,
        alt: "Tether app icon",
      },
    ],
    locale: "en_US",
  },
  twitter: {
  card: "summary_large_image",
    title: "Tether - Local execution debugger for AI coding agents",
    description:
      "Capture prompt-to-action execution paths, command output, file changes, failed tests, and recovery evidence from AI coding agents. Local-first source adapters.",
    images: [APP_ICON_PATH],
  },
  alternates: {
    canonical: SITE_URL,
  },
};

const jsonLd = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "Organization",
      "@id": `${SITE_URL}/#organization`,
      name: "Tether",
      url: SITE_URL,
      logo: APP_ICON_URL,
      image: APP_ICON_URL,
      description:
        "Local execution debugger for AI coding agents on macOS and Linux: prompt, action, file change, and recovery traces stay on your machine.",
    },
    {
      "@type": "SoftwareApplication",
      "@id": `${SITE_URL}/#app`,
      name: "Tether",
      applicationCategory: "DeveloperApplication",
      operatingSystem: "macOS 13+, Linux",
      offers: {
        "@type": "Offer",
        price: "0",
        priceCurrency: "USD",
        description: "Free during alpha",
      },
      publisher: { "@id": `${SITE_URL}/#organization` },
  image: APP_ICON_URL,
      description:
        "Tether captures execution context from local AI coding agents, tracks what changed and what broke, and lets you replay from a failed step with local proxy confidence.",
      featureList: [
        "Local execution capture through source adapters",
        "Agent execution graph",
        "Prompt-action-file-diff recovery path",
        "File-change recovery from failed nodes",
        "Local response cache for repeated execution paths",
        "Keychain-aware macOS secrets",
        "Linux Tauri desktop app",
        "Local-first traces and prompts",
      ],
      screenshot: APP_ICON_URL,
    },
    {
      "@type": "WebSite",
      "@id": `${SITE_URL}/#website`,
      url: SITE_URL,
      name: "Tether",
      publisher: { "@id": `${SITE_URL}/#organization` },
    },
    {
      "@type": "HowTo",
      "@id": `${SITE_URL}/#howto`,
      name: "How to debug broken AI coding agent runs with Tether",
      description: "Set up Tether to capture prompt-to-action execution paths and replay from any failed step in three steps.",
      totalTime: "PT2M",
      step: [
        {
          "@type": "HowToStep",
          position: 1,
          name: "Point the base_url",
      text: "Run tether capture -- <agent command> or point OpenAI-compatible traffic to http://localhost:8080/v1.",
        },
        {
          "@type": "HowToStep",
          position: 2,
          name: "Run your agent",
      text: "Run your agent as normal. Tether captures LLM requests, tool calls, file changes, shell commands, tests, diffs, and errors.",
        },
        {
          "@type": "HowToStep",
          position: 3,
          name: "Inspect and replay",
          text: "Open the canvas, inspect the failed step with output and file impact, then replay the affected branch with your fix.",
        },
      ],
    },
    {
      "@type": "FAQPage",
      mainEntity: [
        {
          "@type": "Question",
          name: "Why not just use print() or logging?",
          acceptedAnswer: {
            "@type": "Answer",
            text: "Logging shows fragments. Tether connects the prompt, action, file diff, command output, failed test, and recovery point in one local execution graph.",
          },
        },
        {
          "@type": "Question",
          name: "Can I use this with production code?",
          acceptedAnswer: {
            "@type": "Answer",
            text: "Yes. It's a local proxy, so your real code doesn't change. Use it locally for debugging, or keep it running. Tether only stores traces locally and never sends anything anywhere.",
          },
        },
        {
          "@type": "Question",
          name: "How much money does caching actually save?",
          acceptedAnswer: {
            "@type": "Answer",
            text: "It depends on your agent. If you're iterating on prompt logic and re-running the same retrieval steps, caching saves you 50-90% of API spend while you debug. Each cached hit costs $0.0000.",
          },
        },
        {
          "@type": "Question",
          name: "Does Tether add latency to my agent?",
          acceptedAnswer: {
            "@type": "Answer",
            text: "Negligible. Tether runs locally on your machine. The only overhead is the proxy hop, which is less than 1ms. Real LLM calls are the bottleneck, not Tether.",
          },
        },
        {
          "@type": "Question",
          name: "Can I share traces with my team?",
          acceptedAnswer: {
            "@type": "Answer",
            text: "Not yet. Each developer runs their own Tether instance locally. Export as JSON is coming in a later release.",
          },
        },
        {
          "@type": "Question",
          name: "How does Tether intercept LLM calls without SDK changes?",
          acceptedAnswer: {
            "@type": "Answer",
            text: "Tether runs a local HTTP proxy on your machine. You point your AI client's base_url at http://localhost:8080/v1 — that's the only change required. Tether forwards requests to the real provider and records everything locally.",
          },
        },
        {
          "@type": "Question",
          name: "Does Tether send my prompts or API keys to the cloud?",
          acceptedAnswer: {
            "@type": "Answer",
            text: "No. Tether is fully air-gapped. Your prompts and responses stay on your machine. macOS secrets use Keychain-aware storage, Linux uses the same local proxy model, and traces stay local.",
          },
        },
        {
          "@type": "Question",
          name: "Which LLM providers does Tether support?",
          acceptedAnswer: {
            "@type": "Answer",
            text: "Tether supports OpenAI, Anthropic, Ollama, LM Studio, and any provider that accepts an OpenAI-compatible base_url. It also works with LangChain, LangGraph, LlamaIndex, and similar frameworks.",
          },
        },
        {
          "@type": "Question",
          name: "Is Tether free?",
          acceptedAnswer: {
            "@type": "Answer",
            text: "Yes. Tether is free during the alpha period. The core proxy is open source.",
          },
        },
      ],
    },
  ],
};

/**
 * Renders the root HTML shell, global analytics tags, and page content.
 */
export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" className={fontVariables}>
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `
(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':
new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],
j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src=
'https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);
})(window,document,'script','dataLayer',${JSON.stringify(GTM_ID)});
`,
          }}
        />
        <script
          type="text/javascript"
          dangerouslySetInnerHTML={{
            __html: `
(function(m,e,t,r,i,k,a){
  m[i]=m[i]||function(){(m[i].a=m[i].a||[]).push(arguments)};
  m[i].l=1*new Date();
  for (var j = 0; j < document.scripts.length; j++) {if (document.scripts[j].src === r) { return; }}
  k=e.createElement(t),a=e.getElementsByTagName(t)[0],k.async=1,k.src=r,a.parentNode.insertBefore(k,a)
})(window, document,'script','https://mc.yandex.ru/metrika/tag.js?id=${YANDEX_METRIKA_ID}', 'ym');

ym(${YANDEX_METRIKA_ID}, 'init', {ssr:true, webvisor:true, clickmap:true, ecommerce:"dataLayer", referrer: document.referrer, url: location.href, accurateTrackBounce:true, trackLinks:true});
`,
          }}
        />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
      </head>
      <body>
        <noscript>
          <iframe
            height="0"
            src={`https://www.googletagmanager.com/ns.html?id=${GTM_ID}`}
            style={{ display: "none", visibility: "hidden" }}
            title="Google Tag Manager"
            width="0"
          />
        </noscript>
        <noscript>
          <div>
            <img
              alt=""
              src={`https://mc.yandex.ru/watch/${YANDEX_METRIKA_ID}`}
              style={{ position: "absolute", left: "-9999px" }}
            />
          </div>
        </noscript>
        {children}
      </body>
    </html>
  );
}
