const crypto = require("node:crypto");
const {google} = require("googleapis");

const CREDIT_PRODUCTS = Object.freeze({
  credits_50: 50,
  credits_100: 100,
});
const CREDIT_PRODUCT_IDS = new Set(Object.keys(CREDIT_PRODUCTS));
const CREDIT_DISCLOSURE_VERSION = "credit-purchase-v1";
const CREDIT_BACKING_TERMS_VERSION = "credit-backing-v1";
const RESOLUTION_WINDOW_HOURS = 24;
const SECONDS_PER_CREDIT = 25920;
const REDEEM_AMOUNTS = Object.freeze([10, 50, 100]);
const LOCK_AMOUNTS = Object.freeze([10, 20, 50, 100]);
const PACKAGE_NAME = "com.crescence.revoke";

const LEDGER_EVENTS = Object.freeze({
  PURCHASE: "CREDIT_PURCHASE",
  LOCK: "CREDIT_LOCK",
  RELEASE: "CREDIT_RELEASE",
  FORFEITURE: "CREDIT_FORFEITURE",
  REDEMPTION: "PREMIUM_REDEMPTION",
  REVERSAL: "PURCHASE_REVERSAL",
});

const EVIDENCE_OUTCOMES = Object.freeze({
  SUCCESS: "SUCCESS_VERIFIED",
  FAILURE: "FAILURE_VERIFIED",
  UNVERIFIABLE: "UNVERIFIABLE",
  CANCELLED: "CANCELLED_PRE_START",
});

// Evidence submitted through a callable is client-originated. It is useful
// for reconciliation and diagnostics, but it is not sufficient by itself to
// create a financial outcome until a server-verifiable evidence path marks it
// trusted. This prevents a forged client success/failure event from moving
// the canonical wallet.
const CLIENT_EVIDENCE_EVENT_TYPES = new Set([
  "FOREGROUND_OBSERVED",
  "RULE_VIOLATION_OBSERVED",
  "POSITIVE_FAILURE",
  "CHECKPOINT_COMPLIANT",
  "MONITORING_HEALTH",
  "SERVICE_HEALTH",
  "PERMISSION_LOST",
  "BOOT",
  "LOCAL_FAILURE_SIGNAL",
]);

function normalizeString(value) {
  return (value || "").toString().trim();
}

function timestampToMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  const number = Number(value);
  return Number.isFinite(number) ? Math.floor(number) : 0;
}

function hashToken(token) {
  return crypto.createHash("sha256").update(normalizeString(token)).digest("hex");
}

function productAmount(productId) {
  return CREDIT_PRODUCTS[normalizeString(productId)] || 0;
}

function projectWallet(wallet, eventType, amount) {
  const current = wallet && typeof wallet === "object" ? wallet : {};
  let available = Math.max(0, Number(current.availableCredits ?? current.available_credits) || 0);
  let locked = Math.max(0, Number(current.lockedCredits ?? current.locked_credits) || 0);
  const value = Math.max(0, Number(amount) || 0);
  switch (eventType) {
    case LEDGER_EVENTS.PURCHASE:
      available += value;
      break;
    case LEDGER_EVENTS.LOCK:
      available -= value;
      locked += value;
      break;
    case LEDGER_EVENTS.RELEASE:
      locked -= value;
      available += value;
      break;
    case LEDGER_EVENTS.FORFEITURE:
      locked -= value;
      break;
    case LEDGER_EVENTS.REDEMPTION:
      available -= value;
      break;
    case LEDGER_EVENTS.REVERSAL:
      available -= value;
      break;
    default:
      break;
  }
  const nextAvailable = Math.max(0, available);
  const nextLocked = Math.max(0, locked);
  return {
    available_credits: nextAvailable,
    locked_credits: nextLocked,
    // Transitional aliases keep existing client/cache readers safe while the
    // canonical backend fields remain snake_case.
    availableCredits: nextAvailable,
    lockedCredits: nextLocked,
  };
}

function availableCredits(wallet) {
  return Math.max(0, Number(wallet?.availableCredits ?? wallet?.available_credits) || 0);
}

