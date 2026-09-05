const crypto = require("node:crypto");

const PREMIUM_PRODUCT_ID = "premium";
const PREMIUM_PACKAGE_NAME = "com.crescence.revoke";
const PREMIUM_BASE_PLANS = Object.freeze({
  "prepaid-30d": Object.freeze({durationDays: 30}),
  "prepaid-365d": Object.freeze({durationDays: 365}),
});

const SUBSCRIPTION_ACTIVE = "SUBSCRIPTION_STATE_ACTIVE";
const ACKNOWLEDGED = "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED";
const RESOLUTION_STATES = new Set([
  "SUBSCRIPTION_STATE_ACTIVE",
  "SUBSCRIPTION_STATE_EXPIRED",
  "SUBSCRIPTION_STATE_REVOKED",
  "SUBSCRIPTION_STATE_PENDING",
  "SUBSCRIPTION_STATE_PAUSED",
  "SUBSCRIPTION_STATE_CANCELED",
]);

function normalizeString(value) {
  return (value || "").toString().trim();
}

function expectedObfuscatedAccountId(uid) {
  const normalizedUid = normalizeString(uid);
  if (!normalizedUid) return "";
  return crypto
      .createHash("sha256")
      .update(`revoke:account:${normalizedUid}`)
      .digest("hex");
}

function hashPurchaseToken(purchaseToken) {
  return crypto
      .createHash("sha256")
      .update(normalizeString(purchaseToken))
      .digest("hex");
}

function timestampToMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  const numeric = Number(value);
  return Number.isFinite(numeric) && numeric > 0 ? Math.floor(numeric) : 0;
}

function parseMillis(value) {
  if (!value) return 0;
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : timestampToMillis(value);
}

function normalizePlaySubscription(raw, nowMs = Date.now()) {
  const source = raw && typeof raw === "object" ? raw : {};
  const lineItems = Array.isArray(source.lineItems) ? source.lineItems : [];
  const productItems = lineItems.filter((item) =>
    normalizeString(item?.productId) === PREMIUM_PRODUCT_ID);
  const items = productItems.map((item) => {
    const offerDetails = item.offerDetails && typeof item.offerDetails === "object" ?
      item.offerDetails : {};
    const basePlanId = normalizeString(offerDetails.basePlanId);
    return {
      productId: normalizeString(item.productId),
      basePlanId,
      expiryTimeMs: parseMillis(item.expiryTime),
      startTimeMs: parseMillis(item.startTime),
      latestSuccessfulOrderId: normalizeString(item.latestSuccessfulOrderId),
      isPrepaid: item.prepaidPlan != null,
    };
  });
  const matching = items
      .filter((item) => Object.prototype.hasOwnProperty.call(PREMIUM_BASE_PLANS, item.basePlanId))
      .sort((a, b) => b.expiryTimeMs - a.expiryTimeMs);
  const selected = matching[0] || null;
  const subscriptionState = normalizeString(source.subscriptionState);
  const external = source.externalAccountIdentifiers &&
      typeof source.externalAccountIdentifiers === "object" ?
    source.externalAccountIdentifiers : {};

  return {
    productId: selected?.productId || "",
    basePlanId: selected?.basePlanId || "",
    expiryTimeMs: selected?.expiryTimeMs || 0,
    startTimeMs: selected?.startTimeMs || 0,
    latestSuccessfulOrderId: selected?.latestSuccessfulOrderId || "",
    subscriptionState,
    acknowledgementState: normalizeString(source.acknowledgementState),
    obfuscatedExternalAccountId: normalizeString(external.obfuscatedExternalAccountId),
    linkedPurchaseToken: normalizeString(source.linkedPurchaseToken),
    active: subscriptionState === SUBSCRIPTION_ACTIVE &&
      Boolean(selected) && selected.expiryTimeMs > nowMs,
    isKnownState: RESOLUTION_STATES.has(subscriptionState),
    isPrepaid: Boolean(selected?.isPrepaid),
  };
}

function grantIdForPurchase(purchaseToken) {
  return `google_${hashPurchaseToken(purchaseToken)}`;
}

