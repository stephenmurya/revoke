const assert = require("node:assert/strict");
const {test} = require("node:test");

require("../index.js");
const {__testables} = require("../index.js");

test("Circle quorum is a strict majority of the fixed voter snapshot", () => {
  assert.equal(__testables.circleMajority(1), 1);
  assert.equal(__testables.circleMajority(2), 2);
  assert.equal(__testables.circleMajority(3), 2);
  assert.equal(__testables.circleMajority(4), 3);
  assert.equal(__testables.circleMajority(0), 0);
});

test("override authority rejects implicit or unknown decision makers", () => {
  assert.equal(__testables.normalizeV2Authority("self"), "self");
  assert.equal(__testables.normalizeV2Authority("ai"), "ai");
  assert.equal(__testables.normalizeV2Authority("circle"), "circle");
  assert.equal(__testables.normalizeV2Authority("system_warden"), "");
  assert.equal(__testables.normalizeV2Authority(""), "");
});

test("Circle permission sanitizer drops unsupported fields", () => {
  const permissions = __testables.sanitizeCirclePermissions({
    viewCommitmentSummary: true,
    voteOnOverrideRequests: true,
    email: true,
  }, "custom");
  assert.deepEqual(Object.keys(permissions).sort(), [
    "participateInOverrideDiscussion",
    "receiveAccountabilityNotifications",
    "receiveOverrideRequests",
    "viewCommitmentSummary",
    "viewOverrideHistory",
    "voteOnOverrideRequests",
  ].sort());
  assert.equal(permissions.email, undefined);
});
