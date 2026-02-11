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
  const pleaId = event.params.pleaId;
  const plea = event.data?.data();

  if (!plea) {
    logger.warn("Plea trigger fired with no document data.", {pleaId});
    return;
  }

  const squadId = plea.squadId;
  const requesterUid = plea.userId;
  const requesterName = (plea.userName || "A squad member").toString();
  const appName = (plea.appName || "an app").toString();

  if (!squadId || !requesterUid) {
    logger.warn("Plea missing required routing fields.", {pleaId});
    return;
  }

  const usersSnap = await db
      .collection("users")
      .where("squadId", "==", squadId)
      .where("uid", "!=", requesterUid)
      .get();

  const tokens = usersSnap.docs
      .map((doc) => doc.get("fcmToken"))
      .where((token) => typeof token === "string" && token.length > 0);

  const uniqueTokens = [...new Set(tokens)];
  if (uniqueTokens.length === 0) {
    logger.info("No target tokens for plea broadcast.", {pleaId, squadId});
    return;
  }

  const title = "JUDGMENT REQUIRED";
  const body = `${requesterName} is begging for time on ${appName}!`;
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
        pleaId: String(pleaId),
        squadId: String(squadId),
      },
    });

    successCount += response.successCount;
    failureCount += response.failureCount;
  }

  logger.info("Plea broadcast completed.", {
    pleaId,
    squadId,
    recipients: uniqueTokens.length,
    successCount,
    failureCount,
  });
});
