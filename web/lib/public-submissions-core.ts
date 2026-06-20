const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export type SubmissionPayload = {
  email: string;
  context: string;
  feedback: string;
  name: string;
  reason: string;
  source: string;
  company: string;
};

export class SubmissionValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "SubmissionValidationError";
  }
}

export function feedbackSubmissionFromPayload(payload: SubmissionPayload) {
  const email = emailField(payload.email);
  const context = textField(payload.context, 2000);
  const feedback = requiredTextField(payload.feedback, 10, 5000, "Write at least 10 characters of feedback.");
  const source = textField(payload.source, 80) || "site";
  const company = textField(payload.company, 200);

  return { email, context, feedback, source, company };
}

export function waitlistSubmissionFromPayload(payload: SubmissionPayload) {
  const email = emailField(payload.email);
  const name = textField(payload.name, 120);
  const reason = textField(payload.reason, 1000);
  const source = textField(payload.source, 80) || "site";
  const company = textField(payload.company, 200);

  return { email, name, reason, source, company };
}

function emailField(value: string) {
  const email = value.trim().toLowerCase();
  if (!EMAIL_PATTERN.test(email)) {
    throw new SubmissionValidationError("Enter a valid email address.");
  }
  return email;
}

function requiredTextField(value: string, min: number, max: number, message: string) {
  const text = textField(value, max);
  if (text.length < min) {
    throw new SubmissionValidationError(message);
  }
  return text;
}

function textField(value: string, max: number) {
  const text = value.trim();
  if (text.length > max) {
    throw new SubmissionValidationError(`Use ${max} characters or fewer.`);
  }
  return text;
}