function purchaseState(raw) {
  const value = normalizeString(
      raw?.purchaseStateContext?.purchaseState || raw?.purchaseState,
  ).toUpperCase();
  return value;
}

function normalizeProductPurchase(raw) {
  const source = raw && typeof raw === "object" ? raw : {};
  const items = Array.isArray(source.productLineItem) ? source.productLineItem : [];
  const item = items[0] || {};
  const offer = item.productOfferDetails && typeof item.productOfferDetails === "object" ?
    item.productOfferDetails : {};
  const productId = normalizeString(item.productId || offer.productId);
  const state = purchaseState(source);
  return {
    productId,
    amount: productAmount(productId),
    state,
    purchased: state === "PURCHASE_STATE_PURCHASED" || state === "PURCHASED",
    pending: state === "PURCHASE_STATE_PENDING" || state === "PENDING",
    acknowledgementState: normalizeString(source.acknowledgementState),
    orderId: normalizeString(source.orderId || source.orderID),
    obfuscatedExternalAccountId: normalizeString(source.obfuscatedExternalAccountId),
    purchaseCompletionTime: normalizeString(source.purchaseCompletionTime),
  };
}

function evaluateEvidence(evidence, nowMs, endAtMs, windowHours = RESOLUTION_WINDOW_HOURS) {
  if (nowMs < endAtMs + windowHours * 60 * 60 * 1000) return null;
  const rows = Array.isArray(evidence) ? evidence : [];
  if (rows.some((row) => row?.trusted === true &&
      (row?.eventType === "RULE_VIOLATION_OBSERVED" ||
       row?.eventType === "POSITIVE_FAILURE"))) return EVIDENCE_OUTCOMES.FAILURE;
  if (rows.some((row) => row?.trusted === true &&
      row?.eventType === "CHECKPOINT_COMPLIANT" &&
      row?.monitoringHealthy === true)) return EVIDENCE_OUTCOMES.SUCCESS;
  if (rows.some((row) => row?.eventType === "CANCELLED_PRE_START")) {
    return EVIDENCE_OUTCOMES.CANCELLED;
  }
  return EVIDENCE_OUTCOMES.UNVERIFIABLE;
}

