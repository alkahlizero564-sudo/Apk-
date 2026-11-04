// Cloud Function deployed by Alpha (factory/backend_setup.py) for project "__PREFIX__": sends every new
// notification document to the right phones with Firebase Cloud Messaging and forgets dead devices.
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const P = "__PREFIX__";

async function tokensFor(n) {
  const col = db.collection(`${P}_device_tokens`);
  if (n.to_user) {
    const snap = await col.where("user_id", "==", n.to_user).get();
    return snap.docs.map((d) => d.id);
  }
  if (n.to_role === "customer") {
    const snap = await col.where("app", "in", ["customer", "single"]).get();
    return snap.docs.map((d) => d.id);
  }
  if (n.to_role === "admin") {
    const admins = await db.collection(`${P}_profiles`).where("role", "==", "admin").get();
    const mails = await db.collection(`${P}_admins`).get();
    const adminMails = new Set(mails.docs.map((d) => d.id));
    const profiles = await db.collection(`${P}_profiles`).get();
    const ids = new Set(admins.docs.map((d) => d.id));
    profiles.docs.forEach((d) => { if (adminMails.has(String(d.get("email") || "").toLowerCase())) ids.add(d.id); });
    const snap = await col.where("app", "in", ["admin", "single"]).get();
    return snap.docs.filter((d) => ids.has(d.get("user_id"))).map((d) => d.id);
  }
  return [];
}

exports[`${P.replace(/_/g, "")}Push`] = onDocumentCreated(`${P}_notifications/{id}`, async (event) => {
  const n = event.data && event.data.data();
  if (!n) return;
  const tokens = await tokensFor(n);
  if (!tokens.length) return;
  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title: n.title || "", body: n.body || "" },
    android: { priority: "high", notification: { sound: "default" } },
    data: { notification_id: event.params.id },
  });
  const dead = [];
  res.responses.forEach((r, i) => {
    const code = r.error && r.error.code;
    if (code === "messaging/registration-token-not-registered" || code === "messaging/invalid-registration-token") dead.push(tokens[i]);
  });
  await Promise.all(dead.map((t) => db.collection(`${P}_device_tokens`).doc(t).delete()));
});
