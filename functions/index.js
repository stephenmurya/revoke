const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

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
