import path from "node:path";
import { NextRequest } from "next/server";
import { Resend } from "resend";
import { logError } from "@/lib/server-diagnostics";
import { handleFeedbackSubmission } from "@/lib/public-submission-handlers";

export const runtime = "nodejs";

export const dynamic = "force-dynamic";

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
    logError("feedback_email_failed", err, { source });
  });
}

export async function POST(request: NextRequest) {
  return handleFeedbackSubmission(request, feedbackFilePath(), sendFeedbackEmail);
}