function sequentialPremiumUntil(grants, nowMs = Date.now()) {
  const activeGrants = (Array.isArray(grants) ? grants : [])
      .filter((grant) => normalizeString(grant?.status) === "active")
      .map((grant) => ({
        id: normalizeString(grant.id),
        startTimeMs: timestampToMillis(grant.startTimeMs) ||
          timestampToMillis(grant.grantedAt),
        durationMs: Math.max(0, Number(grant.durationMs) || 0),
      }))
      .filter((grant) => grant.durationMs > 0)
      .sort((a, b) => a.startTimeMs - b.startTimeMs || a.id.localeCompare(b.id));

  let cursor = 0;
  for (const grant of activeGrants) {
    cursor = Math.max(cursor, grant.startTimeMs || nowMs);
    cursor += grant.durationMs;
  }
  return cursor;
}

function entitlementStatus(premiumUntilMs, nowMs = Date.now()) {
  return premiumUntilMs > nowMs ? "active" : "expired";
}

function buildSanitizedEntitlement({premiumUntilMs, nowMs = Date.now(), basePlanId = "", sourceSummary = ""}) {
  const status = entitlementStatus(premiumUntilMs, nowMs);
  return {
    active: status === "active",
    status,
    premiumUntilMs: Math.max(0, Number(premiumUntilMs) || 0),
    verifiedAtMs: nowMs,
    computedAtMs: nowMs,
    plan: basePlanId,
    sourceSummary: normalizeString(sourceSummary) || "Google Play Premium",
  };
}

function decodeRtdnMessage(event) {
  const message = event?.data?.message || event?.message || {};
  let payload = message.json;
  if (!payload && message.data) {
    try {
      payload = JSON.parse(Buffer.from(message.data, "base64").toString("utf8"));
    } catch (_) {
      payload = null;
    }
  }
  const source = payload && typeof payload === "object" ? payload : {};
  const notification = source.subscriptionNotification || source.subscription_notification;
  if (!notification || typeof notification !== "object") return null;
  return {
    messageId: normalizeString(message.messageId || event?.id),
    packageName: normalizeString(source.packageName),
    eventTimeMillis: Number(source.eventTimeMillis) || 0,
    notificationType: Number(notification.notificationType) || 0,
    purchaseToken: normalizeString(notification.purchaseToken),
  };
}

function isTerminalSubscriptionNotification(notificationType) {
  return [3, 12, 13].includes(Number(notificationType));
}

