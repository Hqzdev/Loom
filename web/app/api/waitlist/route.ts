import { mkdir, appendFile } from "node:fs/promises";
import path from "node:path";
import { NextRequest, NextResponse } from "next/server";
import { Resend } from "resend";

const resend = new Resend(process.env.RESEND_API_KEY);

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function waitlistFilePath() {
  return (
    process.env.LOOM_WAITLIST_FILE ??
    path.join(process.cwd(), "data", "waitlist.ndjson")
  );
}

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

export async function POST(request: NextRequest) {
  const payload = await payloadFromRequest(request);
  const email = payload.email.trim().toLowerCase();
  const name = payload.name.trim();
  const reason = payload.reason.trim();
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

  await resend.emails.send({
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
  });

  return NextResponse.json({ ok: true });
}
