/* Alpha HTML engine: data backends (phone storage, Supabase REST, Firebase Firestore).
   Every backend has the same API, used by app.js and by code written with AI:
     await B.init(); B.signedIn; B.isAdmin; B.userId; B.email; B.name
     await B.signIn(email, pass); await B.signUp(name, email, pass); await B.signOut()
     await B.list(table); await B.insert(table, values); await B.update(table, id, values); await B.remove(table, id)
     await B.notifications(); B.markSeen(); await B.notify({toRole, toUser, title, body}); await B.stats()
     await B.registerDevice(token)
   `table` is an entry of ALPHA.tables. */
(function () {
  "use strict";
  const C = window.ALPHA || { app: { title: "Alpha", role: "single" }, backend: { type: "none" }, tables: [] };
  const role = (C.app && C.app.role) || "single";
  const be = C.backend || { type: "none" };
  const prefix = be.prefix || String((C.app && C.app.slug) || "app").replace(/-/g, "_");
  const needsAccount = be.auth === "email_password" || be.auth === "email_code";
  const emailCode = be.auth === "email_code";

  function store(key, value) {
    try {
      if (value === undefined) return JSON.parse(localStorage.getItem(key) || "null");
      if (value === null) localStorage.removeItem(key);
      else localStorage.setItem(key, JSON.stringify(value));
    } catch (e) { return null; }
    return value;
  }

  function rid() {
    const a = new Uint8Array(16);
    (window.crypto || {}).getRandomValues ? crypto.getRandomValues(a) : a.forEach((_, i) => (a[i] = Math.random() * 256));
    return Array.from(a, (b) => b.toString(16).padStart(2, "0")).join("");
  }

  function clean(table, values, admin) {
    const out = {};
    for (const c of table.columns || []) {
      if (!(c.name in values)) continue;
      if (c.adminOnly && !admin) continue;
      let v = values[c.name];
      if (typeof v === "string") {
        v = v.trim();
        if (v === "") v = null;
        else if (c.type === "int") v = Number.isFinite(parseInt(v.replace(/,/g, ""), 10)) ? parseInt(v.replace(/,/g, ""), 10) : v;
        else if (c.type === "decimal") v = Number.isFinite(parseFloat(v.replace(/,/g, ""))) ? parseFloat(v.replace(/,/g, "")) : v;
      }
      out[c.name] = v;
    }
    return out;
  }

  function defaults(table, admin) {
    const out = {};
    for (const c of table.columns || []) {
      const d = c.default;
      if (d == null || d === "" || (c.adminOnly && !admin)) continue;
      if (c.type === "int") out[c.name] = parseInt(d, 10);
      else if (c.type === "decimal") out[c.name] = parseFloat(d);
      else if (c.type === "bool") out[c.name] = d === "true";
      else if (c.type === "date" && (d === "today" || d === "now")) out[c.name] = new Date().toISOString().slice(0, 10);
      else if (c.type === "datetime" && d === "now") out[c.name] = new Date().toISOString();
      else out[c.name] = d;
    }
    return out;
  }

  const NOT_CONFIRMED = "EMAIL_NOT_CONFIRMED";

  function seenAt() { return new Date(store("alpha_seen") || "2000-01-01T00:00:00Z"); }

  // ---------------- data on the phone ----------------
  function Local() {
    // The phone's owner manages everything; the preview in Alpha can show the customer's side.
    const B = { kind: "none", signedIn: true, isAdmin: role !== "customer", email: null };
    B.init = async () => {
      if (!store("alpha_uid")) store("alpha_uid", rid());
      B.userId = store("alpha_uid");
      B.name = store("alpha_name");
      if (C.preview) seed();
    };
    // Instant preview in Alpha: a few sample rows per table so every screen shows how it will look.
    function seed() {
      const words = ["الأول", "الثاني", "الثالث"];
      const now = Date.now();
      for (const t of C.tables || []) {
        if (rows(t).length) continue;
        const list = words.map((w, i) => {
          const r = { id: rid(), created_at: new Date(now - i * 3600e3).toISOString(), updated_at: new Date(now).toISOString(), customer_id: B.userId };
          for (const c of t.columns || []) {
            const v = {
              text: c.label + " " + w, longtext: "وصف تجريبي لـ" + c.label, int: (i + 1) * 3, decimal: [25, 40, 15.5][i],
              bool: i !== 1, date: new Date(now + i * 864e5).toISOString().slice(0, 10), datetime: new Date(now + i * 864e5).toISOString(),
              image: "", phone: "+24991234567" + i, email: "user" + (i + 1) + "@example.com",
              choice: (c.options || [])[i % Math.max(1, (c.options || []).length)],
            }[c.type || "text"];
            r[c.name] = v === undefined ? c.label + " " + w : v;
          }
          return r;
        });
        store("alpha_rows_" + t.name, list);
      }
    }
    const rows = (t) => store("alpha_rows_" + t.name) || [];
    B.signIn = async () => {};
    B.signUp = async (name) => { store("alpha_name", name); return false; };
    B.verifyCode = async () => {};
    B.resendCode = async () => {};
    B.signOut = async () => {};
    B.list = async (t) => rows(t).sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)));
    B.insert = async (t, v) => {
      const now = new Date().toISOString();
      const row = Object.assign(defaults(t, true), clean(t, v, true), { id: rid(), created_at: now, updated_at: now, customer_id: B.userId });
      store("alpha_rows_" + t.name, rows(t).concat([row]));
      return row;
    };
    B.update = async (t, id, v) => {
      store("alpha_rows_" + t.name, rows(t).map((r) => (r.id === id ? Object.assign({}, r, clean(t, v, true), { updated_at: new Date().toISOString() }) : r)));
    };
    B.remove = async (t, id) => store("alpha_rows_" + t.name, rows(t).filter((r) => r.id !== id));
    B.notifications = async () => [];
    B.markSeen = () => {};
    B.notify = async () => {};
    B.stats = async () => Object.fromEntries((C.tables || []).map((t) => [t.name, rows(t).length]));
    B.registerDevice = async () => {};
    return B;
  }

  // ---------------- Supabase (REST) ----------------
  function Supabase() {
    const url = String(be.url || "").replace(/\/+$/, "");
    const key = be.anonKey || "";
    const B = { kind: "supabase", signedIn: false, isAdmin: false, email: null, name: null, userId: null };
    let session = null;
    let profileRole = "customer";

    function explain(status, body) {
      let msg = body;
      try { const j = JSON.parse(body); msg = j.msg || j.message || j.error_description || j.error || body; } catch (e) {}
      const m = String(msg).toLowerCase();
      if (m.includes("invalid login")) return "البريد أو كلمة المرور غير صحيحة.";
      if (m.includes("already registered") || m.includes("already been registered")) return "هذا البريد مسجّل من قبل، سجّل الدخول.";
      if (m.includes("password should be")) return "كلمة المرور قصيرة (6 أحرف على الأقل).";
      if (m.includes("email not confirmed")) return NOT_CONFIRMED;
      if (m.includes("row-level security") || status === 403) return "ليست لديك صلاحية لهذه العملية.";
      return "خطأ من السيرفر (" + status + "): " + msg;
    }

    async function call(path, opts) {
      opts = opts || {};
      if (!opts.noRefresh) await refresh(false);
      const headers = Object.assign({ apikey: key, Authorization: "Bearer " + ((session && session.access_token) || key), "Content-Type": "application/json" }, opts.headers || {});
      let res;
      try {
        res = await fetch(url + path, { method: opts.method || "GET", headers, body: opts.body === undefined ? undefined : JSON.stringify(opts.body) });
      } catch (e) {
        throw new Error("لا يوجد اتصال بالإنترنت.");
      }
      const text = await res.text();
      if (!res.ok) throw new Error(explain(res.status, text));
      return text ? JSON.parse(text) : null;
    }

    function save(s) {
      s.expires_at_ms = Date.now() + (s.expires_in || 3600) * 1000;
      session = s;
      store("alpha_session", s);
      B.signedIn = true;
      B.userId = s.user && s.user.id;
      B.email = (s.user && s.user.email) || null;
    }

    async function refresh(force) {
      if (!session) return;
      if (!force && session.expires_at_ms - Date.now() > 60000) return;
      const s = await call("/auth/v1/token?grant_type=refresh_token", { method: "POST", body: { refresh_token: session.refresh_token }, noRefresh: true });
      save(s);
    }

    async function anonymous() {
      save(await call("/auth/v1/signup", { method: "POST", body: {}, noRefresh: true }));
    }

    async function profile() {
      try {
        const rows = await call("/rest/v1/" + prefix + "_profiles?select=role,full_name&id=eq." + B.userId);
        profileRole = (rows[0] && rows[0].role) || "customer";
        B.name = (rows[0] && rows[0].full_name) || null;
      } catch (e) { profileRole = "customer"; }
      B.isAdmin = role !== "customer" && profileRole === "admin";
    }

    B.init = async () => {
      if (!url || !key) throw new Error("السيرفر لم يُجهّز بعد. افتح Alpha واضغط «تجهيز السيرفر» ثم ابنِ التطبيق مرة أخرى.");
      session = store("alpha_session");
      if (session) {
        try { save(session); await refresh(true); } catch (e) { session = null; store("alpha_session", null); B.signedIn = false; }
      }
      if (!session && !needsAccount) await anonymous();
      if (session) await profile();
    };
    B.signIn = async (email, password) => {
      try {
        save(await call("/auth/v1/token?grant_type=password", { method: "POST", body: { email: email.trim(), password }, noRefresh: true }));
      } catch (e) {
        if (e.message === NOT_CONFIRMED) { const n = new Error("أكّد بريدك أولاً بالرمز الذي وصلك."); n.needsCode = true; throw n; }
        throw e;
      }
      await profile();
    };
    // Returns true when the email must be confirmed with the 6-digit code first.
    B.signUp = async (name, phone, email, password) => {
      const s = await call("/auth/v1/signup", { method: "POST", body: { email: email.trim(), password, data: { full_name: name.trim(), phone: (phone || "").trim() } }, noRefresh: true });
      if (!s.access_token) {
        if (emailCode) return true;
        await B.signIn(email, password);
        return false;
      }
      save(s);
      await profile();
      return false;
    };
    B.verifyCode = async (email, code, password) => {
      let s;
      try {
        s = await call("/auth/v1/verify", { method: "POST", body: { type: "signup", email: email.trim(), token: String(code).trim() }, noRefresh: true });
      } catch (e) { throw new Error("الرمز غير صحيح أو انتهت صلاحيته. اطلب رمزاً جديداً."); }
      if (s && s.access_token) { save(s); await profile(); } else await B.signIn(email, password);
    };
    B.resendCode = (email) => call("/auth/v1/resend", { method: "POST", body: { type: "signup", email: email.trim() }, noRefresh: true });
    B.signOut = async () => {
      try { await call("/auth/v1/logout", { method: "POST", body: {} }); } catch (e) {}
      session = null; store("alpha_session", null);
      B.signedIn = false; B.isAdmin = false; B.email = null; B.userId = null;
      if (!needsAccount) { await anonymous(); await profile(); }
    };
    const tn = (t) => prefix + "_" + t.name;
    B.list = async (t) => {
      let q = "/rest/v1/" + tn(t) + "?select=*&order=created_at.desc&limit=500";
      if (t.owner === "customer" && !B.isAdmin) q += "&customer_id=eq." + B.userId;
      return call(q);
    };
    B.insert = async (t, v) => {
      const rows = await call("/rest/v1/" + tn(t), { method: "POST", body: clean(t, v, B.isAdmin), headers: { Prefer: "return=representation" } });
      return (rows && rows[0]) || {};
    };
    B.update = (t, id, v) => call("/rest/v1/" + tn(t) + "?id=eq." + encodeURIComponent(id), { method: "PATCH", body: clean(t, v, B.isAdmin), headers: { Prefer: "return=minimal" } });
    B.remove = (t, id) => call("/rest/v1/" + tn(t) + "?id=eq." + encodeURIComponent(id), { method: "DELETE" });
    B.notifications = async () => {
      if (!B.userId) return [];
      const roles = role === "customer" ? ["customer"] : role === "admin" ? ["admin"] : ["customer"].concat(B.isAdmin ? ["admin"] : []);
      const or = ["to_user.eq." + B.userId].concat(roles.map((r) => "to_role.eq." + r)).join(",");
      const rows = await call("/rest/v1/" + prefix + "_notifications?select=*&or=(" + or + ")&order=created_at.desc&limit=60");
      const seen = seenAt();
      return rows.map((r) => ({ id: r.id, title: r.title || "", body: r.body || "", at: new Date(r.created_at), read: new Date(r.created_at) <= seen }));
    };
    B.markSeen = () => store("alpha_seen", new Date().toISOString());
    B.notify = (n) => call("/rest/v1/" + prefix + "_notifications", {
      method: "POST", headers: { Prefer: "return=minimal" },
      body: Object.assign(n.toUser ? { to_user: n.toUser } : { to_role: n.toRole }, { title: n.title, body: n.body || "", created_by: B.userId }),
    });
    B.stats = () => call("/rest/v1/rpc/" + prefix + "_stats", { method: "POST", body: {} });
    B.registerDevice = (token) => call("/rest/v1/rpc/" + prefix + "_register_device", { method: "POST", body: { device_token: token, app_name: role, device_platform: "android" } });
    return B;
  }

  // ---------------- Firebase (Auth + Firestore, compat SDK in vendor/) ----------------
  function Firestore() {
    const B = { kind: "firebase", signedIn: false, isAdmin: false, email: null, name: null, userId: null };
    let auth, db, profileRole = "customer";
    const col = (n) => db.collection(prefix + "_" + n);

    function explain(e) {
      const code = (e && e.code) || "";
      if (/invalid-credential|wrong-password|user-not-found/.test(code)) return "البريد أو كلمة المرور غير صحيحة.";
      if (code.includes("email-already-in-use")) return "هذا البريد مسجّل من قبل، سجّل الدخول.";
      if (code.includes("weak-password")) return "كلمة المرور ضعيفة (6 أحرف على الأقل).";
      if (code.includes("permission-denied")) return "ليست لديك صلاحية لهذه العملية.";
      if (code.includes("network")) return "لا يوجد اتصال بالإنترنت.";
      return (e && e.message) || String(e);
    }
    const wrap = (f) => async function () {
      try { return await f.apply(null, arguments); } catch (e) { throw new Error(explain(e)); }
    };

    function sync() {
      const u = auth.currentUser;
      B.signedIn = !!u && (!emailCode || u.isAnonymous || u.emailVerified); B.userId = u ? u.uid : null; B.email = (u && u.email) || null;
    }

    async function profile() {
      const u = auth.currentUser;
      const ref = col("profiles").doc(u.uid);
      const snap = await ref.get();
      if (!snap.exists) await ref.set({ email: u.email || null, full_name: u.displayName || null, role: "customer", created_at: new Date().toISOString() });
      const d = (await ref.get()).data() || {};
      profileRole = d.role || "customer";
      B.name = d.full_name || u.displayName || null;
      if (u.email && profileRole !== "admin") {
        try { if ((await col("admins").doc(u.email.toLowerCase()).get()).exists) profileRole = "admin"; } catch (e) {}
      }
      B.isAdmin = role !== "customer" && profileRole === "admin";
    }

    function summary(t, row) {
      const parts = [];
      const title = (t.columns || []).find((c) => c.type === "text" || c.type === "choice");
      if (title && row[title.name] != null) parts.push(row[title.name]);
      (t.columns || []).filter((c) => c.adminOnly && row[c.name] != null).forEach((c) => parts.push(row[c.name]));
      return parts.join(" · ");
    }

    async function afterChange(t, row, inserted) {
      const n = t.notify || {};
      const target = inserted ? n.onInsert : n.onUpdate;
      const title = t.label + ": " + (inserted ? "جديد" : "تحديث");
      try {
        if (target === "admin") await B.notify({ toRole: "admin", title, body: summary(t, row) });
        else if (target === "customer" && B.isAdmin) await B.notify({ toRole: "customer", title, body: summary(t, row) });
        else if (target === "owner" && row.customer_id && row.customer_id !== B.userId) await B.notify({ toUser: row.customer_id, title, body: summary(t, row) });
      } catch (e) {}
    }

    B.init = wrap(async () => {
      const f = be.firebase || {};
      if (!window.firebase || !firebase.initializeApp) throw new Error("مكتبة Firebase غير موجودة (vendor/).");
      if (!f.apiKey || !f.appId) throw new Error("Firebase لم يُجهّز بعد لهذا التطبيق. افتح Alpha واضغط «تجهيز السيرفر».");
      if (!firebase.apps.length) firebase.initializeApp({ apiKey: f.apiKey, appId: f.appId, projectId: f.projectId, messagingSenderId: f.senderId, storageBucket: f.storageBucket, authDomain: f.projectId + ".firebaseapp.com" });
      auth = firebase.auth(); db = firebase.firestore();
      await new Promise((ok) => { const off = auth.onAuthStateChanged(() => { off(); ok(); }); });
      if (!auth.currentUser && !needsAccount) await auth.signInAnonymously();
      sync();
      if (auth.currentUser) await profile();
    });
    B.confirmsWithLink = true;
    B.signIn = async (email, pass) => {
      await wrap(() => auth.signInWithEmailAndPassword(email.trim(), pass))();
      if (emailCode && !auth.currentUser.emailVerified) { const n = new Error("أكّد بريدك أولاً من الرابط الذي وصلك."); n.needsCode = true; throw n; }
      sync(); await profile();
    };
    B.signUp = wrap(async (name, phone, email, pass) => {
      const cred = await auth.createUserWithEmailAndPassword(email.trim(), pass);
      await cred.user.updateProfile({ displayName: name.trim() });
      await col("profiles").doc(cred.user.uid).set({ email: email.trim().toLowerCase(), full_name: name.trim(), phone: (phone || "").trim(), role: "customer", created_at: new Date().toISOString() });
      if (emailCode) { await cred.user.sendEmailVerification(); return true; }
      sync(); await profile();
      return false;
    });
    B.verifyCode = async (email, code, pass) => {
      if (!auth.currentUser) await wrap(() => auth.signInWithEmailAndPassword(email.trim(), pass))();
      await auth.currentUser.reload();
      if (!auth.currentUser.emailVerified) throw new Error("لم يتم التأكيد بعد: افتح الرابط في بريدك ثم اضغط «تحقق».");
      sync(); await profile();
    };
    B.resendCode = wrap(async () => { if (auth.currentUser) await auth.currentUser.sendEmailVerification(); });
    B.signOut = wrap(async () => {
      await auth.signOut(); B.isAdmin = false;
      if (!needsAccount) { await auth.signInAnonymously(); }
      sync();
      if (auth.currentUser) await profile();
    });
    B.list = wrap(async (t) => {
      let q = col(t.name);
      if (t.owner === "customer" && !B.isAdmin) q = q.where("customer_id", "==", B.userId);
      const snap = await q.orderBy("created_at", "desc").limit(500).get();
      return snap.docs.map((d) => Object.assign({}, d.data(), { id: d.id }));
    });
    B.insert = wrap(async (t, v) => {
      const now = new Date().toISOString();
      const row = Object.assign(defaults(t, B.isAdmin), clean(t, v, B.isAdmin), { created_at: now, updated_at: now });
      if (t.owner === "customer" || t.owner === "public") row.customer_id = B.userId;
      const ref = await col(t.name).add(row);
      row.id = ref.id;
      await afterChange(t, row, true);
      return row;
    });
    B.update = wrap(async (t, id, v) => {
      await col(t.name).doc(id).update(Object.assign(clean(t, v, B.isAdmin), { updated_at: new Date().toISOString() }));
      const d = await col(t.name).doc(id).get();
      await afterChange(t, Object.assign({}, d.data(), { id }), false);
    });
    B.remove = wrap((t, id) => col(t.name).doc(id).delete());
    B.notifications = wrap(async () => {
      if (!B.userId) return [];
      const roles = role === "customer" ? ["customer"] : role === "admin" ? ["admin"] : ["customer"].concat(B.isAdmin ? ["admin"] : []);
      const [mine, broadcast] = await Promise.all([
        col("notifications").where("to_user", "==", B.userId).limit(60).get(),
        col("notifications").where("to_role", "in", roles).limit(60).get(),
      ]);
      const seen = seenAt();
      const byId = {};
      mine.docs.concat(broadcast.docs).forEach((d) => {
        const r = d.data();
        if (r.to_user && r.to_user !== B.userId) return;
        const at = new Date(r.created_at);
        byId[d.id] = { id: d.id, title: r.title || "", body: r.body || "", at, read: at <= seen };
      });
      return Object.values(byId).sort((a, b) => b.at - a.at);
    });
    B.markSeen = () => store("alpha_seen", new Date().toISOString());
    B.notify = wrap((n) => col("notifications").add(Object.assign(n.toUser ? { to_user: n.toUser } : { to_role: n.toRole },
      { title: n.title, body: n.body || "", created_by: B.userId, created_at: new Date().toISOString() })));
    B.stats = wrap(async () => {
      const out = {};
      for (const t of C.tables || []) out[t.name] = (await col(t.name).limit(1000).get()).size;
      return out;
    });
    B.registerDevice = wrap((token) => col("device_tokens").doc(token).set({ user_id: B.userId, app: role, platform: "android", updated_at: new Date().toISOString() }));
    return B;
  }

  window.AlphaBackend = be.type === "supabase" ? Supabase() : be.type === "firebase" ? Firestore() : Local();
  window.AlphaBackend.config = C;
  window.AlphaBackend.needsAccount = needsAccount && be.type !== "none";
})();