function createPremiumBillingService({db, adminSdk, publisherFactory, now = () => Date.now(), packageName = PREMIUM_PACKAGE_NAME}) {
  if (!db) throw new Error("Firestore is required for Premium billing.");

  const timestampFromMillis = (value) => {
    if (adminSdk?.firestore?.Timestamp?.fromMillis) {
      return adminSdk.firestore.Timestamp.fromMillis(Math.floor(value));
    }
    return new Date(Math.floor(value));
  };

  const getPublisher = publisherFactory || (async () => {
    // Lazy-load Google APIs so rules/unit tests can import this module without
    // contacting Google Play or requiring credentials.
    const {google} = require("googleapis");
    const auth = new google.auth.GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });
    return google.androidpublisher({version: "v3", auth});
  });

  async function recomputeEntitlement(uid) {
    const grantsSnap = await db.collection("users").doc(uid)
        .collection("premiumGrants")
        .where("status", "==", "active")
        .get();
    const grants = grantsSnap.docs.map((doc) => ({id: doc.id, ...doc.data()}));
    const nowMs = now();
    const premiumUntilMs = sequentialPremiumUntil(grants, nowMs);
    const latestPlan = grants
        .sort((a, b) => timestampToMillis(b.grantedAt) - timestampToMillis(a.grantedAt))[0]
        ?.basePlanId || "";
    const entitlement = buildSanitizedEntitlement({
      premiumUntilMs,
      nowMs,
      basePlanId: latestPlan,
      sourceSummary: "Google Play prepaid Premium",
    });
    await db.collection("users").doc(uid).collection("premiumEntitlement")
        .doc("current").set({
          active: entitlement.active,
          status: entitlement.status,
          premiumUntil: timestampFromMillis(entitlement.premiumUntilMs),
          verifiedAt: timestampFromMillis(entitlement.verifiedAtMs),
          computedAt: timestampFromMillis(entitlement.computedAtMs),
          plan: entitlement.plan,
          sourceSummary: entitlement.sourceSummary,
        });
    return entitlement;
  }

  async function verifyPurchase(uid, purchaseToken, options = {}) {
    const normalizedUid = normalizeString(uid);
    const token = normalizeString(purchaseToken);
    if (!normalizedUid || !token) {
      const error = new Error("uid and purchaseToken are required.");
      error.code = "invalid-argument";
      throw error;
    }

    const publisher = await getPublisher();
    const response = await publisher.purchases.subscriptionsv2.get({
      packageName,
      token,
    });
    const normalized = normalizePlaySubscription(response?.data, now());
    const accountHash = expectedObfuscatedAccountId(normalizedUid);
    if (!normalized.productId || !normalized.basePlanId || !normalized.isPrepaid) {
      const error = new Error("Purchase is not an eligible Revoke Premium prepaid plan.");
      error.code = "failed-precondition";
      throw error;
    }
    if (normalized.obfuscatedExternalAccountId &&
        normalized.obfuscatedExternalAccountId !== accountHash) {
      const error = new Error("Purchase account does not match the signed-in Revoke account.");
      error.code = "permission-denied";
      throw error;
    }
    if (!normalized.isKnownState || !normalized.active) {
      const error = new Error("Purchase is not active and was not granted.");
      error.code = "failed-precondition";
      throw error;
    }

    let acknowledged = normalized.acknowledgementState === ACKNOWLEDGED;
    if (!acknowledged) {
      try {
        await publisher.purchases.subscriptions.acknowledge({
          packageName,
          subscriptionId: PREMIUM_PRODUCT_ID,
          token,
          requestBody: {},
        });
        acknowledged = true;
      } catch (error) {
        // Google may report an already acknowledged purchase on a retry. Keep
        // the verification idempotent, but never grant an invalid purchase.
        if (!String(error?.message || "").toLowerCase().includes("acknowledge")) {
          throw error;
        }
      }
    }

    const tokenHash = hashPurchaseToken(token);
    const bindingRef = db.collection("premiumPurchaseBindings").doc(tokenHash);
    const bindingSnap = await bindingRef.get();
    const boundUid = normalizeString(bindingSnap.data()?.uid);
    if (boundUid && boundUid !== normalizedUid) {
      const error = new Error("Purchase token is already bound to another Revoke account.");
      error.code = "permission-denied";
      throw error;
    }
    const purchaseRef = db.collection("users").doc(normalizedUid)
        .collection("premiumPurchases").doc(tokenHash);
    const grantId = grantIdForPurchase(token);
    const grantRef = db.collection("users").doc(normalizedUid)
        .collection("premiumGrants").doc(grantId);
    const nowMs = now();
    const durationMs = PREMIUM_BASE_PLANS[normalized.basePlanId].durationDays * 24 * 60 * 60 * 1000;
    await db.runTransaction(async (tx) => {
      const [purchaseSnap, transactionBindingSnap] = await Promise.all([
        tx.get(purchaseRef),
        tx.get(bindingRef),
      ]);
      const transactionBoundUid = normalizeString(transactionBindingSnap.data()?.uid);
      if (transactionBoundUid && transactionBoundUid !== normalizedUid) {
        const error = new Error("Purchase token is already bound to another Revoke account.");
        error.code = "permission-denied";
        throw error;
      }
      const prior = purchaseSnap.exists ? purchaseSnap.data() || {} : {};
      tx.set(purchaseRef, {
        purchaseToken: token,
        tokenHash,
        uid: normalizedUid,
        packageName,
        productId: normalized.productId,
        basePlanId: normalized.basePlanId,
        purchaseState: normalized.subscriptionState,
        expiryTime: timestampFromMillis(normalized.expiryTimeMs),
        linkedPurchaseTokenHash: normalized.linkedPurchaseToken ?
          hashPurchaseToken(normalized.linkedPurchaseToken) : null,
        latestSuccessfulOrderId: normalized.latestSuccessfulOrderId,
        acknowledged,
        verifiedAt: timestampFromMillis(nowMs),
        grantId,
        createdAt: prior.createdAt || timestampFromMillis(nowMs),
      }, {merge: true});
      tx.set(grantRef, {
        uid: normalizedUid,
        source: "GOOGLE_PLAY_PREPAID",
        purchaseRef: tokenHash,
        basePlanId: normalized.basePlanId,
        durationMs,
        startTimeMs: normalized.startTimeMs || nowMs,
        grantedAt: prior.grantedAt || timestampFromMillis(nowMs),
        status: "active",
        latestObservedExpiry: timestampFromMillis(normalized.expiryTimeMs),
        updatedAt: timestampFromMillis(nowMs),
      }, {merge: true});
      tx.set(db.collection("premiumAccountBindings").doc(accountHash), {
        uid: normalizedUid,
        purchaseTokenHash: tokenHash,
        updatedAt: timestampFromMillis(nowMs),
      }, {merge: true});
      tx.set(bindingRef, {
        uid: normalizedUid,
        purchaseTokenHash: tokenHash,
        accountHash,
        updatedAt: timestampFromMillis(nowMs),
      }, {merge: true});
    });

    const entitlement = await recomputeEntitlement(normalizedUid);
    return {
      entitlement,
      plan: normalized.basePlanId,
      purchaseState: normalized.subscriptionState,
      acknowledged,
      idempotent: Boolean(options.idempotencyKey),
    };
  }

  async function reconcilePurchase(uid, purchaseToken, options = {}) {
    const normalizedUid = normalizeString(uid);
    const token = normalizeString(purchaseToken);
    if (!normalizedUid || !token) return null;
    let normalized;
    try {
      const publisher = await getPublisher();
      const response = await publisher.purchases.subscriptionsv2.get({packageName, token});
      normalized = normalizePlaySubscription(response?.data, now());
    } catch (error) {
      if (!options.allowMissing) throw error;
      normalized = {active: false, subscriptionState: "SUBSCRIPTION_STATE_EXPIRED"};
    }
    const tokenHash = hashPurchaseToken(token);
    const purchaseRef = db.collection("users").doc(normalizedUid)
        .collection("premiumPurchases").doc(tokenHash);
    const purchaseSnap = await purchaseRef.get();
    if (!purchaseSnap.exists) return null;
    const purchase = purchaseSnap.data() || {};
    const grantId = normalizeString(purchase.grantId) || grantIdForPurchase(token);
    const grantRef = db.collection("users").doc(normalizedUid)
        .collection("premiumGrants").doc(grantId);
    if (!normalized.active || isTerminalSubscriptionNotification(options.notificationType)) {
      await grantRef.set({
        status: "revoked",
        revokedAt: timestampFromMillis(now()),
        revocationReason: options.reason || normalized.subscriptionState || "subscription_update",
        updatedAt: timestampFromMillis(now()),
      }, {merge: true});
    } else {
      await purchaseRef.set({
        purchaseState: normalized.subscriptionState,
        expiryTime: timestampFromMillis(normalized.expiryTimeMs),
        verifiedAt: timestampFromMillis(now()),
      }, {merge: true});
    }
    return recomputeEntitlement(normalizedUid);
  }

  return {verifyPurchase, reconcilePurchase, recomputeEntitlement};
}

module.exports = {
  PREMIUM_PRODUCT_ID,
  PREMIUM_PACKAGE_NAME,
  PREMIUM_BASE_PLANS,
  expectedObfuscatedAccountId,
  hashPurchaseToken,
  normalizePlaySubscription,
  sequentialPremiumUntil,
  buildSanitizedEntitlement,
  decodeRtdnMessage,
  isTerminalSubscriptionNotification,
  grantIdForPurchase,
  createPremiumBillingService,
};
