import assert from "node:assert/strict";
import { mkdtemp, readFile, stat } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test, { after, before } from "node:test";
import { NextRequest } from "next/server";
import { handleFeedbackSubmission, handleWaitlistSubmission } from "./public-submission-handlers";

const originalInfo = console.info;

before(() => {
  console.info = () => undefined;
});

after(() => {
  console.info = originalInfo;
});

test("feedback route handler accepts JSON, writes one row, and calls email callback", async () => {
  const filePath = await tempSubmissionPath("feedback");
  const sent: unknown[] = [];
  const response = await handleFeedbackSubmission(
    jsonRequest({
      email: " User@Example.com ",
      context: " settings ",
      feedback: " this feedback is long enough ",
      source: "docs",
    }),
    filePath,
    (submission) => sent.push(submission),
  );

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { ok: true });
  assert.equal(sent.length, 1);

  const rows = await readRows(filePath);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].email, "user@example.com");
  assert.equal(rows[0].context, "settings");
  assert.equal(rows[0].feedback, "this feedback is long enough");
  assert.equal(rows[0].source, "docs");
  assert.equal(rows[0].userAgent, "node-test");
});

test("feedback route handler rejects invalid JSON submissions before side effects", async () => {
  const filePath = await tempSubmissionPath("feedback-invalid");
  const sent: unknown[] = [];
  const response = await handleFeedbackSubmission(
    jsonRequest({ email: "bad", feedback: "valid length feedback" }),
    filePath,
    (submission) => sent.push(submission),
  );

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { ok: false, error: "Enter a valid email address." });
  assert.equal(sent.length, 0);
  await assert.rejects(() => stat(filePath));
});

test("waitlist route handler accepts form submissions", async () => {
  const filePath = await tempSubmissionPath("waitlist");
  const sent: unknown[] = [];
  const body = new URLSearchParams({
    email: " Ada@Example.com ",
    name: " Ada ",
    reason: " local debugging ",
    source: "site",
  });

  const response = await handleWaitlistSubmission(
    new NextRequest("https://tether.test/api/waitlist", {
      method: "POST",
      headers: {
        "content-type": "application/x-www-form-urlencoded",
        "user-agent": "node-test",
      },
      body,
    }),
    filePath,
    (submission) => sent.push(submission),
  );

  assert.equal(response.status, 200);
  assert.equal(sent.length, 1);

  const rows = await readRows(filePath);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].email, "ada@example.com");
  assert.equal(rows[0].name, "Ada");
  assert.equal(rows[0].reason, "local debugging");
});

test("waitlist honeypot submissions return ok without file or email side effects", async () => {
  const filePath = await tempSubmissionPath("waitlist-honeypot");
  const sent: unknown[] = [];
  const response = await handleWaitlistSubmission(
    jsonRequest({
      email: "user@example.com",
      company: "bot corp",
    }),
    filePath,
    (submission) => sent.push(submission),
  );

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { ok: true });
  assert.equal(sent.length, 0);
  await assert.rejects(() => stat(filePath));
});

function jsonRequest(body: Record<string, string>) {
  return new NextRequest("https://tether.test/api/submit", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "user-agent": "node-test",
    },
    body: JSON.stringify(body),
  });
}

async function tempSubmissionPath(prefix: string) {
  const directory = await mkdtemp(path.join(os.tmpdir(), `tether-${prefix}-`));
  return path.join(directory, "submissions.ndjson");
}

async function readRows(filePath: string) {
  const content = await readFile(filePath, "utf8");
  return content.trim().split("\n").map((line) => JSON.parse(line));
}
