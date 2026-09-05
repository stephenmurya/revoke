const {
  onDocumentCreated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onTaskDispatched} = require("firebase-functions/v2/tasks");
const {onMessagePublished} = require("firebase-functions/v2/pubsub");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {getFunctions} = require("firebase-admin/functions");
const {
  PREMIUM_PACKAGE_NAME,
  hashPurchaseToken,
  decodeRtdnMessage,
  isTerminalSubscriptionNotification,
  createPremiumBillingService,
} = require("./premium_billing");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();
const openRouterKey = defineSecret("OPENROUTER_API_KEY");
const premiumBilling = createPremiumBillingService({
  db,
  adminSdk: admin,
  packageName: PREMIUM_PACKAGE_NAME,
});
const RAP_SHEET_VERSION = 1;
const RAP_SHEET_MAX_INFRACTIONS = 5;
const RAP_SHEET_QUERY_LIMIT = 25;

async function _getPremiumEntitlement(uid) {
  const normalizedUid = (uid || "").toString().trim();
  if (!normalizedUid) return null;
  const snap = await db.collection("users").doc(normalizedUid)
      .collection("premiumEntitlement").doc("current").get();
  if (!snap.exists) return null;
  const data = snap.data() || {};
  const premiumUntilMs = _timestampToMillis(data.premiumUntil);
  return {
    ...data,
    premiumUntilMs,
    active: data.active === true && premiumUntilMs > Date.now(),
  };
}

async function _assertPremiumEntitled(uid) {
  const entitlement = await _getPremiumEntitlement(uid);
  if (!entitlement?.active) {
    throw new HttpsError(
        "failed-precondition",
        "Premium is required for this capability.",
    );
  }
  return entitlement;
}

function _premiumError(error) {
  if (error instanceof HttpsError) return error;
  const code = [
    "invalid-argument",
    "failed-precondition",
    "permission-denied",
    "not-found",
  ].includes(error?.code) ? error.code : "internal";
  return new HttpsError(code, error?.message || "Premium verification failed.");
}

async function logSquadEvent(squadId, type, title, user, metadata) {
  const normalizedSquadId = (squadId || "").toString().trim();
  if (!normalizedSquadId) return;

  const normalizedType = (type || "").toString().trim();
  const normalizedTitle = (title || "").toString().trim();

  const userId = (user?.userId || user?.uid || "").toString().trim();
  const userName = (user?.userName || user?.name || "").toString().trim();
  const userAvatar = (user?.userAvatar || user?.avatar || "").toString().trim();

  const safeMetadata = metadata && typeof metadata === "object" ? metadata : {};

  try {
    await db.collection("squads").doc(normalizedSquadId).collection("logs").add({
      type: normalizedType,
      title: normalizedTitle,
      userId,
      userName,
      userAvatar,
      timestamp: FieldValue.serverTimestamp(),
      metadata: safeMetadata,
      reactions: {},
    });
  } catch (error) {
    logger.warn("logSquadEvent failed.", {
      squadId: normalizedSquadId,
      type: normalizedType,
      title: normalizedTitle,
      errorMessage: error?.message || String(error),
    });
  }
}

async function _loadUserProfileOrThrow(uid, label) {
  const normalized = (uid || "").toString().trim();
  if (!normalized) {
    throw new HttpsError("invalid-argument", `${label} uid is required.`);
  }
  const snap = await db.collection("users").doc(normalized).get();
  if (!snap.exists) {
    throw new HttpsError(
        "failed-precondition",
        `${label} user profile is missing.`,
    );
  }
  const data = snap.data() || {};
  return {
    uid: (data.uid || snap.id || normalized).toString().trim(),
    ref: snap.ref,
    squadId: (data.squadId || "").toString().trim(),
    name: _deriveUserDisplayName(data),
    avatar: (data.photoUrl || "").toString().trim(),
    token: (data.fcmToken || "").toString().trim(),
    wantsShameAlerts: _wantsNotification(data, "shameAlerts"),
    wantsPleaRequests: _wantsNotification(data, "pleaRequests"),
    wantsVerdicts: _wantsNotification(data, "verdicts"),
    focusScore: Number(data.focusScore),
  };
}

async function _sendUserNotificationBestEffort(token, title, body, data) {
  const normalizedToken = (token || "").toString().trim();
  if (!normalizedToken) return;
  const safeTitle = (title || "").toString().trim();
  const safeBody = (body || "").toString().trim();
  try {
    await messaging.send({
      token: normalizedToken,
      notification: {
        title: safeTitle,
        body: safeBody,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "squad_alerts",
          sound: "lookatthisdude",
        },
      },
      data: data && typeof data === "object" ? data : {},
    });
  } catch (error) {
    logger.warn("FCM send failed.", {
      tokenSuffix: normalizedToken.slice(-8),
      errorCode: error?.code,
      errorMessage: error?.message || String(error),
    });
  }
}

function _normalizeNotificationMetadata(metadata) {
  if (!metadata || typeof metadata !== "object" || Array.isArray(metadata)) {
    return {};
  }

  const normalized = {};
  for (const [key, value] of Object.entries(metadata)) {
    const safeKey = (key || "").toString().trim();
    if (!safeKey || value === undefined) continue;
    normalized[safeKey] = value;
  }
  return normalized;
}

function _buildInAppNotificationPayload(payload, idOverride) {
  const source = payload && typeof payload === "object" ? payload : {};
  const normalizedTitle = (source.title || "").toString().trim();
  const normalizedBody = (source.body || "").toString().trim();
  const normalizedType = (source.type || "system")
      .toString()
      .trim()
      .toLowerCase() || "system";

  return {
    id: (idOverride || "").toString().trim(),
    title: normalizedTitle,
    body: normalizedBody,
    type: normalizedType,
    isRead: false,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    metadata: _normalizeNotificationMetadata(source.metadata),
  };
}

async function createInAppNotification(uid, payload) {
  const normalizedUid = (uid || "").toString().trim();
  if (!normalizedUid) return false;

  try {
    const notificationRef = admin
        .firestore()
        .collection("users")
        .doc(normalizedUid)
        .collection("notifications")
        .doc();

    await notificationRef.set(_buildInAppNotificationPayload(
        payload,
        notificationRef.id,
    ));
    return true;
  } catch (error) {
    // Explicit console error for quick inspection in Cloud logs.
    console.error(
        `Failed to create in-app notification for ${normalizedUid}:`,
        error,
    );
    return false;
  }
}

async function _sendPleaVerdictSideEffects({
  pleaId,
  pleaData,
  requesterId,
  verdict,
  acceptVotes = 0,
  rejectVotes = 0,
  outcomeSource = "human_tribunal",
}) {
  const normalizedPleaId = (pleaId || "").toString().trim();
  const normalizedRequesterId = (requesterId || "").toString().trim();
  const normalizedVerdict = (verdict || "").toString().trim().toLowerCase();
  if (!normalizedPleaId || !normalizedRequesterId) return;
  if (normalizedVerdict !== "approved" && normalizedVerdict !== "rejected") {
    return;
  }

  // Firestore triggers and retrying tasks can both reach this function. Claim
  // the delivery once; native also treats the request id as idempotent.
  const pleaRef = db.collection("pleas").doc(normalizedPleaId);
  const claimed = await db.runTransaction(async (tx) => {
    const snap = await tx.get(pleaRef);
    if (snap.exists && snap.data()?.nativeUnlockDeliveryClaimedAt) return false;
    if (snap.exists) {
      tx.set(pleaRef, {
        nativeUnlockDeliveryClaimedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    return true;
  });
  if (!claimed) return;

  const squadId = (pleaData?.squadId || "").toString().trim();
  const requesterName = (pleaData?.userName || "").toString().trim() ||
    "A Member";
  const appName = (pleaData?.appName || "access").toString().trim() ||
    "access";
  const isApproved = normalizedVerdict === "approved";
  const outcome = isApproved ? "approved" : "not approved";
  const inAppVerdictTitle = isApproved ? "Temporary access approved" : "Access request closed";
  const inAppVerdictBody = isApproved
    ? `${appName} is available for a short period.`
    : `The request for ${appName} was not approved.`;
  const verdictBody = isApproved
    ? `Temporary access to ${appName} is available now.`
    : `Your request for ${appName} was not approved.`;
  const approvedUntilMs = _timestampToMillis(pleaData?.approvedUntil) ||
    (isApproved ? Date.now() + Math.max(1, Number(pleaData?.durationMinutes) || 5) * 60 * 1000 : 0);

  try {
    const userSnap = await db.collection("users").doc(normalizedRequesterId).get();
    const requesterData = userSnap.data() || {};
    const avatar = (requesterData.photoUrl || "").toString().trim();
    const requesterToken = (requesterData.fcmToken || "").toString().trim();
    const requesterWantsVerdicts = _wantsNotification(requesterData, "verdicts");

    await createInAppNotification(normalizedRequesterId, {
      title: inAppVerdictTitle,
      body: inAppVerdictBody,
      type: "override_resolution",
      metadata: {
        pleaId: String(normalizedPleaId),
        squadId: String(squadId),
        verdict: String(normalizedVerdict),
        outcomeSource: String(outcomeSource),
      },
    });

    if (requesterToken && (isApproved || requesterWantsVerdicts)) {
      await _sendUserNotificationBestEffort(
          requesterToken,
          isApproved ? "Temporary access approved" : "Access request closed",
          verdictBody,
          {
            type: isApproved ? "override_approved" : "override_resolved",
            pleaId: String(normalizedPleaId),
            overrideId: String(normalizedPleaId),
            uid: String(normalizedRequesterId),
            squadId: String(squadId),
            verdict: String(normalizedVerdict),
            outcomeSource: String(outcomeSource),
            packageName: String((pleaData?.packageName || "").toString()),
            approvedUntilMs: String(approvedUntilMs),
            durationMinutes: String(Math.max(1, Number(pleaData?.durationMinutes) || 5)),
            idempotencyKey: String((pleaData?.idempotencyKey || normalizedPleaId).toString()),
          },
      );
    }

    await logSquadEvent(
        squadId,
        "verdict",
        `Temporary access ${outcome} for ${requesterName}.`,
        {
          userId: normalizedRequesterId,
          userName: requesterName,
          userAvatar: avatar,
        },
        {
          pleaId: String(normalizedPleaId),
          verdict: normalizedVerdict,
          acceptVotes,
          rejectVotes,
          outcomeSource,
        },
    );
  } catch (_) {
    // Best-effort only.
  }
}

async function _createInAppNotificationsBatch(userIds, payload) {
  const normalizedIds = [...new Set(
      (Array.isArray(userIds) ? userIds : [])
          .map((uid) => (uid || "").toString().trim())
          .filter((uid) => Boolean(uid)),
  )];
  if (normalizedIds.length === 0) return 0;

  let writes = 0;
  const safePayload = payload && typeof payload === "object" ? payload : {};
  const firestore = admin.firestore();

  for (let i = 0; i < normalizedIds.length; i += 400) {
    const chunk = normalizedIds.slice(i, i + 400);
    const batch = firestore.batch();

    for (const uid of chunk) {
      const notificationRef = firestore
          .collection("users")
          .doc(uid)
          .collection("notifications")
          .doc();
      batch.set(notificationRef, _buildInAppNotificationPayload(
          safePayload,
          notificationRef.id,
      ));
    }

    try {
      await batch.commit();
      writes += chunk.length;
    } catch (error) {
      logger.warn("createInAppNotificationsBatch commit failed.", {
        chunkSize: chunk.length,
        type: (safePayload.type || "system")
            .toString()
            .trim()
            .toLowerCase() || "system",
        errorMessage: error?.message || String(error),
      });
    }
  }

  return writes;
}

function _readNotificationPrefs(userData) {
  if (!userData || typeof userData !== "object") return {};
  const prefs = userData.notificationPrefs;
  if (!prefs || typeof prefs !== "object" || Array.isArray(prefs)) {
    return {};
  }
  return prefs;
}

function _wantsNotification(userData, prefKey) {
  const prefs = _readNotificationPrefs(userData);
  return prefs[prefKey] !== false;
}

// -----------------------------
// Abuse controls & lifecycle
// -----------------------------
// Quorum model: attendance-based. Eligible voters are all attendees except the requester.
// Resolution happens when all eligible voters have cast a vote, OR the session times out.
const PLEA_CREATE_WINDOW_MS = 10 * 60 * 1000;
const PLEA_CREATE_MAX_PER_WINDOW = 3;

const MESSAGE_WINDOW_MS = 60 * 1000;
const MESSAGE_MAX_PER_WINDOW = 20;
const MESSAGE_COOLDOWN_MS = 2 * 1000;
const MESSAGE_MAX_LEN = 400;

const ACTIVE_PLEA_TIMEOUT_MS = 5 * 60 * 1000;
const AI_FALLBACK_DELAY_SECONDS = 30;
const AI_FORCE_KILL_DELAY_SECONDS = 5 * 60;
const AI_FALLBACK_MAX_APPROVAL_MINUTES = 15;
const OPENROUTER_MODEL = "meta-llama/llama-3-8b-instruct:free";
const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

// V2 Circle/Override authority contract. These values are intentionally kept
// server-side so membership or client payloads cannot expand authority.
const CIRCLE_PERMISSIONS = Object.freeze([
  "viewCommitmentSummary",
  "viewOverrideHistory",
  "receiveOverrideRequests",
  "participateInOverrideDiscussion",
  "voteOnOverrideRequests",
  "receiveAccountabilityNotifications",
]);
const CIRCLE_PRESETS = Object.freeze([
  "observer",
  "accountabilityPartner",
  "guardian",
  "custom",
]);
const OVERRIDE_AUTHORITIES = Object.freeze(["self", "ai", "circle"]);
const OVERRIDE_DURATION_MINUTES = Object.freeze([5, 10, 15]);
const CIRCLE_DEFAULT_PERMISSIONS = Object.freeze({
  viewCommitmentSummary: true,
  viewOverrideHistory: false,
  receiveOverrideRequests: false,
  participateInOverrideDiscussion: false,
  voteOnOverrideRequests: false,
  receiveAccountabilityNotifications: false,
});

const RESOLVED_PLEA_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const MARKED_FOR_DELETION_TTL_MS = 10 * 60 * 1000;
const CLEANUP_BATCH_LIMIT = 100;

const PREMIUM_DISCLOSURE_VERSION = "premium-purchase-v1";

exports.recordPremiumPurchaseDisclosure = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Authentication required.");
  const payload = request.data || {};
  const allowed = new Set(["purchaseFlowId", "disclosureVersion"]);
  for (const key of Object.keys(payload)) {
    if (!allowed.has(key)) throw new HttpsError("invalid-argument", `Unexpected field: ${key}`);
  }
  const flowId = (payload.purchaseFlowId || "").toString().trim();
  const version = (payload.disclosureVersion || "").toString().trim();
  if (!flowId || flowId.length > 120 || !/^[a-zA-Z0-9_-]+$/.test(flowId)) {
    throw new HttpsError("invalid-argument", "A valid purchase flow ID is required.");
  }
  if (version !== PREMIUM_DISCLOSURE_VERSION) {
    throw new HttpsError("failed-precondition", "The Premium purchase disclosure is out of date.");
  }
  await db.collection("users").doc(request.auth.uid)
      .collection("premiumDisclosureAcceptances").doc(flowId).set({
        uid: request.auth.uid,
        disclosureVersion: version,
        acceptedAt: FieldValue.serverTimestamp(),
      });
  return {success: true, purchaseFlowId: flowId, disclosureVersion: version};
});

exports.verifyPremiumPurchase = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Authentication required.");
  const payload = request.data || {};
  const allowed = new Set(["purchaseToken", "purchaseFlowId"]);
  for (const key of Object.keys(payload)) {
    if (!allowed.has(key)) throw new HttpsError("invalid-argument", `Unexpected field: ${key}`);
  }
  const uid = request.auth.uid;
  const purchaseToken = (payload.purchaseToken || "").toString().trim();
  const purchaseFlowId = (payload.purchaseFlowId || "").toString().trim();
  if (!purchaseToken || purchaseToken.length > 4096) {
    throw new HttpsError("invalid-argument", "purchaseToken is required.");
  }

  // A new purchase must have an acceptance recorded immediately before the
  // Play sheet was opened. Existing purchase records can be reverified after
  // restore without asking the user to accept a purchase disclosure again.
  const purchaseRef = db.collection("users").doc(uid)
      .collection("premiumPurchases").doc(hashPurchaseToken(purchaseToken));
  const existingPurchase = await purchaseRef.get();
  if (!existingPurchase.exists) {
    if (!purchaseFlowId) {
      throw new HttpsError("failed-precondition", "Premium purchase disclosure acceptance is required.");
    }
    const acceptance = purchaseFlowId ? await db.collection("users").doc(uid)
        .collection("premiumDisclosureAcceptances").doc(purchaseFlowId).get() : null;
    if (!acceptance?.exists || acceptance.data()?.disclosureVersion !== PREMIUM_DISCLOSURE_VERSION) {
      throw new HttpsError("failed-precondition", "Premium purchase disclosure acceptance is required.");
    }
  }

  try {
    return await premiumBilling.verifyPurchase(uid, purchaseToken, {
      idempotencyKey: purchaseFlowId,
    });
  } catch (error) {
    logger.error("verifyPremiumPurchase failed.", {
      uid,
      purchaseTokenHash: hashPurchaseToken(purchaseToken),
      errorMessage: error?.message || String(error),
    });
    throw _premiumError(error);
  }
});

exports.reconcilePremiumRtdn = onMessagePublished({
  topic: "revoke-premium-rtdn",
  region: "us-central1",
}, async (event) => {
  const notification = decodeRtdnMessage(event);
  if (!notification || notification.packageName !== PREMIUM_PACKAGE_NAME ||
      !notification.purchaseToken) return;

  const messageId = notification.messageId || hashPurchaseToken(notification.purchaseToken);
  const eventRef = db.collection("premiumRtdnEvents").doc(messageId);
  const claim = await db.runTransaction(async (tx) => {
    const existing = await tx.get(eventRef);
    if (existing.exists) return false;
    tx.create(eventRef, {
      packageName: notification.packageName,
      notificationType: notification.notificationType,
      eventTimeMillis: notification.eventTimeMillis,
      purchaseTokenHash: hashPurchaseToken(notification.purchaseToken),
      receivedAt: FieldValue.serverTimestamp(),
    });
    return true;
  });
  if (!claim) return;

  const tokenHash = hashPurchaseToken(notification.purchaseToken);
  const tokenBinding = await db.collection("premiumPurchaseBindings")
      .doc(tokenHash).get();
  const bindingQuery = await db.collectionGroup("premiumPurchases")
      .where("tokenHash", "==", tokenHash).limit(1).get();
  // Purchases are kept in user-owned server-only subcollections, so RTDN
  // resolves the account through a private token binding map.
  let uid = "";
  if (tokenBinding.exists) uid = (tokenBinding.data()?.uid || "").toString().trim();
  const bindingSnap = await db.collection("premiumAccountBindings")
      .where("purchaseTokenHash", "==", tokenHash).limit(1).get();
  if (!bindingSnap.empty) uid = (bindingSnap.docs[0].data()?.uid || "").toString().trim();
  if (!uid && !bindingQuery.empty) uid = (bindingQuery.docs[0].data()?.uid || "").toString().trim();
  if (!uid) {
    // The API is still re-queried only when a prior verification has bound the
    // token. Never guess an account from an untrusted RTDN payload.
    logger.warn("Premium RTDN has no known account binding.", {tokenHash, messageId});
    return;
  }
  try {
    await premiumBilling.reconcilePurchase(uid, notification.purchaseToken, {
      notificationType: notification.notificationType,
      reason: isTerminalSubscriptionNotification(notification.notificationType) ?
        "google_play_subscription_terminal" : "google_play_subscription_update",
      allowMissing: true,
    });
  } catch (error) {
    logger.error("Premium RTDN reconciliation failed.", {
      uid,
      tokenHash,
      messageId,
      errorMessage: error?.message || String(error),
    });
    throw error;
  }
});

