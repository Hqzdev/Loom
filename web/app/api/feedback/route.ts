import { appendFile, mkdir } from "node:fs/promises";
import path from "node:path";
import { NextRequest, NextResponse } from "next/server";
import { Resend } from "resend";

/** Forces the feedback endpoint onto the Node.js runtime for filesystem and email access. */
export const runtime = "nodejs";

/** Prevents static caching so every feedback submission is processed live. */
export const dynamic = "force-dynamic";

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Returns the append-only feedback storage path, overridable for deployments.
function feedbackFilePath() {
  return (
    process.env.TETHER_FEEDBACK_FILE ??
    path.join(process.cwd(), "data", "feedback.ndjson")
  );
}

// Escapes feedback before inserting it into the notification email body.
function escapeHtml(value: string) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

// Normalizes JSON and form submissions into the same feedback payload shape.
async function payloadFromRequest(request: NextRequest) {
  const contentType = request.headers.get("content-type") ?? "";

  if (contentType.includes("application/json")) {
    const json = await request.json();
    return {
      email: String(json.email ?? ""),
      context: String(json.context ?? ""),
      feedback: String(json.feedback ?? ""),
      source: String(json.source ?? "site"),
      company: String(json.company ?? ""),
    };
  }

  const formData = await request.formData();
  return {
    email: String(formData.get("email") ?? ""),
    context: String(formData.get("context") ?? ""),
    feedback: String(formData.get("feedback") ?? ""),
    source: String(formData.get("source") ?? "site"),
    company: String(formData.get("company") ?? ""),
  };
}

// Sends the notification only when Resend is configured, keeping local builds secret-free.
function sendFeedbackEmail({
  email,
  context,
  feedback,
  source,
  createdAt,
}: {
  email: string;
  context: string;
  feedback: string;
  source: string;
  createdAt: string;
}) {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    return;
  }

  new Resend(apiKey).emails.send({
    from: "onboarding@resend.dev",
    to: process.env.TETHER_FEEDBACK_TO ?? "wkeyqwert@gmail.com",
    subject: `Tether feedback from ${email}`,
    html: `
      <p><strong>Email:</strong> ${escapeHtml(email)}</p>
      <p><strong>Context:</strong> ${escapeHtml(context || "not provided")}</p>
      <p><strong>Feedback:</strong></p>
      <p>${escapeHtml(feedback).replace(/\n/g, "<br />")}</p>
      <p><strong>Source:</strong> ${escapeHtml(source)}</p>
      <p><strong>Time:</strong> ${createdAt}</p>
    `,
  }).catch((err: unknown) => {
    console.error("Feedback email error:", err);
  });
}

/**
 * Accepts product feedback, stores it locally, and sends an email notification.
 */
export async function POST(request: NextRequest) {
  try {
    const payload = await payloadFromRequest(request);
    const email = payload.email.trim().toLowerCase();
    const context = payload.context.trim();
    const feedback = payload.feedback.trim();
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

    if (feedback.length < 10) {
      return NextResponse.json(
        { ok: false, error: "Write at least 10 characters of feedback." },
        { status: 400 },
      );
    }

    const createdAt = new Date().toISOString();
    const filePath = feedbackFilePath();
    await mkdir(path.dirname(filePath), { recursive: true });
    await appendFile(
      filePath,
      JSON.stringify({
        email,
        context,
        feedback,
        source,
        createdAt,
        userAgent: request.headers.get("user-agent") ?? "",
      }) + "\n",
      "utf8",
    );

    sendFeedbackEmail({ email, context, feedback, source, createdAt });

    return NextResponse.json({ ok: true });
  } catch (err) {
    console.error("Feedback error:", err);
    return NextResponse.json({ ok: false, error: "Something went wrong." }, { status: 500 });
  }
}
