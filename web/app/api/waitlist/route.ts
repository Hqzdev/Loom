import { mkdir, appendFile } from "node:fs/promises";
import path from "node:path";
import { NextRequest, NextResponse } from "next/server";
import { Resend } from "resend";

/** Forces the waitlist endpoint onto the Node.js runtime for filesystem and email access. */
export const runtime = "nodejs";

/** Prevents static caching so every waitlist submission is processed live. */
export const dynamic = "force-dynamic";

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Returns the append-only waitlist storage path, overridable for deployments.
function waitlistFilePath() {
  return (
    process.env.Tether_WAITLIST_FILE ??
    path.join(process.cwd(), "data", "waitlist.ndjson")
  );
}

// Normalizes JSON and form submissions into the same waitlist payload shape.
async function payloadFromRequest(request: NextRequest) {
  const contentType = request.headers.get("content-type") ?? "";

  if (contentType.includes("application/json")) {
    const json = await request.json();
    return {
      email: String(json.email ?? ""),
      name: String(json.name ?? ""),
      reason: String(json.reason ?? ""),
      source: String(json.source ?? "site"),
      company: String(json.company ?? ""),
    };
  }

  const formData = await request.formData();
  return {
    email: String(formData.get("email") ?? ""),
    name: String(formData.get("name") ?? ""),
    reason: String(formData.get("reason") ?? ""),
    source: String(formData.get("source") ?? "site"),
    company: String(formData.get("company") ?? ""),
  };
}

// Sends the notification only when Resend is configured, keeping local builds secret-free.
function sendWaitlistEmail({
  email,
  name,
  reason,
  source,
}: {
  email: string;
  name: string;
  reason: string;
  source: string;
}) {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    return;
  }

  new Resend(apiKey).emails.send({
    from: "onboarding@resend.dev",
    to: "wkeyqwert@gmail.com",
    subject: `Новая заявка в вейтлист от ${name || email}`,
    html: `
      <p><strong>Имя:</strong> ${name || "не указано"}</p>
      <p><strong>Email:</strong> ${email}</p>
      <p><strong>Причина:</strong> ${reason || "не указана"}</p>
      <p><strong>Source:</strong> ${source}</p>
      <p><strong>Время:</strong> ${new Date().toISOString()}</p>
    `,
  }).catch((err: unknown) => {
    console.error("Resend error:", err);
  });
}

/**
 * Accepts a waitlist signup, stores it locally, and mirrors the signup to email.
 */
export async function POST(request: NextRequest) {
  try {
    const payload = await payloadFromRequest(request);
    const email = payload.email.trim().toLowerCase();
    const name = payload.name.trim();
    const reason = payload.reason.trim();
    const source = payload.source.trim() || "site";

    // The hidden company field is a honeypot; successful no-op responses avoid bot feedback.
    if (payload.company.trim()) {
      return NextResponse.json({ ok: true });
    }

    if (!EMAIL_PATTERN.test(email)) {
      return NextResponse.json(
        { ok: false, error: "Enter a valid email address." },
        { status: 400 },
      );
    }

    const filePath = waitlistFilePath();
    await mkdir(path.dirname(filePath), { recursive: true });
    await appendFile(
      filePath,
      JSON.stringify({
        email,
        name,
        reason,
        source,
        createdAt: new Date().toISOString(),
        userAgent: request.headers.get("user-agent") ?? "",
      }) + "\n",
      "utf8",
    );

    sendWaitlistEmail({ email, name, reason, source });

    return NextResponse.json({ ok: true });
  } catch (err) {
    console.error("Waitlist error:", err);
    return NextResponse.json({ ok: false, error: "Something went wrong." }, { status: 500 });
  }
}
