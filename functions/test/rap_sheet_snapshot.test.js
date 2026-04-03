const assert = require("node:assert/strict");
const {test, afterEach} = require("node:test");
const {Timestamp, getFirestore} = require("firebase-admin/firestore");
require("../index.js");

const {__testables} = require("../index.js");
const db = getFirestore();

async function safeDelete(ref) {
  const snap = await ref.get();
  if (snap.exists) {
    await ref.delete();
  }
}

afterEach(async () => {
  const userRef = db.collection("users").doc("rap_sheet_alice");
  const scoreEvents = await userRef.collection("scoreEvents").get();
  for (const doc of scoreEvents.docs) {
    await doc.ref.delete();
  }
  await safeDelete(userRef.collection("rapSheet").doc("latest"));
  await safeDelete(userRef);

  const pleas = await db.collection("pleas")
      .where("userId", "==", "rap_sheet_alice")
      .get();
  for (const doc of pleas.docs) {
    await doc.ref.delete();
  }
});

test("buildRapSheetSnapshot denormalizes the latest five safe infractions", async () => {
  const uid = "rap_sheet_alice";
  const squadId = "squad_rap";
  const userRef = db.collection("users").doc(uid);

  await userRef.set({
    uid,
    squadId,
  });

  await db.collection("pleas").doc("plea_1").set({
    userId: uid,
    squadId,
    status: "approved",
    appName: "Instagram",
    packageName: "com.instagram.android",
    reason: "should never leak",
    createdAt: Timestamp.fromMillis(1_710_000_000_000),
    resolvedAt: Timestamp.fromMillis(1_710_000_100_000),
  });
  await db.collection("pleas").doc("plea_2").set({
    userId: uid,
    squadId,
    status: "rejected",
    appName: "TikTok",
    packageName: "com.zhiliaoapp.musically",
    createdAt: Timestamp.fromMillis(1_710_000_150_000),
    resolvedAt: Timestamp.fromMillis(1_710_000_200_000),
  });

  await userRef.collection("scoreEvents").doc("event_1").set({
    type: "blocked_attempt",
    appName: "X",
    packageName: "com.twitter.android",
    createdAtMs: 1_710_000_250_000,
  });
  await userRef.collection("scoreEvents").doc("event_2").set({
    type: "blocked_attempt",
    appName: "YouTube",
    packageName: "com.google.android.youtube",
    createdAtMs: 1_710_000_300_000,
  });
  await userRef.collection("scoreEvents").doc("event_3").set({
    type: "blocked_attempt",
    appName: "Reddit",
    packageName: "com.reddit.frontpage",
    createdAtMs: 1_710_000_350_000,
  });
  await userRef.collection("scoreEvents").doc("event_4").set({
    type: "bail_outgoing",
    appName: "Ignore Me",
    packageName: "com.example.ignore",
    createdAtMs: 1_710_000_360_000,
  });

  await __testables.buildRapSheetSnapshot(uid, {source: "test"});

  const snapshot = (await userRef.collection("rapSheet").doc("latest").get()).data();
  assert.ok(snapshot, "expected rap sheet snapshot to exist");
  assert.equal(snapshot.uid, uid);
  assert.equal(snapshot.squadId, squadId);
  assert.equal(snapshot.version, 1);
  assert.equal(snapshot.pleaStats.total, 2);
  assert.equal(snapshot.pleaStats.approved, 1);
  assert.equal(snapshot.pleaStats.rejected, 1);
  assert.equal(snapshot.latestInfractions.length, 5);

  const occurredAtValues = snapshot.latestInfractions.map((entry) => entry.occurredAtMs);
  assert.deepEqual(
      [...occurredAtValues].sort((a, b) => b - a),
      occurredAtValues,
      "latest infractions should be newest first",
  );
  assert.deepEqual(
      Object.keys(snapshot.latestInfractions[0]).sort(),
      ["appName", "kind", "occurredAtMs", "packageName", "sourceId", "status"].sort(),
  );
  assert.ok(
      !Object.prototype.hasOwnProperty.call(snapshot.latestInfractions[0], "reason"),
      "sensitive plea fields should not be denormalized",
  );
});
