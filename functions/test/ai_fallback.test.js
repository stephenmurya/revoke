const assert = require("node:assert/strict");
const {test} = require("node:test");

require("../index.js");

const {__testables} = require("../index.js");

test("sanitizeReasonText strips obvious PII before AI context", () => {
  const raw = [
    "I am Stephen, email stephen@example.com, call +1 (555) 123-4567.",
    "Avatar https://cdn.example.com/avatar.png token abcdefghijklmnopqrstuvwxyz123456.",
    "Ask @squadmate to approve.",
  ].join(" ");

  const sanitized = __testables.sanitizeReasonText(raw);

  assert.ok(!sanitized.includes("stephen@example.com"));
  assert.ok(!sanitized.includes("555"));
  assert.ok(!sanitized.includes("https://cdn.example.com/avatar.png"));
  assert.ok(!sanitized.includes("abcdefghijklmnopqrstuvwxyz123456"));
  assert.ok(!sanitized.includes("@squadmate"));
});

test("parseAiDecision clamps approval minutes to the v1.3 maximum", () => {
  const decision = __testables.parseAiDecision(JSON.stringify({
    decision: "approve",
    minutes: 90,
    rationale: "Brief proportionate exception.",
  }));

  assert.deepEqual(decision, {
    decision: "approve",
    minutes: 15,
    rationale: "Brief proportionate exception.",
  });
});

test("extractJsonObjectString strips markdown wrappers and surrounding prose", () => {
  const raw = [
    "Here is the decision:",
    "```json",
    "{\"decision\":\"approve\",\"minutes\":8,\"rationale\":\"short\"}",
    "```",
    "Done.",
  ].join("\n");

  assert.equal(
      __testables.extractJsonObjectString(raw),
      "{\"decision\":\"approve\",\"minutes\":8,\"rationale\":\"short\"}",
  );
});

test("parseAiDecision rejects malformed or incomplete approvals", () => {
  assert.equal(
      __testables.parseAiDecision("not json").decision,
      "reject",
  );
  assert.deepEqual(
      __testables.parseAiDecision({decision: "approve", rationale: "missing"}),
      {
        decision: "reject",
        minutes: 0,
        rationale: "AI approval omitted valid minutes.",
      },
  );
});
