"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { Icon } from "@/components/Icon";
import { trackEvent } from "@/lib/analytics";

const PRODUCT_LINKS = [
  { label: "Product demo", href: "/#demo" },
  { label: "Setup", href: "/#how" },
  { label: "Privacy review", href: "/security" },
  { label: "Download", href: "/#download" },
];

const DEVELOPER_LINKS = [
  { label: "Documentation", href: "/docs" },
  { label: "CLI reference", href: "/cli-reference" },
  { label: "Changelog", href: "/changelog" },
  { label: "GitHub", href: "https://github.com/Hqzdev/Tether", external: true },
];

const COMPANY_LINKS = [
  { label: "Privacy", href: "/privacy" },
  { label: "Security", href: "/security" },
  { label: "Contact", href: "/contact" },
];

// Renders the shared decorative product mark used in the header and footer.
function LogoMark() {
  return (
    <img
      alt=""
      aria-hidden="true"
      decoding="async"
      height="28"
      src="/icon-1024.png"
      width="28"
    />
  );
}

// Renders an internal or external footer link with matching analytics metadata.
function FooterLink({ href, label, external = false }: { href: string; label: string; external?: boolean }) {
  if (external) {
    return (
      <a
        href={href}
        onClick={() => trackEvent("navigation_clicked", { label, location: "footer" })}
        rel="noreferrer"
        target="_blank"
      >
        {label}
      </a>
    );
  }

  return (
    <Link href={href} onClick={() => trackEvent("navigation_clicked", { label, location: "footer" })}>
      {label}
    </Link>
  );
}

/**
 * Renders the shared marketing-site header and sticky navigation state.
 */
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
          Tether
        </Link>
        <div className="nav-links">
          <details className="nav-solutions">
            <summary>Solutions</summary>
            <div className="nav-menu">
              <Link href="/#features" onClick={() => trackEvent("navigation_clicked", { label: "Founders", location: "header_solutions" })}>
                <span>Founders</span>
                <small>Show proof before the buyer asks.</small>
              </Link>
              <Link href="/#demo" onClick={() => trackEvent("navigation_clicked", { label: "Engineers", location: "header_solutions" })}>
                <span>Engineers</span>
                <small>Replay the exact node that broke.</small>
              </Link>
              <Link href="/security" onClick={() => trackEvent("navigation_clicked", { label: "Security", location: "header_solutions" })}>
                <span>Security</span>
                <small>Keep traces local and inspectable.</small>
              </Link>
            </div>
          </details>
          <Link href="/#demo" onClick={() => trackEvent("navigation_clicked", { label: "Demo", location: "header" })}>
            Demo
          </Link>
          <Link href="/docs" onClick={() => trackEvent("navigation_clicked", { label: "Docs", location: "header" })}>
            Docs
          </Link>
          <Link href="/#how" onClick={() => trackEvent("navigation_clicked", { label: "Setup", location: "header" })}>
            Setup
          </Link>
          <Link href="/security" onClick={() => trackEvent("navigation_clicked", { label: "Security", location: "header" })}>
            Security
          </Link>
          <Link href="/#faq" onClick={() => trackEvent("navigation_clicked", { label: "FAQ", location: "header" })}>
            FAQ
          </Link>
        </div>
        <div className="nav-actions">
          <Link
            className="nav-cta"
            href="/#download"
            onClick={() => trackEvent("cta_clicked", { button_text: "Download", location: "header" })}
          >
            Download
          </Link>
        </div>
      </div>
    </nav>
  );
}

/**
 * Renders the shared marketing-site footer and grouped footer links.
 */
export function SiteFooter() {
  return (
    <footer className="footer wrap">
      <div className="foot-grid">
        <div className="foot-brand">
          <Link className="brand" href="/">
            <span className="logo">
              <LogoMark />
            </span>
            Tether
          </Link>
          <p>
            Local-first trace debugging, replay, and mocking for LLM agents. Built for teams that need proof
            without sending prompts to another cloud.
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
        <span>&copy; 2026 Tether - Crafted for the Mac</span>
        <span>
          <Icon className="ic" name="arrow-right" strokeWidth={1.7} /> All systems local
        </span>
      </div>
    </footer>
  );
}
