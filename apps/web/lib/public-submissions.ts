import { NextRequest } from "next/server";
import {
  SubmissionValidationError,
  feedbackSubmissionFromPayload,
  waitlistSubmissionFromPayload,
} from "./public-submissions-core";

export type FeedbackSubmission = {
  email: string;
  context: string;
  feedback: string;
  source: string;
  company: string;
};

export type WaitlistSubmission = {
  email: string;
  name: string;
  reason: string;
  source: string;
  company: string;
};

export { SubmissionValidationError };

export async function feedbackSubmissionFromRequest(request: NextRequest) {
  const payload = await payloadFromRequest(request);
  return feedbackSubmissionFromPayload(payload);
}

export async function waitlistSubmissionFromRequest(request: NextRequest) {
  const payload = await payloadFromRequest(request);
  return waitlistSubmissionFromPayload(payload);
}

async function payloadFromRequest(request: NextRequest) {
  const contentType = request.headers.get("content-type") ?? "";

  if (contentType.includes("application/json")) {
    const json = await request.json();
    return {
      email: String(json.email ?? ""),
      context: String(json.context ?? ""),
      feedback: String(json.feedback ?? ""),
      name: String(json.name ?? ""),
      reason: String(json.reason ?? ""),
      source: String(json.source ?? "site"),
      company: String(json.company ?? ""),
    };
  }

  const formData = await request.formData();
  return {
    email: String(formData.get("email") ?? ""),
    context: String(formData.get("context") ?? ""),
    feedback: String(formData.get("feedback") ?? ""),
    name: String(formData.get("name") ?? ""),
    reason: String(formData.get("reason") ?? ""),
    source: String(formData.get("source") ?? "site"),
    company: String(formData.get("company") ?? ""),
  };
}
