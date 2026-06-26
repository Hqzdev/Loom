import path from "node:path";
import { NextRequest } from "next/server";
import { Resend } from "resend";
import { logError } from "@/lib/server-diagnostics";
import { handleWaitlistSubmission } from "@/lib/public-submission-handlers";

export const runtime = "nodejs";

export const dynamic = "force-dynamic";

function waitlistFilePath() {
  return (
    process.env.TETHER_WAITLIST_FILE ??
    path.join(process.cwd(), "data", "waitlist.ndjson")
  );
}

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
    logError("waitlist_email_failed", err, { source });
  });
}

export async function POST(request: NextRequest) {
  return handleWaitlistSubmission(request, waitlistFilePath(), sendWaitlistEmail);
}
