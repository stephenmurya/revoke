const assert = require("node:assert/strict");
const {test} = require("node:test");

const {
  PREMIUM_PRODUCT_ID,
  expectedObfuscatedAccountId,
  normalizePlaySubscription,
  sequentialPremiumUntil,
  decodeRtdnMessage,
  isTerminalSubscriptionNotification,
} = require("../premium_billing");

test("Premium Play parsing accepts only the prepaid Revoke base plans", () => {
  const normalized = normalizePlaySubscription({
    subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
    acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
    externalAccountIdentifiers: {
      obfuscatedExternalAccountId: expectedObfuscatedAccountId("alice"),
    },
    lineItems: [
      {
        productId: "unrelated",
        expiryTime: "2099-01-01T00:00:00Z",
        offerDetails: {basePlanId: "weekly"},
      },
      {
        productId: PREMIUM_PRODUCT_ID,
        expiryTime: "2099-01-01T00:00:00Z",
        startTime: "2026-09-05T00:00:00Z",
        latestSuccessfulOrderId: "GPA.123",
        prepaidPlan: {},
        offerDetails: {basePlanId: "prepaid-30d"},
      },
    ],
  });

  assert.equal(normalized.productId, PREMIUM_PRODUCT_ID);
  assert.equal(normalized.basePlanId, "prepaid-30d");
  assert.equal(normalized.isPrepaid, true);
  assert.equal(normalized.active, true);
});

test("Premium grant settlement is deterministic and sequential", () => {
  const until = sequentialPremiumUntil([
    {id: "b", status: "active", startTimeMs: 1000, durationMs: 30},
    {id: "a", status: "active", startTimeMs: 1000, durationMs: 365},
    {id: "ignored", status: "revoked", startTimeMs: 1000, durationMs: 1000},
  ], 1000);
  assert.equal(until, 1000 + 365 + 30);
});

test("RTDN parsing treats the Pub/Sub message as a requery signal", () => {
  const notification = decodeRtdnMessage({
    id: "message-1",
    data: {
      message: {
        messageId: "message-1",
        json: {
          packageName: "com.crescence.revoke",
          eventTimeMillis: "1234",
          subscriptionNotification: {
            notificationType: 3,
            purchaseToken: "token",
          },
        },
      },
    },
  });
  assert.deepEqual(notification, {
    messageId: "message-1",
    packageName: "com.crescence.revoke",
    eventTimeMillis: 1234,
    notificationType: 3,
    purchaseToken: "token",
  });
  assert.equal(isTerminalSubscriptionNotification(3), true);
  assert.equal(isTerminalSubscriptionNotification(4), false);
});