exports.createCircle = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Authentication required.");
  await _assertPremiumEntitled(request.auth.uid);
  const uid = request.auth.uid;
  const userRef = db.collection("users").doc(uid);
  const circleRef = db.collection("squads").doc();
  const squadCode = `REV-${Math.random().toString(36).slice(2, 5).toUpperCase()}`;
  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (userSnap.exists && (userSnap.data()?.squadId || "").toString().trim()) {
      throw new HttpsError("failed-precondition", "You are already in a Circle.");
    }
    tx.create(circleRef, {
      joinCode: squadCode,
      squadCode,
      creatorId: uid,
      memberIds: [uid],
      premiumRequired: true,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.set(userRef, {squadId: circleRef.id, squadCode}, {merge: true});
  });
  return {success: true, circleId: circleRef.id, squadCode};
});

exports.assertPremiumCapability = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Authentication required.");
  const capability = (request.data?.capability || "").toString().trim();
  const allowed = new Set([
    "reduce_commitment",
    "additional_protect_commitment",
    "ai_authority",
    "circle_authority",
    "circle_member_management",
  ]);
  if (!allowed.has(capability)) {
    throw new HttpsError("invalid-argument", "Unknown Premium capability.");
  }
  if (capability === "additional_protect_commitment") {
    const userRef = db.collection("users").doc(request.auth.uid);
    const [schedules, taperPlans] = await Promise.all([
      userRef.collection("regimes").get(),
      userRef.collection("taperPlans").get(),
    ]);
    const taperScheduleIds = new Set(taperPlans.docs.map((doc) =>
      (doc.data()?.scheduleId || "").toString().trim()).filter((id) => Boolean(id)));
    const activeProtectCount = schedules.docs.filter((doc) => {
      const data = doc.data() || {};
      return data.isActive !== false && data.isEnabled !== false &&
        !taperScheduleIds.has(doc.id) &&
        [0, 1].includes(Number(data.type));
    }).length;
    if (activeProtectCount < 1) return {allowed: true, premiumRequired: false};
  }
  await _assertPremiumEntitled(request.auth.uid);
  return {allowed: true, premiumRequired: true};
});

