const test = require("node:test");
const assert = require("node:assert/strict");
const {
  productAmount,
  projectWallet,
  evaluateEvidence,
  normalizeProductPurchase,
  LEDGER_EVENTS,
  EVIDENCE_OUTCOMES,
} = require("../credit_ledger");

test("Credit products have fixed server quantities", () => {
  assert.equal(productAmount("credits_50"), 50);
  assert.equal(productAmount("credits_100"), 100);
  assert.equal(productAmount("premium"), 0);
});

test("wallet projection moves available and locked Credits by event", () => {
  let wallet = {availableCredits: 50, lockedCredits: 0};
  wallet = projectWallet(wallet, LEDGER_EVENTS.LOCK, 20);
  assert.equal(wallet.available_credits, 30);
  assert.equal(wallet.locked_credits, 20);
  wallet = projectWallet(wallet, LEDGER_EVENTS.RELEASE, 20);
  assert.equal(wallet.available_credits, 50);
  assert.equal(wallet.locked_credits, 0);
  wallet = projectWallet(wallet, LEDGER_EVENTS.LOCK, 20);
  wallet = projectWallet(wallet, LEDGER_EVENTS.FORFEITURE, 20);
  assert.equal(wallet.available_credits, 30);
  assert.equal(wallet.locked_credits, 0);
});

test("evidence waits for the reconciliation window and fails safe", () => {
  const end = 1_000_000;
  assert.equal(evaluateEvidence([], end + 23 * 60 * 60 * 1000, end), null);
  assert.equal(
      evaluateEvidence([], end + 24 * 60 * 60 * 1000, end),
      EVIDENCE_OUTCOMES.UNVERIFIABLE,
  );
  assert.equal(
      evaluateEvidence([{eventType: "RULE_VIOLATION_OBSERVED"}], end + 24 * 60 * 60 * 1000, end),
      EVIDENCE_OUTCOMES.FAILURE,
  );
  assert.equal(
      evaluateEvidence([{eventType: "CHECKPOINT_COMPLIANT", monitoringHealthy: true}], end + 24 * 60 * 60 * 1000, end),
      EVIDENCE_OUTCOMES.SUCCESS,
  );
});

test("ProductPurchaseV2 normalization never treats pending as purchased", () => {
  const pending = normalizeProductPurchase({
    purchaseStateContext: {purchaseState: "PURCHASE_STATE_PENDING"},
    productLineItem: [{productId: "credits_50"}],
  });
  assert.equal(pending.amount, 50);
  assert.equal(pending.purchased, false);
  assert.equal(pending.pending, true);
});
