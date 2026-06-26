import { appendFile, mkdir } from "node:fs/promises";
import path from "node:path";
import { NextRequest, NextResponse } from "next/server";
import { logError, logInfo } from "./server-diagnostics";
import {
  FeedbackSubmission,
  SubmissionValidationError,
  WaitlistSubmission,
  feedbackSubmissionFromRequest,
  waitlistSubmissionFromRequest,
} from "./public-submissions";

type FeedbackEmailSender = (submission: FeedbackSubmission & { createdAt: string }) => void;
type WaitlistEmailSender = (submission: WaitlistSubmission) => void;

export async function handleFeedbackSubmission(
  request: NextRequest,
  filePath: string,
  sendEmail: FeedbackEmailSender,
) {
  try {
    const payload = await feedbackSubmissionFromRequest(request);
    const { email, context, feedback, source } = payload;

    if (payload.company.trim()) {
      logInfo("feedback_honeypot_ignored", { source });
      return NextResponse.json({ ok: true });
    }

    const createdAt = new Date().toISOString();
    await writeSubmission(filePath, {
      email,
      context,
      feedback,
      source,
      createdAt,
      userAgent: request.headers.get("user-agent") ?? "",
    });

    sendEmail({ email, context, feedback, source, company: payload.company, createdAt });
    logInfo("feedback_saved", { source });

    return NextResponse.json({ ok: true });
  } catch (err) {
    if (err instanceof SubmissionValidationError) {
      return NextResponse.json({ ok: false, error: err.message }, { status: 400 });
    }

    logError("feedback_failed", err);
    return NextResponse.json({ ok: false, error: "Something went wrong." }, { status: 500 });
  }
}

export async function handleWaitlistSubmission(
  request: NextRequest,
  filePath: string,
  sendEmail: WaitlistEmailSender,
) {
  try {
    const payload = await waitlistSubmissionFromRequest(request);
    const { email, name, reason, source } = payload;

    if (payload.company.trim()) {
      logInfo("waitlist_honeypot_ignored", { source });
      return NextResponse.json({ ok: true });
    }

    await writeSubmission(filePath, {
      email,
      name,
      reason,
      source,
      createdAt: new Date().toISOString(),
      userAgent: request.headers.get("user-agent") ?? "",
    });

    sendEmail({ email, name, reason, source, company: payload.company });
    logInfo("waitlist_saved", { source });

    return NextResponse.json({ ok: true });
  } catch (err) {
    if (err instanceof SubmissionValidationError) {
      return NextResponse.json({ ok: false, error: err.message }, { status: 400 });
    }

    logError("waitlist_failed", err);
    return NextResponse.json({ ok: false, error: "Something went wrong." }, { status: 500 });
  }
}

async function writeSubmission(filePath: string, row: Record<string, string>) {
  await mkdir(path.dirname(filePath), { recursive: true });
  await appendFile(filePath, `${JSON.stringify(row)}\n`, "utf8");
}
