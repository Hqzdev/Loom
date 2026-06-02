"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

const PRODUCT_LINKS = [
  { label: "Features", href: "/features" },
  { label: "Inspector", href: "/inspector" },
  { label: "How it works", href: "/how-it-works" },
  { label: "Download", href: "/download" },
];

const DEVELOPER_LINKS = [
  { label: "Documentation", href: "/documentation" },
  { label: "CLI reference", href: "/cli-reference" },
  { label: "Changelog", href: "/changelog" },
  { label: "GitHub", href: "https://github.com/Hqzdev/Loom", external: true },
];

const COMPANY_LINKS = [
  { label: "Privacy", href: "/privacy" },
  { label: "Security", href: "/security" },
  { label: "Contact", href: "/contact" },
];

function LogoMark() {
  return (
    <svg
      aria-hidden="true"
      className="ic"
      fill="none"
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.7"
      viewBox="0 0 24 24"
    >
      <rect height="8" rx="2" width="8" x="3" y="3" />
      <rect height="8" rx="2" width="8" x="13" y="13" />
      <path d="M7 11v3a2 2 0 0 0 2 2h4" />
    </svg>
  );
}

function CircleIcon() {
  return (
    <svg aria-hidden="true" className="ic" fill="currentColor" viewBox="0 0 24 24">
      <circle cx="12" cy="12" r="8" />
    </svg>
  );
}

function AppleIcon() {
  return (
    <svg aria-hidden="true" className="ic" fill="currentColor" viewBox="0 0 24 24">
      <path d="M16.37 12.78c-.02-2.2 1.8-3.26 1.88-3.31-1.03-1.5-2.62-1.71-3.19-1.73-1.36-.14-2.65.8-3.34.8-.69 0-1.75-.78-2.88-.76-1.48.02-2.85.86-3.61 2.19-1.54 2.67-.39 6.62 1.11 8.79.73 1.06 1.6 2.25 2.74 2.21 1.1-.04 1.51-.71 2.84-.71 1.32 0 1.7.71 2.86.69 1.18-.02 1.93-1.08 2.65-2.15.84-1.23 1.18-2.42 1.2-2.48-.03-.01-2.29-.88-2.31-3.49zM14.4 6.24c.61-.74 1.02-1.77.91-2.8-.88.04-1.95.59-2.58 1.33-.56.65-1.06 1.7-.93 2.7.98.08 1.99-.5 2.6-1.23z" />
    </svg>
  );
}

function ArrowIcon() {
  return (
    <svg
      aria-hidden="true"
      className="ic"
      fill="none"
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.7"
      viewBox="0 0 24 24"
    >
      <path d="M5 12h14" />
      <path d="m13 6 6 6-6 6" />
    </svg>
  );
}

function FooterLink({ href, label, external = false }: { href: string; label: string; external?: boolean }) {
  if (external) {
    return (
      <a href={href} rel="noreferrer" target="_blank">
        {label}
      </a>
    );
  }

  return <Link href={href}>{label}</Link>;
}

export function SiteHeader() {
  const [navStuck, setNavStuck] = useState(false);

  useEffect(() => {
    const onScroll = () => setNavStuck(window.scrollY > 12);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <nav className={`nav ${navStuck ? "stuck" : ""}`} id="nav">
      <div className="wrap nav-inner">
        <Link className="brand" href="/">
          <span className="logo">
            <LogoMark />
          </span>
          Loom
        </Link>
        <div className="nav-links">
          <Link href="/features">Features</Link>
          <Link href="/inspector">Inspector</Link>
          <Link href="/how-it-works">How it works</Link>
          <Link href="/download">Download</Link>
        </div>
        <div className="nav-right">
          <Link className="gh-pill" href="/download" aria-label="Get the Loom alpha build">
            <CircleIcon />
            Alpha build
          </Link>
          <Link className="btn btn-primary btn-sm" href="/download">
            <AppleIcon />
            Download
          </Link>
        </div>
      </div>
    </nav>
  );
}

export function SiteFooter() {
  return (
    <footer className="footer wrap">
      <div className="foot-grid">
        <div className="foot-brand">
          <Link className="brand" href="/">
            <span className="logo">
              <LogoMark />
            </span>
            Loom
          </Link>
          <p>
            Local-first observability and mocking for LLM agents. Built for developers who refuse to debug in
            the dark.
          </p>
        </div>
        <div className="foot-col">
          <h5>
            <Link href="/product">Product</Link>
          </h5>
          {PRODUCT_LINKS.map((link) => (
            <FooterLink href={link.href} key={link.href} label={link.label} />
          ))}
        </div>
        <div className="foot-col">
          <h5>
            <Link href="/developers">Developers</Link>
          </h5>
          {DEVELOPER_LINKS.map((link) => (
            <FooterLink
              external={link.external}
              href={link.href}
              key={link.href}
              label={link.label}
            />
          ))}
        </div>
        <div className="foot-col">
          <h5>
            <Link href="/company">Company</Link>
          </h5>
          {COMPANY_LINKS.map((link) => (
            <FooterLink href={link.href} key={link.href} label={link.label} />
          ))}
        </div>
      </div>
      <div className="foot-bottom">
        <span>&copy; 2026 Loom - Crafted for the Mac</span>
        <span>
          <ArrowIcon /> All systems local
        </span>
      </div>
    </footer>
  );
}
