const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
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
    for (const userDoc of usersSnap.docs) {
      const data = userDoc.data() || {};
      const memberUid = (data.uid || userDoc.id || "").toString();
      const token = (data.fcmToken || "").toString().trim();
      if (!memberUid || memberUid === requesterUid) continue;
      if (!token) continue;
      tokens.push(token);
    }

    const uniqueTokens = [...new Set(tokens)];
    if (uniqueTokens.length === 0) {
      logger.info("No target tokens for plea broadcast.", {pleaId, squadId});
      return;
    }

    const title = "JUDGMENT REQUIRED";
    const body = `${requesterName} is begging for ${durationMinutes} mins on ${appName}!`;
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
          type: "plea_judgement",
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
      recipients: uniqueTokens.length,
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

exports.resolvePleaVerdict = onDocumentUpdated({
  document: "pleas/{pleaId}",
  region: "us-central1",
}, async (event) => {
  const pleaId = event.params?.pleaId;
  try {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};

    const beforeVotes = _normalizeVotes(before.votes);
    const afterVotes = _normalizeVotes(after.votes);

    if (_votesAreEqual(beforeVotes, afterVotes)) {
      return;
    }

    const status = (after.status || "active").toString().trim().toLowerCase();
    if (status !== "active") {
      return;
    }

    const requesterId = (after.userId || "").toString().trim();
    const participantsRaw = Array.isArray(after.participants) ?
      after.participants : [];
    const participants = [...new Set(
      participantsRaw
          .map((id) => id?.toString().trim())
          .filter((id) => Boolean(id)),
    )];

    // Deadlock fix: requester attends, but requester does not vote.
    const voters = participants.filter((id) => id !== requesterId);
    const voterSet = new Set(voters);

    let acceptVotes = 0;
    let rejectVotes = 0;
    let votesCast = 0;

    for (const [uid, vote] of Object.entries(afterVotes)) {
      if (!voterSet.has(uid)) continue;
      votesCast += 1;
      if (vote === "accept") acceptVotes += 1;
      if (vote === "reject") rejectVotes += 1;
    }

    const updates = {
      voteCounts: {
        accept: acceptVotes,
        reject: rejectVotes,
      },
    };

    if (votesCast >= voters.length && voters.length > 0) {
      updates.status = acceptVotes > rejectVotes ? "approved" : "rejected";
      updates.resolvedAt = FieldValue.serverTimestamp();
    }

    await event.data.after.ref.update(updates);

    if (updates.status) {
      try {
        const squadId = (after.squadId || "").toString().trim();
        const requesterName = (after.userName || "").toString().trim() || "A Member";
        let avatar = "";
        if (requesterId) {
          const userSnap = await db.collection("users").doc(requesterId).get();
          avatar = (userSnap.data()?.photoUrl || "").toString().trim();
        }

        const title = `Verdict: ${updates.status.toUpperCase()} for ${requesterName}.`;
        await logSquadEvent(
            squadId,
            "verdict",
            title,
            {userId: requesterId, userName: requesterName, userAvatar: avatar},
            {
              pleaId: String(pleaId),
              verdict: updates.status,
              acceptVotes,
              rejectVotes,
            },
        );
      } catch (_) {
        // Best-effort only.
      }
    }

    logger.info("resolvePleaVerdict processed vote update.", {
      pleaId,
      requesterId,
      participants: participants.length,
      voters: voters.length,
      votesCast,
      acceptVotes,
      rejectVotes,
      resolved: Boolean(updates.status),
      status: updates.status || "active",
    });
  } catch (error) {
    logger.error("resolvePleaVerdict crashed.", {
      pleaId,
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

    await pleaRef.set({
      status: verdict,
      resolvedAt: FieldValue.serverTimestamp(),
      outcomeSource: "admin_override",
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
    const messageId = await messaging.send({
      topic: "global_citizens",
      notification: {title, body},
      data: {
        type: "SYSTEM_MANDATE",
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

    logger.info("broadcastSystemMandate sent.", {
      actorUid: request.auth.uid,
      messageId,
    });
    return {success: true, messageId};
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
        duration: String(durationMinutes),
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

    await db.runTransaction(async (tx) => {
      const requesterSnap = await tx.get(requesterRef);
      if (!requesterSnap.exists) {
        throw new HttpsError("failed-precondition", "Requester user profile is missing.");
      }
      const requesterData = requesterSnap.data() || {};
      const squadId = (requesterData.squadId || "").toString().trim();
      if (!squadId) {
        throw new HttpsError("failed-precondition", "Requester is not in a squad.");
      }

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
      tx.set(pleaRef, {
        userId: requestedUid,
        userName,
        squadId,
        appName,
        packageName,
        durationMinutes,
        reason,
        participants: [requestedUid],
        voteCounts: {accept: 0, reject: 0},
        votes: {},
        status: "active",
        createdAt: FieldValue.serverTimestamp(),
        createdBy: callerUid,
      });

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
    });

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
          },
      );
    } catch (_) {
      // Best-effort only.
    }

    return {
      success: true,
      pleaId: pleaRef.id,
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

      tx.update(pleaRef, {
        [`votes.${uid}`]: choice,
        participants: FieldValue.arrayUnion(uid),
        lastVoteAt: FieldValue.serverTimestamp(),
      });
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
          await _deletePleaWithMessages(pleaRef);
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

      const requesterId = (plea.userId || "").toString().trim();
      const participantsRaw = Array.isArray(plea.participants) ? plea.participants : [];
      const participants = [...new Set(
          participantsRaw
              .map((id) => id?.toString().trim())
              .filter((id) => Boolean(id)),
      )];
      const voters = participants.filter((id) => id !== requesterId);
      const voterSet = new Set(voters);
      const votes = _normalizeVotes(plea.votes);

      let acceptVotes = 0;
      let rejectVotes = 0;
      let votesCast = 0;

      for (const [uid, vote] of Object.entries(votes)) {
        if (!voterSet.has(uid)) continue;
        votesCast += 1;
        if (vote === "accept") acceptVotes += 1;
        if (vote === "reject") rejectVotes += 1;
      }

      // Timeout verdict is always rejected on tie or incomplete quorum.
      const verdict = acceptVotes > rejectVotes ? "approved" : "rejected";

      await pleaRef.set({
        status: verdict,
        voteCounts: {accept: acceptVotes, reject: rejectVotes},
        resolvedAt: FieldValue.serverTimestamp(),
        outcomeSource: "timeout",
        timedOutAt: FieldValue.serverTimestamp(),
      }, {merge: true});

      await pleaRef.collection("messages").add({
        senderId: "SYSTEM",
        senderName: "System",
        isSystem: true,
        text: `Tribunal timed out. Verdict: ${verdict.toUpperCase()}.`,
        timestamp: FieldValue.serverTimestamp(),
      });

      finalized += 1;
      logger.info("autoFinalizeStalePleas resolved plea.", {
        pleaId: doc.id,
        requesterId,
        participants: participants.length,
        voters: voters.length,
        votesCast,
        acceptVotes,
        rejectVotes,
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
    let pleaDeletes = 0;

    for (const pleaRef of toDelete.values()) {
      const messages = await pleaRef.collection("messages").listDocuments();
      for (const msgRef of messages) {
        writer.delete(msgRef);
        messageDeletes += 1;
      }
      writer.delete(pleaRef);
      pleaDeletes += 1;
    }

    await writer.close();

    logger.info("cleanupPleaData completed.", {
      pleasDeleted: pleaDeletes,
      messagesDeleted: messageDeletes,
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
    await _deletePleaWithMessages(pleaRef);
    deleted += 1;
  }
  return deleted;
}

async function _deletePleaWithMessages(pleaRef) {
  const messagesSnap = await pleaRef.collection("messages").get();
  const batch = db.batch();
  for (const messageDoc of messagesSnap.docs) {
    batch.delete(messageDoc.ref);
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

function _normalizeVotes(rawVotes) {
  if (!rawVotes || typeof rawVotes !== "object") return {};
  const normalized = {};
  for (const [uidRaw, voteRaw] of Object.entries(rawVotes)) {
    const uid = uidRaw.toString().trim();
    const vote = voteRaw?.toString().trim().toLowerCase();
    if (!uid) continue;
    if (vote !== "accept" && vote !== "reject") continue;
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
