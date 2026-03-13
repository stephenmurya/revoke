const path = require("node:path");
const fs = require("node:fs");
const {test, before, after, afterEach} = require("node:test");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  setDoc,
  getDoc,
} = require("firebase/firestore");

const projectId = "revoke-firestore-rules-test";
const rulesPath = path.resolve(__dirname, "../../firestore.rules");

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(rulesPath, "utf8"),
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

async function seedWithBypass(seedFn) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await seedFn(db);
  });
}

test("own score events are readable but not client-writable", async () => {
  await seedWithBypass(async (db) => {
    await setDoc(doc(db, "users/alice"), {
      uid: "alice",
      squadId: "squad_1",
    });
    await setDoc(doc(db, "users/alice/scoreEvents/event_1"), {
      type: "blocked_attempt",
      eventDay: "2026-02-16",
    });
  });

  const aliceDb = testEnv.authenticatedContext("alice").firestore();
  await assertSucceeds(getDoc(doc(aliceDb, "users/alice/scoreEvents/event_1")));
  await assertFails(setDoc(doc(aliceDb, "users/alice/scoreEvents/event_2"), {
    type: "blocked_attempt",
    eventDay: "2026-02-16",
  }));
});

test("cross-user regime reads are denied even for same-squad members", async () => {
  await seedWithBypass(async (db) => {
    await setDoc(doc(db, "users/alice"), {
      uid: "alice",
      squadId: "squad_1",
    });
    await setDoc(doc(db, "users/bob"), {
      uid: "bob",
      squadId: "squad_1",
    });
    await setDoc(doc(db, "users/alice/regimes/regime_1"), {
      name: "Night Lock",
      isEnabled: true,
    });
  });

  const bobDb = testEnv.authenticatedContext("bob").firestore();
  await assertFails(getDoc(doc(bobDb, "users/alice/regimes/regime_1")));
});

test("same-squad members can read plea vote docs", async () => {
  await seedWithBypass(async (db) => {
    await setDoc(doc(db, "users/alice"), {
      uid: "alice",
      squadId: "squad_1",
    });
    await setDoc(doc(db, "users/bob"), {
      uid: "bob",
      squadId: "squad_1",
    });
    await setDoc(doc(db, "pleas/plea_1"), {
      squadId: "squad_1",
      userId: "alice",
      status: "active",
    });
    await setDoc(doc(db, "pleas/plea_1/votes/bob"), {
      uid: "bob",
      choice: "accept",
    });
  });

  const bobDb = testEnv.authenticatedContext("bob").firestore();
  await assertSucceeds(getDoc(doc(bobDb, "pleas/plea_1/votes/bob")));
});

test("non-squad members cannot read plea vote docs", async () => {
  await seedWithBypass(async (db) => {
    await setDoc(doc(db, "users/alice"), {
      uid: "alice",
      squadId: "squad_1",
    });
    await setDoc(doc(db, "users/charlie"), {
      uid: "charlie",
      squadId: "squad_2",
    });
    await setDoc(doc(db, "pleas/plea_1"), {
      squadId: "squad_1",
      userId: "alice",
      status: "active",
    });
    await setDoc(doc(db, "pleas/plea_1/votes/alice"), {
      uid: "alice",
      choice: "accept",
    });
  });

  const charlieDb = testEnv.authenticatedContext("charlie").firestore();
  await assertFails(getDoc(doc(charlieDb, "pleas/plea_1/votes/alice")));
});

test("squad logs remain server-only writable", async () => {
  await seedWithBypass(async (db) => {
    await setDoc(doc(db, "users/alice"), {
      uid: "alice",
      squadId: "squad_1",
    });
    await setDoc(doc(db, "squads/squad_1"), {
      memberIds: ["alice"],
      squadCode: "REV-ABC",
    });
  });

  const aliceDb = testEnv.authenticatedContext("alice").firestore();
  await assertFails(setDoc(doc(aliceDb, "squads/squad_1/logs/log_1"), {
    type: "verdict",
    title: "Denied",
  }));
});
