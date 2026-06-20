import assert from "node:assert/strict";
import test from "node:test";
import {
  SubmissionPayload,
  SubmissionValidationError,
  feedbackSubmissionFromPayload,
  waitlistSubmissionFromPayload,
} from "./public-submissions-core.js";

const basePayload: SubmissionPayload = {
  email: " User@Example.COM ",
  context: " settings ",
  feedback: " this is useful feedback ",
  name: " Ada ",
  reason: " debugging agents ",
  source: "",
  company: "",
};

test("feedback submissions normalize email, trim fields, and default source", () => {
  assert.deepEqual(feedbackSubmissionFromPayload(basePayload), {
    email: "user@example.com",
    context: "settings",
    feedback: "this is useful feedback",
    source: "site",
    company: "",
  });
});

test("waitlist submissions normalize email, trim fields, and keep source", () => {
  assert.deepEqual(waitlistSubmissionFromPayload({ ...basePayload, source: "docs" }), {
    email: "user@example.com",
    name: "Ada",
    reason: "debugging agents",
    source: "docs",
    company: "",
  });
});

test("invalid emails are rejected", () => {
  assert.throws(
    () => feedbackSubmissionFromPayload({ ...basePayload, email: "not-an-email" }),
    SubmissionValidationError,
  );
});

test("short feedback is rejected", () => {
  assert.throws(
    () => feedbackSubmissionFromPayload({ ...basePayload, feedback: "short" }),
    /Write at least 10 characters/,
  );
});

test("oversized source is rejected", () => {
  assert.throws(
    () => waitlistSubmissionFromPayload({ ...basePayload, source: "x".repeat(81) }),
    /Use 80 characters or fewer/,
  );
});