async function _enqueuePleaFallbackTask(pleaId, requesterUid) {
  const normalizedPleaId = (pleaId || "").toString().trim();
  const normalizedRequesterUid = (requesterUid || "").toString().trim();
  if (!normalizedPleaId || !normalizedRequesterUid) return false;

  try {
    const queue = getFunctions().taskQueue("evaluatePleaFallback");
    await queue.enqueue(
        {
          pleaId: normalizedPleaId,
          requesterUid: normalizedRequesterUid,
        },
        {
          scheduleDelaySeconds: AI_FALLBACK_DELAY_SECONDS,
        },
    );
    logger.info("AI fallback task enqueued.", {
      pleaId: normalizedPleaId,
      requesterUid: normalizedRequesterUid,
      delaySeconds: AI_FALLBACK_DELAY_SECONDS,
    });
    return true;
  } catch (error) {
    logger.error("AI fallback enqueue failed.", {
      pleaId: normalizedPleaId,
      requesterUid: normalizedRequesterUid,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    return false;
  }
}

async function _enqueuePleaForceKillTask(pleaId, requesterUid) {
  const normalizedPleaId = (pleaId || "").toString().trim();
  const normalizedRequesterUid = (requesterUid || "").toString().trim();
  if (!normalizedPleaId || !normalizedRequesterUid) return false;

  try {
    const queue = getFunctions().taskQueue("forceKillStaleTribunal");
    await queue.enqueue(
        {
          pleaId: normalizedPleaId,
          requesterUid: normalizedRequesterUid,
        },
        {
          scheduleDelaySeconds: AI_FORCE_KILL_DELAY_SECONDS,
        },
    );
    logger.info("Tribunal dead-man task enqueued.", {
      pleaId: normalizedPleaId,
      requesterUid: normalizedRequesterUid,
      delaySeconds: AI_FORCE_KILL_DELAY_SECONDS,
    });
    return true;
  } catch (error) {
    logger.error("Tribunal dead-man enqueue failed.", {
      pleaId: normalizedPleaId,
      requesterUid: normalizedRequesterUid,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    return false;
  }
}

// Vote migration flags.
// Keep dual-write enabled during migration so existing clients remain stable.
const ENABLE_LEGACY_PLEA_VOTE_MAP_WRITE = true;
// Keep this enabled until all client runtime paths no longer read plea.votes.
const ENABLE_LEGACY_PLEA_VOTE_MAP_SYNC = true;

const MOCK_SQUAD_ID = "mock_squad_core";
const MOCK_SQUAD_CODE = "MOCK-CORE";
const MOCK_USERS = [
  {
    uid: "mock_actor_azra",
    fullName: "Azra Kline",
    nickname: "Azra",
    email: "azra.actor@revoke.local",
    defaultFocusScore: 430,
  },
  {
    uid: "mock_actor_brynn",
    fullName: "Brynn Cole",
    nickname: "Brynn",
    email: "brynn.actor@revoke.local",
    defaultFocusScore: 410,
  },
  {
    uid: "mock_actor_cass",
    fullName: "Cass Vega",
    nickname: "Cass",
    email: "cass.actor@revoke.local",
    defaultFocusScore: 390,
  },
  {
    uid: "mock_actor_dima",
    fullName: "Dima Shore",
    nickname: "Dima",
    email: "dima.actor@revoke.local",
    defaultFocusScore: 370,
  },
  {
    uid: "mock_actor_eden",
    fullName: "Eden Mar",
    nickname: "Eden",
    email: "eden.actor@revoke.local",
    defaultFocusScore: 350,
  },
];

exports.broadcastPleaCreated = onDocumentCreated({
  document: "pleas/{pleaId}",
  region: "us-central1",
}, async (event) => {
  const pleaId = event.params?.pleaId;
  try {
    logger.info("Plea trigger received.", {
      pleaId,
      eventId: event.id,
      eventType: event.type,
    });

    const plea = event.data?.data();
    if (!plea) {
      logger.warn("Plea trigger fired with no document data.", {pleaId});
      return;
    }

    const squadId = plea.squadId;
    const requesterUid = plea.userId;
    const requesterName = (plea.userName || "A squad member").toString();
    const appName = (plea.appName || "an app").toString();
    const durationMinutes = Number(plea.durationMinutes) || 5;

    if (!squadId || !requesterUid) {
      logger.warn("Plea missing required routing fields.", {pleaId});
      return;
    }

    const visibleToUids = Array.isArray(plea.visibleToUids)
      ? [...new Set(plea.visibleToUids.map((id) => id?.toString().trim()).filter((id) => id))]
      : [];
    const recipientIds = visibleToUids.length > 0
      ? visibleToUids.filter((id) => id !== requesterUid)
      : (await db.collection("users").where("squadId", "==", squadId).get())
          .docs.map((doc) => doc.id).filter((id) => id !== requesterUid);
    const userSnaps = await Promise.all(
        recipientIds.map((uid) => db.collection("users").doc(uid).get()),
    );
    const memberSnaps = visibleToUids.length > 0
      ? await Promise.all(
          recipientIds.map((uid) => db.collection("squads").doc(squadId)
              .collection("members").doc(uid).get()),
      )
      : [];

    const tokens = [];
    const notificationRecipientIds = [];
    let optOutCount = 0;
    for (let index = 0; index < userSnaps.length; index += 1) {
      const data = userSnaps[index].data() || {};
      const memberUid = recipientIds[index];
      const token = (data.fcmToken || "").toString().trim();
      const permissions = memberSnaps[index]?.data()?.permissions || {};
      const hasV2ReceivePermission = visibleToUids.length === 0 ||
        permissions.receiveAccountabilityNotifications === true;
      const wantsReq = hasV2ReceivePermission &&
        data.notificationPrefs?.receiveAccountabilityNotifications !== false &&
        _wantsNotification(data, "pleaRequests");
      if (!memberUid) continue;
      if (!wantsReq) {
        optOutCount += 1;
        continue;
      }
      notificationRecipientIds.push(memberUid);
      if (!token) continue;
      tokens.push(token);
    }

    const uniqueNotificationRecipientIds = [...new Set(notificationRecipientIds)];
    const uniqueTokens = [...new Set(tokens)];
    const inAppBody = `${requesterName} requested temporary access to ${appName}.`;
    const inAppPromises = uniqueNotificationRecipientIds.map((memberId) =>
      createInAppNotification(memberId, {
        title: "Override request",
        body: inAppBody,
        type: "override_request",
        metadata: {
          pleaId: String(pleaId),
          squadId: String(squadId),
          requesterUid: String(requesterUid),
        },
      }),
    );
    const inAppResults = await Promise.all(inAppPromises);
    const inAppWrites = inAppResults.filter((created) => created).length;

    if (uniqueTokens.length === 0) {
      logger.info("No target tokens for plea broadcast.", {
        pleaId,
        squadId,
        inAppWrites,
      });
      return;
    }

    const title = "Override request";
    const body = inAppBody;
    let successCount = 0;
    let failureCount = 0;

    for (let i = 0; i < uniqueTokens.length; i += 500) {
      const tokenChunk = uniqueTokens.slice(i, i + 500);
      const response = await messaging.sendEachForMulticast({
        tokens: tokenChunk,
        notification: {
          title,
          body,
        },
        android: {
          notification: {
            channelId: "squad_alerts",
            sound: "lookatthisdude",
          },
        },
        data: {
          type: "override_request",
          event: "plea_created",
          pleaId: String(pleaId),
          squadId: String(squadId),
        },
      });

      successCount += response.successCount;
      failureCount += response.failureCount;

      response.responses.forEach((result, idx) => {
        if (result.success) return;
        logger.warn("Plea push failed for token.", {
          pleaId,
          squadId,
          tokenSuffix: tokenChunk[idx]?.slice(-8),
          errorCode: result.error?.code,
          errorMessage: result.error?.message,
        });
      });
    }

    logger.info("Plea broadcast completed.", {
      pleaId,
      squadId,
      inAppRecipients: uniqueNotificationRecipientIds.length,
      inAppWrites,
      recipients: uniqueTokens.length,
      optedOut: optOutCount,
      successCount,
      failureCount,
    });
  } catch (error) {
    logger.error("Plea broadcast crashed.", {
      pleaId,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw error;
  }
});

exports.resolvePleaVerdict = onDocumentWritten({
  document: "pleas/{pleaId}/votes/{voterUid}",
  region: "us-central1",
}, async (event) => {
  const pleaId = (event.params?.pleaId || "").toString().trim();
  const voterUid = (event.params?.voterUid || "").toString().trim();

  try {
    if (!pleaId || !voterUid) return;

    const beforeData = event.data?.before?.data() || {};
    const afterData = event.data?.after?.data() || {};
    const beforeChoice = _normalizeVoteChoice(beforeData.choice);
    const afterChoice = _normalizeVoteChoice(afterData.choice);
    const beforeVoteUid = (beforeData.uid || voterUid).toString().trim();
    const afterVoteUid = (afterData.uid || voterUid).toString().trim();

    if (
      beforeChoice === afterChoice &&
      beforeVoteUid === afterVoteUid
    ) {
      return;
    }

    const pleaRef = db.collection("pleas").doc(pleaId);
    const pleaSnap = await pleaRef.get();
    if (!pleaSnap.exists) {
      logger.warn("resolvePleaVerdict skipped missing plea.", {pleaId, voterUid});
      return;
    }

    const pleaData = pleaSnap.data() || {};
    const status = (pleaData.status || "active").toString().trim().toLowerCase();
    if (status !== "active") {
      logger.info("resolvePleaVerdict skipped non-active plea.", {
        pleaId,
        voterUid,
        status,
      });
      return;
    }

    const summary = await _computePleaVoteSummary(pleaRef, pleaData);
    const updates = _buildPleaVoteUpdates(pleaData, summary);

    if (!updates) {
      return;
    }

    await pleaRef.set(updates, {merge: true});

    if (updates.status) {
      await _sendPleaVerdictSideEffects({
        pleaId,
        pleaData,
        requesterId: summary.requesterId,
        verdict: updates.status,
        acceptVotes: summary.acceptVotes,
        rejectVotes: summary.rejectVotes,
        outcomeSource: "human_tribunal",
      });
    }

    logger.info("resolvePleaVerdict processed vote doc update.", {
      pleaId,
      voterUid,
      requesterId: summary.requesterId,
      participants: summary.participants.length,
      voters: summary.voters.length,
      votesCast: summary.votesCast,
      acceptVotes: summary.acceptVotes,
      rejectVotes: summary.rejectVotes,
      resolved: Boolean(updates.status),
      status: updates.status || (pleaData.status || "active"),
    });
  } catch (error) {
    logger.error("resolvePleaVerdict crashed.", {
      pleaId,
      voterUid,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw error;
  }
});

exports.recalculateShameLedger = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  if (request.auth.token?.admin !== true) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }

  try {
    const rejectedSnap = await db
        .collection("pleas")
        .where("status", "==", "rejected")
        .get();

    const rejectionByUser = {};
    for (const doc of rejectedSnap.docs) {
      const data = doc.data() || {};
      const userId = (data.userId || "").toString().trim();
      if (!userId) continue;
      rejectionByUser[userId] = (rejectionByUser[userId] || 0) + 1;
    }

    const shameLedger = Object.entries(rejectionByUser)
        .sort((a, b) => b[1] - a[1])
        .map(([userId, rejections], index) => ({
          rank: index + 1,
          userId,
          rejections,
        }));

    await db.doc("system/stats").set({
      shameLedger,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    logger.info("Shame ledger recalculated.", {
      totalRejectedPleas: rejectedSnap.size,
      uniqueUsers: shameLedger.length,
    });

    return {
      success: true,
      totalRejectedPleas: rejectedSnap.size,
      uniqueUsers: shameLedger.length,
    };
  } catch (error) {
    logger.error("recalculateShameLedger crashed.", {
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to recalculate shame ledger.");
  }
});

exports.broadcastSystemMandate = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  if (request.auth.token?.admin !== true) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }

  const title = (request.data?.title || "").toString().trim();
  const body = (request.data?.body || "").toString().trim();
  if (!title || !body) {
    throw new HttpsError("invalid-argument", "title and body are required.");
  }

  try {
    const usersSnap = await db.collection("users").get();
    const targetUserIds = usersSnap.docs
        .map((doc) => (doc.id || "").toString().trim())
        .filter((uid) => Boolean(uid));

    const messageId = await messaging.send({
      topic: "global_citizens",
      notification: {title, body},
      data: {
        type: "system",
        event: "broadcast",
        title,
        body,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "squad_alerts",
          sound: "lookatthisdude",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    const inAppWrites = await _createInAppNotificationsBatch(
        targetUserIds,
        {
          title,
          body,
          type: "system",
          metadata: {
          source: "admin_broadcast",
          messageId: String(messageId),
          actorUid: request.auth.uid,
          },
        },
    );

    logger.info("broadcastSystemMandate sent.", {
      actorUid: request.auth.uid,
      messageId,
      targetUsers: targetUserIds.length,
      inAppWrites,
    });
    return {
      success: true,
      messageId,
      targetUsers: targetUserIds.length,
      inAppWrites,
    };
  } catch (error) {
    logger.error("broadcastSystemMandate crashed.", {
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to broadcast system mandate.");
  }
});

exports.grantAmnesty = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  if (request.auth.token?.admin !== true) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }

  const targetUserId = (request.data?.targetUserId || "")
      .toString()
      .trim();
  const durationRaw = Number(request.data?.durationMinutes);
  const durationMinutes = Number.isFinite(durationRaw) && durationRaw > 0 ?
    Math.floor(durationRaw) : 60;

  if (!targetUserId) {
    throw new HttpsError("invalid-argument", "targetUserId is required.");
  }

  try {
    const userRef = db.collection("users").doc(targetUserId);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "Target user does not exist.");
    }

    const userData = userSnap.data() || {};
    const token = (userData.fcmToken || "").toString().trim();
    if (!token) {
      throw new HttpsError(
          "failed-precondition",
          "Target user has no FCM token.",
      );
    }

    const messageId = await messaging.send({
      token,
      data: {
        type: "AMNESTY",
        nativeAction: "com.revoke.app.AMNESTY_GRANTED",
        duration: String(durationMinutes),
        durationMinutes: String(durationMinutes),
      },
      android: {
        priority: "high",
      },
      apns: {
        headers: {"apns-priority": "10"},
        payload: {
          aps: {
            contentAvailable: true,
          },
        },
      },
    });

    logger.info("grantAmnesty sent.", {
      actorUid: request.auth.uid,
      targetUserId,
      durationMinutes,
      messageId,
    });

    return {success: true, targetUserId, durationMinutes, messageId};
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    logger.error("grantAmnesty crashed.", {
      targetUserId,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to grant amnesty.");
  }
});

exports.createPlea = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const callerUid = request.auth.uid;
  const isAdmin = request.auth.token?.admin === true;
  const payload = request.data || {};
  const allowedCreateKeys = new Set([
    "uid",
    "appName",
    "packageName",
    "durationMinutes",
    "reason",
  ]);
  for (const key of Object.keys(payload)) {
    if (!allowedCreateKeys.has(key)) {
      throw new HttpsError("invalid-argument", `Unexpected field: ${key}`);
    }
  }
  const requestedUid = (payload.uid || callerUid).toString().trim();
  if (!requestedUid) {
    throw new HttpsError("invalid-argument", "uid is required.");
  }
  if (!isAdmin && requestedUid !== callerUid) {
    throw new HttpsError("permission-denied", "Cannot create plea for another user.");
  }

  const appName = (payload.appName || "").toString().trim();
  const packageName = (payload.packageName || "").toString().trim();
  const reason = (payload.reason || "").toString().trim();
  const durationRaw = Number(payload.durationMinutes);
  const durationMinutes = Number.isFinite(durationRaw) ? Math.floor(durationRaw) : 0;

  if (!appName || appName.length > 80) {
    throw new HttpsError("invalid-argument", "appName must be 1-80 characters.");
  }
  if (!packageName || packageName.length > 180) {
    throw new HttpsError("invalid-argument", "packageName must be 1-180 characters.");
  }
  if (!reason || reason.length > 300) {
    throw new HttpsError("invalid-argument", "reason must be 1-300 characters.");
  }
  if (durationMinutes < 1 || durationMinutes > 120) {
    throw new HttpsError("invalid-argument", "durationMinutes must be between 1 and 120.");
  }

  try {
    const requesterRef = db.collection("users").doc(requestedUid);
    const limitsRef = db.collection("limits").doc(requestedUid);
    const pleaRef = db.collection("pleas").doc();
    const nowMs = Date.now();
    let createdStatus = "active";
    let outcomeSource = "human_tribunal";
    let usedWarden = false;

    await db.runTransaction(async (tx) => {
      const requesterSnap = await tx.get(requesterRef);
      if (!requesterSnap.exists) {
        throw new HttpsError("failed-precondition", "Requester user profile is missing.");
      }
      const requesterData = requesterSnap.data() || {};
      const squadId = (requesterData.squadId || "").toString().trim();
      if (!squadId) {
        throw new HttpsError(
            "failed-precondition",
            "Requester is not in a squad.",
            {
              reasonCode: "NO_SQUAD",
              requesterUid: requestedUid,
            },
        );
      }
      const squadRef = db.collection("squads").doc(squadId);
      const squadSnap = await tx.get(squadRef);
      if (!squadSnap.exists) {
        throw new HttpsError(
            "failed-precondition",
            "Requester squad is missing.",
            {
              reasonCode: "SQUAD_MISSING",
              requesterUid: requestedUid,
              squadId,
            },
        );
      }
      const squadData = squadSnap.data() || {};
      const rawMemberIds = Array.isArray(squadData.memberIds) ?
        squadData.memberIds :
        [];
      const normalizedMemberIds = [...new Set(
          rawMemberIds
              .map((id) => id?.toString().trim())
              .filter((id) => Boolean(id)),
      )];
      if (!normalizedMemberIds.includes(requestedUid)) {
        normalizedMemberIds.push(requestedUid);
      }
      const eligibleVoters = normalizedMemberIds.filter((id) => id !== requestedUid);
      const isSoloPlea = eligibleVoters.length === 0;

      const limitsSnap = await tx.get(limitsRef);
      const limits = limitsSnap.exists ? (limitsSnap.data() || {}) : {};
      const cutoffMs = nowMs - PLEA_CREATE_WINDOW_MS;
      const existingEvents = _pruneTimestamps(
          limits.pleaEvents,
          cutoffMs,
          50,
      );

      if (existingEvents.length >= PLEA_CREATE_MAX_PER_WINDOW) {
        const oldestRelevant = existingEvents[0] || nowMs;
        const retryAfterMs = Math.max(0, (oldestRelevant + PLEA_CREATE_WINDOW_MS) - nowMs);
        const retryAfterSeconds = Math.ceil(retryAfterMs / 1000);
        throw new HttpsError(
            "resource-exhausted",
            `Too many pleas. Try again in ~${retryAfterSeconds}s.`,
            {retryAfterSeconds},
        );
      }

      const userName = _deriveUserDisplayName(requesterData);
      const basePleaDoc = {
        userId: requestedUid,
        userName,
        squadId,
        appName,
        packageName,
        durationMinutes,
        reason,
        authority: "circle",
        visibleToUids: [requestedUid, ...eligibleVoters],
        eligibleVoterIds: eligibleVoters,
        requiredApprovalCount: _circleMajority(eligibleVoters.length),
        createdAt: FieldValue.serverTimestamp(),
        createdBy: callerUid,
      };

      if (isSoloPlea) {
        // Legacy createPlea has no explicit authority and cannot silently
        // choose a decision-maker. V2 self requests use recordSelfOverride;
        // legacy social requests require an actual eligible member.
        throw new HttpsError(
            "failed-precondition",
            "An explicit access authority is required for this request.",
            {reasonCode: "AUTHORITY_REQUIRED"},
        );
      } else {
        tx.set(pleaRef, {
          ...basePleaDoc,
          participants: [requestedUid],
          voteCounts: {accept: 0, reject: 0},
          votes: {},
          status: "active",
          outcomeSource: "circle_vote",
          eligibleVoterCount: eligibleVoters.length,
        });
      }

      tx.set(limitsRef, {
        pleaEvents: [...existingEvents, nowMs].slice(-50),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });

    logger.info("createPlea callable completed.", {
      actorUid: callerUid,
      requesterUid: requestedUid,
      pleaId: pleaRef.id,
      durationMinutes,
      appName,
      status: createdStatus,
      outcomeSource,
      usedWarden,
    });

    if (createdStatus === "active") {
      await _enqueuePleaForceKillTask(pleaRef.id, requestedUid);
    }

    // Best-effort squad log entry (outside transaction).
    try {
      const requesterSnap = await db.collection("users").doc(requestedUid).get();
      const requesterData = requesterSnap.exists ? (requesterSnap.data() || {}) : {};
      const squadId = (requesterData.squadId || "").toString().trim();
      const userName = _deriveUserDisplayName(requesterData);
      const userAvatar = (requesterData.photoUrl || "").toString().trim();
      const title = `${userName} requested temporary access to ${appName}.`;
      await logSquadEvent(
          squadId,
          "plea_request",
          title,
          {userId: requestedUid, userName, userAvatar},
          {
            pleaId: pleaRef.id,
            appName,
            packageName,
            durationMinutes,
            status: createdStatus,
            outcomeSource,
            usedWarden,
          },
      );
    } catch (_) {
      // Best-effort only.
    }

    return {
      success: true,
      pleaId: pleaRef.id,
      status: createdStatus,
      outcomeSource,
      usedWarden,
    };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("createPlea callable crashed.", {
      actorUid: callerUid,
      requesterUid: requestedUid,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to create plea.");
  }
});

exports.evaluatePleaFallback = onTaskDispatched({
  region: "us-central1",
  secrets: [openRouterKey],
  retryConfig: {
    maxAttempts: 1,
  },
  rateLimits: {
    maxConcurrentDispatches: 10,
  },
  timeoutSeconds: 120,
}, async (request) => {
  const pleaId = (request.data?.pleaId || "").toString().trim();
  const requesterUid = (request.data?.requesterUid || "").toString().trim();
  if (!pleaId) {
    logger.warn("evaluatePleaFallback skipped missing pleaId.");
    return;
  }

  const pleaRef = db.collection("pleas").doc(pleaId);

  try {
    const claim = await _claimPleaForAiFallback(pleaRef);

    if (claim.skipped) {
      logger.info("evaluatePleaFallback skipped.", {
        pleaId,
        requesterUid,
        reason: claim.reason,
        status: claim.status || null,
      });
      return;
    }

    const plea = claim.plea || {};
    const requesterId = (plea.userId || requesterUid || "").toString().trim();
    if (plea.authority === "ai" || plea.premiumRequired === true) {
      try {
        await _assertPremiumEntitled(requesterId);
      } catch (_) {
        // Premium expiry changes the effective authority for new AI work. A
        // pending request is closed safely without changing the saved policy,
        // so the user can renew and choose AI authority again later.
        await _finalizePleaWithAiDecision(pleaRef, pleaId, {
          decision: "reject",
          minutes: 0,
          rationale: "AI Architect requires an active Premium entitlement.",
        });
        return;
      }
    }
    const requesterSnap = requesterId ?
      await db.collection("users").doc(requesterId).get() :
      null;
    const requesterData = requesterSnap?.data() || {};
    const taperGoal = await _loadActiveTaperGoal(requesterId);
    const aiContext = _buildAiPleaContext(plea, requesterData, taperGoal);

    let decision = {
      decision: "reject",
      minutes: 0,
      rationale: "AI fallback failed safely.",
    };
    try {
      decision = await _callOpenRouterForPlea(aiContext);
    } catch (error) {
      logger.error("OpenRouter fallback call failed.", {
        pleaId,
        errorMessage: error?.message || String(error),
        errorStack: error?.stack,
      });
    }

    const result = await _finalizePleaWithAiDecision(pleaRef, pleaId, decision);
    logger.info("evaluatePleaFallback completed.", {
      pleaId,
      requesterUid: requesterId,
      skipped: result.skipped === true,
      skipReason: result.reason || null,
      decision: decision.decision,
      minutes: decision.minutes,
      verdict: result.verdict || null,
    });
  } catch (error) {
    logger.error("evaluatePleaFallback crashed.", {
      pleaId,
      requesterUid,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });

    try {
      await _finalizePleaWithAiDecision(pleaRef, pleaId, {
        decision: "reject",
        minutes: 0,
        rationale: "AI fallback encountered an internal error.",
      });
    } catch (fallbackError) {
      logger.error("Failed to safely reject after AI fallback crash.", {
        pleaId,
        errorMessage: fallbackError?.message || String(fallbackError),
      });
    }
  }
});

exports.forceKillStaleTribunal = onTaskDispatched({
  region: "us-central1",
  retryConfig: {
    maxAttempts: 1,
  },
  rateLimits: {
    maxConcurrentDispatches: 10,
  },
  timeoutSeconds: 60,
}, async (request) => {
  const pleaId = (request.data?.pleaId || "").toString().trim();
  const requesterUid = (request.data?.requesterUid || "").toString().trim();
  if (!pleaId) {
    logger.warn("forceKillStaleTribunal skipped missing pleaId.");
    return;
  }

  const pleaRef = db.collection("pleas").doc(pleaId);
  const systemText =
    "This access request expired before a decision was available.";

  try {
    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(pleaRef);
      if (!snap.exists) return {skipped: true, reason: "missing"};

      const plea = snap.data() || {};
      const status = (plea.status || "active").toString().trim().toLowerCase();
      const authority = _normalizeV2Authority(plea.authority);
      const expectedStatus = authority === "circle" ? "active" : "pending";
      if (status !== expectedStatus) {
        return {skipped: true, reason: "not_pending", status};
      }

      tx.set(pleaRef, {
        status: "rejected",
        voteCounts: {accept: 0, reject: 1},
        resolvedAt: FieldValue.serverTimestamp(),
        outcomeSource: authority === "circle" ? "circle_timeout" : "ai_deadman",
        ...(authority === "ai" ? {
          aiFallbackStatus: "force_rejected",
          aiResolvedAt: FieldValue.serverTimestamp(),
          aiFallbackDecision: "rejected",
          aiFallbackMinutes: 0,
          aiFallbackRationale: systemText,
        } : {}),
      }, {merge: true});
      tx.set(pleaRef.collection("messages").doc(), {
        text: systemText,
        senderId: "SYSTEM",
        senderName: "Revoke",
        isSystem: true,
        timestamp: FieldValue.serverTimestamp(),
      });

      return {
        skipped: false,
        plea,
        requesterId: (plea.userId || requesterUid || "").toString().trim(),
      };
    });

    if (!result.skipped) {
      await _sendPleaVerdictSideEffects({
        pleaId,
        pleaData: result.plea,
        requesterId: result.requesterId,
        verdict: "rejected",
        acceptVotes: 0,
        rejectVotes: 1,
        outcomeSource: _normalizeV2Authority(result.plea?.authority) === "circle"
          ? "circle_timeout"
          : "ai_deadman",
      });
    }

    logger.info("forceKillStaleTribunal completed.", {
      pleaId,
      requesterUid,
      skipped: result.skipped === true,
      reason: result.reason || null,
      status: result.status || null,
    });
  } catch (error) {
    logger.error("forceKillStaleTribunal crashed.", {
      pleaId,
      requesterUid,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
  }
});

exports.sendPleaMessage = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const isAdmin = request.auth.token?.admin === true;
  const payload = request.data || {};
  const allowedKeys = new Set(["pleaId", "text"]);
  for (const key of Object.keys(payload)) {
    if (!allowedKeys.has(key)) {
      throw new HttpsError("invalid-argument", `Unexpected field: ${key}`);
    }
  }

  const pleaId = (payload.pleaId || "").toString().trim();
  const text = (payload.text || "").toString().trim();
  if (!pleaId) {
    throw new HttpsError("invalid-argument", "pleaId is required.");
  }
  if (!text) {
    throw new HttpsError("invalid-argument", "text is required.");
  }
  if (text.length > MESSAGE_MAX_LEN) {
    throw new HttpsError("invalid-argument", `text must be <= ${MESSAGE_MAX_LEN} chars.`);
  }

  const pleaRef = db.collection("pleas").doc(pleaId);
  const userRef = db.collection("users").doc(uid);
  const limitsRef = db.collection("limits").doc(uid);
  const nowMs = Date.now();

  try {
    const messageId = await db.runTransaction(async (tx) => {
      const pleaSnap = await tx.get(pleaRef);
      if (!pleaSnap.exists) {
        throw new HttpsError("not-found", "Plea not found.");
      }
      const plea = pleaSnap.data() || {};
      const status = (plea.status || "active").toString().trim().toLowerCase();
      if (status !== "active" && status !== "pending") {
        throw new HttpsError("failed-precondition", "Tribunal is closed.");
      }

      if (!isAdmin) {
        const userSnap = await tx.get(userRef);
        if (!userSnap.exists) {
          throw new HttpsError("failed-precondition", "User profile is missing.");
        }
        const userData = userSnap.data() || {};
        const fixedVoters = _normalizeParticipantIds(plea.eligibleVoterIds);
        if (Array.isArray(plea.visibleToUids) && !plea.visibleToUids.includes(uid)) {
          throw new HttpsError("permission-denied", "User cannot message this request.");
        }
        if (Array.isArray(plea.eligibleVoterIds) && uid !== plea.userId) {
          const memberRef = db.collection("squads").doc((plea.squadId || "").toString().trim())
              .collection("members").doc(uid);
          const memberSnap = await tx.get(memberRef);
          const permissions = memberSnap.data()?.permissions || {};
          if (!fixedVoters.includes(uid) || permissions.participateInOverrideDiscussion !== true) {
            throw new HttpsError("permission-denied", "Discussion permission is not enabled.");
          }
        } else if (!Array.isArray(plea.eligibleVoterIds)) {
          const userSquadId = (userData.squadId || "").toString().trim();
          const pleaSquadId = (plea.squadId || "").toString().trim();
          if (!userSquadId || userSquadId !== pleaSquadId) {
            throw new HttpsError("permission-denied", "User cannot message this tribunal.");
          }
        }

        const limitsSnap = await tx.get(limitsRef);
        const limits = limitsSnap.exists ? (limitsSnap.data() || {}) : {};

        const lastMessageAt = Number(limits.lastMessageAt) || 0;
        const sinceLast = nowMs - lastMessageAt;
        if (sinceLast >= 0 && sinceLast < MESSAGE_COOLDOWN_MS) {
          const retryAfterSeconds = Math.ceil((MESSAGE_COOLDOWN_MS - sinceLast) / 1000);
          throw new HttpsError(
              "resource-exhausted",
              `Slow down. Try again in ~${retryAfterSeconds}s.`,
              {retryAfterSeconds},
          );
        }

        const cutoffMs = nowMs - MESSAGE_WINDOW_MS;
        const existingEvents = _pruneTimestamps(
            limits.messageEvents,
            cutoffMs,
            120,
        );
        if (existingEvents.length >= MESSAGE_MAX_PER_WINDOW) {
          const oldestRelevant = existingEvents[0] || nowMs;
          const retryAfterMs = Math.max(0, (oldestRelevant + MESSAGE_WINDOW_MS) - nowMs);
          const retryAfterSeconds = Math.ceil(retryAfterMs / 1000);
          throw new HttpsError(
              "resource-exhausted",
              `Too many messages. Try again in ~${retryAfterSeconds}s.`,
              {retryAfterSeconds},
          );
        }

        tx.set(limitsRef, {
          messageEvents: [...existingEvents, nowMs].slice(-120),
          lastMessageAt: nowMs,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});

        // Attendance: sending a message implies being present in the room.
        tx.update(pleaRef, {
          participants: FieldValue.arrayUnion(uid),
          lastMessageAt: FieldValue.serverTimestamp(),
        });

        const senderName = _deriveUserDisplayName(userData);
        const messageRef = pleaRef.collection("messages").doc();
        tx.set(messageRef, {
          senderId: uid,
          senderName,
          text,
          isSystem: false,
          timestamp: FieldValue.serverTimestamp(),
        });
        return messageRef.id;
      }

      // Admin messages should use the admin tools (Architect/system) instead.
      throw new HttpsError(
          "failed-precondition",
          "Admin should use Architect messaging tools.",
      );
    });

    return {success: true, pleaId, messageId};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("sendPleaMessage callable crashed.", {
      uid,
      pleaId,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to send message.");
  }
});

exports.castVote = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const isAdmin = request.auth.token?.admin === true;
  const payload = request.data || {};
  const allowedVoteKeys = new Set(["pleaId", "choice"]);
  for (const key of Object.keys(payload)) {
    if (!allowedVoteKeys.has(key)) {
      throw new HttpsError("invalid-argument", `Unexpected field: ${key}`);
    }
  }
  const pleaId = (payload.pleaId || "").toString().trim();
  const choice = (payload.choice || "").toString().trim().toLowerCase();

  if (!pleaId) {
    throw new HttpsError("invalid-argument", "pleaId is required.");
  }
  if (choice !== "accept" && choice !== "reject") {
    throw new HttpsError("invalid-argument", "choice must be 'accept' or 'reject'.");
  }

  const pleaRef = db.collection("pleas").doc(pleaId);
  try {
    await db.runTransaction(async (tx) => {
      const pleaSnap = await tx.get(pleaRef);
      if (!pleaSnap.exists) {
        throw new HttpsError("not-found", "Plea not found.");
      }
      const plea = pleaSnap.data() || {};

      const status = (plea.status || "active").toString().trim().toLowerCase();
      if (status !== "active") {
        throw new HttpsError("failed-precondition", "Plea is already resolved.");
      }

      const requesterId = (plea.userId || "").toString().trim();
      if (!isAdmin && requesterId === uid) {
        throw new HttpsError("failed-precondition", "Requester cannot vote on own plea.");
      }

      if (!isAdmin) {
        const fixedVoters = _normalizeParticipantIds(plea.eligibleVoterIds);
        if (Array.isArray(plea.eligibleVoterIds) && !fixedVoters.includes(uid)) {
          throw new HttpsError("permission-denied", "You are not an eligible voter for this request.");
        }
        // V2 requests carry an immutable voter snapshot. Permission changes
        // after creation must not silently change the quorum for that request.
        if (!Array.isArray(plea.eligibleVoterIds)) {
          const callerRef = db.collection("users").doc(uid);
          const callerSnap = await tx.get(callerRef);
          const callerSquadId = (callerSnap.data()?.squadId || "").toString().trim();
          const pleaSquadId = (plea.squadId || "").toString().trim();
          if (!callerSnap.exists || !callerSquadId || callerSquadId !== pleaSquadId) {
            throw new HttpsError("permission-denied", "User is not allowed to vote on this request.");
          }
        }
      }

      const voteRef = pleaRef.collection("votes").doc(uid);
      const existingVoteSnap = await tx.get(voteRef);

      const votePayload = {
        uid,
        choice,
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (!existingVoteSnap.exists) {
        votePayload.createdAt = FieldValue.serverTimestamp();
      }

      tx.set(voteRef, votePayload, {merge: true});

      const pleaUpdates = {
        participants: FieldValue.arrayUnion(uid),
        lastVoteAt: FieldValue.serverTimestamp(),
      };
      if (ENABLE_LEGACY_PLEA_VOTE_MAP_WRITE) {
        pleaUpdates[`votes.${uid}`] = choice;
      }

      tx.update(pleaRef, pleaUpdates);
    });

    logger.info("castVote callable completed.", {
      uid,
      pleaId,
      choice,
    });
    return {success: true, pleaId, choice};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("castVote callable crashed.", {
      uid,
      pleaId,
      choice,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to cast vote.");
  }
});

exports.backfillPleaVoteSubcollection = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  if (request.auth.token?.admin !== true) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }

  const payload = request.data || {};
  const allowedKeys = new Set(["limit", "cursor", "dryRun"]);
  for (const key of Object.keys(payload)) {
    if (!allowedKeys.has(key)) {
      throw new HttpsError("invalid-argument", `Unexpected field: ${key}`);
    }
  }

  const requestedLimit = Number(payload.limit);
  const normalizedLimit = Number.isFinite(requestedLimit) ?
    Math.floor(requestedLimit) : 25;
  const limit = Math.min(Math.max(normalizedLimit, 1), 100);
  const cursor = (payload.cursor || "").toString().trim();
  const dryRun = payload.dryRun === true;

  try {
    let query = db.collection("pleas").orderBy("__name__").limit(limit);
    if (cursor) {
      query = query.startAfter(cursor);
    }

    const pleasSnap = await query.get();
    if (pleasSnap.empty) {
      return {
        success: true,
        dryRun,
        scannedPleas: 0,
        touchedPleas: 0,
        writtenVoteDocs: 0,
        nextCursor: "",
      };
    }

    let scannedPleas = 0;
    let touchedPleas = 0;
    let writtenVoteDocs = 0;

    for (const pleaDoc of pleasSnap.docs) {
      scannedPleas += 1;
      const pleaRef = pleaDoc.ref;
      const pleaData = pleaDoc.data() || {};
      const legacyVotes = _normalizeVotes(pleaData.votes);
      if (Object.keys(legacyVotes).length === 0) continue;

      const existingVoteDocs = await _loadVoteSubcollectionVotes(pleaRef);
      const writes = [];
      for (const [uid, choice] of Object.entries(legacyVotes)) {
        if (existingVoteDocs[uid] === choice) continue;
        writes.push({uid, choice});
      }

      if (writes.length === 0 && !ENABLE_LEGACY_PLEA_VOTE_MAP_SYNC) {
        continue;
      }

      touchedPleas += 1;

      if (!dryRun && writes.length > 0) {
        const batch = db.batch();
        for (const write of writes) {
          const voteRef = pleaRef.collection("votes").doc(write.uid);
          batch.set(voteRef, {
            uid: write.uid,
            choice: write.choice,
            migratedFromLegacy: true,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
        }
        await batch.commit();
      }

      writtenVoteDocs += writes.length;

      if (!dryRun) {
        const refreshedPlea = await pleaRef.get();
        if (!refreshedPlea.exists) continue;

        const refreshedData = refreshedPlea.data() || {};
        const summary = await _computePleaVoteSummary(pleaRef, refreshedData);
        const updates = _buildPleaVoteUpdates(refreshedData, summary) || {};
        updates.voteMigration = {
          backfilledAt: FieldValue.serverTimestamp(),
          backfilledBy: request.auth.uid,
        };

        await pleaRef.set(updates, {merge: true});
      }
    }

    const nextCursor = pleasSnap.docs[pleasSnap.docs.length - 1]?.id || "";

    logger.info("backfillPleaVoteSubcollection completed.", {
      actorUid: request.auth.uid,
      dryRun,
      cursor: cursor || null,
      limit,
      scannedPleas,
      touchedPleas,
      writtenVoteDocs,
      nextCursor: nextCursor || null,
    });

    return {
      success: true,
      dryRun,
      scannedPleas,
      touchedPleas,
      writtenVoteDocs,
      nextCursor,
    };
  } catch (error) {
    logger.error("backfillPleaVoteSubcollection crashed.", {
      actorUid: request.auth.uid,
      dryRun,
      limit,
      cursor: cursor || null,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to backfill plea vote docs.");
  }
});

exports.recordBlockedAttempt = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const payload = request.data || {};
  const allowedKeys = new Set(["packageName", "appName", "blockedAtMs", "eventDay"]);
  for (const key of Object.keys(payload)) {
    if (!allowedKeys.has(key)) {
      throw new HttpsError("invalid-argument", `Unexpected field: ${key}`);
    }
  }

  const packageName = (payload.packageName || "").toString().trim();
  const appName = (payload.appName || "").toString().trim();
  const eventDayRaw = (payload.eventDay || "").toString().trim();
  const blockedAtRaw = Number(payload.blockedAtMs);

  if (!packageName) {
    throw new HttpsError("invalid-argument", "packageName is required.");
  }
  if (packageName.length > 180) {
    throw new HttpsError("invalid-argument", "packageName exceeds max length.");
  }
  if (appName.length > 100) {
    throw new HttpsError("invalid-argument", "appName exceeds max length.");
  }

  const nowMs = Date.now();
  let eventMs = nowMs;
  if (Number.isFinite(blockedAtRaw)) {
    const normalized = Math.floor(blockedAtRaw);
    // Accept client event timestamps only if they are close to server time.
    if (Math.abs(normalized - nowMs) <= 5 * 60 * 1000) {
      eventMs = normalized;
    }
  }

  const eventDay = /^\d{4}-\d{2}-\d{2}$/.test(eventDayRaw) ?
    eventDayRaw :
    _dateOnlyUtc(eventMs);

  const limitsRef = db.collection("limits").doc(uid);
  const dayStatsRef = db.collection("users").doc(uid).collection("focusStats").doc(eventDay);
  const scoreEventRef = db.collection("users").doc(uid).collection("scoreEvents").doc();

  let deduped = false;
  let throttled = false;
  let written = false;

  try {
    await db.runTransaction(async (tx) => {
      const limitsSnap = await tx.get(limitsRef);
      const limits = limitsSnap.exists ? (limitsSnap.data() || {}) : {};

      const events = _pruneTimestamps(
          limits.blockedAttemptEvents,
          eventMs - (24 * 60 * 60 * 1000),
          500,
      );

      const lastPackage = (limits.blockedAttemptLastPackage || "").toString().trim();
      const lastAtMs = Number(limits.blockedAttemptLastAtMs) || 0;
      if (lastPackage === packageName && eventMs - lastAtMs < 4000) {
        deduped = true;
        tx.set(limitsRef, {
          blockedAttemptLastAtMs: eventMs,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return;
      }

      const recentWindowStart = eventMs - 60 * 1000;
      const recentEvents = events.filter((ts) => ts >= recentWindowStart);
      if (recentEvents.length >= 30) {
        throttled = true;
        tx.set(limitsRef, {
          blockedAttemptEvents: events,
          blockedAttemptLastPackage: packageName,
          blockedAttemptLastAtMs: eventMs,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return;
      }

      const nextEvents = [...events, eventMs].slice(-500);
      tx.set(limitsRef, {
        blockedAttemptEvents: nextEvents,
        blockedAttemptLastPackage: packageName,
        blockedAttemptLastAtMs: eventMs,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});

      tx.set(scoreEventRef, {
        type: "blocked_attempt",
        packageName,
        appName: appName || packageName,
        source: "native_overlay",
        eventDay,
        createdAtMs: eventMs,
        createdAt: FieldValue.serverTimestamp(),
      });

      tx.set(dayStatsRef, {
        day: eventDay,
        blockedAttempts: FieldValue.increment(1),
        lastBlockedPackage: packageName,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});

      written = true;
    });

    return {
      success: true,
      deduped,
      throttled,
      written,
      eventDay,
    };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("recordBlockedAttempt crashed.", {
      uid,
      packageName,
      eventDay,
      deduped,
      throttled,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to record blocked attempt.");
  }
});

exports.joinPleaSession = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const isAdmin = request.auth.token?.admin === true;
  const pleaId = (request.data?.pleaId || "").toString().trim();
  if (!pleaId) {
    throw new HttpsError("invalid-argument", "pleaId is required.");
  }

  const pleaRef = db.collection("pleas").doc(pleaId);
  try {
    const pleaSnap = await pleaRef.get();
    if (!pleaSnap.exists) {
      throw new HttpsError("not-found", "Plea not found.");
    }
    const plea = pleaSnap.data() || {};
    const status = (plea.status || "active").toString().trim().toLowerCase();
    if (status !== "active") {
      return {success: true, pleaId, active: false};
    }

    if (!isAdmin) {
      await _assertUserCanAccessPlea(uid, plea);
      if (Array.isArray(plea.eligibleVoterIds) && uid !== plea.userId) {
        const memberRef = db.collection("squads").doc((plea.squadId || "").toString().trim())
            .collection("members").doc(uid);
        const memberSnap = await memberRef.get();
        if (!memberSnap.exists || memberSnap.data()?.permissions?.participateInOverrideDiscussion !== true) {
          throw new HttpsError("permission-denied", "Discussion permission is not enabled.");
        }
      }
    }

    await pleaRef.set({
      participants: FieldValue.arrayUnion(uid),
      lastJoinAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return {success: true, pleaId, active: true};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("joinPleaSession callable crashed.", {
      uid,
      pleaId,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to join plea session.");
  }
});

exports.markPleaForDeletion = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const isAdmin = request.auth.token?.admin === true;
  const pleaId = (request.data?.pleaId || "").toString().trim();
  if (!pleaId) {
    throw new HttpsError("invalid-argument", "pleaId is required.");
  }

  try {
    const pleaRef = db.collection("pleas").doc(pleaId);
    const pleaSnap = await pleaRef.get();
    if (!pleaSnap.exists) {
      return {success: true, pleaId, existed: false};
    }
    const plea = pleaSnap.data() || {};
    if (!isAdmin) {
      await _assertUserCanAccessPlea(uid, plea);
      if (uid !== plea.userId) {
        throw new HttpsError("permission-denied", "Only the requester can remove this history item.");
      }
    }

    await pleaRef.set({
      markedForDeletion: true,
      deletionMarkedAt: FieldValue.serverTimestamp(),
      deletionMarkedBy: uid,
    }, {merge: true});

    return {success: true, pleaId, existed: true};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("markPleaForDeletion callable crashed.", {
      uid,
      pleaId,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to mark plea for deletion.");
  }
});

exports.syncRapSheetSnapshotOnPleaWrite = onDocumentWritten({
  region: "us-central1",
  document: "pleas/{pleaId}",
}, async (event) => {
  const pleaId = (event.params?.pleaId || "").toString().trim();
  const after = event.data?.after?.data() || null;
  const before = event.data?.before?.data() || null;
  const uid = (after?.userId || before?.userId || "").toString().trim();
  if (!uid) return;

  try {
    await buildRapSheetSnapshot(uid, {
      source: "plea_write",
      pleaId,
    });
  } catch (error) {
    logger.error("syncRapSheetSnapshotOnPleaWrite crashed.", {
      uid,
      pleaId,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
  }
});

exports.syncRapSheetSnapshotOnBlockedAttempt = onDocumentCreated({
  region: "us-central1",
  document: "users/{uid}/scoreEvents/{eventId}",
}, async (event) => {
  const uid = (event.params?.uid || "").toString().trim();
  const eventId = (event.params?.eventId || "").toString().trim();
  const scoreEvent = event.data?.data() || {};
  if (!uid) return;
  if ((scoreEvent.type || "").toString().trim().toLowerCase() !== "blocked_attempt") {
    return;
  }

  try {
    await buildRapSheetSnapshot(uid, {
      source: "blocked_attempt",
      eventId,
    });
  } catch (error) {
    logger.error("syncRapSheetSnapshotOnBlockedAttempt crashed.", {
      uid,
      eventId,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
  }
});

exports.getMemberRapSheetSnapshot = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const isAdmin = request.auth.token?.admin === true;
  const payload = request.data || {};
  const allowedKeys = new Set(["targetUid"]);
  for (const key of Object.keys(payload)) {
    if (!allowedKeys.has(key)) {
      throw new HttpsError("invalid-argument", `Unexpected field: ${key}`);
    }
  }

  const targetUid = (payload.targetUid || "").toString().trim();
  if (!targetUid) {
    throw new HttpsError("invalid-argument", "targetUid is required.");
  }

  try {
    const targetUser = await _loadUserProfileOrThrow(targetUid, "Target");
    if (!targetUser.squadId) {
      throw new HttpsError("failed-precondition", "Target user is not in a squad.");
    }

    if (!isAdmin) {
      const actorUser = await _loadUserProfileOrThrow(uid, "Actor");
      if (!actorUser.squadId || actorUser.squadId !== targetUser.squadId) {
        throw new HttpsError(
            "permission-denied",
            "User is not allowed to view this member snapshot.",
        );
      }
    }

    const regimeSummary = await _buildRegimeProtocolSummary(targetUid);
    let rapSheetSnapshot = await _loadRapSheetSnapshotDoc(targetUid);
    if (!rapSheetSnapshot) {
      rapSheetSnapshot = await buildRapSheetSnapshot(targetUid, {
        source: "callable_fallback",
        actorUid: uid,
      });
    }

    const snapshot = {
      targetUid,
      squadId: targetUser.squadId,
      activeProtocols: regimeSummary.activeProtocols,
      activeProtocolCount: regimeSummary.activeProtocols.length,
      blacklistApps: regimeSummary.blacklistApps,
      blacklistCount: regimeSummary.blacklistApps.length,
      pleaStats: rapSheetSnapshot?.pleaStats || {
        total: 0,
        approved: 0,
        rejected: 0,
      },
      latestInfractions: Array.isArray(rapSheetSnapshot?.latestInfractions) ?
        rapSheetSnapshot.latestInfractions :
        [],
      updatedAtMs: Number(rapSheetSnapshot?.updatedAtMs) || Date.now(),
      version: Number(rapSheetSnapshot?.version) || RAP_SHEET_VERSION,
    };

    return {
      success: true,
      snapshot,
    };
  } catch (error) {
    if (error instanceof HttpsError) throw error;

    logger.error("getMemberRapSheetSnapshot crashed.", {
      uid,
      targetUid,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to get member snapshot.");
  }
});

async function buildRapSheetSnapshot(uid, cause) {
  const normalizedUid = (uid || "").toString().trim();
  if (!normalizedUid) return null;

  const causeMeta = cause && typeof cause === "object" ? cause : {
    source: (cause || "unknown").toString(),
  };
  const userRef = db.collection("users").doc(normalizedUid);
  const snapshotRef = userRef.collection("rapSheet").doc("latest");
  const userSnap = await userRef.get();

  if (!userSnap.exists) {
    try {
      await snapshotRef.delete();
    } catch (_) {}
    return null;
  }

  const userData = userSnap.data() || {};
  const squadId = (userData.squadId || "").toString().trim();
  const pleas = await _loadUserPleasForRapSheet(normalizedUid, squadId);
  const blockedAttempts = await _loadBlockedAttemptInfractions(normalizedUid);
  const pleaStats = _computeRapSheetPleaStats(pleas);
  const latestInfractions = _mergeLatestInfractions([
    ..._buildPleaInfractions(pleas),
    ...blockedAttempts,
  ]);
  const updatedAtMs = Date.now();

  const snapshotData = {
    uid: normalizedUid,
    squadId,
    pleaStats,
    latestInfractions,
    updatedAtMs,
    version: RAP_SHEET_VERSION,
  };

  await snapshotRef.set({
    ...snapshotData,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  logger.info("buildRapSheetSnapshot completed.", {
    uid: normalizedUid,
    squadId,
    cause: causeMeta,
    infractionCount: latestInfractions.length,
  });

  return snapshotData;
}

async function _loadRapSheetSnapshotDoc(uid) {
  const normalizedUid = (uid || "").toString().trim();
  if (!normalizedUid) return null;
  const snap = await db
      .collection("users")
      .doc(normalizedUid)
      .collection("rapSheet")
      .doc("latest")
      .get();
  return snap.exists ? (snap.data() || null) : null;
}

async function _buildRegimeProtocolSummary(uid) {
  const normalizedUid = (uid || "").toString().trim();
  if (!normalizedUid) {
    return {activeProtocols: [], blacklistApps: []};
  }

  const regimesSnap = await db
      .collection("users")
      .doc(normalizedUid)
      .collection("regimes")
      .get();

  const activeProtocols = new Set();
  const blacklistApps = new Set();

  for (const regimeDoc of regimesSnap.docs) {
    const regime = regimeDoc.data() || {};
    const isEnabled = Boolean(regime.isEnabled ?? regime.isActive ?? true);
    if (!isEnabled) continue;

    const regimeName = (regime.name || "").toString().trim();
    if (regimeName) {
      activeProtocols.add(regimeName);
    }

    const targets = Array.isArray(regime.targetApps) ?
      regime.targetApps :
      (Array.isArray(regime.apps) ? regime.apps : []);
    for (const app of targets) {
      const appName = (app || "").toString().trim();
      if (appName) blacklistApps.add(appName);
    }
  }

  return {
    activeProtocols: [...activeProtocols].sort((a, b) => a.localeCompare(b)),
    blacklistApps: [...blacklistApps].sort((a, b) => a.localeCompare(b)),
  };
}

async function _loadUserPleasForRapSheet(uid, squadId) {
  if (!squadId) return [];

  const pleasSnap = await db
      .collection("pleas")
      .where("squadId", "==", squadId)
      .where("userId", "==", uid)
      .get();

  return pleasSnap.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  }));
}

function _computeRapSheetPleaStats(pleas) {
  let approved = 0;
  let rejected = 0;

  for (const plea of pleas) {
    const status = (plea.status || "").toString().trim().toLowerCase();
    if (status === "approved") approved += 1;
    if (status === "rejected") rejected += 1;
  }

  return {
    total: pleas.length,
    approved,
    rejected,
  };
}

function _buildPleaInfractions(pleas) {
  return pleas
      .map((plea) => ({
        kind: "plea",
        sourceId: (plea.id || "").toString().trim(),
        status: (plea.status || "active").toString().trim().toLowerCase(),
        appName: (plea.appName || "").toString().trim(),
        packageName: (plea.packageName || "").toString().trim(),
        occurredAtMs: _resolvePleaOccurredAtMs(plea),
      }))
      .filter((entry) => entry.sourceId && entry.occurredAtMs > 0);
}

async function _loadBlockedAttemptInfractions(uid) {
  const scoreEventsSnap = await db
      .collection("users")
      .doc(uid)
      .collection("scoreEvents")
      .orderBy("createdAtMs", "desc")
      .limit(RAP_SHEET_QUERY_LIMIT)
      .get();

  return scoreEventsSnap.docs
      .map((doc) => ({
        sourceId: doc.id,
        ...doc.data(),
      }))
      .filter((event) =>
        (event.type || "").toString().trim().toLowerCase() === "blocked_attempt",
      )
      .map((event) => ({
        kind: "blocked_attempt",
        sourceId: (event.sourceId || "").toString().trim(),
        status: "",
        appName: (event.appName || "").toString().trim(),
        packageName: (event.packageName || "").toString().trim(),
        occurredAtMs: _resolveScoreEventOccurredAtMs(event),
      }))
      .filter((entry) => entry.sourceId && entry.occurredAtMs > 0);
}

function _mergeLatestInfractions(infractions) {
  const deduped = new Map();
  const sorted = infractions
      .filter((entry) => entry && entry.kind && entry.sourceId)
      .sort((a, b) => (Number(b.occurredAtMs) || 0) - (Number(a.occurredAtMs) || 0));

  for (const entry of sorted) {
    const key = `${entry.kind}:${entry.sourceId}`;
    if (!deduped.has(key)) {
      deduped.set(key, {
        kind: entry.kind,
        sourceId: entry.sourceId,
        status: entry.status || "",
        appName: entry.appName || "",
        packageName: entry.packageName || "",
        occurredAtMs: Number(entry.occurredAtMs) || 0,
      });
    }
    if (deduped.size >= RAP_SHEET_MAX_INFRACTIONS) break;
  }

  return [...deduped.values()];
}

function _resolvePleaOccurredAtMs(plea) {
  const resolvedAtMs = _timestampToMillis(plea.resolvedAt);
  if (resolvedAtMs > 0) return resolvedAtMs;

  const explicitMs = Number(plea.resolvedAtMs || plea.createdAtMs);
  if (Number.isFinite(explicitMs) && explicitMs > 0) {
    return Math.floor(explicitMs);
  }

  return _timestampToMillis(plea.createdAt);
}

function _resolveScoreEventOccurredAtMs(event) {
  const explicitMs = Number(event.createdAtMs);
  if (Number.isFinite(explicitMs) && explicitMs > 0) {
    return Math.floor(explicitMs);
  }
  return _timestampToMillis(event.createdAt);
}

function _normalizeV2Authority(value) {
  const normalized = (value || "").toString().trim().toLowerCase();
  return OVERRIDE_AUTHORITIES.includes(normalized) ? normalized : "";
}

function _circlePresetPermissions(preset) {
  const all = Object.fromEntries(CIRCLE_PERMISSIONS.map((key) => [key, true]));
  switch (preset) {
    case "accountabilityPartner":
      return all;
    case "guardian":
      return all;
    case "observer":
      return {...CIRCLE_DEFAULT_PERMISSIONS, receiveAccountabilityNotifications: true};
    case "custom":
    default:
      return {...CIRCLE_DEFAULT_PERMISSIONS};
  }
}

function _sanitizeCirclePermissions(rawPermissions, preset) {
  const source = rawPermissions && typeof rawPermissions === "object" ?
    rawPermissions : _circlePresetPermissions(preset);
  const normalized = {};
  for (const key of CIRCLE_PERMISSIONS) {
    normalized[key] = source[key] === true;
  }
  return normalized;
}

function _circleMajority(count) {
  const safeCount = Number.isFinite(Number(count)) ? Math.max(0, Math.floor(Number(count))) : 0;
  return safeCount === 0 ? 0 : Math.floor(safeCount / 2) + 1;
}

function _buildCircleMemberSummary(uid, userData, existingData, role) {
  const existingPermissions = existingData?.permissions;
  const preset = CIRCLE_PRESETS.includes(existingData?.preset) ?
    existingData.preset : "custom";
  const permissions = existingPermissions && typeof existingPermissions === "object" ?
    _sanitizeCirclePermissions(existingPermissions, preset) :
    _sanitizeCirclePermissions(
        role === "owner" ? _circlePresetPermissions("guardian") : null,
        role === "owner" ? "guardian" : "custom",
    );
  return {
    uid,
    displayName: _deriveUserDisplayName(userData),
    avatarUrl: (userData?.photoUrl || "").toString().trim(),
    role,
    preset,
    permissions,
    updatedAt: FieldValue.serverTimestamp(),
  };
}

exports.syncCircleMemberSummaries = onDocumentWritten({
  document: "squads/{squadId}",
  region: "us-central1",
}, async (event) => {
  const squadId = (event.params?.squadId || "").toString().trim();
  const squad = event.data?.after?.data();
  if (!squadId || !squad) return;
  const memberIds = [...new Set(
      (Array.isArray(squad.memberIds) ? squad.memberIds : [])
          .map((uid) => uid?.toString().trim())
          .filter((uid) => Boolean(uid)),
  )];
  if (memberIds.length === 0) return;

  const memberRef = db.collection("squads").doc(squadId).collection("members");
  const userSnaps = await Promise.all(
      memberIds.map((uid) => db.collection("users").doc(uid).get()),
  );
  const existingSnaps = await Promise.all(
      memberIds.map((uid) => memberRef.doc(uid).get()),
  );
  const batch = db.batch();
  for (let i = 0; i < memberIds.length; i += 1) {
    const uid = memberIds[i];
    const userData = userSnaps[i].data() || {};
    const existingData = existingSnaps[i].exists ? existingSnaps[i].data() : null;
    const role = uid === (squad.creatorId || "").toString().trim() ? "owner" : "member";
    batch.set(memberRef.doc(uid), _buildCircleMemberSummary(
        uid,
        userData,
        existingData,
        role,
    ), {merge: true});
  }
  await batch.commit();
});

// Existing Circles may predate the projection trigger. A member may request a
// server-side refresh of the sanitized projection without receiving any user
// profile fields in the response.
exports.ensureCircleMemberSummaries = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Authentication required.");
  const circleId = (request.data?.circleId || "").toString().trim();
  if (!circleId) throw new HttpsError("invalid-argument", "circleId is required.");
  const uid = request.auth.uid;
  const circleRef = db.collection("squads").doc(circleId);
  const [circleSnap, userSnap] = await Promise.all([
    circleRef.get(),
    db.collection("users").doc(uid).get(),
  ]);
  const circle = circleSnap.data() || {};
  const memberIds = Array.isArray(circle.memberIds) ? circle.memberIds : [];
  if (!circleSnap.exists || (userSnap.data()?.squadId || "").toString().trim() !== circleId ||
      !memberIds.includes(uid)) {
    throw new HttpsError("permission-denied", "You are not a member of this Circle.");
  }
  const normalizedMemberIds = [...new Set(
      memberIds.map((memberId) => memberId?.toString().trim()).filter((memberId) => Boolean(memberId)),
  )];
  const memberRef = circleRef.collection("members");
  const [userSnaps, existingSnaps] = await Promise.all([
    Promise.all(normalizedMemberIds.map((memberUid) => db.collection("users").doc(memberUid).get())),
    Promise.all(normalizedMemberIds.map((memberUid) => memberRef.doc(memberUid).get())),
  ]);
  const batch = db.batch();
  for (let index = 0; index < normalizedMemberIds.length; index += 1) {
    const memberUid = normalizedMemberIds[index];
    const existing = existingSnaps[index].exists ? existingSnaps[index].data() : null;
    const role = memberUid === (circle.creatorId || "").toString().trim() ? "owner" : "member";
    batch.set(memberRef.doc(memberUid), _buildCircleMemberSummary(
        memberUid,
        userSnaps[index].data() || {},
        existing,
        role,
    ), {merge: true});
  }
  await batch.commit();
  return {success: true, circleId, memberCount: normalizedMemberIds.length};
});

exports.setCircleMemberPermissions = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Authentication required.");
  const payload = request.data || {};
  const allowed = new Set(["circleId", "memberUid", "preset", "permissions"]);
  for (const key of Object.keys(payload)) {
    if (!allowed.has(key)) throw new HttpsError("invalid-argument", `Unexpected field: ${key}`);
  }
  const actorUid = request.auth.uid;
  const circleId = (payload.circleId || "").toString().trim();
  const memberUid = (payload.memberUid || "").toString().trim();
  const preset = (payload.preset || "custom").toString().trim();
  if (!circleId || !memberUid || !CIRCLE_PRESETS.includes(preset)) {
    throw new HttpsError("invalid-argument", "circleId, memberUid, and a valid preset are required.");
  }
  if (memberUid === actorUid) {
    throw new HttpsError("failed-precondition", "Owner permissions are managed by Circle authority.");
  }
  const permissions = _sanitizeCirclePermissions(payload.permissions, preset);
  const circleRef = db.collection("squads").doc(circleId);
  const memberRef = circleRef.collection("members").doc(memberUid);
  const circleCheck = await circleRef.get();
  if (circleCheck.exists && circleCheck.data()?.premiumRequired === true) {
    await _assertPremiumEntitled(actorUid);
  }
  await db.runTransaction(async (tx) => {
    const circleSnap = await tx.get(circleRef);
    const memberSnap = await tx.get(memberRef);
    if (!circleSnap.exists || circleSnap.data()?.creatorId !== actorUid) {
      throw new HttpsError("permission-denied", "Only the Circle owner can manage permissions.");
    }
    const memberIds = Array.isArray(circleSnap.data()?.memberIds) ? circleSnap.data().memberIds : [];
    if (!memberIds.includes(memberUid)) {
      throw new HttpsError("not-found", "Circle member not found.");
    }
    if (!memberSnap.exists) {
      const userSnap = await tx.get(db.collection("users").doc(memberUid));
      if (!userSnap.exists) throw new HttpsError("not-found", "Circle member profile not found.");
      tx.set(memberRef, _buildCircleMemberSummary(
          memberUid,
          userSnap.data() || {},
          {preset, permissions},
          "member",
      ));
    } else {
      tx.update(memberRef, {
        preset,
        permissions,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  });
  return {success: true, circleId, memberUid, preset, permissions};
});

exports.leaveCircle = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Authentication required.");
  const circleId = (request.data?.circleId || "").toString().trim();
  if (!circleId) throw new HttpsError("invalid-argument", "circleId is required.");
  const uid = request.auth.uid;
  const userRef = db.collection("users").doc(uid);
  const circleRef = db.collection("squads").doc(circleId);
  await db.runTransaction(async (tx) => {
    const [userSnap, circleSnap] = await Promise.all([tx.get(userRef), tx.get(circleRef)]);
    if (!circleSnap.exists) return;
    const circle = circleSnap.data() || {};
    if ((userSnap.data()?.squadId || "").toString().trim() !== circleId) {
      throw new HttpsError("permission-denied", "You are not a member of this Circle.");
    }
    const memberIds = (Array.isArray(circle.memberIds) ? circle.memberIds : [])
        .map((memberId) => memberId?.toString().trim())
        .filter((memberId) => memberId && memberId !== uid);
    if ((circle.creatorId || "").toString().trim() === uid && memberIds.length > 0) {
      throw new HttpsError("failed-precondition", "Transfer Circle ownership before leaving.");
    }
    if (memberIds.length === 0) tx.delete(circleRef);
    else tx.update(circleRef, {memberIds, updatedAt: FieldValue.serverTimestamp()});
    tx.set(userRef, {squadId: null, squadCode: null}, {merge: true});
    tx.delete(circleRef.collection("members").doc(uid));
  });
  return {success: true, circleId};
});

exports.setCommitmentOverridePolicy = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Authentication required.");
  const payload = request.data || {};
  const allowed = new Set(["commitmentId", "authority", "selectedMemberIds", "sharedMemberIds"]);
  for (const key of Object.keys(payload)) {
    if (!allowed.has(key)) throw new HttpsError("invalid-argument", `Unexpected field: ${key}`);
  }
  const uid = request.auth.uid;
  const commitmentId = (payload.commitmentId || "").toString().trim();
  const authority = _normalizeV2Authority(payload.authority);
  const selectedMemberIds = [...new Set(
      (Array.isArray(payload.selectedMemberIds) ? payload.selectedMemberIds : [])
          .map((id) => id?.toString().trim())
          .filter((id) => Boolean(id) && id !== uid),
  )];
  const sharedMemberIds = [...new Set(
      (Array.isArray(payload.sharedMemberIds) ? payload.sharedMemberIds : [])
          .map((id) => id?.toString().trim())
          .filter((id) => Boolean(id) && id !== uid),
  )];
  if (!commitmentId || !authority) {
    throw new HttpsError("invalid-argument", "commitmentId and authority are required.");
  }
  if (authority === "circle" && selectedMemberIds.length === 0) {
    throw new HttpsError("failed-precondition", "Circle authority requires eligible members.");
  }

  const userRef = db.collection("users").doc(uid);
  const commitmentRef = userRef.collection("regimes").doc(commitmentId);
  const policyRef = userRef.collection("commitmentPolicies").doc(commitmentId);
  // AI and Circle authority are paid configuration capabilities. Existing
  // policies remain readable and enforceable, but changing either authority
  // must not become a free entitlement bypass.
  const needsPremium = authority === "ai" || authority === "circle";
  if (needsPremium) await _assertPremiumEntitled(uid);
  await db.runTransaction(async (tx) => {
    const [userSnap, commitmentSnap] = await Promise.all([tx.get(userRef), tx.get(commitmentRef)]);
    if (!userSnap.exists || !commitmentSnap.exists) {
      throw new HttpsError("not-found", "Commitment not found.");
    }
    const userData = userSnap.data() || {};
    const circleId = (userData.squadId || "").toString().trim();
    if (authority === "circle" || sharedMemberIds.length > 0) {
      if (!circleId) throw new HttpsError("failed-precondition", "Join a Circle before using Circle authority.");
      const circleSnap = await tx.get(db.collection("squads").doc(circleId));
      if (!circleSnap.exists) throw new HttpsError("failed-precondition", "Circle is unavailable.");
      const memberIds = Array.isArray(circleSnap.data()?.memberIds) ? circleSnap.data().memberIds : [];
      const assignedIds = [...new Set([...selectedMemberIds, ...sharedMemberIds])];
      if (!assignedIds.every((id) => memberIds.includes(id))) {
        throw new HttpsError("permission-denied", "Selected Circle member is no longer a member.");
      }
      for (const memberUid of selectedMemberIds) {
        const memberSnap = await tx.get(db.collection("squads").doc(circleId).collection("members").doc(memberUid));
        const permissions = memberSnap.data()?.permissions || {};
        if (!memberSnap.exists || permissions.voteOnOverrideRequests !== true) {
          throw new HttpsError("failed-precondition", "Every selected member must have voting permission.");
        }
      }
      for (const memberUid of sharedMemberIds) {
        const memberSnap = await tx.get(db.collection("squads").doc(circleId).collection("members").doc(memberUid));
        const permissions = memberSnap.data()?.permissions || {};
        if (!memberSnap.exists || permissions.viewCommitmentSummary !== true) {
          throw new HttpsError("failed-precondition", "Every shared member must have summary-view permission.");
        }
      }
    }
    tx.set(policyRef, {
      commitmentId,
      authority,
      selectedMemberIds: authority === "circle" ? selectedMemberIds : [],
      sharedMemberIds,
      premiumRequired: authority === "ai" || authority === "circle",
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: uid,
    }, {merge: true});
  });
  return {success: true, commitmentId, authority, selectedMemberIds, sharedMemberIds};
});

exports.getSharedCommitmentSummaries = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Authentication required.");
  const viewerUid = request.auth.uid;
  const viewerSnap = await db.collection("users").doc(viewerUid).get();
  const circleId = (viewerSnap.data()?.squadId || "").toString().trim();
  if (!circleId) return {commitments: []};

  const circleSnap = await db.collection("squads").doc(circleId).get();
  if (!circleSnap.exists) return {commitments: []};
  const memberIds = [...new Set(
      (Array.isArray(circleSnap.data()?.memberIds) ? circleSnap.data().memberIds : [])
          .map((id) => id?.toString().trim())
          .filter((id) => id && id !== viewerUid),
  )];
  const summaries = [];
  for (const ownerUid of memberIds) {
    const memberSnap = await db.collection("squads").doc(circleId).collection("members").doc(ownerUid).get();
    if (!memberSnap.exists || memberSnap.data()?.permissions?.viewCommitmentSummary !== true) continue;
    const ownerName = (memberSnap.data()?.displayName || "A Circle member").toString().trim() || "A Circle member";
    const [regimesSnap, taperSnap] = await Promise.all([
      db.collection("users").doc(ownerUid).collection("regimes").get(),
      db.collection("users").doc(ownerUid).collection("taperPlans").get(),
    ]);
    const taperByScheduleId = new Map();
    for (const planDoc of taperSnap.docs) {
      const plan = planDoc.data() || {};
      const scheduleId = (plan.scheduleId || "").toString().trim();
      if (scheduleId) taperByScheduleId.set(scheduleId, plan);
    }
    const policySnaps = await Promise.all(
        regimesSnap.docs.map((doc) => db.collection("users").doc(ownerUid)
            .collection("commitmentPolicies").doc(doc.id).get()),
    );
    for (let index = 0; index < regimesSnap.docs.length; index += 1) {
      const scheduleDoc = regimesSnap.docs[index];
      const policy = policySnaps[index].data() || {};
      const sharedIds = Array.isArray(policy.sharedMemberIds) ? policy.sharedMemberIds : [];
      if (!sharedIds.map((id) => id?.toString().trim()).includes(viewerUid)) continue;
      const schedule = scheduleDoc.data() || {};
      if (schedule.isActive === false || schedule.isEnabled === false) continue;
      const taper = taperByScheduleId.get(scheduleDoc.id);
      const type = taper ? "reduce" : Number(schedule.type) === 0 ? "protect_period" : "protect_daily_limit";
      const summary = taper
        ? `Reduce plan · target ${Number(taper.targetDailyMinutes) || 0} min/day`
        : type === "protect_period" ? "Protected period" : `Daily limit · ${Number(schedule.limitMinutes || schedule.durationSeconds / 60) || 0} min`;
      summaries.push({
        ownerName,
        name: (schedule.name || "Commitment").toString().trim() || "Commitment",
        type,
        summary,
        targetAppCount: Array.isArray(schedule.targetApps) ? schedule.targetApps.length :
          (Array.isArray(schedule.apps) ? schedule.apps.length : 0),
      });
      if (summaries.length >= 50) return {commitments: summaries};
    }
  }
  return {commitments: summaries};
});

async function _validateOverrideRequestPayload(payload) {
  const appName = (payload.appName || "").toString().trim();
  const packageName = (payload.packageName || "").toString().trim();
  const reason = (payload.reason || "").toString().trim();
  const durationMinutes = Number(payload.durationMinutes);
  if (!appName || appName.length > 80 || !packageName || packageName.length > 180 || !reason || reason.length > 300) {
    throw new HttpsError("invalid-argument", "App, package, and reason are required.");
  }
  if (!Number.isFinite(durationMinutes) || !OVERRIDE_DURATION_MINUTES.includes(Math.floor(durationMinutes))) {
    throw new HttpsError("invalid-argument", "durationMinutes must be 5, 10, or 15.");
  }
  return {appName, packageName, reason, durationMinutes: Math.floor(durationMinutes)};
}

exports.createOverrideRequest = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Authentication required.");
  const payload = request.data || {};
  const allowed = new Set(["commitmentId", "authority", "appName", "packageName", "durationMinutes", "reason"]);
  for (const key of Object.keys(payload)) {
    if (!allowed.has(key)) throw new HttpsError("invalid-argument", `Unexpected field: ${key}`);
  }
  const uid = request.auth.uid;
  const authority = _normalizeV2Authority(payload.authority);
  const commitmentId = (payload.commitmentId || "").toString().trim();
  if (!authority) throw new HttpsError("invalid-argument", "authority is required.");
  const requestData = await _validateOverrideRequestPayload(payload);
  const userRef = db.collection("users").doc(uid);
  const pleaRef = db.collection("pleas").doc();
  const requestedPolicySnap = commitmentId ?
    await userRef.collection("commitmentPolicies").doc(commitmentId).get() : null;
  if (authority === "ai" ||
      (authority === "circle" && requestedPolicySnap?.data()?.premiumRequired === true)) {
    await _assertPremiumEntitled(uid);
  }
  let result;
  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) throw new HttpsError("failed-precondition", "User profile is missing.");
    const userData = userSnap.data() || {};
    const policySnap = commitmentId ?
      await tx.get(userRef.collection("commitmentPolicies").doc(commitmentId)) : null;
    const policy = policySnap?.exists ? policySnap.data() || {} : {authority: "self", selectedMemberIds: []};
    const storedAuthority = _normalizeV2Authority(policy.authority) || "self";
    if (storedAuthority !== authority) {
      throw new HttpsError("failed-precondition", "Request authority does not match this Commitment's policy.");
    }
    const circleId = (userData.squadId || "").toString().trim();
    const eligibleVoterIds = [];
    if (authority === "circle") {
      if (!circleId) throw new HttpsError("failed-precondition", "Circle authority is unavailable without a Circle.");
      const selected = Array.isArray(policy.selectedMemberIds) ? policy.selectedMemberIds : [];
      for (const memberUid of [...new Set(selected.map((id) => id?.toString().trim()).filter((id) => id && id !== uid))]) {
        const memberSnap = await tx.get(db.collection("squads").doc(circleId).collection("members").doc(memberUid));
        if (memberSnap.exists && memberSnap.data()?.permissions?.voteOnOverrideRequests === true) {
          eligibleVoterIds.push(memberUid);
        }
      }
      if (eligibleVoterIds.length === 0) {
        throw new HttpsError("failed-precondition", "No eligible Circle voters are available.");
      }
    }
    const nowMs = Date.now();
    const status = authority === "ai" ? "pending" : authority === "circle" ? "active" : "approved";
    const approvedUntil = status === "approved" ? nowMs + requestData.durationMinutes * 60 * 1000 : 0;
    const visibleToUids = [uid, ...eligibleVoterIds];
    const base = {
      userId: uid,
      userName: _deriveUserDisplayName(userData),
      squadId: circleId,
      commitmentId,
      appName: requestData.appName,
      packageName: requestData.packageName,
      durationMinutes: requestData.durationMinutes,
      reason: _sanitizeReasonText(requestData.reason),
      authority,
      premiumRequired: authority === "ai" || policy.premiumRequired === true,
      visibleToUids,
      eligibleVoterIds,
      requiredApprovalCount: authority === "circle" ? _circleMajority(eligibleVoterIds.length) : 0,
      participants: [uid],
      voteCounts: {accept: 0, reject: 0},
      votes: {},
      status,
      outcomeSource: authority === "self" ? "self" : authority === "ai" ? "ai_architect" : "circle_vote",
      createdAt: FieldValue.serverTimestamp(),
      createdBy: uid,
      idempotencyKey: pleaRef.id,
    };
    if (status === "approved") {
      base.resolvedAt = FieldValue.serverTimestamp();
      base.approvedUntil = Timestamp.fromMillis(approvedUntil);
    } else if (authority === "ai") {
      base.aiFallbackStatus = "queued";
      base.aiFallbackDueAt = Timestamp.fromMillis(nowMs + AI_FALLBACK_DELAY_SECONDS * 1000);
      base.aiFallbackModel = OPENROUTER_MODEL;
    }
    tx.set(pleaRef, base);
    result = {status, approvedUntil, eligibleVoterIds};
  });

  if (result.status === "approved") {
    await _sendPleaVerdictSideEffects({
      pleaId: pleaRef.id,
      pleaData: {
        ...requestData,
        squadId: "",
        userName: "You",
        approvedUntil: Timestamp.fromMillis(result.approvedUntil),
        authority,
      },
      requesterId: uid,
      verdict: "approved",
      outcomeSource: "self",
    });
  } else if (authority === "ai") {
    await _enqueuePleaFallbackTask(pleaRef.id, uid);
    await _enqueuePleaForceKillTask(pleaRef.id, uid);
  } else {
    await _enqueuePleaForceKillTask(pleaRef.id, uid);
  }
  return {success: true, pleaId: pleaRef.id, status: result.status, authority};
});

exports.recordSelfOverride = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Authentication required.");
  const payload = request.data || {};
  const allowed = new Set(["commitmentId", "appName", "packageName", "durationMinutes", "reason", "idempotencyKey"]);
  for (const key of Object.keys(payload)) {
    if (!allowed.has(key)) throw new HttpsError("invalid-argument", `Unexpected field: ${key}`);
  }
  const values = await _validateOverrideRequestPayload(payload);
  const uid = request.auth.uid;
  const idempotencyKey = (payload.idempotencyKey || "").toString().trim();
  const pleaRef = idempotencyKey ? db.collection("pleas").doc(`self_${idempotencyKey.replace(/[^a-zA-Z0-9_-]/g, "_")}`) : db.collection("pleas").doc();
  const nowMs = Date.now();
  let alreadyExists = false;
  await db.runTransaction(async (tx) => {
    const existing = await tx.get(pleaRef);
    if (existing.exists) {
      alreadyExists = true;
      return;
    }
    tx.set(pleaRef, {
      userId: uid,
      userName: "You",
      squadId: "",
      commitmentId: (payload.commitmentId || "").toString().trim(),
      appName: values.appName,
      packageName: values.packageName,
      durationMinutes: values.durationMinutes,
      reason: _sanitizeReasonText(values.reason),
      authority: "self",
      visibleToUids: [uid],
      eligibleVoterIds: [],
      participants: [uid],
      voteCounts: {accept: 1, reject: 0},
      votes: {},
      status: "approved",
      outcomeSource: "self",
      createdAt: FieldValue.serverTimestamp(),
      resolvedAt: FieldValue.serverTimestamp(),
      approvedUntil: Timestamp.fromMillis(nowMs + values.durationMinutes * 60 * 1000),
      idempotencyKey: idempotencyKey || pleaRef.id,
    });
  });
  if (!alreadyExists) {
    await _sendPleaVerdictSideEffects({
      pleaId: pleaRef.id,
      pleaData: {...values, authority: "self", approvedUntil: Timestamp.fromMillis(nowMs + values.durationMinutes * 60 * 1000)},
      requesterId: uid,
      verdict: "approved",
      outcomeSource: "self",
    });
  }
  return {success: true, pleaId: pleaRef.id, status: "approved", idempotent: alreadyExists};
});

exports.getCircleMemberOverrideHistory = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Authentication required.");
  const targetUid = (request.data?.targetUid || "").toString().trim();
  if (!targetUid) throw new HttpsError("invalid-argument", "targetUid is required.");
  const actorUid = request.auth.uid;
  if (actorUid !== targetUid) {
    const [actorSnap, targetSnap] = await Promise.all([
      db.collection("users").doc(actorUid).get(),
      db.collection("users").doc(targetUid).get(),
    ]);
    const actorData = actorSnap.data() || {};
    const targetData = targetSnap.data() || {};
    const circleId = (actorData.squadId || "").toString().trim();
    if (!circleId || circleId !== (targetData.squadId || "").toString().trim()) {
      throw new HttpsError("permission-denied", "Member history is not shared with this Circle.");
    }
    const memberSnap = await db.collection("squads").doc(circleId).collection("members").doc(actorUid).get();
    if (memberSnap.data()?.permissions?.viewOverrideHistory !== true) {
      throw new HttpsError("permission-denied", "Override History permission is not enabled.");
    }
  }
  const snapshot = await db.collection("pleas")
      .where("userId", "==", targetUid)
      .orderBy("createdAt", "desc")
      .limit(50)
      .get();
  return {
    success: true,
    targetUid,
    history: snapshot.docs.map((doc) => {
      const data = doc.data() || {};
      return {
        id: doc.id,
        appName: (data.appName || "App").toString(),
        durationMinutes: Number(data.durationMinutes) || 0,
        authority: _normalizeV2Authority(data.authority) || "legacy",
        status: (data.status || "recorded").toString(),
        createdAtMs: _timestampToMillis(data.createdAt),
        resolvedAtMs: _timestampToMillis(data.resolvedAt),
      };
    }),
  };
});

exports.__testables = {
  buildRapSheetSnapshot,
  parseAiDecision: _parseAiDecision,
  sanitizeReasonText: _sanitizeReasonText,
  deriveAppCategory: _deriveAppCategory,
  extractJsonObjectString: _extractJsonObjectString,
  circleMajority: _circleMajority,
  normalizeV2Authority: _normalizeV2Authority,
  sanitizeCirclePermissions: _sanitizeCirclePermissions,
  premiumAccountHash: require("./premium_billing").expectedObfuscatedAccountId,
  normalizePremiumPlaySubscription: require("./premium_billing").normalizePlaySubscription,
  sequentialPremiumUntil: require("./premium_billing").sequentialPremiumUntil,
  decodePremiumRtdn: require("./premium_billing").decodeRtdnMessage,
};

exports.updateUserStatus = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const status = (request.data?.status || "").toString().trim().toLowerCase();
  const allowed = new Set(["locked_in", "idle", "vulnerable"]);
  if (!allowed.has(status)) {
    throw new HttpsError(
        "invalid-argument",
        "status must be one of: locked_in, idle, vulnerable.",
    );
  }

  try {
    await db.collection("users").doc(uid).set({
      currentStatus: status,
      statusUpdatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return {success: true, uid, status};
  } catch (error) {
    logger.error("updateUserStatus crashed.", {
      uid,
      status,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to update user status.");
  }
});

exports.joinSquadByCode = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const payload = request.data || {};
  const allowedKeys = new Set(["squadCode"]);
  for (const key of Object.keys(payload)) {
    if (!allowedKeys.has(key)) {
      throw new HttpsError("invalid-argument", `Unexpected field: ${key}`);
    }
  }

  if (typeof payload.squadCode !== "string") {
    throw new HttpsError("invalid-argument", "squadCode must be a string.");
  }

  const normalizedCode = payload.squadCode.trim().toUpperCase();
  if (!normalizedCode) {
    throw new HttpsError("invalid-argument", "squadCode is required.");
  }

  const squadMatch = await db
      .collection("squads")
      .where("joinCode", "==", normalizedCode)
      .limit(1)
      .get();

  const squadSnap = squadMatch.empty ?
    await db
        .collection("squads")
        .where("squadCode", "==", normalizedCode)
        .limit(1)
        .get() :
    squadMatch;

  if (squadSnap.empty) {
    throw new HttpsError("not-found", "Invalid squad code");
  }

  const squadDoc = squadSnap.docs[0];
  const squadId = squadDoc.id;
  const squadRef = squadDoc.ref;
  const userRef = db.collection("users").doc(uid);

  await db.runTransaction(async (tx) => {
    const [userSnap, freshSquadSnap] = await Promise.all([
      tx.get(userRef),
      tx.get(squadRef),
    ]);

    if (!freshSquadSnap.exists) {
      throw new HttpsError("not-found", "Invalid squad code");
    }

    const currentUserData = userSnap.exists ? (userSnap.data() || {}) : {};
    const oldSquadId = (currentUserData.squadId || "").toString().trim();

    if (oldSquadId && oldSquadId !== squadId) {
      const oldSquadRef = db.collection("squads").doc(oldSquadId);
      const oldSquadSnap = await tx.get(oldSquadRef);
      if (oldSquadSnap.exists) {
        const oldMemberIds = Array.isArray(oldSquadSnap.data()?.memberIds) ?
          [...oldSquadSnap.data().memberIds] :
          [];
        const nextOldMemberIds = oldMemberIds.filter((memberId) =>
          (memberId || "").toString().trim() !== uid,
        );

        if (nextOldMemberIds.length === 0) {
          tx.delete(oldSquadRef);
        } else {
          tx.update(oldSquadRef, {memberIds: nextOldMemberIds});
        }
      }
    }

    tx.update(squadRef, {
      memberIds: FieldValue.arrayUnion(uid),
      joinCode: normalizedCode,
      squadCode: normalizedCode,
    });

    tx.set(userRef, {
      squadId,
      squadCode: normalizedCode,
    }, {merge: true});
  });

  return {squadId};
});

exports.castStone = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const isAdmin = request.auth.token?.admin === true;
  const payload = request.data || {};
  const allowedKeys = new Set(["targetUserId", "squadId"]);
  for (const key of Object.keys(payload)) {
    if (!allowedKeys.has(key)) {
      throw new HttpsError("invalid-argument", `Unexpected field: ${key}`);
    }
  }

  const targetUserId = (payload.targetUserId || "").toString().trim();
  const squadId = (payload.squadId || "").toString().trim();
  if (!targetUserId || !squadId) {
    throw new HttpsError(
        "invalid-argument",
        "targetUserId and squadId are required.",
    );
  }
  if (!isAdmin && targetUserId === uid) {
    throw new HttpsError(
        "failed-precondition",
        "Cannot cast a stone at yourself.",
    );
  }

  const caller = await _loadUserProfileOrThrow(uid, "Caller");
  const target = await _loadUserProfileOrThrow(targetUserId, "Target");

  if (!isAdmin) {
    if (!caller.squadId || caller.squadId !== squadId) {
      throw new HttpsError("permission-denied", "Caller is not in this squad.");
    }
    if (!target.squadId || target.squadId !== squadId) {
      throw new HttpsError("permission-denied", "Target is not in this squad.");
    }
  }

  const callerName = caller.name || "A Member";
  const title = "JUDGMENT";
  const body = `${callerName} cast a stone at you.`;
  if (target.wantsShameAlerts) {
    await _sendUserNotificationBestEffort(target.token, title, body, {
      type: "shame",
      actorUid: uid,
      squadId: String(squadId),
    });
  }
  await createInAppNotification(target.uid, {
    title: "JUDGMENT",
    body: `${callerName} cast a stone at you. Shame.`,
    type: "shame",
    metadata: {
      actorUid: uid,
      squadId: String(squadId),
    },
  });

  await logSquadEvent(
      squadId,
      "shame",
      `${callerName} cast a stone.`,
      {userId: uid, userName: callerName, userAvatar: caller.avatar},
      {targetUserId: String(targetUserId)},
  );

  return {success: true};
});

exports.prayFor = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const isAdmin = request.auth.token?.admin === true;
  const payload = request.data || {};
  const allowedKeys = new Set(["targetUserId", "squadId"]);
  for (const key of Object.keys(payload)) {
    if (!allowedKeys.has(key)) {
      throw new HttpsError("invalid-argument", `Unexpected field: ${key}`);
    }
  }

  const targetUserId = (payload.targetUserId || "").toString().trim();
  const squadId = (payload.squadId || "").toString().trim();
  if (!targetUserId || !squadId) {
    throw new HttpsError(
        "invalid-argument",
        "targetUserId and squadId are required.",
    );
  }
  if (!isAdmin && targetUserId === uid) {
    throw new HttpsError(
        "failed-precondition",
        "Cannot pray for yourself here.",
    );
  }

  const caller = await _loadUserProfileOrThrow(uid, "Caller");
  const target = await _loadUserProfileOrThrow(targetUserId, "Target");

  if (!isAdmin) {
    if (!caller.squadId || caller.squadId !== squadId) {
      throw new HttpsError("permission-denied", "Caller is not in this squad.");
    }
    if (!target.squadId || target.squadId !== squadId) {
      throw new HttpsError("permission-denied", "Target is not in this squad.");
    }
  }

  const callerName = caller.name || "A Member";
  const title = "PRAYER";
  const body = `${callerName} is praying for your focus.`;
  if (target.wantsShameAlerts) {
    await _sendUserNotificationBestEffort(target.token, title, body, {
      type: "support",
      actorUid: uid,
      squadId: String(squadId),
    });
  }
  await createInAppNotification(target.uid, {
    title: "STRENGTH",
    body: `${callerName} is praying for your discipline.`,
    type: "support",
    metadata: {
      actorUid: uid,
      squadId: String(squadId),
    },
  });

  await logSquadEvent(
      squadId,
      "support",
      `${callerName} sent prayers.`,
      {userId: uid, userName: callerName, userAvatar: caller.avatar},
      {targetUserId: String(targetUserId)},
  );

  return {success: true};
});

exports.postBail = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const isAdmin = request.auth.token?.admin === true;
  const payload = request.data || {};
  const allowedKeys = new Set(["targetUserId", "squadId"]);
  for (const key of Object.keys(payload)) {
    if (!allowedKeys.has(key)) {
      throw new HttpsError("invalid-argument", `Unexpected field: ${key}`);
    }
  }

  const targetUserId = (payload.targetUserId || "").toString().trim();
  const squadId = (payload.squadId || "").toString().trim();
  if (!targetUserId || !squadId) {
    throw new HttpsError(
        "invalid-argument",
        "targetUserId and squadId are required.",
    );
  }
  if (!isAdmin && targetUserId === uid) {
    throw new HttpsError(
        "failed-precondition",
        "Cannot post bail for yourself.",
    );
  }

  const callerRef = db.collection("users").doc(uid);
  const targetRef = db.collection("users").doc(targetUserId);

  let callerName = "A Member";
  let callerAvatar = "";
  let targetToken = "";

  const COST = 50;

  await db.runTransaction(async (tx) => {
    const callerSnap = await tx.get(callerRef);
    const targetSnap = await tx.get(targetRef);
    if (!callerSnap.exists) {
      throw new HttpsError("failed-precondition", "Caller profile is missing.");
    }
    if (!targetSnap.exists) {
      throw new HttpsError("failed-precondition", "Target profile is missing.");
    }

    const callerData = callerSnap.data() || {};
    const targetData = targetSnap.data() || {};

    const callerSquadId = (callerData.squadId || "").toString().trim();
    const targetSquadId = (targetData.squadId || "").toString().trim();

    if (!isAdmin) {
      if (!callerSquadId || callerSquadId !== squadId) {
        throw new HttpsError(
            "permission-denied",
            "Caller is not in this squad.",
        );
      }
      if (!targetSquadId || targetSquadId !== squadId) {
        throw new HttpsError(
            "permission-denied",
            "Target is not in this squad.",
        );
      }
    }

    const callerScoreRaw = Number(callerData.focusScore);
    const callerScore = Number.isFinite(callerScoreRaw) ?
      Math.floor(callerScoreRaw) : 0;

    if (callerScore < COST) {
      throw new HttpsError(
          "failed-precondition",
          "Insufficient points to post bail.",
      );
    }

    // Capture for use after the transaction.
    callerName = _deriveUserDisplayName(callerData) || "A Member";
    callerAvatar = (callerData.photoUrl || "").toString().trim();
    targetToken = (targetData.fcmToken || "").toString().trim();

    tx.update(callerRef, {
      focusScore: callerScore - COST,
      updatedAt: FieldValue.serverTimestamp(),
    });

    const targetScoreRaw = Number(targetData.focusScore);
    const targetScore = Number.isFinite(targetScoreRaw) ?
      Math.floor(targetScoreRaw) : 0;

    tx.update(targetRef, {
      focusScore: targetScore + COST,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  const scoreEventDay = _dateOnlyUtc(Date.now());
  await Promise.all([
    db.collection("users").doc(uid).collection("scoreEvents").add({
      type: "bail_outgoing",
      delta: -COST,
      targetUserId: targetUserId,
      source: "post_bail",
      eventDay: scoreEventDay,
      createdAtMs: Date.now(),
      createdAt: FieldValue.serverTimestamp(),
    }),
    db.collection("users").doc(targetUserId).collection("scoreEvents").add({
      type: "bail_incoming",
      delta: COST,
      actorUid: uid,
      source: "post_bail",
      eventDay: scoreEventDay,
      createdAtMs: Date.now(),
      createdAt: FieldValue.serverTimestamp(),
    }),
  ]);

  await _sendUserNotificationBestEffort(
      targetToken,
      "FREEDOM",
      `${callerName} posted bail for you (50 pts).`,
      {
        type: "support",
        actorUid: uid,
        squadId: String(squadId),
        amount: String(COST),
      },
  );
  await createInAppNotification(targetUserId, {
    title: "REDEMPTION",
    body: `${callerName} sacrificed 50 points to bail you out.`,
    type: "support",
    metadata: {
      actorUid: uid,
      squadId: String(squadId),
      amount: COST,
    },
  });

  await logSquadEvent(
      squadId,
      "redemption",
      `${callerName} posted bail.`,
      {userId: uid, userName: callerName, userAvatar: callerAvatar},
      {targetUserId: String(targetUserId), amount: COST},
  );

  return {success: true, amount: COST};
});

exports.saluteSquadLog = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const isAdmin = request.auth.token?.admin === true;
  const payload = request.data || {};
  const allowedKeys = new Set(["squadId", "logId"]);
  for (const key of Object.keys(payload)) {
    if (!allowedKeys.has(key)) {
      throw new HttpsError("invalid-argument", `Unexpected field: ${key}`);
    }
  }

  const squadId = (payload.squadId || "").toString().trim();
  const logId = (payload.logId || "").toString().trim();
  if (!squadId) {
    throw new HttpsError("invalid-argument", "squadId is required.");
  }
  if (!logId) {
    throw new HttpsError("invalid-argument", "logId is required.");
  }

  const logRef = db.collection("squads").doc(squadId).collection("logs").doc(logId);
  const limitsRef = db.collection("limits").doc(uid);
  const nowMs = Date.now();

  let alreadySaluted = false;
  let saluteCount = 0;

  try {
    await db.runTransaction(async (tx) => {
      if (!isAdmin) {
        const callerRef = db.collection("users").doc(uid);
        const callerSnap = await tx.get(callerRef);
        if (!callerSnap.exists) {
          throw new HttpsError("failed-precondition", "User profile is missing.");
        }
        const callerSquadId = (callerSnap.data()?.squadId || "").toString().trim();
        if (!callerSquadId || callerSquadId !== squadId) {
          throw new HttpsError("permission-denied", "User is not allowed to react to this log.");
        }
      }

      const logSnap = await tx.get(logRef);
      if (!logSnap.exists) {
        throw new HttpsError("not-found", "Squad log not found.");
      }
      const logData = logSnap.data() || {};
      const rawReactions = logData.reactions && typeof logData.reactions === "object" ?
        logData.reactions :
        {};

      let existingSalutes = 0;
      for (const reactionRaw of Object.values(rawReactions)) {
        const reaction = (reactionRaw || "").toString().trim().toLowerCase();
        if (reaction === "salute") existingSalutes += 1;
      }

      const currentReaction = (rawReactions[uid] || "").toString().trim().toLowerCase();
      if (currentReaction === "salute") {
        alreadySaluted = true;
        saluteCount = existingSalutes;
        return;
      }

      const limitsSnap = await tx.get(limitsRef);
      const limits = limitsSnap.exists ? (limitsSnap.data() || {}) : {};
      const recentSalutes = _pruneTimestamps(
          limits.saluteEvents,
          nowMs - 60 * 1000,
          100,
      );
      if (recentSalutes.length >= 20) {
        throw new HttpsError(
            "resource-exhausted",
            "Too many salute reactions. Try again shortly.",
        );
      }

      tx.update(logRef, {
        [`reactions.${uid}`]: "salute",
        reactionsUpdatedAt: FieldValue.serverTimestamp(),
      });

      tx.set(limitsRef, {
        saluteEvents: [...recentSalutes, nowMs].slice(-100),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});

      saluteCount = existingSalutes + 1;
    });

    return {
      success: true,
      alreadySaluted,
      saluteCount,
    };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("saluteSquadLog crashed.", {
      uid,
      squadId,
      logId,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to react to squad log.");
  }
});

exports.createMockTribunal = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  if (request.auth.token?.admin !== true) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }

  try {
    await _ensurePermanentMockActors();
    const staleSquadIds = await _cleanupLegacyMockUsersAndSquads();
    await _destroyMockSessions({staleSquadIds});

    const pleaRef = db.collection("pleas").doc();

    const mockUserIds = MOCK_USERS.map((user) => user.uid);
    const requester = MOCK_USERS[0];

    await pleaRef.set({
      userId: requester.uid,
      userName: requester.fullName,
      squadId: MOCK_SQUAD_ID,
      appName: "Instagram",
      packageName: "com.instagram.android",
      durationMinutes: 20,
      reason: "Need to publish campaign updates before deadline.",
      participants: mockUserIds,
      voteCounts: {accept: 1, reject: 1},
      votes: {
        [MOCK_USERS[1].uid]: "accept",
        [MOCK_USERS[2].uid]: "reject",
      },
      status: "active",
      isMockSession: true,
      mockSessionOwnerUid: request.auth.uid,
      createdAt: FieldValue.serverTimestamp(),
    });

    await pleaRef.collection("votes").doc(MOCK_USERS[1].uid).set({
      uid: MOCK_USERS[1].uid,
      choice: "accept",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      seededBy: "mock_session",
    });
    await pleaRef.collection("votes").doc(MOCK_USERS[2].uid).set({
      uid: MOCK_USERS[2].uid,
      choice: "reject",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      seededBy: "mock_session",
    });

    const messagesRef = pleaRef.collection("messages");
    const seedMessages = /** @type {Array<{senderId:string,senderName:string,text:string,isSystem:boolean}>} */ ([
      {
        senderId: "SYSTEM",
        senderName: "System",
        text: "Simulation initialized. Tribunal recording has begun.",
        isSystem: true,
      },
      {
        senderId: requester.uid,
        senderName: requester.fullName,
        text: "Requesting 20 minutes for Instagram.",
        isSystem: false,
      },
      {
        senderId: MOCK_USERS[1].uid,
        senderName: MOCK_USERS[1].fullName,
        text: "State your case quickly. Time is expensive.",
        isSystem: false,
      },
      {
        senderId: MOCK_USERS[2].uid,
        senderName: MOCK_USERS[2].fullName,
        text: "I am leaning toward reject.",
        isSystem: false,
      },
      {
        senderId: requester.uid,
        senderName: requester.fullName,
        text: "I need this window to answer urgent messages.",
        isSystem: false,
      },
      {
        senderId: MOCK_USERS[3].uid,
        senderName: MOCK_USERS[3].fullName,
        text: "The squad needs evidence, not promises.",
        isSystem: false,
      },
      {
        senderId: MOCK_USERS[4].uid,
        senderName: MOCK_USERS[4].fullName,
        text: "I can support a short extension if accountability is clear.",
        isSystem: false,
      },
    ]);

    const baseMillis = Date.now() - (seedMessages.length * 15000);
    for (let i = 0; i < seedMessages.length; i += 1) {
      const msg = seedMessages[i];
      await messagesRef.add({
        ...msg,
        timestamp: Timestamp.fromMillis(baseMillis + (i * 15000)),
      });
    }

    logger.info("createMockTribunal completed.", {
      actorUid: request.auth.uid,
      squadId: MOCK_SQUAD_ID,
      pleaId: pleaRef.id,
      mockActors: mockUserIds,
    });

    return {
      success: true,
      squadId: MOCK_SQUAD_ID,
      pleaId: pleaRef.id,
      userIds: mockUserIds,
    };
  } catch (error) {
    logger.error("createMockTribunal crashed.", {
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to create mock tribunal.");
  }
});

exports.destroyMockTribunal = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  if (request.auth.token?.admin !== true) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }

  const pleaId = (request.data?.pleaId || "").toString().trim();
  try {
    let deletedPleas = 0;
    if (pleaId) {
      const pleaRef = db.collection("pleas").doc(pleaId);
      const pleaSnap = await pleaRef.get();
      if (pleaSnap.exists) {
        const data = pleaSnap.data() || {};
        const isMock = data.isMockSession === true ||
          (data.squadId || "").toString().trim() === MOCK_SQUAD_ID;
        if (isMock) {
          await _deletePleaWithChildren(pleaRef);
          deletedPleas = 1;
        }
      }
    } else {
      deletedPleas = await _destroyMockSessions({staleSquadIds: []});
    }

    logger.info("destroyMockTribunal completed.", {
      actorUid: request.auth.uid,
      pleaId: pleaId || null,
      deletedPleas,
    });
    return {success: true, deletedPleas};
  } catch (error) {
    logger.error("destroyMockTribunal crashed.", {
      pleaId: pleaId || null,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to destroy mock tribunal.");
  }
});

exports.autoFinalizeStalePleas = onSchedule({
  region: "us-central1",
  schedule: "every 1 minutes",
}, async () => {
  const nowMs = Date.now();
  const cutoff = Timestamp.fromMillis(nowMs - ACTIVE_PLEA_TIMEOUT_MS);

  try {
    const snap = await db
        .collection("pleas")
        .where("status", "==", "active")
        .where("createdAt", "<=", cutoff)
        .orderBy("createdAt", "asc")
        .limit(50)
        .get();

    let finalized = 0;

    for (const doc of snap.docs) {
      const pleaRef = doc.ref;
      const plea = doc.data() || {};

      if (plea.isMockSession === true) continue;
      const aiFallbackStatus = (plea.aiFallbackStatus || "")
          .toString()
          .trim()
          .toLowerCase();
      if (aiFallbackStatus === "processing") continue;

      const summary = await _computePleaVoteSummary(pleaRef, plea);

      // Circle requests require a fixed-snapshot majority. An incomplete
      // snapshot never becomes an approval merely because one member voted.
      const required = summary.hasFixedVoterSnapshot
        ? (summary.requiredApprovalCount || _circleMajority(summary.voters.length))
        : 0;
      const verdict = summary.hasFixedVoterSnapshot
        ? (summary.acceptVotes >= required ? "approved" : "rejected")
        : (summary.acceptVotes > summary.rejectVotes ? "approved" : "rejected");

      const timeoutUpdate = {
        status: verdict,
        voteCounts: {accept: summary.acceptVotes, reject: summary.rejectVotes},
        resolvedAt: FieldValue.serverTimestamp(),
        outcomeSource: "timeout",
        timedOutAt: FieldValue.serverTimestamp(),
      };
      if (aiFallbackStatus === "queued") {
        timeoutUpdate.aiFallbackStatus = "missed";
      }
      if (ENABLE_LEGACY_PLEA_VOTE_MAP_SYNC) {
        timeoutUpdate.votes = summary.votes;
      }
      await pleaRef.set(timeoutUpdate, {merge: true});

      await pleaRef.collection("messages").add({
        senderId: "SYSTEM",
        senderName: "System",
        isSystem: true,
        text: `Tribunal timed out. Verdict: ${verdict.toUpperCase()}.`,
        timestamp: FieldValue.serverTimestamp(),
      });

      await _sendPleaVerdictSideEffects({
        pleaId: doc.id,
        pleaData: plea,
        requesterId: summary.requesterId,
        verdict,
        acceptVotes: summary.acceptVotes,
        rejectVotes: summary.rejectVotes,
        outcomeSource: "timeout",
      });

      finalized += 1;
      logger.info("autoFinalizeStalePleas resolved plea.", {
        pleaId: doc.id,
        requesterId: summary.requesterId,
        participants: summary.participants.length,
        voters: summary.voters.length,
        votesCast: summary.votesCast,
        acceptVotes: summary.acceptVotes,
        rejectVotes: summary.rejectVotes,
        verdict,
      });
    }

    const pendingSnap = await db
        .collection("pleas")
        .where("status", "==", "pending")
        .where("createdAt", "<=", cutoff)
        .orderBy("createdAt", "asc")
        .limit(50)
        .get();

    for (const doc of pendingSnap.docs) {
      const plea = doc.data() || {};
      if (plea.isMockSession === true) continue;

      if (_normalizeV2Authority(plea.authority) !== "ai") continue;
      const result = await _finalizePleaWithAiDecision(doc.ref, doc.id, {
        decision: "reject",
        minutes: 0,
        rationale: "AI fallback safety timeout.",
      });
      if (result.skipped) continue;
      finalized += 1;
      logger.info("autoFinalizeStalePleas resolved pending AI plea.", {
        pleaId: doc.id,
        requesterId: result.requesterId,
        verdict: result.verdict,
      });
    }

    logger.info("autoFinalizeStalePleas completed.", {finalized});
  } catch (error) {
    logger.error("autoFinalizeStalePleas crashed.", {
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
  }
});

exports.cleanupPleaData = onSchedule({
  region: "us-central1",
  schedule: "every 60 minutes",
}, async () => {
  const nowMs = Date.now();
  const resolvedCutoff = Timestamp.fromMillis(nowMs - RESOLVED_PLEA_TTL_MS);
  const deletionCutoff = Timestamp.fromMillis(nowMs - MARKED_FOR_DELETION_TTL_MS);

  const toDelete = new Map();

  try {
    const resolvedSnap = await db
        .collection("pleas")
        .where("status", "in", ["approved", "rejected"])
        .where("resolvedAt", "<=", resolvedCutoff)
        .orderBy("resolvedAt", "asc")
        .limit(CLEANUP_BATCH_LIMIT)
        .get();

    for (const doc of resolvedSnap.docs) {
      const data = doc.data() || {};
      if (data.isMockSession === true) continue;
      toDelete.set(doc.id, doc.ref);
    }

    const markedSnap = await db
        .collection("pleas")
        .where("markedForDeletion", "==", true)
        .where("deletionMarkedAt", "<=", deletionCutoff)
        .orderBy("deletionMarkedAt", "asc")
        .limit(CLEANUP_BATCH_LIMIT)
        .get();

    for (const doc of markedSnap.docs) {
      const data = doc.data() || {};
      if (data.isMockSession === true) continue;
      toDelete.set(doc.id, doc.ref);
    }

    if (toDelete.size === 0) return;

    const writer = db.bulkWriter();
    writer.onWriteError((err) => {
      // Retry transient failures a few times.
      return err.failedAttempts < 3;
    });

    let messageDeletes = 0;
    let voteDeletes = 0;
    let pleaDeletes = 0;

    for (const pleaRef of toDelete.values()) {
      const messages = await pleaRef.collection("messages").listDocuments();
      for (const msgRef of messages) {
        writer.delete(msgRef);
        messageDeletes += 1;
      }
      const votes = await pleaRef.collection("votes").listDocuments();
      for (const voteRef of votes) {
        writer.delete(voteRef);
        voteDeletes += 1;
      }
      writer.delete(pleaRef);
      pleaDeletes += 1;
    }

    await writer.close();

    logger.info("cleanupPleaData completed.", {
      pleasDeleted: pleaDeletes,
      messagesDeleted: messageDeletes,
      voteDocsDeleted: voteDeletes,
    });
  } catch (error) {
    logger.error("cleanupPleaData crashed.", {
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
  }
});

async function _ensurePermanentMockActors() {
  const squadRef = db.collection("squads").doc(MOCK_SQUAD_ID);
  const userRefs = MOCK_USERS.map((user) => db.collection("users").doc(user.uid));
  const userSnaps = await db.getAll(...userRefs);

  const batch = db.batch();
  batch.set(squadRef, {
    squadCode: MOCK_SQUAD_CODE,
    creatorId: MOCK_USERS[0].uid,
    memberIds: MOCK_USERS.map((user) => user.uid),
    isMockSquad: true,
    updatedAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  for (let i = 0; i < MOCK_USERS.length; i += 1) {
    const mock = MOCK_USERS[i];
    const existing = userSnaps[i].data() || {};
    const existingScore = Number(existing.focusScore);
    const preservedFocus = Number.isFinite(existingScore) ?
      Math.floor(existingScore) : mock.defaultFocusScore;

    batch.set(userRefs[i], {
      uid: mock.uid,
      fullName: mock.fullName,
      nickname: mock.nickname,
      email: mock.email,
      squadId: MOCK_SQUAD_ID,
      squadCode: MOCK_SQUAD_CODE,
      isMockUser: true,
      focusScore: preservedFocus,
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: existing.createdAt || FieldValue.serverTimestamp(),
    }, {merge: true});
  }

  await batch.commit();
}

async function _cleanupLegacyMockUsersAndSquads() {
  const staleSquadIds = [];

  const legacyUserSnap = await db
      .collection("users")
      .where("email", ">=", "mock.user")
      .where("email", "<", "mock.user\uf8ff")
      .get();

  for (const userDoc of legacyUserSnap.docs) {
    if (MOCK_USERS.some((user) => user.uid === userDoc.id)) {
      continue;
    }
    await userDoc.ref.delete();
  }

  const mockSquadSnap = await db
      .collection("squads")
      .where("squadCode", ">=", "MOCK-")
      .where("squadCode", "<", "MOCK-\uf8ff")
      .get();

  for (const squadDoc of mockSquadSnap.docs) {
    if (squadDoc.id === MOCK_SQUAD_ID) continue;
    staleSquadIds.push(squadDoc.id);
    await squadDoc.ref.delete();
  }

  return staleSquadIds;
}

async function _destroyMockSessions({staleSquadIds}) {
  const sessionRefs = new Map();

  const markedMockSessions = await db
      .collection("pleas")
      .where("isMockSession", "==", true)
      .get();
  for (const pleaDoc of markedMockSessions.docs) {
    sessionRefs.set(pleaDoc.id, pleaDoc.ref);
  }

  const mockSquadSessions = await db
      .collection("pleas")
      .where("squadId", "==", MOCK_SQUAD_ID)
      .get();
  for (const pleaDoc of mockSquadSessions.docs) {
    sessionRefs.set(pleaDoc.id, pleaDoc.ref);
  }

  for (const staleSquadId of staleSquadIds) {
    const staleSquadSessions = await db
        .collection("pleas")
        .where("squadId", "==", staleSquadId)
        .get();
    for (const pleaDoc of staleSquadSessions.docs) {
      sessionRefs.set(pleaDoc.id, pleaDoc.ref);
    }
  }

  let deleted = 0;
  for (const pleaRef of sessionRefs.values()) {
    await _deletePleaWithChildren(pleaRef);
    deleted += 1;
  }
  return deleted;
}

async function _deletePleaWithChildren(pleaRef) {
  const messagesSnap = await pleaRef.collection("messages").get();
  const votesSnap = await pleaRef.collection("votes").get();
  const batch = db.batch();
  for (const messageDoc of messagesSnap.docs) {
    batch.delete(messageDoc.ref);
  }
  for (const voteDoc of votesSnap.docs) {
    batch.delete(voteDoc.ref);
  }
  batch.delete(pleaRef);
  await batch.commit();
}

function _sanitizeReasonText(value) {
  return (value || "")
      .toString()
      .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, "[redacted-email]")
      .replace(/https?:\/\/\S+|www\.\S+/gi, "[redacted-url]")
      .replace(/\+?\d[\d\s().-]{7,}\d/g, "[redacted-phone]")
      .replace(/@[A-Za-z0-9_.-]+/g, "[redacted-handle]")
      .replace(/\b[A-Za-z0-9_-]{32,}\b/g, "[redacted-token]")
      .replace(/\s+/g, " ")
      .trim()
      .slice(0, 240);
}

function _deriveAppCategory(appName, packageName) {
  const text = `${appName || ""} ${packageName || ""}`.toLowerCase();
  if (/instagram|tiktok|snapchat|facebook|twitter|x\.com|reddit|threads/.test(text)) {
    return "social";
  }
  if (/youtube|netflix|hulu|primevideo|disney|twitch|video/.test(text)) {
    return "video";
  }
  if (/game|roblox|minecraft|steam|pubg|fortnite|clash/.test(text)) {
    return "games";
  }
  if (/chrome|browser|safari|firefox|edge/.test(text)) {
    return "browser";
  }
  if (/whatsapp|telegram|messenger|discord|signal/.test(text)) {
    return "messaging";
  }
  return "other";
}

function _deriveDefectorStatus(userData) {
  const status = (userData?.currentStatus || userData?.status || "")
      .toString()
      .trim()
      .toLowerCase();
  if (status === "vulnerable" || status === "locked_in" || status === "idle") {
    return status;
  }
  const focusScore = Number(userData?.focusScore);
  if (!Number.isFinite(focusScore)) return "unknown";
  if (focusScore < 350) return "high_risk";
  if (focusScore < 500) return "vulnerable";
  return "stable";
}

async function _loadActiveTaperGoal(uid) {
  const normalizedUid = (uid || "").toString().trim();
  if (!normalizedUid) return null;

  try {
    const snap = await db
        .collection("users")
        .doc(normalizedUid)
        .collection("taperPlans")
        .where("status", "==", "active")
        .limit(1)
        .get();
    if (snap.empty) return null;
    const data = snap.docs[0].data() || {};
    const targetDailyMinutes = Number(data.targetDailyMinutes);
    const todayLimitMinutes = Number(data.todayLimitMinutes);
    return {
      targetDailyMinutes: Number.isFinite(targetDailyMinutes) ?
        Math.max(0, Math.floor(targetDailyMinutes)) :
        null,
      todayLimitMinutes: Number.isFinite(todayLimitMinutes) ?
        Math.max(0, Math.floor(todayLimitMinutes)) :
        null,
    };
  } catch (error) {
    logger.warn("Failed to load active taper goal for AI context.", {
      uid: normalizedUid,
      errorMessage: error?.message || String(error),
    });
    return null;
  }
}

function _buildAiPleaContext(plea, requesterData, taperGoal) {
  const requestedRaw = Number(plea?.durationMinutes);
  const requestedMinutes = Number.isFinite(requestedRaw) ?
    Math.max(1, Math.min(120, Math.floor(requestedRaw))) :
    1;

  return {
    appCategory: _deriveAppCategory(plea?.appName, plea?.packageName),
    requestedMinutes,
    taperGoal: taperGoal || null,
    defectorStatus: _deriveDefectorStatus(requesterData),
    sanitizedReason: _sanitizeReasonText(plea?.reason),
  };
}

function _parseAiDecision(rawValue) {
  let parsed = rawValue;
  if (typeof rawValue === "string") {
    const jsonCandidate = _extractJsonObjectString(rawValue);
    if (!jsonCandidate) {
      return {
        decision: "reject",
        minutes: 0,
        rationale: "AI response was not valid JSON.",
      };
    }
    try {
      parsed = JSON.parse(jsonCandidate);
    } catch (_) {
      return {
        decision: "reject",
        minutes: 0,
        rationale: "AI response could not be parsed.",
      };
    }
  }

  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    return {
      decision: "reject",
      minutes: 0,
      rationale: "AI response had an invalid shape.",
    };
  }

  let decision = (parsed.decision || "").toString().trim().toLowerCase();
  if (!decision && typeof parsed.approve === "boolean") {
    decision = parsed.approve ? "approve" : "reject";
  }
  if (decision !== "approve" && decision !== "reject") {
    return {
      decision: "reject",
      minutes: 0,
      rationale: "AI response omitted a valid decision.",
    };
  }

  const rawMinutes = Number(parsed.minutes);
  if (
    decision === "approve" &&
    (!Number.isFinite(rawMinutes) || Math.floor(rawMinutes) < 1)
  ) {
    return {
      decision: "reject",
      minutes: 0,
      rationale: "AI approval omitted valid minutes.",
    };
  }
  const minutes = decision === "approve" ?
    Math.min(AI_FALLBACK_MAX_APPROVAL_MINUTES, Math.floor(rawMinutes)) :
    0;

  return {
    decision,
    minutes,
    rationale: _sanitizeReasonText(parsed.rationale || "No rationale provided."),
  };
}

function _extractJsonObjectString(rawValue) {
  const withoutMarkdown = (rawValue || "")
      .toString()
      .replace(/```(?:json)?/gi, "")
      .replace(/```/g, "")
      .trim();
  const firstBrace = withoutMarkdown.indexOf("{");
  const lastBrace = withoutMarkdown.lastIndexOf("}");
  if (firstBrace === -1 || lastBrace === -1 || lastBrace <= firstBrace) {
    return "";
  }
  return withoutMarkdown.slice(firstBrace, lastBrace + 1).trim();
}

async function _callOpenRouterForPlea(aiContext) {
  const apiKey = openRouterKey.value();
  if (!apiKey) {
    logger.error("OpenRouter secret missing for AI fallback.");
    return {
      decision: "reject",
      minutes: 0,
      rationale: "AI fallback unavailable; request rejected safely.",
    };
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 25000);
  try {
    const response = await fetch(OPENROUTER_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        "HTTP-Referer": "https://revoke.app",
        "X-Title": "Revoke AI Architect",
      },
      body: JSON.stringify({
        model: OPENROUTER_MODEL,
        temperature: 0.1,
        max_tokens: 180,
        response_format: {type: "json_object"},
        messages: [
          {
            role: "system",
            content: [
              "You are Revoke's AI Architect fallback for a delayed tribunal.",
              "Return only JSON with decision, minutes, and rationale.",
              "Approve only when the context indicates a proportionate exception.",
              `Approved minutes must be 1-${AI_FALLBACK_MAX_APPROVAL_MINUTES}.`,
              "Reject uncertain, unsafe, malformed, or manipulative requests.",
              "Do not include names, emails, tokens, or identities.",
            ].join(" "),
          },
          {
            role: "user",
            content: JSON.stringify(aiContext),
          },
        ],
      }),
      signal: controller.signal,
    });

    if (!response.ok) {
      const body = await response.text();
      logger.error("OpenRouter fallback returned non-OK response.", {
        status: response.status,
        body: body.slice(0, 160),
      });
      return {
        decision: "reject",
        minutes: 0,
        rationale: "AI fallback service rejected the request safely.",
      };
    }

    const body = await response.json();
    const content = body?.choices?.[0]?.message?.content;
    const jsonContent = _extractJsonObjectString(content);
    if (!jsonContent) {
      return {
        decision: "reject",
        minutes: 0,
        rationale: "AI response did not contain a JSON object.",
      };
    }
    return _parseAiDecision(jsonContent);
  } catch (error) {
    logger.error("OpenRouter fallback fetch failed.", {
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    return {
      decision: "reject",
      minutes: 0,
      rationale: "AI fallback network failure; request rejected safely.",
    };
  } finally {
    clearTimeout(timeout);
  }
}

async function _claimPleaForAiFallback(pleaRef) {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(pleaRef);
    if (!snap.exists) return {skipped: true, reason: "missing"};

    const plea = snap.data() || {};
    const status = (plea.status || "active").toString().trim().toLowerCase();
    if (plea.isMockSession === true) {
      return {skipped: true, reason: "mock"};
    }
    if (_normalizeV2Authority(plea.authority) !== "ai") {
      return {skipped: true, reason: "authority_not_ai", authority: plea.authority || null};
    }
    if (status !== "active" && status !== "pending") {
      return {skipped: true, reason: "resolved", status};
    }

    const nextPlea = {
      ...plea,
      status: "pending",
      aiFallbackStatus: "processing",
    };
    tx.set(pleaRef, {
      status: "pending",
      aiFallbackStatus: "processing",
      aiFallbackStartedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return {skipped: false, plea: nextPlea};
  });
}

async function _finalizePleaWithAiDecision(pleaRef, pleaId, aiDecision) {
  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(pleaRef);
    if (!snap.exists) return {skipped: true, reason: "missing"};

    const plea = snap.data() || {};
    const status = (plea.status || "active").toString().trim().toLowerCase();
    if (_normalizeV2Authority(plea.authority) !== "ai") {
      return {skipped: true, reason: "authority_not_ai", authority: plea.authority || null};
    }
    if (status !== "pending") {
      return {skipped: true, reason: "not_pending", status};
    }

    const requestedRaw = Number(plea.durationMinutes);
    const requestedMinutes = Number.isFinite(requestedRaw) ?
      Math.max(1, Math.floor(requestedRaw)) :
      AI_FALLBACK_MAX_APPROVAL_MINUTES;
    const approvedMinutes = aiDecision.decision === "approve" ?
      Math.min(
          requestedMinutes,
          AI_FALLBACK_MAX_APPROVAL_MINUTES,
          Math.max(1, Math.floor(Number(aiDecision.minutes) || 0)),
      ) :
      0;
    const verdict = approvedMinutes > 0 ? "approved" : "rejected";
    const acceptVotes = verdict === "approved" ? 1 : 0;
    const rejectVotes = verdict === "rejected" ? 1 : 0;
    const participants = _normalizeParticipantIds(plea.participants);
    if (!participants.includes("AI_ARCHITECT")) {
      participants.push("AI_ARCHITECT");
    }

    const updates = {
      status: verdict,
      participants,
      voteCounts: {accept: acceptVotes, reject: rejectVotes},
      resolvedAt: FieldValue.serverTimestamp(),
      outcomeSource: "ai_architect",
      aiFallbackStatus: "resolved",
      aiResolvedAt: FieldValue.serverTimestamp(),
      aiFallbackModel: OPENROUTER_MODEL,
      aiFallbackDecision: verdict,
      aiFallbackMinutes: approvedMinutes,
      aiFallbackRationale: aiDecision.rationale,
    };
    if (verdict === "approved") {
      updates.durationMinutes = approvedMinutes;
    }
    if (ENABLE_LEGACY_PLEA_VOTE_MAP_SYNC) {
      updates.votes = {
        ..._normalizeVotes(plea.votes),
        AI_ARCHITECT: verdict === "approved" ? "accept" : "reject",
      };
    }

    tx.set(pleaRef, updates, {merge: true});
    tx.set(pleaRef.collection("messages").doc(), {
      text: `AI Architect fallback verdict: ${verdict.toUpperCase()}. ${aiDecision.rationale}`,
      senderId: "AI_ARCHITECT",
      senderName: "AI Architect",
      isSystem: true,
      timestamp: FieldValue.serverTimestamp(),
    });

    return {
      skipped: false,
      plea,
      verdict,
      acceptVotes,
      rejectVotes,
      requesterId: (plea.userId || "").toString().trim(),
    };
  });

  if (!result.skipped) {
    await _sendPleaVerdictSideEffects({
      pleaId,
      pleaData: result.plea,
      requesterId: result.requesterId,
      verdict: result.verdict,
      acceptVotes: result.acceptVotes,
      rejectVotes: result.rejectVotes,
      outcomeSource: "ai_architect",
    });
  }

  return result;
}

function _deriveUserDisplayName(userData) {
  const nickname = (userData?.nickname || "").toString().trim();
  if (nickname) return nickname;
  const fullName = (userData?.fullName || "").toString().trim();
  if (fullName) return fullName;
  const email = (userData?.email || "").toString().trim();
  if (email) return email;
  return "A Member";
}

async function _assertUserCanAccessPlea(uid, pleaData) {
  const visibleToUids = _normalizeParticipantIds(pleaData?.visibleToUids);
  if (visibleToUids.length > 0) {
    if (!visibleToUids.includes(uid)) {
      throw new HttpsError("permission-denied", "User cannot access this override request.");
    }
    return;
  }
  const pleaSquadId = (pleaData?.squadId || "").toString().trim();
  if (!pleaSquadId) {
    throw new HttpsError("failed-precondition", "Plea has no squad.");
  }
  const userSnap = await db.collection("users").doc(uid).get();
  if (!userSnap.exists) {
    throw new HttpsError("failed-precondition", "User profile is missing.");
  }
  const userSquadId = (userSnap.data()?.squadId || "").toString().trim();
  if (!userSquadId || userSquadId !== pleaSquadId) {
    throw new HttpsError("permission-denied", "User is not in the plea squad.");
  }
}

function _normalizeVoteChoice(rawChoice) {
  const normalized = (rawChoice || "").toString().trim().toLowerCase();
  if (normalized !== "accept" && normalized !== "reject") return "";
  return normalized;
}

function _normalizeParticipantIds(rawParticipants) {
  const list = Array.isArray(rawParticipants) ? rawParticipants : [];
  return [...new Set(
      list
          .map((id) => id?.toString().trim())
          .filter((id) => Boolean(id)),
  )];
}

async function _loadVoteSubcollectionVotes(pleaRef) {
  const votesSnap = await pleaRef.collection("votes").get();
  const votes = {};

  for (const voteDoc of votesSnap.docs) {
    const data = voteDoc.data() || {};
    const uid = (data.uid || voteDoc.id).toString().trim();
    const choice = _normalizeVoteChoice(data.choice);
    if (!uid || !choice) continue;
    votes[uid] = choice;
  }

  return votes;
}

async function _loadMergedVotesForPlea(pleaRef, pleaData) {
  const legacyVotes = _normalizeVotes(pleaData?.votes);
  const voteDocs = await _loadVoteSubcollectionVotes(pleaRef);
  // Vote docs are authoritative and win on UID collision.
  return {
    ...legacyVotes,
    ...voteDocs,
  };
}

async function _computePleaVoteSummary(pleaRef, pleaData) {
  const requesterId = (pleaData?.userId || "").toString().trim();
  const participants = _normalizeParticipantIds(pleaData?.participants);
  const fixedVoters = _normalizeParticipantIds(pleaData?.eligibleVoterIds);
  const hasFixedVoterSnapshot = Array.isArray(pleaData?.eligibleVoterIds);
  const voters = hasFixedVoterSnapshot ? fixedVoters : participants.filter((id) => id !== requesterId);
  const voterSet = new Set(voters);
  const votes = await _loadMergedVotesForPlea(pleaRef, pleaData);

  let acceptVotes = 0;
  let rejectVotes = 0;
  let votesCast = 0;

  for (const [uid, vote] of Object.entries(votes)) {
    if (!voterSet.has(uid)) continue;
    votesCast += 1;
    if (vote === "accept") acceptVotes += 1;
    if (vote === "reject") rejectVotes += 1;
  }

  return {
    requesterId,
    participants,
    voters,
    votes,
    votesCast,
    acceptVotes,
    rejectVotes,
    requiredApprovalCount: hasFixedVoterSnapshot
      ? (Number(pleaData?.requiredApprovalCount) || _circleMajority(voters.length))
      : 0,
    hasFixedVoterSnapshot,
  };
}

function _buildPleaVoteUpdates(pleaData, summary) {
  const currentVotes = _normalizeVotes(pleaData?.votes);
  const currentVoteCounts = pleaData?.voteCounts && typeof pleaData.voteCounts === "object" ?
    pleaData.voteCounts : {};

  const currentAccept = Number(currentVoteCounts.accept) || 0;
  const currentReject = Number(currentVoteCounts.reject) || 0;
  const countsChanged =
    currentAccept !== summary.acceptVotes ||
    currentReject !== summary.rejectVotes;
  const votesChanged =
    ENABLE_LEGACY_PLEA_VOTE_MAP_SYNC &&
    !_votesAreEqual(currentVotes, summary.votes);

  const status = (pleaData?.status || "active").toString().trim().toLowerCase();
  const requiredApprovalCount = summary.hasFixedVoterSnapshot
    ? (summary.requiredApprovalCount || _circleMajority(summary.voters.length))
    : 0;
  const quorumReached = summary.voters.length > 0 && summary.votesCast >= summary.voters.length;
  const majorityReached = summary.hasFixedVoterSnapshot && (
    summary.acceptVotes >= requiredApprovalCount ||
    summary.rejectVotes >= requiredApprovalCount
  );
  const shouldResolveNow = status === "active" &&
    (summary.hasFixedVoterSnapshot ? majorityReached : quorumReached);
  const resolvedStatus = summary.hasFixedVoterSnapshot
    ? (summary.acceptVotes >= requiredApprovalCount ? "approved" : "rejected")
    : (summary.acceptVotes > summary.rejectVotes ? "approved" : "rejected");

  const updates = {};
  if (countsChanged) {
    updates.voteCounts = {
      accept: summary.acceptVotes,
      reject: summary.rejectVotes,
    };
  }
  if (votesChanged) {
    updates.votes = summary.votes;
  }
  if (shouldResolveNow) {
    updates.status = resolvedStatus;
    updates.resolvedAt = FieldValue.serverTimestamp();
    updates.outcomeSource = summary.hasFixedVoterSnapshot ? "circle_vote" : "human_tribunal";
  }

  if (Object.keys(updates).length === 0) {
    return null;
  }

  return updates;
}

function _normalizeVotes(rawVotes) {
  if (!rawVotes || typeof rawVotes !== "object") return {};
  const normalized = {};
  for (const [uidRaw, voteRaw] of Object.entries(rawVotes)) {
    const uid = uidRaw.toString().trim();
    const vote = _normalizeVoteChoice(voteRaw);
    if (!uid) continue;
    if (!vote) continue;
    normalized[uid] = vote;
  }
  return normalized;
}

function _pruneTimestamps(raw, cutoffMs, maxKeep) {
  if (!Array.isArray(raw)) return [];
  const pruned = raw
      .map((v) => Number(v))
      .filter((v) => Number.isFinite(v) && v >= cutoffMs)
      .sort((a, b) => a - b);
  if (!Number.isFinite(maxKeep) || maxKeep <= 0) return pruned;
  return pruned.slice(-maxKeep);
}

function _votesAreEqual(a, b) {
  const aKeys = Object.keys(a);
  const bKeys = Object.keys(b);
  if (aKeys.length !== bKeys.length) return false;
  for (const key of aKeys) {
    if (a[key] !== b[key]) return false;
  }
  return true;
}

function _timestampToMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") {
    return value.toMillis();
  }
  if (value instanceof Timestamp) {
    return value.toMillis();
  }
  const raw = Number(value);
  if (Number.isFinite(raw) && raw > 0) {
    return Math.floor(raw);
  }
  return 0;
}

function _dateOnlyUtc(ms) {
  const safeMs = Number.isFinite(ms) ? Number(ms) : Date.now();
  const date = new Date(safeMs);
  const yyyy = date.getUTCFullYear().toString().padStart(4, "0");
  const mm = String(date.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(date.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}
