import { appendFile, mkdir } from "node:fs/promises";
import path from "node:path";
import { NextRequest, NextResponse } from "next/server";
import { Resend } from "resend";

const resend = new Resend(process.env.RESEND_API_KEY);

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function feedbackFilePath() {
  return (
    process.env.TETHER_FEEDBACK_FILE ??
    path.join(process.cwd(), "data", "feedback.ndjson")
  );
}

function escapeHtml(value: string) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

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

export async function POST(request: NextRequest) {
  try {
    const payload = await payloadFromRequest(request);
    const email = payload.email.trim().toLowerCase();
    const context = payload.context.trim();
    const feedback = payload.feedback.trim();
    const source = payload.source.trim() || "site";

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

    resend.emails.send({
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

    return NextResponse.json({ ok: true });
  } catch (err) {
    console.error("Feedback error:", err);
    return NextResponse.json({ ok: false, error: "Something went wrong." }, { status: 500 });
  }
}
