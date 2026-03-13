const {
  onDocumentCreated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

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

const RESOLVED_PLEA_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const MARKED_FOR_DELETION_TTL_MS = 10 * 60 * 1000;
const CLEANUP_BATCH_LIMIT = 100;

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

    const usersSnap = await db
        .collection("users")
        .where("squadId", "==", squadId)
        .get();

    const tokens = [];
    const eligibleVoterIds = [];
    let optOutCount = 0;
    for (const userDoc of usersSnap.docs) {
      const data = userDoc.data() || {};
      const memberUid = (data.uid || userDoc.id || "").toString().trim();
      const token = (data.fcmToken || "").toString().trim();
      const wantsReq = _wantsNotification(data, "pleaRequests");
      if (!memberUid || memberUid === requesterUid) continue;
      eligibleVoterIds.push(memberUid);
      if (!wantsReq) {
        optOutCount += 1;
        continue;
      }
      if (!token) continue;
      tokens.push(token);
    }

    const uniqueEligibleVoterIds = [...new Set(eligibleVoterIds)];
    const uniqueTokens = [...new Set(tokens)];
    const inAppBody = `${requesterName} is begging the Squad. Cast your vote.`;
    const inAppPromises = uniqueEligibleVoterIds.map((memberId) =>
      createInAppNotification(memberId, {
        title: "TRIBUNAL SUMMONED",
        body: inAppBody,
        type: "plea",
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

    const title = "JUDGMENT REQUIRED";
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
          type: "plea",
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
      inAppRecipients: uniqueEligibleVoterIds.length,
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
      try {
        const squadId = (pleaData.squadId || "").toString().trim();
        const requesterName = (pleaData.userName || "").toString().trim() || "A Member";
        let requesterToken = "";
        let requesterWantsVerdicts = true;
        let avatar = "";
        const isApproved = updates.status === "approved";
        const outcome = isApproved ? "APPROVED" : "REJECTED";
        const inAppVerdictTitle = `VERDICT: ${isApproved ? "GRANTED" : "DENIED"}`;
        const inAppVerdictBody = "The Conclave has decided your fate.";
        const verdictBody = `Your plea for ${pleaData.appName || "access"} was ${outcome.toLowerCase()}.`;
        if (summary.requesterId) {
          const userSnap = await db.collection("users").doc(summary.requesterId).get();
          const requesterData = userSnap.data() || {};
          avatar = (requesterData.photoUrl || "").toString().trim();
          requesterToken = (requesterData.fcmToken || "").toString().trim();
          requesterWantsVerdicts = _wantsNotification(requesterData, "verdicts");

          await createInAppNotification(summary.requesterId, {
            title: inAppVerdictTitle,
            body: inAppVerdictBody,
            type: "verdict",
            metadata: {
                pleaId: String(pleaId),
                squadId: String(squadId),
                verdict: String(updates.status),
            },
          });
        }

        if (requesterToken && requesterWantsVerdicts) {
          await _sendUserNotificationBestEffort(
              requesterToken,
              `VERDICT: ${outcome}`,
              verdictBody,
              {
                type: "verdict",
                pleaId: String(pleaId),
                squadId: String(squadId),
                verdict: String(updates.status),
              },
          );
        }

        const title = `Verdict: ${updates.status.toUpperCase()} for ${requesterName}.`;
        await logSquadEvent(
            squadId,
            "verdict",
            title,
            {
              userId: summary.requesterId,
              userName: requesterName,
              userAvatar: avatar,
            },
            {
              pleaId: String(pleaId),
              verdict: updates.status,
              acceptVotes: summary.acceptVotes,
              rejectVotes: summary.rejectVotes,
            },
        );
      } catch (_) {
        // Best-effort only.
      }
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

exports.adminOverridePlea = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  if (request.auth.token?.admin !== true) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }

  const pleaId = (request.data?.pleaId || "").toString().trim();
  const verdict = (request.data?.verdict || "").toString().trim().toLowerCase();
  const reason = (request.data?.reason || "").toString().trim();

  if (!pleaId) {
    throw new HttpsError("invalid-argument", "pleaId is required.");
  }
  if (verdict !== "approved" && verdict !== "rejected") {
    throw new HttpsError(
        "invalid-argument",
        "verdict must be 'approved' or 'rejected'.",
    );
  }

  const pleaRef = db.collection("pleas").doc(pleaId);

  try {
    const pleaSnap = await pleaRef.get();
    if (!pleaSnap.exists) {
      throw new HttpsError("not-found", "Plea not found.");
    }
    const plea = pleaSnap.data() || {};
    const currentStatus = (plea.status || "active").toString().trim().toLowerCase();
    if (currentStatus !== "active") {
      throw new HttpsError(
          "failed-precondition",
          "Plea is already resolved.",
      );
    }

    await pleaRef.set({
      status: verdict,
      resolvedAt: FieldValue.serverTimestamp(),
      outcomeSource: "admin_override",
      markedForDeletion: true,
      deletionMarkedAt: FieldValue.serverTimestamp(),
      deletionMarkedBy: request.auth.uid,
    }, {merge: true});

    const architectMessage = `The Architect has intervened. Verdict: ${verdict.toUpperCase()}. Reason: ${reason || "No reason provided."}`;
    await pleaRef.collection("messages").add({
      text: architectMessage,
      senderId: "THE_ARCHITECT",
      senderName: "The Architect",
      isSystem: true,
      timestamp: FieldValue.serverTimestamp(),
    });

    logger.info("adminOverridePlea applied.", {
      pleaId,
      verdict,
      reasonProvided: Boolean(reason),
      actorUid: request.auth.uid,
    });

    return {
      success: true,
      pleaId,
      verdict,
      outcomeSource: "admin_override",
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    logger.error("adminOverridePlea crashed.", {
      pleaId,
      verdict,
      errorMessage: error?.message || String(error),
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "Failed to override plea.");
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
    const highScoreWardenApproval = Math.random() >= 0.5;

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
        createdAt: FieldValue.serverTimestamp(),
        createdBy: callerUid,
      };

      if (isSoloPlea) {
        const focusScoreRaw = Number(requesterData.focusScore);
        const focusScore = Number.isFinite(focusScoreRaw) ?
          Math.floor(focusScoreRaw) :
          0;

        let isApproved = false;
        let wardenReason = "Score too low. The Warden denies your request.";

        if (focusScore >= 500) {
          isApproved = highScoreWardenApproval;
          wardenReason = isApproved ?
            "The Warden grants you mercy. Do not waste this time." :
            "The Warden has spoken. Plea denied.";
        }

        const verdict = isApproved ? "approved" : "rejected";
        createdStatus = verdict;
        outcomeSource = "system_warden";
        usedWarden = true;

        tx.set(pleaRef, {
          ...basePleaDoc,
          participants: [requestedUid, "SYSTEM_WARDEN"],
          voteCounts: {
            accept: isApproved ? 1 : 0,
            reject: isApproved ? 0 : 1,
          },
          votes: {
            SYSTEM_WARDEN: isApproved ? "accept" : "reject",
          },
          status: verdict,
          resolvedAt: FieldValue.serverTimestamp(),
          outcomeSource: "system_warden",
          wardenReason,
          eligibleVoterCount: 0,
        });

        const verdictMessage = isApproved ?
          "The Warden grants you mercy. Do not waste this time." :
          "The Warden has spoken. Plea denied.";
        tx.set(pleaRef.collection("messages").doc(), {
          senderId: "SYSTEM_WARDEN",
          senderName: "The Warden",
          isSystem: true,
          text: verdictMessage,
          timestamp: FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(pleaRef, {
          ...basePleaDoc,
          participants: [requestedUid],
          voteCounts: {accept: 0, reject: 0},
          votes: {},
          status: "active",
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

    if (usedWarden) {
      const isApproved = createdStatus === "approved";
      await createInAppNotification(requestedUid, {
        title: `VERDICT: ${isApproved ? "GRANTED" : "DENIED"}`,
        body: "The Conclave has decided your fate.",
        type: "verdict",
        metadata: {
          pleaId: pleaRef.id,
          outcomeSource,
          source: "system_warden",
        },
      });
    }

    // Best-effort squad log entry (outside transaction).
    try {
      const requesterSnap = await db.collection("users").doc(requestedUid).get();
      const requesterData = requesterSnap.exists ? (requesterSnap.data() || {}) : {};
      const squadId = (requesterData.squadId || "").toString().trim();
      const userName = _deriveUserDisplayName(requesterData);
      const userAvatar = (requesterData.photoUrl || "").toString().trim();
      const title = `${userName} is begging for ${durationMinutes} mins on ${appName}.`;
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
      if (status !== "active") {
        throw new HttpsError("failed-precondition", "Tribunal is closed.");
      }

      if (!isAdmin) {
        const userSnap = await tx.get(userRef);
        if (!userSnap.exists) {
          throw new HttpsError("failed-precondition", "User profile is missing.");
        }
        const userData = userSnap.data() || {};
        const userSquadId = (userData.squadId || "").toString().trim();
        const pleaSquadId = (plea.squadId || "").toString().trim();
        if (!userSquadId || userSquadId !== pleaSquadId) {
          throw new HttpsError("permission-denied", "User cannot message this tribunal.");
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
        const callerRef = db.collection("users").doc(uid);
        const callerSnap = await tx.get(callerRef);
        if (!callerSnap.exists) {
          throw new HttpsError("failed-precondition", "User profile is missing.");
        }
        const callerSquadId = (callerSnap.data()?.squadId || "").toString().trim();
        const pleaSquadId = (plea.squadId || "").toString().trim();
        if (!callerSquadId || callerSquadId != pleaSquadId) {
          throw new HttpsError("permission-denied", "User is not allowed to vote on this plea.");
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

    const regimesSnap = await db
        .collection("users")
        .doc(targetUid)
        .collection("regimes")
        .get();

    const activeProtocols = [];
    const blacklistApps = new Set();

    for (const regimeDoc of regimesSnap.docs) {
      const regime = regimeDoc.data() || {};
      const isEnabled = Boolean(
          regime.isEnabled ?? regime.isActive ?? true,
      );
      if (!isEnabled) continue;

      const regimeName = (regime.name || "").toString().trim() || "REGIME";
      activeProtocols.push(regimeName);

      const targets = Array.isArray(regime.targetApps) ?
        regime.targetApps :
        (Array.isArray(regime.apps) ? regime.apps : []);
      for (const app of targets) {
        const appName = (app || "").toString().trim();
        if (!appName) continue;
        blacklistApps.add(appName);
      }
    }

    const pleaBaseQuery = db
        .collection("pleas")
        .where("squadId", "==", targetUser.squadId)
        .where("userId", "==", targetUid);

    let totalPleas = 0;
    let approvedPleas = 0;
    let rejectedPleas = 0;

    try {
      const [totalAgg, approvedAgg, rejectedAgg] = await Promise.all([
        pleaBaseQuery.count().get(),
        pleaBaseQuery.where("status", "==", "approved").count().get(),
        pleaBaseQuery.where("status", "==", "rejected").count().get(),
      ]);

      totalPleas = Number(totalAgg.data().count) || 0;
      approvedPleas = Number(approvedAgg.data().count) || 0;
      rejectedPleas = Number(rejectedAgg.data().count) || 0;
    } catch (_) {
      // Fallback path if aggregate query support is unavailable.
      const pleasSnap = await pleaBaseQuery.get();
      totalPleas = pleasSnap.size;
      for (const pleaDoc of pleasSnap.docs) {
        const status = (pleaDoc.data()?.status || "").toString().trim().toLowerCase();
        if (status === "approved") approvedPleas += 1;
        if (status === "rejected") rejectedPleas += 1;
      }
    }

    const sortedProtocols = activeProtocols
        .map((name) => name.toString().trim())
        .filter((name) => Boolean(name))
        .sort((a, b) => a.localeCompare(b));
    const sortedBlacklist = [...blacklistApps].sort((a, b) => a.localeCompare(b));

    const snapshot = {
      targetUid,
      squadId: targetUser.squadId,
      activeProtocols: sortedProtocols,
      activeProtocolCount: sortedProtocols.length,
      blacklistApps: sortedBlacklist,
      blacklistCount: sortedBlacklist.length,
      pleaStats: {
        total: totalPleas,
        approved: approvedPleas,
        rejected: rejectedPleas,
      },
      generatedAtMs: Date.now(),
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
        senderId: "THE_ARCHITECT",
        senderName: "The Architect",
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

    if (snap.empty) return;

    let finalized = 0;

    for (const doc of snap.docs) {
      const pleaRef = doc.ref;
      const plea = doc.data() || {};

      if (plea.isMockSession === true) continue;

      const summary = await _computePleaVoteSummary(pleaRef, plea);

      // Timeout verdict is always rejected on tie or incomplete quorum.
      const verdict = summary.acceptVotes > summary.rejectVotes ? "approved" : "rejected";

      const timeoutUpdate = {
        status: verdict,
        voteCounts: {accept: summary.acceptVotes, reject: summary.rejectVotes},
        resolvedAt: FieldValue.serverTimestamp(),
        outcomeSource: "timeout",
        timedOutAt: FieldValue.serverTimestamp(),
      };
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

      if (summary.requesterId) {
        const isApproved = verdict === "approved";
        await createInAppNotification(summary.requesterId, {
          title: `VERDICT: ${isApproved ? "GRANTED" : "DENIED"}`,
          body: "The Conclave has decided your fate.",
          type: "verdict",
          metadata: {
            pleaId: doc.id,
            squadId: (plea.squadId || "").toString().trim(),
            verdict,
            outcomeSource: "timeout",
          },
        });
      }

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
  const voters = participants.filter((id) => id !== requesterId);
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
  const quorumReached = summary.voters.length > 0 && summary.votesCast >= summary.voters.length;
  const shouldResolveNow = status === "active" && quorumReached;
  const resolvedStatus = summary.acceptVotes > summary.rejectVotes ? "approved" : "rejected";

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

function _dateOnlyUtc(ms) {
  const safeMs = Number.isFinite(ms) ? Number(ms) : Date.now();
  const date = new Date(safeMs);
  const yyyy = date.getUTCFullYear().toString().padStart(4, "0");
  const mm = String(date.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(date.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}
