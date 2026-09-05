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
  Timestamp,
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
  if (testEnv) {
    await testEnv.cleanup();
  }
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

test("Circle members cannot read another member's private regimes", async () => {
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
  await assertFails(setDoc(doc(bobDb, "users/alice/regimes/regime_1"), {
    name: "Tampered",
    isEnabled: false,
  }));
});

test("Circle creation is bound to the authenticated owner", async () => {
  await seedWithBypass(async (db) => {
    await setDoc(doc(db, "users/alice/premiumEntitlement/current"), {
      active: true,
      premiumUntil: Timestamp.fromMillis(Date.now() + 86400000),
    });
  });
  const aliceDb = testEnv.authenticatedContext("alice").firestore();
  await assertSucceeds(setDoc(doc(aliceDb, "squads/squad_owned"), {
    creatorId: "alice",
    memberIds: ["alice"],
    premiumRequired: true,
  }));
  await assertFails(setDoc(doc(aliceDb, "squads/squad_spoofed"), {
    creatorId: "bob",
    memberIds: ["alice", "bob"],
  }));
});

test("users can sync only their own taper plans", async () => {
  await seedWithBypass(async (db) => {
    await setDoc(doc(db, "users/alice"), {
      uid: "alice",
      squadId: "squad_1",
    });
    await setDoc(doc(db, "users/bob"), {
      uid: "bob",
      squadId: "squad_1",
    });
    await setDoc(doc(db, "users/alice/taperPlans/plan_1"), {
      status: "active",
      targetDailyMinutes: 45,
    });
  });

  const aliceDb = testEnv.authenticatedContext("alice").firestore();
  const bobDb = testEnv.authenticatedContext("bob").firestore();

  await assertSucceeds(getDoc(doc(aliceDb, "users/alice/taperPlans/plan_1")));
  await assertSucceeds(setDoc(doc(aliceDb, "users/alice/taperPlans/plan_2"), {
    status: "active",
    targetDailyMinutes: 30,
  }));
  await assertFails(getDoc(doc(bobDb, "users/alice/taperPlans/plan_1")));
  await assertFails(setDoc(doc(bobDb, "users/alice/taperPlans/plan_3"), {
    status: "active",
    targetDailyMinutes: 10,
  }));
});

test("Circle members cannot read another member's private rap sheet", async () => {
  await seedWithBypass(async (db) => {
    await setDoc(doc(db, "users/alice"), {
      uid: "alice",
      squadId: "squad_1",
    });
    await setDoc(doc(db, "users/bob"), {
      uid: "bob",
      squadId: "squad_1",
    });
    await setDoc(doc(db, "users/alice/rapSheet/latest"), {
      uid: "alice",
      squadId: "squad_1",
      pleaStats: {
        total: 2,
        approved: 1,
        rejected: 1,
      },
      latestInfractions: [],
      updatedAtMs: 1710000000000,
      version: 1,
    });
  });

  const bobDb = testEnv.authenticatedContext("bob").firestore();
  await assertFails(getDoc(doc(bobDb, "users/alice/rapSheet/latest")));
});

test("cross-squad members cannot read another member's rap sheet snapshot", async () => {
  await seedWithBypass(async (db) => {
    await setDoc(doc(db, "users/alice"), {
      uid: "alice",
      squadId: "squad_1",
    });
    await setDoc(doc(db, "users/charlie"), {
      uid: "charlie",
      squadId: "squad_2",
    });
    await setDoc(doc(db, "users/alice/rapSheet/latest"), {
      uid: "alice",
      squadId: "squad_1",
      pleaStats: {
        total: 1,
        approved: 0,
        rejected: 1,
      },
      latestInfractions: [],
      updatedAtMs: 1710000000000,
      version: 1,
    });
  });

  const charlieDb = testEnv.authenticatedContext("charlie").firestore();
  await assertFails(getDoc(doc(charlieDb, "users/alice/rapSheet/latest")));
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
      visibleToUids: ["alice", "bob"],
      eligibleVoterIds: ["bob"],
    });
    await setDoc(doc(db, "pleas/plea_1/votes/bob"), {
      uid: "bob",
      choice: "accept",
    });
  });

  const bobDb = testEnv.authenticatedContext("bob").firestore();
  await assertSucceeds(getDoc(doc(bobDb, "pleas/plea_1/votes/bob")));
});

test("Circle member summaries are readable without exposing the user profile", async () => {
  await seedWithBypass(async (db) => {
    await setDoc(doc(db, "users/alice"), {uid: "alice", squadId: "squad_1", email: "private@example.com"});
    await setDoc(doc(db, "users/bob"), {uid: "bob", squadId: "squad_1"});
    await setDoc(doc(db, "squads/squad_1"), {memberIds: ["alice", "bob"], creatorId: "alice"});
    await setDoc(doc(db, "squads/squad_1/members/alice"), {
      uid: "alice",
      displayName: "Alice",
      avatarUrl: "",
      role: "owner",
      preset: "guardian",
      permissions: {viewCommitmentSummary: true},
    });
  });

  const bobDb = testEnv.authenticatedContext("bob").firestore();
  await assertSucceeds(getDoc(doc(bobDb, "squads/squad_1/members/alice")));
  await assertFails(getDoc(doc(bobDb, "users/alice")));
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