function createCreditLedgerService({
  db,
  adminSdk,
  premiumBilling,
  now = () => Date.now(),
  publisherFactory,
  packageName = PACKAGE_NAME,
}) {
  if (!db) throw new Error("Firestore is required for Credit ledger.");
  const serverTimestamp = () => adminSdk.firestore.FieldValue.serverTimestamp();
  const timestamp = (ms) => adminSdk.firestore.Timestamp.fromMillis(Math.max(0, Number(ms) || 0));
  let publisherPromise;

  function userRef(uid) {
    return db.collection("users").doc(uid);
  }

  function walletRef(uid) {
    return userRef(uid).collection("creditWallet").doc("current");
  }

  async function getPublisher() {
    if (publisherFactory) return publisherFactory();
    publisherPromise ||= (async () => {
      const auth = new google.auth.GoogleAuth({
        scopes: ["https://www.googleapis.com/auth/androidpublisher"],
      });
      const client = await auth.getClient();
      return google.androidpublisher({version: "v3", auth: client});
    })();
    return publisherPromise;
  }

  async function recordDisclosure(uid, payload) {
    const flowId = normalizeString(payload?.purchaseFlowId);
    const productId = normalizeString(payload?.productId);
    const version = normalizeString(payload?.disclosureVersion);
    if (!/^[a-zA-Z0-9_-]{1,120}$/.test(flowId) || !CREDIT_PRODUCT_IDS.has(productId) ||
        version !== CREDIT_DISCLOSURE_VERSION) {
      const error = new Error("A current Credit purchase disclosure is required.");
      error.code = "failed-precondition";
      throw error;
    }
    await userRef(uid).collection("creditDisclosureAcceptances").doc(flowId).set({
      uid,
      productId,
      disclosureVersion: version,
      acceptedAt: serverTimestamp(),
      clientTimestampMs: Number(payload?.clientTimestampMs) || null,
    });
    return {success: true, purchaseFlowId: flowId, disclosureVersion: version};
  }

  async function appendLedgerEventTx(tx, uid, event) {
    const id = normalizeString(event.id) || `credit_${now()}_${crypto.randomUUID()}`;
    const ledgerRef = userRef(uid).collection("creditLedger").doc(id);
    const historyRef = userRef(uid).collection("creditHistory").doc(id);
    const data = {
      id,
      uid,
      type: event.type,
      amount: Math.max(0, Number(event.amount) || 0),
      availableDelta: Number(event.availableDelta) || 0,
      lockedDelta: Number(event.lockedDelta) || 0,
      createdAt: serverTimestamp(),
      sourceId: normalizeString(event.sourceId),
      purchaseTokenHash: normalizeString(event.purchaseTokenHash) || null,
      commitmentId: normalizeString(event.commitmentId) || null,
      backingId: normalizeString(event.backingId) || null,
      description: normalizeString(event.description),
    };
    tx.create(ledgerRef, data);
    tx.create(historyRef, {
      type: data.type,
      amount: data.availableDelta || data.lockedDelta || data.amount,
      createdAt: data.createdAt,
      description: data.description,
      sourceId: data.sourceId,
    });
    return {id, data};
  }

  async function verifyPurchase(uid, payload) {
    const token = normalizeString(payload?.purchaseToken);
    const requestedProductId = normalizeString(payload?.productId);
    const flowId = normalizeString(payload?.purchaseFlowId);
    if (!token || token.length > 4096 || !CREDIT_PRODUCT_IDS.has(requestedProductId)) {
      const error = new Error("A valid Credit purchase is required.");
      error.code = "invalid-argument";
      throw error;
    }
    const tokenHash = hashToken(token);
    const purchaseRef = userRef(uid).collection("creditPurchases").doc(tokenHash);
    const existing = await purchaseRef.get();
    if (!existing.exists) {
      if (!flowId) {
        const error = new Error("Credit purchase disclosure acceptance is required.");
        error.code = "failed-precondition";
        throw error;
      }
      const acceptance = await userRef(uid).collection("creditDisclosureAcceptances").doc(flowId).get();
      if (!acceptance.exists || acceptance.data()?.disclosureVersion !== CREDIT_DISCLOSURE_VERSION ||
          acceptance.data()?.productId !== requestedProductId) {
        const error = new Error("Credit purchase disclosure acceptance is required.");
        error.code = "failed-precondition";
        throw error;
      }
    }

    const publisher = await getPublisher();
    const response = await publisher.purchases.productsv2.getproductpurchasev2({
      packageName,
      token,
    });
    const purchase = normalizeProductPurchase(response?.data);
    if (purchase.productId !== requestedProductId || !purchase.amount) {
      const error = new Error("Google Play product is not an eligible Revoke Credit product.");
      error.code = "failed-precondition";
      throw error;
    }
    if (!purchase.purchased) {
      const error = new Error(purchase.pending ? "Credit purchase is still pending." : "Credit purchase was not completed.");
      error.code = "failed-precondition";
      throw error;
    }

    const accountHash = crypto.createHash("sha256").update(`revoke:account:${uid}`).digest("hex");
    if (purchase.obfuscatedExternalAccountId && purchase.obfuscatedExternalAccountId !== accountHash) {
      const error = new Error("Purchase account does not match the signed-in Revoke account.");
      error.code = "permission-denied";
      throw error;
    }

    let acknowledged = purchase.acknowledgementState === "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED" ||
      purchase.acknowledgementState === "ACKNOWLEDGED";
    if (!acknowledged) {
      await publisher.purchases.products.acknowledge({
        packageName,
        productId: requestedProductId,
        token,
        requestBody: {},
      });
      acknowledged = true;
    }

    const bindingRef = db.collection("creditPurchaseBindings").doc(tokenHash);
    const binding = await bindingRef.get();
    if (binding.exists && normalizeString(binding.data()?.uid) !== uid) {
      const error = new Error("Purchase token is already bound to another Revoke account.");
      error.code = "permission-denied";
      throw error;
    }

    let issued = false;
    let wallet;
    const eventId = `purchase_${tokenHash}`;
    await db.runTransaction(async (tx) => {
      const [purchaseSnap, walletSnap, bindingSnap] = await Promise.all([
        tx.get(purchaseRef),
        tx.get(walletRef(uid)),
        tx.get(bindingRef),
      ]);
      const boundUid = normalizeString(bindingSnap.data()?.uid);
      if (boundUid && boundUid !== uid) {
        const error = new Error("Purchase token is already bound to another Revoke account.");
        error.code = "permission-denied";
        throw error;
      }
      const prior = purchaseSnap.exists ? purchaseSnap.data() || {} : {};
      const currentWallet = purchaseSnap.exists ?
        (walletSnap.data() || {availableCredits: 0, lockedCredits: 0}) :
        (walletSnap.data() || {availableCredits: 0, lockedCredits: 0});
      if (!prior.issuedAt) {
        const next = projectWallet(currentWallet, LEDGER_EVENTS.PURCHASE, purchase.amount);
        const event = await appendLedgerEventTx(tx, uid, {
          id: eventId,
          type: LEDGER_EVENTS.PURCHASE,
          amount: purchase.amount,
          availableDelta: purchase.amount,
          sourceId: tokenHash,
          purchaseTokenHash: tokenHash,
          description: `${purchase.amount} Credits purchased`,
        });
        tx.set(walletRef(uid), {...next, updatedAt: serverTimestamp()}, {merge: true});
        tx.set(purchaseRef, {
          uid,
          productId: requestedProductId,
          creditAmount: purchase.amount,
          tokenHash,
          purchaseToken: token,
          orderId: purchase.orderId,
          acknowledgementState: purchase.acknowledgementState,
          purchaseState: purchase.state,
          issuedAt: serverTimestamp(),
          ledgerEventId: event.id,
          consumptionState: "PENDING",
          createdAt: prior.createdAt || serverTimestamp(),
          updatedAt: serverTimestamp(),
        }, {merge: true});
        issued = true;
        wallet = next;
      } else {
        wallet = currentWallet;
      }
      tx.set(bindingRef, {uid, tokenHash, updatedAt: serverTimestamp()}, {merge: true});
    });

    try {
      await publisher.purchases.products.consume({
        packageName,
        productId: requestedProductId,
        token,
      });
    } catch (error) {
      const message = String(error?.message || "").toLowerCase();
      if (!message.includes("already") && !message.includes("consum")) throw error;
    }
    await purchaseRef.set({consumptionState: "CONSUMED", consumedAt: serverTimestamp(), updatedAt: serverTimestamp()}, {merge: true});
    return {success: true, issued, wallet};
  }

  async function redeemCredits(uid, amount) {
    const credits = Math.floor(Number(amount) || 0);
    if (!REDEEM_AMOUNTS.includes(credits)) {
      const error = new Error("Choose an available Premium redemption amount.");
      error.code = "invalid-argument";
      throw error;
    }
    const id = `redemption_${uid}_${now()}_${crypto.randomUUID()}`;
    const result = await db.runTransaction(async (tx) => {
      const walletSnap = await tx.get(walletRef(uid));
      const current = walletSnap.data() || {availableCredits: 0, lockedCredits: 0};
      if (availableCredits(current) < credits) {
        const error = new Error("There are not enough available Credits.");
        error.code = "failed-precondition";
        throw error;
      }
      const next = projectWallet(current, LEDGER_EVENTS.REDEMPTION, credits);
      await appendLedgerEventTx(tx, uid, {
        id,
        type: LEDGER_EVENTS.REDEMPTION,
        amount: credits,
        availableDelta: -credits,
        sourceId: id,
        description: `${credits} Credits redeemed for Premium`,
      });
      const grantRef = userRef(uid).collection("premiumGrants").doc(`credit_${id}`);
      tx.create(grantRef, {
        uid,
        source: "CREDIT_REDEMPTION",
        redemptionId: id,
        durationMs: credits * SECONDS_PER_CREDIT * 1000,
        startTimeMs: now(),
        grantedAt: serverTimestamp(),
        status: "active",
      });
      tx.set(walletRef(uid), {...next, updatedAt: serverTimestamp()}, {merge: true});
      return next;
    });
    const entitlement = await premiumBilling.recomputeEntitlement(uid);
    return {success: true, wallet: result, premiumUntilMs: entitlement.premiumUntilMs};
  }

  async function createBacking(uid, payload) {
    const commitmentId = normalizeString(payload?.commitmentId);
    const amount = Math.floor(Number(payload?.amount) || 0);
    const gracePolicy = normalizeString(payload?.gracePolicy) || "STRICT";
    if (!commitmentId || !LOCK_AMOUNTS.includes(amount) || payload?.termsAcceptedVersion !== CREDIT_BACKING_TERMS_VERSION) {
      const error = new Error("A valid Credit-backed Commitment review is required.");
      error.code = "invalid-argument";
      throw error;
    }
    if (!payload?.monitoringHealth?.accessibility || !payload?.monitoringHealth?.usageStats) {
      const error = new Error("Monitoring must be healthy before Credits can back a Commitment.");
      error.code = "failed-precondition";
      throw error;
    }
    const regimeRef = userRef(uid).collection("regimes").doc(commitmentId);
    const regimeSnap = await regimeRef.get();
    if (!regimeSnap.exists || regimeSnap.data()?.isActive === false) {
      const error = new Error("The Commitment is not active.");
      error.code = "failed-precondition";
      throw error;
    }
    const regime = regimeSnap.data() || {};
    const type = Number(regime.type);
    if (![0, 1].includes(type)) {
      const error = new Error("This Commitment type cannot be backed yet.");
      error.code = "failed-precondition";
      throw error;
    }
    const existing = await userRef(uid).collection("creditBackings")
        .where("commitmentId", "==", commitmentId).where("status", "in", ["LOCKED", "GRACE"]).limit(1).get();
    if (!existing.empty) {
      const error = new Error("This Commitment already has locked Credits.");
      error.code = "already-exists";
      throw error;
    }
    const backingId = `backing_${crypto.randomUUID()}`;
    const backingRef = userRef(uid).collection("creditBackings").doc(backingId);
    const holdRef = userRef(uid).collection("creditHolds").doc(backingId);
    const eventId = `lock_${backingId}`;
    const startAt = Number(regime.startAtMs || regime.activatedAtMs || now());
    const endAt = Number(regime.endAtMs || (now() + 24 * 60 * 60 * 1000));
    const snapshot = {
      backingId,
      commitmentId,
      uid,
      lockedCredits: amount,
      commitmentType: type === 0 ? "PROTECT_PERIOD" : "PROTECT_DAILY_LIMIT",
      targetApps: Array.isArray(regime.targetApps) ? regime.targetApps.slice(0, 100) : [],
      ruleSnapshot: {
        type,
        durationLimit: regime.durationLimit || null,
        days: Array.isArray(regime.days) ? regime.days : [],
        blocks: Array.isArray(regime.blocks) ? regime.blocks : [],
      },
      startAt: timestamp(startAt),
      endAt: timestamp(endAt),
      resolutionWindowHours: RESOLUTION_WINDOW_HOURS,
      gracePolicy,
      graceRemaining: gracePolicy === "THREE" ? 3 : gracePolicy === "ONE" ? 1 : 0,
      retryPolicy: normalizeString(payload?.retryPolicy) || "SHORT_RETRY_WINDOW",
      proofPolicyVersion: "credit-proof-v1",
      status: "LOCKED",
      evidenceOutcome: null,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };
    await db.runTransaction(async (tx) => {
      const walletSnap = await tx.get(walletRef(uid));
      const current = walletSnap.data() || {availableCredits: 0, lockedCredits: 0};
      if (availableCredits(current) < amount) {
        const error = new Error("There are not enough available Credits.");
        error.code = "failed-precondition";
        throw error;
      }
      const next = projectWallet(current, LEDGER_EVENTS.LOCK, amount);
      await appendLedgerEventTx(tx, uid, {
        id: eventId,
        type: LEDGER_EVENTS.LOCK,
        amount,
        availableDelta: -amount,
        lockedDelta: amount,
        sourceId: backingId,
        commitmentId,
        backingId,
        description: `${amount} Credits locked for Commitment`,
      });
      tx.create(holdRef, {backingId, commitmentId, uid, amount, status: "LOCKED", createdAt: serverTimestamp(), updatedAt: serverTimestamp()});
      tx.create(backingRef, snapshot);
      tx.set(walletRef(uid), {...next, updatedAt: serverTimestamp()}, {merge: true});
    });
    return {success: true, backing: {...snapshot, startAt: startAt, endAt: endAt}};
  }

  async function submitEvidence(uid, payload) {
    const backingId = normalizeString(payload?.backingId);
    const entries = Array.isArray(payload?.entries) ? payload.entries.slice(0, 100) : [];
    if (!backingId || entries.length === 0) {
      const error = new Error("Evidence entries are required.");
      error.code = "invalid-argument";
      throw error;
    }
    const backingRef = userRef(uid).collection("creditBackings").doc(backingId);
    const backingSnap = await backingRef.get();
    if (!backingSnap.exists) {
      const error = new Error("Credit backing was not found.");
      error.code = "not-found";
      throw error;
    }
    const backingStatus = normalizeString(backingSnap.data()?.status);
    if (!["LOCKED", "GRACE"].includes(backingStatus)) {
      // A retry arriving after finalization is harmless and must not mutate
      // the finalized backing or append late evidence.
      return {success: true, accepted: 0, finalized: true};
    }

    const commitmentId = normalizeString(backingSnap.data()?.commitmentId);
    const normalizedEntries = entries.map((entry) => {
      const source = entry && typeof entry === "object" ? entry : {};
      const eventId = normalizeString(source.eventId) || hashToken(JSON.stringify(source));
      const eventType = normalizeString(source.eventType).toUpperCase();
      if (!/^[a-zA-Z0-9_-]{1,200}$/.test(eventId) ||
          !CLIENT_EVIDENCE_EVENT_TYPES.has(eventType)) {
        const error = new Error("Evidence event is invalid.");
        error.code = "invalid-argument";
        throw error;
      }
      return {
        eventId,
        eventType,
        backingId,
        commitmentId,
        uid,
        sequence: Math.max(0, Math.floor(Number(source.sequence) || 0)),
        bootSessionId: normalizeString(source.bootSessionId).slice(0, 160),
        elapsedRealtimeMs: Math.max(0, Math.floor(Number(source.elapsedRealtimeMs) || 0)),
        observedWallClockMs: Math.max(0, Math.floor(Number(source.observedWallClockMs || source.observedAtMs) || 0)),
        packageName: normalizeString(source.packageName).slice(0, 180),
        monitoringHealthy: source.monitoringHealthy === true,
        eventHash: normalizeString(source.eventHash).slice(0, 128),
        previousHash: normalizeString(source.previousHash).slice(0, 128),
      };
    });

    const accepted = await db.runTransaction(async (tx) => {
      let transactionAccepted = 0;
      const latestBacking = await tx.get(backingRef);
      if (!latestBacking.exists || !["LOCKED", "GRACE"].includes(
          normalizeString(latestBacking.data()?.status))) {
        return 0;
      }
      const refs = normalizedEntries.map((entry) =>
        userRef(uid).collection("creditEvidence").doc(entry.eventId));
      const existing = await Promise.all(refs.map((ref) => tx.get(ref)));
      normalizedEntries.forEach((entry, index) => {
        const existingData = existing[index].data();
        if (existingData) {
          const sameEvent = normalizeString(existingData.eventHash) === entry.eventHash &&
            normalizeString(existingData.eventType) === entry.eventType &&
            Number(existingData.sequence || 0) === entry.sequence;
          if (!sameEvent) {
            const error = new Error("Evidence event ID was reused with different data.");
            error.code = "failed-precondition";
            throw error;
          }
          return;
        }
        // Never copy arbitrary client fields, especially trusted/server-owned
        // flags. A future signed verifier may promote an event separately.
        tx.create(refs[index], {
          ...entry,
          trusted: false,
          source: "client_evidence_upload",
          receivedAt: serverTimestamp(),
        });
        transactionAccepted++;
      });
      if (transactionAccepted > 0) {
        tx.set(backingRef, {
          lastEvidenceAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        }, {merge: true});
      }
      return transactionAccepted;
    });
    return {success: true, accepted, trusted: false};
  }

  async function submitPendingLocalForfeiture(uid, payload) {
    const backingId = normalizeString(payload?.backingId);
    const eventId = normalizeString(payload?.eventId);
    if (!backingId || !eventId) {
      const error = new Error("A pending local Credit event is invalid.");
      error.code = "invalid-argument";
      throw error;
    }
    return submitEvidence(uid, {
      backingId,
      entries: [{
        eventId,
        eventType: "LOCAL_FAILURE_SIGNAL",
        amount: Number(payload?.amount) || 0,
        provisionalState: "FAILURE_VERIFIED_LOCAL",
        observedAtMs: now(),
      }],
    });
  }

  async function reconcilePurchaseReversal(uid, purchaseToken, reason = "google_play_reversal") {
    const tokenHash = hashToken(purchaseToken);
    const purchaseRef = userRef(uid).collection("creditPurchases").doc(tokenHash);
    const reversalId = `reversal_${tokenHash}`;
    let reversedAmount = 0;
    await db.runTransaction(async (tx) => {
      const [purchaseSnap, walletSnap] = await Promise.all([
        tx.get(purchaseRef),
        tx.get(walletRef(uid)),
      ]);
      if (!purchaseSnap.exists) return;
      const purchase = purchaseSnap.data() || {};
      if (purchase.reversalEventId) return;
      const current = walletSnap.data() || {availableCredits: 0, lockedCredits: 0};
      const issued = Math.max(0, Number(purchase.creditAmount) || 0);
      const available = availableCredits(current);
      // Never create a negative wallet. Any amount currently held behind an
      // active Commitment remains attributable and is reconciled after the
      // hold resolves; the original history is never rewritten.
      reversedAmount = Math.min(issued, available);
      const next = reversedAmount > 0 ? projectWallet(current, LEDGER_EVENTS.REVERSAL, reversedAmount) : current;
      if (reversedAmount > 0) {
        await appendLedgerEventTx(tx, uid, {
          id: reversalId,
          type: LEDGER_EVENTS.REVERSAL,
          amount: reversedAmount,
          availableDelta: -reversedAmount,
          sourceId: tokenHash,
          purchaseTokenHash: tokenHash,
          description: "Credit purchase reversed by Google Play",
        });
        tx.set(walletRef(uid), {...next, updatedAt: serverTimestamp()}, {merge: true});
      }
      tx.set(purchaseRef, {
        reversalEventId: reversalId,
        reversalReason: reason,
        reversedCredits: reversedAmount,
        reversalPendingHeldCredits: Math.max(0, issued - reversedAmount),
        reversedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }, {merge: true});
    });
    return {success: true, reversedCredits: reversedAmount};
  }

  async function resolveBacking(uid, backingId) {
    const backingRef = userRef(uid).collection("creditBackings").doc(backingId);
    const holdRef = userRef(uid).collection("creditHolds").doc(backingId);
    const backingSnap = await backingRef.get();
    if (!backingSnap.exists) return null;
    if (!["LOCKED", "GRACE"].includes(backingSnap.data()?.status)) {
      return {status: backingSnap.data()?.status};
    }
    const evidenceQuery = userRef(uid).collection("creditEvidence")
        .where("backingId", "==", backingId).limit(500);
    return db.runTransaction(async (tx) => {
      const [latestBacking, latestHold, walletSnap, evidenceSnap] = await Promise.all([
        tx.get(backingRef), tx.get(holdRef), tx.get(walletRef(uid)),
        tx.get(evidenceQuery),
      ]);
      if (!latestBacking.exists || !latestHold.exists) {
        return {status: "MISSING"};
      }
      const latest = latestBacking.data() || {};
      if (!["LOCKED", "GRACE"].includes(latest.status)) {
        return {status: latest.status || "UNKNOWN", outcome: latest.evidenceOutcome, settlement: latest.settlement};
      }
      const outcome = evaluateEvidence(
          evidenceSnap.docs.map((doc) => doc.data()),
          now(),
          timestampToMillis(latest.endAt),
          Number(latest.resolutionWindowHours) || RESOLUTION_WINDOW_HOURS,
      );
      if (!outcome) return {status: latest.status, pending: true};
      const isFailure = outcome === EVIDENCE_OUTCOMES.FAILURE;
      const eventType = isFailure ? LEDGER_EVENTS.FORFEITURE : LEDGER_EVENTS.RELEASE;
      const settlement = isFailure ? "FORFEIT_FAILURE" : outcome === EVIDENCE_OUTCOMES.UNVERIFIABLE ? "RELEASE_UNVERIFIABLE" : "RELEASE_SUCCESS";
      const lockedCredits = Number(latest.lockedCredits) || 0;
      const graceRemaining = Number(latest.graceRemaining) || 0;
      if (outcome === EVIDENCE_OUTCOMES.FAILURE && graceRemaining > 0) {
        tx.set(backingRef, {
          status: "GRACE",
          graceRemaining: graceRemaining - 1,
          retryEndsAt: timestamp(now() + 24 * 60 * 60 * 1000),
          evidenceOutcome: outcome,
          updatedAt: serverTimestamp(),
        }, {merge: true});
        tx.set(holdRef, {status: "GRACE", updatedAt: serverTimestamp()}, {merge: true});
        return {status: "GRACE", outcome};
      }
      const current = walletSnap.data() || {availableCredits: 0, lockedCredits: 0};
      const next = projectWallet(current, eventType, lockedCredits);
      await appendLedgerEventTx(tx, uid, {
        id: `settle_${backingId}`,
        type: eventType,
        amount: lockedCredits,
        availableDelta: isFailure ? 0 : lockedCredits,
        lockedDelta: -lockedCredits,
        sourceId: backingId,
        commitmentId: latest.commitmentId,
        backingId,
        description: isFailure ? "Credits forfeited after verified failure" : "Credits returned after Commitment resolution",
      });
      tx.set(walletRef(uid), {...next, updatedAt: serverTimestamp()}, {merge: true});
      tx.set(holdRef, {status: isFailure ? "FORFEITED" : "RELEASED", settledAt: serverTimestamp(), settlement, updatedAt: serverTimestamp()}, {merge: true});
      tx.set(backingRef, {status: isFailure ? "FORFEITED" : "RELEASED", evidenceOutcome: outcome, settlement, settledAt: serverTimestamp(), updatedAt: serverTimestamp()}, {merge: true});
      return {status: isFailure ? "FORFEITED" : "RELEASED", outcome, settlement};
    });
  }

  async function resolveDue() {
    const snapshot = await db.collectionGroup("creditBackings")
        .where("status", "in", ["LOCKED", "GRACE"]).limit(100).get();
    const results = [];
    for (const doc of snapshot.docs) {
      const uid = doc.ref.parent.parent?.id;
      if (!uid) continue;
      results.push(await resolveBacking(uid, doc.id));
    }
    return {processed: results.length, results};
  }

  return {
    recordDisclosure,
    verifyPurchase,
    redeemCredits,
    createBacking,
    submitEvidence,
    submitPendingLocalForfeiture,
    reconcilePurchaseReversal,
    resolveBacking,
    resolveDue,
    normalizeProductPurchase,
    evaluateEvidence,
    projectWallet,
    productAmount,
  };
}

module.exports = {
  CREDIT_PRODUCTS,
  CREDIT_PRODUCT_IDS,
  CREDIT_DISCLOSURE_VERSION,
  CREDIT_BACKING_TERMS_VERSION,
  RESOLUTION_WINDOW_HOURS,
  SECONDS_PER_CREDIT,
  REDEEM_AMOUNTS,
  LOCK_AMOUNTS,
  LEDGER_EVENTS,
  EVIDENCE_OUTCOMES,
  normalizeProductPurchase,
  evaluateEvidence,
  projectWallet,
  productAmount,
  hashToken,
  createCreditLedgerService,
};
