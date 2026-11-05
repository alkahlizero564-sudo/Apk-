/* Alpha HTML engine: screens made from ALPHA (the app's design in Alpha). Uses window.AlphaBackend. */
(function () {
  "use strict";
  const B = window.AlphaBackend;
  const C = B.config;
  const role = C.app.role || "single";
  const $ = (s, el) => (el || document).querySelector(s);
  const esc = (v) => String(v == null ? "" : v).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

  // Line icons (24px, stroke), same names as the other engines.
  const P = {
    list: "M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01",
    shopping_bag: "M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4zM3 6h18M16 10a4 4 0 0 1-8 0",
    receipt: "M4 2v20l3-2 3 2 3-2 3 2 3-2 1 .7V2l-3 2-3-2-3 2-3-2-3 2zM8 8h8M8 12h8M8 16h5",
    star: "m12 2 3.1 6.3 6.9 1-5 4.9 1.2 6.8L12 17.8 5.8 21l1.2-6.8-5-4.9 6.9-1z",
    restaurant: "M3 2v7a3 3 0 0 0 6 0V2M6 2v20M18 2c-2 0-3 2.5-3 6s1 5 3 5v9",
    delivery: "M10 17h4V5H2v12h3M14 9h4l4 4v4h-2M7.5 19.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5zM17.5 19.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z",
    medical: "M9 3h6v6h6v6h-6v6H9v-6H3V9h6z",
    calendar: "M3 5h18v16H3zM3 10h18M8 3v4M16 3v4",
    event: "M3 5h18v16H3zM3 10h18M8 3v4M16 3v4m-7 9 2 2 4-4",
    place: "M12 22s7-6.2 7-12a7 7 0 0 0-14 0c0 5.8 7 12 7 12zM12 12.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z",
    school: "M2 9l10-5 10 5-10 5zM6 11v5c0 1.7 2.7 3 6 3s6-1.3 6-3v-5",
    campaign: "M3 11v2a1 1 0 0 0 1 1h3l6 4V6L7 10H4a1 1 0 0 0-1 1zM17 8a5 5 0 0 1 0 8",
    book: "M4 19.5A2.5 2.5 0 0 1 6.5 17H20V2H6.5A2.5 2.5 0 0 0 4 4.5zM4 19.5A2.5 2.5 0 0 0 6.5 22H20v-5",
    chat: "M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z",
    person: "M20 21a8 8 0 0 0-16 0M12 13a5 5 0 1 0 0-10 5 5 0 0 0 0 10z",
    wallet: "M3 7a2 2 0 0 1 2-2h14v4M3 7v12a2 2 0 0 0 2 2h16V9H5a2 2 0 0 1-2-2zM16 15h.01",
    checklist: "m3 7 2 2 4-4M3 17l2 2 4-4M13 6h8M13 12h8M13 18h8",
    home: "M3 10.5 12 3l9 7.5V21h-6v-6H9v6H3z",
    settings: "M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z",
    car: "M5 17h14M5 17a2 2 0 1 0 4 0M15 17a2 2 0 1 0 4 0M3 17v-5l2-5h14l2 5v5",
    phone: "M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1.9.4 1.8.7 2.7a2 2 0 0 1-.5 2.1L8 9.8a16 16 0 0 0 6 6l1.3-1.3a2 2 0 0 1 2.1-.4c.9.3 1.8.6 2.7.7a2 2 0 0 1 1.7 2z",
    photo: "M3 3h18v18H3zM8.5 10a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3zM21 15l-5-5L5 21",
    store: "M3 9 4.5 3h15L21 9M3 9v12h18V9M3 9a3 3 0 0 0 6 0 3 3 0 0 0 6 0 3 3 0 0 0 6 0M9 21v-6h6v6",
    work: "M3 7h18v13H3zM8 7V4h8v3M3 13h18",
    payments: "M2 6h20v12H2zM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM6 9v.01M18 15v.01",
    dashboard: "M3 3h8v10H3zM13 3h8v6h-8zM13 11h8v10h-8zM3 15h8v6H3z",
    bell: "M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9M10.3 21a1.9 1.9 0 0 0 3.4 0",
    plus: "M12 5v14M5 12h14",
    search: "M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16zM21 21l-4.3-4.3",
    back: "M15 18l-6-6 6-6",
    more: "M12 12h.01M19 12h.01M5 12h.01",
    send: "M22 2 11 13M22 2l-7 20-4-9-9-4z",
    edit: "M12 20h9M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z",
    trash: "M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6",
    logout: "M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9",
    lock: "M5 11h14v10H5zM8 11V7a4 4 0 0 1 8 0v4",
    cloud: "M17.5 19H9a7 7 0 1 1 6.7-9h1.8a4.5 4.5 0 1 1 0 9z",
    heart: "M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1-1.1a5.5 5.5 0 0 0-7.8 7.8l1 1.1L12 21l7.8-7.5 1-1.1a5.5 5.5 0 0 0 0-7.8z",
    share: "M18 8a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM6 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM18 22a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM8.6 13.5l6.8 4M15.4 6.5l-6.8 4",
    sparkle: "M12 3l1.9 5.6L19.5 10.5l-5.6 1.9L12 18l-1.9-5.6L4.5 10.5l5.6-1.9zM19 3v4M17 5h4M5 17v4M3 19h4",
    arrow: "M19 12H5M12 19l-7-7 7-7",
  };
  const ic = (n, size) => '<svg width="' + (size || 22) + '" height="' + (size || 22) + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="' + (P[n] || P.list) + '"/></svg>';

  // ---------- theme ----------
  // A design school sets everything (see style.css); its usual layout comes with it and each part can be changed alone.
  const SCHOOLS = {
    flat: ["tiles", "cards", "bar"], material: ["tiles", "cards", "bar"], bento: ["bento", "grid", "floating"], cards: ["carousel", "cards", "bar"],
    swiss: ["tiles", "compact", "bar", "page"], skeuo: ["tiles", "cards", "bar"], glass: ["bento", "cards", "floating"], neu: ["tiles", "cards", "floating"],
    clay: ["bento", "grid", "pill"], spatial: ["carousel", "cards", "floating"], dark: ["tiles", "compact", "bar"], cyber: ["tiles", "timeline", "floating"],
    aurora: ["carousel", "cards", "pill"], hud: ["tiles", "timeline", "bar"], brutal: ["bento", "cards", "bar"], retro: ["tiles", "compact", "bar"],
    pixel: ["tiles", "grid", "bar"], y2k: ["carousel", "grid", "pill"], anti: ["bento", "cards", "floating"], kinetic: ["tiles", "cards", "pill"],
    sketch: ["tiles", "cards", "bar"], chat: ["chat", "compact", "pill"], zero: ["focus", "compact", "pill"],
  };
  // Apps made before the schools: their look maps to the nearest school.
  const FROM_LOOK = { aurora: "aurora", wave: "material", bold: "brutal", luxe: "swiss", soft: "neu", gallery: "bento", neon: "cyber", geo: "dark" };
  const T = (function theme() {
    const t = C.theme || {};
    const root = document.documentElement;
    const mode = t.mode === "system" ? (matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark") : t.mode || "light";
    const school = SCHOOLS[t.school] ? t.school : FROM_LOOK[t.look] || "material";
    const d = SCHOOLS[school];
    const own = !!t.school; // a school chosen in Alpha: its own layout choices count; older apps take the school's
    const pick = (v, ok, def) => (own && ok.includes(v) ? v : def);
    const tok = {
      home: pick(t.home, ["tiles", "bento", "carousel", "feed", "chat", "focus"], d[0]),
      list: pick(t.list, ["cards", "compact", "grid", "timeline", "reels"], d[1]),
      nav: pick(t.nav, ["bar", "floating", "pill", "none"], d[2]),
      sheet: pick(t.sheet, ["sheet", "page"], d[3] || "sheet"),
    };
    if (tok.home === "focus" && tok.nav === "none") tok.nav = "pill"; // the focus home needs a way back
    root.classList.toggle("light", mode === "light");
    root.classList.add("s-" + school);
    if (t.ai) root.classList.add("ai"); // the interface the AI designed for this app (design.css / design.js)
    Object.entries(tok).forEach(([k, v]) => root.classList.add(k + "-" + v));
    if (!document.querySelector(".deco")) document.body.insertAdjacentHTML("afterbegin", '<div class="deco"></div>');
    // Theme values (html:root beats the stylesheet defaults; a school or the AI design, :root.ai, can still redefine them).
    const safe = (v) => String(v).replace(/[^#\w\s.,'()-]/g, "");
    const vars = ["--seed:" + safe(t.seed || "#6750A4"), "--accent:" + safe(t.accent || "#7D5260")];
    // The owner's radius and font beat the school's (higher specificity), but not the AI design.
    const own2 = [];
    if (own && t.radius != null) own2.push("--r:" + Number(t.radius) + "px");
    if (t.font) own2.push("--font:'A-" + safe(t.font) + "', system-ui, sans-serif");
    if (t.display) own2.push("--display:'A-" + safe(t.display) + "', system-ui, sans-serif");
    const tag = document.createElement("style");
    tag.textContent = "html:root{" + vars.join(";") + "}" + (own2.length ? ":root:not(.ai):not(.x){" + own2.join(";") + "}" : "");
    document.head.insertBefore(tag, document.head.firstChild);
    root.dir = C.app.rtl === false ? "ltr" : "rtl";
    root.lang = C.app.rtl === false ? "en" : "ar";
    document.title = C.app.title || "Alpha";
    const meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.content = getComputedStyle(root).getPropertyValue("--bg").trim() || (mode === "light" ? "#F6F5FA" : "#0E0E14");
    return Object.assign({ school, mode }, tok);
  })();

  // Generated artwork for rows without a picture: a pattern and the table's icon, different for every row.
  function hash(s) { let h = 2166136261; s = String(s); for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; }
  function artInner(key, icon, size) {
    const h = hash(key), w = "rgba(255,255,255,", n = (i) => ((h >>> (i * 3)) % 100);
    const pats = [
      () => '<circle cx="' + n(1) + '" cy="' + n(2) + '" r="' + (26 + n(3) % 30) + '" fill="' + w + '.22)"/><circle cx="' + n(4) + '" cy="' + n(5) + '" r="' + (14 + n(6) % 20) + '" fill="' + w + '.16)"/><circle cx="' + n(7) + '" cy="' + n(8) + '" r="10" fill="' + w + '.3)"/>',
      () => Array.from({ length: 9 }, (_, i) => '<path d="M' + (i * 16 - 40) + ' 110 L' + (i * 16 + 20) + ' -10" stroke="' + w + '.16)" stroke-width="5"/>').join(""),
      () => [0, 1, 2, 3].map((i) => '<path d="M-5 ' + (30 + i * 18) + ' Q 25 ' + (14 + i * 18 + n(i) % 12) + ' 50 ' + (30 + i * 18) + ' T 105 ' + (30 + i * 18) + '" fill="none" stroke="' + w + (0.12 + i * 0.06) + ')" stroke-width="4"/>').join(""),
      () => [52, 38, 24, 10].map((r, i) => '<circle cx="' + (n(1) % 60 + 20) + '" cy="' + (n(2) % 60 + 20) + '" r="' + r + '" fill="none" stroke="' + w + (0.1 + i * 0.07) + ')" stroke-width="3"/>').join(""),
      () => Array.from({ length: 36 }, (_, i) => '<circle cx="' + ((i % 6) * 18 + 5) + '" cy="' + (Math.floor(i / 6) * 18 + 5) + '" r="' + (i % 7 === h % 7 ? 4 : 2) + '" fill="' + w + '.3)"/>').join(""),
      () => '<rect x="' + (n(1) % 40) + '" y="' + (n(2) % 40) + '" width="60" height="60" rx="14" transform="rotate(' + (n(3) % 45) + ' 50 50)" fill="' + w + '.18)"/><rect x="' + (n(4) % 50 + 20) + '" y="' + (n(5) % 50 + 20) + '" width="34" height="34" rx="8" transform="rotate(' + (n(6) % 45) + ' 50 50)" fill="' + w + '.12)"/>',
    ];
    return '<svg class="bg" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice">' + pats[h % pats.length]() + "</svg>" + (icon ? '<span style="position:relative;opacity:.95">' + ic(icon, size || 26) + "</span>" : "");
  }
  function art(cls, key, icon, img, size) {
    const hue = (hash(key + "h") % 50) - 25;
    return '<div class="' + cls + ' art" style="--hue:' + hue + 'deg">' + artInner(key, icon, size) + (img ? '<img src="' + esc(img) + '" alt="" loading="lazy" onerror="this.remove()">' : "") + "</div>";
  }

  // The AI-designed interface (design.js) adds its motion after every render: window.AlphaDesign.onRender({screen, root}).
  function designHook(screen) {
    const D = window.AlphaDesign;
    if (!D || typeof D.onRender !== "function") return;
    try { D.onRender({ screen: screen, root: document.getElementById("app"), theme: T, title: C.app.title }); }
    catch (e) { console.warn("design.js:", e); }
  }

  // Kinetic schools reveal cards as they scroll in.
  let io;
  function reveal() {
    if (!["kinetic", "anti", "spatial"].includes(T.school) || !("IntersectionObserver" in window)) return;
    io = io || new IntersectionObserver((es) => es.forEach((e) => { if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); } }), { threshold: 0.12 });
    document.querySelectorAll(".wrap .card:not(.rv), .feat:not(.rv)").forEach((el) => { el.classList.add("rv"); io.observe(el); });
  }

  // ---------- helpers ----------
  let toastTimer;
  function toast(text, bad) {
    const el = $("#toast");
    el.textContent = text; el.className = "toast" + (bad ? " bad" : ""); el.hidden = false;
    clearTimeout(toastTimer); toastTimer = setTimeout(() => (el.hidden = true), 3200);
  }
  function openSheet(html) {
    $("#sheet-body").innerHTML = (T.sheet === "page" ? '<button class="iconbtn" id="sheet-x" style="margin-bottom:12px">' + ic("back", 20) + "</button>" : "") + html;
    $("#sheet").hidden = false;
    const x = $("#sheet-x"); if (x) x.onclick = closeSheet;
    designHook("sheet");
  }
  function closeSheet() { $("#sheet").hidden = true; $("#sheet-body").innerHTML = ""; $(".sheet-card").style.transform = ""; }
  $("#sheet").addEventListener("click", (e) => { if (e.target.id === "sheet") closeSheet(); });
  // Drag the handle down to close the sheet.
  (function drag() {
    const card = $(".sheet-card"), handle = $(".handle");
    if (!card || !handle) return;
    let y0 = null, dy = 0;
    handle.addEventListener("pointerdown", (e) => { y0 = e.clientY; dy = 0; card.style.transition = "none"; handle.setPointerCapture(e.pointerId); });
    handle.addEventListener("pointermove", (e) => { if (y0 == null) return; dy = Math.max(0, e.clientY - y0); card.style.transform = "translateY(" + dy + "px)"; });
    const end = () => { if (y0 == null) return; y0 = null; card.style.transition = ""; if (dy > 90) closeSheet(); else card.style.transform = ""; };
    handle.addEventListener("pointerup", end); handle.addEventListener("pointercancel", end);
  })();

  const titleCol = (t) => (t.columns || []).find((c) => c.type === "text" || c.type === "choice") || (t.columns || [])[0];
  const imageCol = (t) => (t.columns || []).find((c) => c.type === "image");
  const badgeCol = (t) => (t.columns || []).find((c) => c.type === "choice" && c.adminOnly) || (t.columns || []).find((c) => c.type === "choice");
  const priceCol = (t) => (t.columns || []).find((c) => c.type === "decimal");
  const canAdd = (t) => B.isAdmin || t.owner === "customer" || t.owner === "public";
  const mine = (row) => !row.customer_id || row.customer_id === B.userId;
  const canEdit = (t, row) => B.isAdmin || ((t.owner === "customer" || t.owner === "public") && mine(row));
  const visibleTables = () => (C.tables || []).filter((t) => t.owner !== "admin" || B.isAdmin || role === "admin");

  function fmt(c, v) {
    if (v == null || v === "") return "";
    if (c.type === "bool") return v === true || v === "true" ? "نعم" : "لا";
    if (c.type === "decimal") { const n = Number(v); return Number.isFinite(n) ? (Number.isInteger(n) ? String(n) : n.toFixed(2)) : String(v); }
    if (c.type === "datetime") { const d = new Date(v); return isNaN(d) ? v : d.toLocaleString("ar", { dateStyle: "medium", timeStyle: "short" }); }
    if (c.type === "date") { const d = new Date(v); return isNaN(d) ? v : d.toLocaleDateString("ar"); }
    return String(v);
  }
  function pillClass(v) {
    const s = String(v);
    if (/ملغي|مرفوض|cancel|reject/i.test(s)) return "bad";
    if (/تم|وصل|مؤكد|done|deliver|confirm/i.test(s)) return "ok";
    if (/جديد|new|انتظار/i.test(s)) return "";
    return "warn";
  }
  function ago(d) {
    const m = Math.floor((Date.now() - d.getTime()) / 60000);
    if (m < 1) return "الآن"; if (m < 60) return "قبل " + m + " د";
    const h = Math.floor(m / 60); if (h < 24) return "قبل " + h + " س";
    return d.toLocaleDateString("ar");
  }

  // ---------- state ----------
  const S = { tab: "home", table: null, rows: {}, query: "", filter: null, unread: 0, stats: null };

  // ---------- screens ----------
  function render() {
    const app = $("#app");
    if (!B.signedIn) return renderLogin(app);
    if (role === "admin" && !B.isAdmin) {
      app.innerHTML = '<div class="wrap"><div class="empty"><span class="big">' + ic("lock", 46) + '</span>الحساب ' + esc(B.email || "") +
        ' ليس مديراً.<br>أضف بريده كمدير في Alpha ثم سجّل الدخول مرة أخرى.<br><br><button class="btn sm" id="out">تسجيل الخروج</button></div></div>';
      $("#out").onclick = async () => { await B.signOut(); render(); };
      return;
    }
    const tables = visibleTables();
    const tabs = [{ id: "home", label: "الرئيسية", icon: "dashboard" }]
      .concat(tables.slice(0, 3).map((t) => ({ id: "t:" + t.name, label: t.label, icon: t.icon })))
      .concat(B.kind !== "none" ? [{ id: "notes", label: "الإشعارات", icon: "bell" }] : [])
      .concat([{ id: "me", label: "حسابي", icon: "person" }]);
    let body = "";
    if (S.tab === "home") body = homeView(tables);
    else if (S.tab.startsWith("t:")) body = tableView(tables.find((t) => "t:" + t.name === S.tab) || S.table);
    else if (S.tab === "notes") body = '<div class="topbar"><h2>الإشعارات</h2></div><div class="wrap" id="notes"><div class="boot" style="height:40vh"><div class="spinner"></div></div></div>';
    else if (S.tab === "me") body = meView();
    app.innerHTML = body + '<nav class="nav">' + tabs.map((t) =>
      '<button data-tab="' + esc(t.id) + '" class="' + (S.tab === t.id ? "on" : "") + '"><i>' + ic(t.icon) + "</i>" + esc(t.label) +
      (t.id === "notes" && S.unread ? '<span class="badge">' + S.unread + "</span>" : "") + "</button>").join("") + "</nav>";
    app.querySelectorAll("[data-tab]").forEach((b) => (b.onclick = () => go(b.dataset.tab)));
    bind();
    reveal();
    designHook(S.tab === "home" ? "home" : S.tab.startsWith("t:") ? "list" : S.tab);
  }

  function go(tab) {
    S.tab = tab; S.query = ""; S.filter = null;
    if (tab.startsWith("t:")) S.table = (C.tables || []).find((t) => "t:" + t.name === tab);
    render();
    if (tab.startsWith("t:")) loadRows(S.table);
    if (tab === "notes") loadNotes();
    if (tab === "home") { loadStats(); loadHome(); }
    window.scrollTo(0, 0);
  }

  function renderLogin(app) {
    // login | signup | code (the email confirmation code, or link with Firebase)
    let mode = "login";
    const form = { name: "", phone: "", email: "", pass: "" };
    function keep() {
      ["name", "phone", "email", "pass"].forEach((k) => { const el = $("#l_" + k); if (el) form[k] = el.value; });
    }
    function draw() {
      const link = !!B.confirmsWithLink;
      const sub = mode === "code" ? "تأكيد البريد الإلكتروني" : mode === "signup" ? "أنشئ حسابك" : role === "admin" ? "لوحة الإدارة" : "مرحباً بعودتك";
      let fields;
      if (mode === "code") {
        fields = '<p style="text-align:center;line-height:1.8">' + (link ? "افتح الرابط الذي أرسلناه إلى " : "أدخل الرمز المكوّن من 6 أرقام الذي أرسلناه إلى ") + "<b>" + esc(form.email) + "</b></p>" +
          (link ? "" : '<input class="input ltr" id="l_code" inputmode="numeric" maxlength="6" placeholder="••••••" style="text-align:center;font-size:26px;letter-spacing:10px;font-weight:800">');
      } else {
        fields = (mode === "signup" ? '<label class="lbl">الاسم</label><input class="input" id="l_name" autocomplete="name" value="' + esc(form.name) + '">' +
          '<label class="lbl">رقم الهاتف</label><input class="input ltr" id="l_phone" type="tel" autocomplete="tel" value="' + esc(form.phone) + '">' : "") +
          '<label class="lbl">البريد الإلكتروني</label><input class="input ltr" id="l_email" type="email" autocomplete="email" value="' + esc(form.email) + '">' +
          '<label class="lbl">كلمة المرور</label><input class="input ltr" id="l_pass" type="password" autocomplete="current-password" value="' + esc(form.pass) + '">';
      }
      const label = mode === "code" ? (link ? "تحقق" : "تأكيد") : mode === "signup" ? "إنشاء الحساب" : "دخول";
      const links = mode === "code"
        ? '<button class="linkbtn" id="l_resend">أرسل الرمز مرة أخرى</button><button class="linkbtn" id="l_back">رجوع لتسجيل الدخول</button>'
        : '<button class="linkbtn" id="l_switch">' + (mode === "signup" ? "عندي حساب، سجّل دخولي" : "ما عندي حساب؟ أنشئ واحداً") + "</button>";
      app.innerHTML = '<div class="login"><header class="hero"><i class="o o1"></i><i class="o o2"></i><div class="avatar" style="margin:0 auto 12px;background:rgba(255,255,255,.2)">' + ic(role === "admin" ? "lock" : "person", 30) +
        '</div><h1>' + esc(C.app.title) + "</h1><p>" + sub + '</p></header><div class="card">' + fields + '<button class="btn" id="l_go">' + label + "</button>" + links + "</div></div>";
      const sw = $("#l_switch"); if (sw) sw.onclick = () => { keep(); mode = mode === "signup" ? "login" : "signup"; draw(); };
      const back = $("#l_back"); if (back) back.onclick = () => { mode = "login"; draw(); };
      const resend = $("#l_resend"); if (resend) resend.onclick = async () => {
        try { await B.resendCode(form.email); toast("أُرسل من جديد إلى " + form.email); } catch (err) { toast(err.message, true); }
      };
      $("#l_go").onclick = async (e) => {
        keep();
        const email = form.email.trim(), pass = form.pass;
        if (mode === "code") {
          const code = ($("#l_code") || { value: "" }).value.trim();
          if (!link && !/^\d{6}$/.test(code)) return toast("اكتب الرمز من 6 أرقام", true);
          e.target.disabled = true;
          try { await B.verifyCode(email, code, pass); afterSignIn(); go("home"); }
          catch (err) { toast(err.message, true); e.target.disabled = false; }
          return;
        }
        if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return toast("بريد غير صحيح", true);
        if (pass.length < 6) return toast("كلمة المرور 6 أحرف على الأقل", true);
        if (mode === "signup" && form.name.trim().length < 2) return toast("اكتب اسمك", true);
        if (mode === "signup" && !/^[+0-9 ()-]{7,20}$/.test(form.phone.trim())) return toast("رقم الهاتف غير صحيح", true);
        e.target.disabled = true;
        try {
          if (mode === "signup") {
            if (await B.signUp(form.name, form.phone, email, pass)) {
              mode = "code"; draw();
              return toast(B.confirmsWithLink ? "أرسلنا رابط التأكيد إلى بريدك" : "أرسلنا رمز التأكيد إلى بريدك");
            }
          } else await B.signIn(email, pass);
          afterSignIn(); go("home");
        } catch (err) {
          if (err.needsCode) { mode = "code"; draw(); return toast("أكّد بريدك أولاً: أدخل الرمز الذي وصلك، أو اطلب رمزاً جديداً"); }
          toast(err.message, true); e.target.disabled = false;
        }
      };
    }
    draw();
    designHook("login");
  }

  // In-app updates: the build publishes each version at a public link; the phone's browser downloads it.
  async function checkUpdate() {
    const u = C.update || {};
    if (!u.url || !u.version) return;
    try {
      const res = await fetch(u.url + "?t=" + Date.now());
      if (!res.ok) return;
      const j = await res.json();
      if (!(j.version > u.version) || !j.apk) return;
      openSheet("<h3>تحديث جديد</h3><p>النسخة " + esc(j.name || "1.0." + j.version) + " جاهزة." + (j.notes ? "<br><br>" + esc(j.notes) : "") + '</p><button class="btn" id="upd">حدّث الآن</button><button class="linkbtn" id="later">لاحقاً</button>');
      $("#later").onclick = closeSheet;
      $("#upd").onclick = () => { closeSheet(); toast("يتم التحميل… افتح الملف عند انتهائه واضغط «تثبيت»"); window.location.href = j.apk; };
    } catch (e) { /* offline: try next time */ }
  }

  // The home header: badge, title, a line, numbers, and the school's own shapes (.o) / wave / moving title.
  function heroHtml(title, subtitle, icon, badge, stats) {
    const wave = '<svg class="wave" viewBox="0 0 400 40" preserveAspectRatio="none"><path d="M0,24 C80,48 160,0 240,18 C300,32 350,34 400,14 L400,40 L0,40 Z" fill="var(--bg)"/></svg>';
    const hs = stats && stats.length ? '<div class="hs">' + stats.map((s) => "<div><b>" + esc(s[0]) + "</b><span>" + esc(s[1]) + "</span></div>").join("") + "</div>" : "";
    const words = Array(6).fill(esc(title)).join(" ✦ ") + " ✦ ";
    return '<header class="hero"><i class="o o1"></i><i class="o o2"></i><div class="hb">' + ic(icon, 14) + esc(badge || "") + "</div><h1>" + esc(title) + "</h1><p>" + esc(subtitle) + "</p>" + hs +
      '<div class="marq" aria-hidden="true"><span>' + words + "</span><span>" + words + "</span></div>" + wave + "</header>";
  }

  // The table whose rows the home shows (featured / feed): the first one the person can see, preferring pictures or prices.
  const homeTable = (tables) => tables.find((x) => imageCol(x) && x.owner !== "admin") || tables.find((x) => priceCol(x)) || tables[0];

  function tilesHtml(tables) {
    let list = tables.map((x, i) => '<div class="card tile tap' + (i === 0 ? " hl" : "") + '" data-open="' + esc(x.name) + '"><div class="ic">' + ic(x.icon) + "</div><b>" +
      (S.stats && S.stats[x.name] != null ? S.stats[x.name] : S.rows[x.name] ? S.rows[x.name].length : "…") + "</b><span>" + esc(x.label) + "</span>" +
      (i === 0 && T.home === "bento" ? '<svg class="spark" width="90" height="34" viewBox="0 0 90 34"><path d="M2 28 L16 20 L28 24 L42 10 L56 16 L70 6 L88 12" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" opacity=".7"/></svg>' : "") + "</div>");
    if (S.stats && S.stats._customers != null) list.push('<div class="card tile tap"><div class="ic">' + ic("person") + "</div><b>" + S.stats._customers + "</b><span>العملاء</span></div>");
    if (list.length % 2 && T.home !== "bento") list[list.length - 1] = list[list.length - 1].replace("card tile", "card tile wide");
    return '<div class="grid">' + list.join("") + "</div>";
  }

  function homeView(tables) {
    const a = C.app;
    const hello = B.name ? "أهلاً " + B.name : "أهلاً بك";
    const first = homeTable(tables);
    const head = B.isAdmin ? "نظرة عامة" : "الأقسام";
    const stats = S.stats ? tables.slice(0, 3).filter((x) => S.stats[x.name] != null).map((x) => [S.stats[x.name], x.label]) : null;
    const hero = heroHtml(a.headline || a.title, a.subtitle || (B.isAdmin ? "لوحة التحكم" : hello), B.isAdmin ? "dashboard" : "sparkle", B.isAdmin ? "لوحة الإدارة" : a.title, stats);
    const rail = first ? '<div class="section"><h3>' + (B.isAdmin ? "الأحدث في " : "مميز في ") + esc(first.label) + '</h3><button data-open="' + esc(first.name) + '">الكل</button></div><div class="rail" id="feat"><div class="spinner" style="margin:30px auto"></div></div>' : "";
    if (T.home === "feed" && first) {
      S.table = first;
      return '<div class="reel-top">' + esc(a.title) + '</div><div class="reels" id="rows"><div class="boot"><div class="spinner"></div></div></div>';
    }
    if (T.home === "chat") {
      return hero + '<div class="wrap"><div class="chat" id="chat"><div class="bubble ai"><div class="bi">' + ic("sparkle", 18) + esc(a.title) + "</div>" + esc(hello) + "، ماذا تريد اليوم؟ اكتب ما تبحث عنه أو اختر قسماً.</div>" +
        '<div class="suggest">' + tables.map((x) => '<span class="chip" data-open="' + esc(x.name) + '">' + ic(x.icon, 16) + esc(x.label) + "</span>").join("") + "</div></div>" + '<div style="height:90px"></div></div>' +
        '<div class="composer"><input id="cq" placeholder="ابحث أو اسأل…" autocomplete="off"><button id="cs" aria-label="إرسال">' + ic("send", 18) + "</button></div>";
    }
    if (T.home === "focus") {
      return '<div class="focus"><button class="orb" id="orb" aria-label="' + esc(first ? first.label : "") + '">' + ic(first && canAdd(first) ? "plus" : (first || {}).icon || "sparkle", 56) + "</button><h1>" + esc(hello) + "</h1><p>" +
        esc(a.subtitle || (first && canAdd(first) ? "اضغط للإضافة إلى " + first.label : a.title)) + '</p><div class="quick">' +
        tables.map((x) => '<span class="chip" data-open="' + esc(x.name) + '">' + ic(x.icon, 16) + esc(x.label) + "</span>").join("") + "</div></div>";
    }
    if (T.home === "carousel") return hero + '<div class="wrap">' + rail + '<div class="section"><h3>' + head + "</h3></div>" + tilesHtml(tables) + "</div>";
    return hero + '<div class="wrap"><div class="section"><h3>' + head + "</h3></div>" + tilesHtml(tables) + rail + "</div>";
  }

  // Rows for the home's featured rail (and the feed home).
  async function loadHome() {
    const tables = visibleTables(), t = homeTable(tables);
    if (!t) return;
    // Tiles show how many items each table has (the admin's numbers come from stats).
    if (!S.stats) tables.slice(0, 6).forEach(async (x) => {
      try { const n = (S.rows[x.name] = await B.list(x)).length; const b = document.querySelector('.tile[data-open="' + x.name + '"] b'); if (b && S.tab === "home") b.textContent = n; } catch (e) {}
    });
    let rows;
    try { rows = S.rows[t.name] = await B.list(t); } catch (e) { rows = []; }
    if (S.tab !== "home") return;
    if (T.home === "feed") return drawRows(t);
    const el = $("#feat");
    if (!el) return;
    const title = titleCol(t), image = imageCol(t), price = priceCol(t), badge = badgeCol(t);
    el.innerHTML = rows.length ? rows.slice(0, 8).map((r) =>
      '<div class="card feat tap" data-hit="' + esc(t.name) + "|" + esc(r.id) + '">' + art("cv", t.name + r.id, t.icon, image && /^https?:/.test(r[image.name] || "") ? r[image.name] : "", 40) +
      '<div class="fb"><div class="title">' + esc(title ? fmt(title, r[title.name]) : t.label) + '</div><div class="meta">' +
      (badge && r[badge.name] ? '<span class="pill ' + pillClass(r[badge.name]) + '">' + esc(r[badge.name]) + "</span>" : "") +
      (price && r[price.name] != null ? '<span class="price">' + esc(fmt(price, r[price.name])) + "</span>" : "") + "</div></div></div>").join("")
      : '<div class="empty" style="padding:20px;width:100%">لا يوجد شيء في ' + esc(t.label) + " بعد</div>";
    el.querySelectorAll("[data-hit]").forEach((x) => (x.onclick = () => details(t, rows.find((r) => t.name + "|" + r.id === x.dataset.hit))));
    reveal();
    designHook("featured");
  }

  // Chat home: what you type is searched in every table; answers come back as bubbles.
  async function ask(text) {
    const box = $("#chat");
    if (!box || !text.trim()) return;
    box.insertAdjacentHTML("beforeend", '<div class="bubble me">' + esc(text) + "</div>");
    const q = text.trim().toLowerCase();
    const tables = visibleTables();
    const named = tables.find((x) => q.includes(String(x.label).toLowerCase()));
    let html = "", hits = [];
    for (const t of tables) {
      try {
        const rows = S.rows[t.name] || (S.rows[t.name] = await B.list(t));
        rows.filter((r) => (t.columns || []).some((c) => String(r[c.name] == null ? "" : r[c.name]).toLowerCase().includes(q))).slice(0, 3).forEach((r) => hits.push([t, r]));
      } catch (e) {}
    }
    if (hits.length) {
      html = "وجدت " + hits.length + " نتيجة:" + hits.map(([t, r]) => { const tc = titleCol(t); return '<div class="row" data-hit="' + esc(t.name) + "|" + esc(r.id) + '" style="margin-top:10px;cursor:pointer">' + art("thumb", t.name + r.id, t.icon, "", 18) + '<div class="grow"><div class="title" style="font-size:14px">' + esc(tc ? fmt(tc, r[tc.name]) : t.label) + '</div><div class="sub">' + esc(t.label) + "</div></div></div>"; }).join("");
    } else html = named ? "افتح «" + esc(named.label) + "» من هنا:" : "لم أجد شيئاً بهذا. جرّب كلمة أخرى أو افتح قسماً:";
    const open = named || (!hits.length && tables[0]);
    box.insertAdjacentHTML("beforeend", '<div class="bubble ai"><div class="bi">' + ic("sparkle", 18) + esc(C.app.title) + "</div>" + html +
      (open ? '<div class="suggest" style="margin-top:10px"><span class="chip on" data-open="' + esc(open.name) + '">' + esc(open.label) + "</span></div>" : "") + "</div>");
    box.querySelectorAll("[data-hit]").forEach((x) => (x.onclick = () => { const [tn] = x.dataset.hit.split("|"); const t = tables.find((y) => y.name === tn); details(t, (S.rows[tn] || []).find((r) => tn + "|" + r.id === x.dataset.hit)); }));
    bind();
    window.scrollTo({ top: document.body.scrollHeight, behavior: "smooth" });
  }

  function tableView(t) {
    if (!t) return '<div class="wrap"><div class="empty">لا يوجد</div></div>';
    const add = canAdd(t) ? '<button class="fab" id="add">' + ic("plus", 18) + " إضافة</button>" : "";
    if (T.list === "reels" && !B.isAdmin) return '<div class="reel-top">' + esc(t.label) + '</div><div class="reels" id="rows"><div class="boot"><div class="spinner"></div></div></div>' + add;
    const badge = badgeCol(t);
    const chips = badge && badge.options && badge.options.length
      ? '<div class="chips"><span class="chip ' + (S.filter == null ? "on" : "") + '" data-f="">الكل</span>' +
        badge.options.map((o) => '<span class="chip ' + (S.filter === o ? "on" : "") + '" data-f="' + esc(o) + '">' + esc(o) + "</span>").join("") + "</div>" : "";
    return '<div class="topbar"><h2>' + esc(t.label) + '</h2></div><div class="wrap"><div class="search">' + ic("search", 18) + '<input class="input" id="q" placeholder="بحث في ' + esc(t.label) + '" value="' + esc(S.query) + '"></div>' +
      chips + '<div id="rows"><div class="boot" style="height:30vh"><div class="spinner"></div></div></div></div>' + add;
  }

  function meView() {
    const label = B.name || (B.email ? B.email.split("@")[0] : "مستخدم");
    return '<div class="topbar"><h2>حسابي</h2></div><div class="wrap"><div class="card row"><div class="avatar">' + esc(label.charAt(0).toUpperCase()) +
      '</div><div class="grow"><div class="title">' + esc(label) + "</div>" + (B.email ? '<div class="sub">' + esc(B.email) + "</div>" : "") +
      '<div class="meta"><span class="pill">' + (B.isAdmin ? "مدير" : "عميل") + '</span></div></div></div><div class="card">' +
      '<div class="kv"><span>التطبيق</span><span>' + esc(C.app.title) + '</span></div><div class="kv"><span>البيانات</span><span>' +
      ({ supabase: "Supabase", firebase: "Firebase" }[B.kind] || "على الجهاز") + '</span></div><div class="kv"><span>الإشعارات</span><span>' +
      ((C.backend || {}).push ? "مفعّلة" : "داخل التطبيق") + "</span></div></div>" +
      (B.needsAccount ? '<button class="btn ghost" id="out">' + ic("logout", 18) + " تسجيل الخروج</button>" : "") +
      '<p class="empty" style="padding:24px">صُنع بواسطة Alpha</p></div>';
  }

  function bind() {
    document.querySelectorAll("[data-open]").forEach((el) => (el.onclick = () => {
      const name = el.dataset.open;
      const tables = visibleTables();
      const i = tables.findIndex((t) => t.name === name);
      if (i >= 0 && i < 3) return go("t:" + name);
      S.table = tables[i]; S.tab = "t:" + name; render(); loadRows(S.table);
    }));
    const q = $("#q");
    if (q) q.oninput = () => { S.query = q.value; drawRows(S.table); };
    document.querySelectorAll("[data-f]").forEach((el) => (el.onclick = () => {
      S.filter = el.dataset.f || null;
      document.querySelectorAll("[data-f]").forEach((x) => x.classList.toggle("on", (x.dataset.f || null) === S.filter));
      drawRows(S.table);
    }));
    const add = $("#add"); if (add) add.onclick = () => form(S.table);
    const cq = $("#cq"), cs = $("#cs");
    if (cq && cs) { const send = () => { const v = cq.value; cq.value = ""; ask(v); }; cs.onclick = send; cq.onkeydown = (e) => { if (e.key === "Enter") send(); }; }
    const orb = $("#orb");
    if (orb) orb.onclick = () => { const t = homeTable(visibleTables()); if (!t) return; if (canAdd(t)) { S.table = t; form(t); } else go("t:" + t.name); };
    const out = $("#out"); if (out) out.onclick = async () => { await B.signOut(); go("home"); };
  }

  async function loadStats() {
    try { S.stats = B.isAdmin ? await B.stats() : null; } catch (e) { S.stats = null; }
    if (S.tab === "home" && S.stats) { render(); loadHome(); }
  }

  async function loadRows(t, quiet) {
    if (!t) return;
    try { S.rows[t.name] = await B.list(t); drawRows(t); }
    catch (e) { if (!quiet) { const el = $("#rows"); if (el) el.innerHTML = '<div class="empty"><span class="big">' + ic("cloud", 46) + "</span>" + esc(e.message) + '<br><br><button class="btn sm ghost" id="retry">إعادة المحاولة</button></div>'; const r = $("#retry"); if (r) r.onclick = () => loadRows(t); } }
  }

  function drawRows(t) {
    const el = $("#rows");
    if (!el || !t) return;
    const all = S.rows[t.name] || [];
    const badge = badgeCol(t), title = titleCol(t), image = imageCol(t), price = priceCol(t);
    const q = S.query.trim().toLowerCase();
    const rows = all.filter((r) => (S.filter == null || !badge || r[badge.name] === S.filter) &&
      (!q || (t.columns || []).some((c) => String(r[c.name] == null ? "" : r[c.name]).toLowerCase().includes(q))));
    const reels = el.classList.contains("reels");
    if (!rows.length) {
      el.innerHTML = '<div class="empty"' + (reels ? ' style="color:#fff;padding-top:40vh"' : "") + '><span class="big">' + ic(t.icon, 46) + "</span>" + (all.length ? "لا نتائج" : "لا يوجد شيء في " + esc(t.label) + " بعد") + "</div>";
      return;
    }
    const pic = (r) => (image && /^https?:/.test(r[image.name] || "") ? r[image.name] : "");
    const detailsOf = (r) => (t.columns || []).filter((c) => c.show !== false && c !== title && c !== image && c !== badge && c !== price && r[c.name] != null && r[c.name] !== "")
      .slice(0, 3).map((c) => esc(c.label) + ": " + esc(fmt(c, r[c.name]))).join("  •  ");
    const meta = (r) => '<div class="meta">' + (badge && r[badge.name] ? '<span class="pill ' + pillClass(r[badge.name]) + '">' + esc(r[badge.name]) + "</span>" : "") +
      (price && r[price.name] != null ? '<span class="price">' + esc(fmt(price, r[price.name])) + "</span>" : "") + "</div>";
    if (reels) {
      el.innerHTML = rows.map((r) => '<section class="reel" data-row="' + esc(r.id) + '">' + art("rbg", t.name + r.id, t.icon, pic(r), 90) +
        '<div class="rb"><div class="title">' + esc(title ? fmt(title, r[title.name]) : t.label) + "</div>" + (detailsOf(r) ? '<div class="sub">' + detailsOf(r) + "</div>" : "") + meta(r) + "</div>" +
        '<div class="side"><button data-like aria-label="إعجاب">' + ic("heart", 22) + '</button><button data-share aria-label="مشاركة">' + ic("share", 22) + '</button><button aria-label="المزيد">' + ic("more", 22) + "</button></div></section>").join("");
      el.querySelectorAll("[data-like]").forEach((b) => (b.onclick = (e) => { e.stopPropagation(); b.style.color = b.style.color ? "" : "#FF3B6B"; }));
      el.querySelectorAll("[data-share]").forEach((b) => (b.onclick = (e) => { e.stopPropagation(); const r = rows.find((x) => String(x.id) === b.closest("[data-row]").dataset.row); const text = title ? fmt(title, r[title.name]) : t.label; if (navigator.share) navigator.share({ title: C.app.title, text }).catch(() => {}); else toast(text); }));
    } else {
      el.innerHTML = rows.map((r) => {
        const d = detailsOf(r);
        return '<div class="card row tap" data-row="' + esc(r.id) + '">' + art("thumb", t.name + r.id, t.icon, pic(r), T.list === "grid" ? 40 : 24) + '<div class="grow">' +
          (r.created_at ? '<div class="when">' + ago(new Date(r.created_at)) + "</div>" : "") + '<div class="title">' +
          esc(title ? fmt(title, r[title.name]) : t.label) + "</div>" + (d ? '<div class="sub">' + d + "</div>" : "") + meta(r) + "</div></div>";
      }).join("");
    }
    el.querySelectorAll("[data-row]").forEach((x) => (x.onclick = () => details(t, rows.find((r) => String(r.id) === x.dataset.row))));
    reveal();
    designHook("rows");
  }

  function details(t, row) {
    if (!row) return;
    const image = imageCol(t);
    const quick = B.isAdmin ? (t.columns || []).filter((c) => c.type === "choice" && c.adminOnly) : [];
    const tc = titleCol(t);
    openSheet(art("cover", t.name + row.id, t.icon, image && /^https?:/.test(row[image.name] || "") ? row[image.name] : "", 64) +
      (tc && row[tc.name] ? "<h3>" + esc(fmt(tc, row[tc.name])) + "</h3>" : "") +
      (t.columns || []).filter((c) => c.type !== "image" && row[c.name] != null && row[c.name] !== "").map((c) =>
        '<div class="kv"><span>' + esc(c.label) + "</span><span>" + esc(fmt(c, row[c.name])) + "</span></div>").join("") +
      (row.created_at ? '<p class="sub">أُضيف ' + ago(new Date(row.created_at)) + "</p>" : "") +
      quick.map((c) => '<div class="section"><h3 style="font-size:15px">تغيير ' + esc(c.label) + '</h3></div><div class="chips" style="flex-wrap:wrap">' +
        (c.options || []).map((o) => '<span class="chip ' + (row[c.name] === o ? "on" : "") + '" data-set="' + esc(c.name) + '" data-v="' + esc(o) + '">' + esc(o) + "</span>").join("") + "</div>").join("") +
      (canEdit(t, row) ? '<div class="row" style="margin-top:18px;cursor:default"><button class="btn" id="ed">' + ic("edit", 18) + ' تعديل</button><button class="iconbtn" id="del" style="color:var(--bad)">' + ic("trash", 18) + "</button></div>" : ""));
    document.querySelectorAll("[data-set]").forEach((el) => (el.onclick = async () => {
      try { await B.update(t, row.id, { [el.dataset.set]: el.dataset.v }); closeSheet(); toast("تم التحديث ✓"); loadRows(t); } catch (e) { toast(e.message, true); }
    }));
    const ed = $("#ed"); if (ed) ed.onclick = () => form(t, row);
    const del = $("#del"); if (del) del.onclick = async () => {
      if (!confirm("حذف؟ لا يمكن التراجع.")) return;
      try { await B.remove(t, row.id); closeSheet(); toast("تم الحذف"); loadRows(t); } catch (e) { toast(e.message, true); }
    };
  }

  function form(t, row) {
    const cols = (t.columns || []).filter((c) => !c.adminOnly || B.isAdmin);
    const val = (c) => {
      if (row) return row[c.name];
      const d = c.default;
      if (c.type === "date" && (d === "today" || d === "now")) return new Date().toISOString().slice(0, 10);
      return d;
    };
    const field = (c) => {
      const v = val(c), id = "f_" + c.name, label = '<label class="lbl" for="' + id + '">' + esc(c.label) + (c.required ? " *" : "") + "</label>";
      if (c.type === "bool") return '<div class="switch"><span>' + esc(c.label) + '</span><input type="checkbox" id="' + id + '"' + (v === true || v === "true" ? " checked" : "") + "></div>";
      if (c.type === "choice") return label + '<select class="input" id="' + id + '"><option value="">اختر</option>' + (c.options || []).map((o) => '<option' + (v === o ? " selected" : "") + ">" + esc(o) + "</option>").join("") + "</select>";
      if (c.type === "longtext") return label + '<textarea class="input" id="' + id + '">' + esc(v) + "</textarea>";
      if (c.type === "date") return label + '<input class="input" type="date" id="' + id + '" value="' + esc(v ? String(v).slice(0, 10) : "") + '">';
      if (c.type === "datetime") { const d = v ? new Date(v) : null; const local = d && !isNaN(d) ? new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 16) : ""; return label + '<input class="input" type="datetime-local" id="' + id + '" value="' + local + '">'; }
      const type = { int: "number", decimal: "number", phone: "tel", email: "email", image: "url" }[c.type] || "text";
      const ltr = ["int", "decimal", "phone", "email", "image"].includes(c.type) ? " ltr" : "";
      return label + '<input class="input' + ltr + '" type="' + type + '"' + (c.type === "decimal" ? ' step="any"' : "") + ' id="' + id + '" value="' + esc(v) + '"' + (c.type === "image" ? ' placeholder="https://…"' : "") + ">";
    };
    openSheet("<h3>" + (row ? "تعديل " : "إضافة إلى ") + esc(t.label) + "</h3>" + cols.map(field).join("") + '<button class="btn" id="save">' + (row ? "حفظ التعديل" : "إضافة") + "</button>");
    $("#save").onclick = async (e) => {
      const values = {};
      for (const c of cols) {
        const el = $("#f_" + c.name);
        let v = c.type === "bool" ? el.checked : el.value;
        if (c.type === "datetime" && v) v = new Date(v).toISOString();
        if (c.required && (v === "" || v == null)) { el.focus(); return toast("«" + c.label + "» مطلوب", true); }
        if (c.type === "email" && v && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(v)) return toast("بريد غير صحيح", true);
        values[c.name] = v;
      }
      e.target.disabled = true;
      try { row ? await B.update(t, row.id, values) : await B.insert(t, values); closeSheet(); toast(row ? "تم الحفظ ✓" : "تمت الإضافة ✓"); loadRows(t); }
      catch (err) { toast(err.message, true); e.target.disabled = false; }
    };
  }

  async function loadNotes() {
    const el = $("#notes");
    try {
      const items = await B.notifications();
      B.markSeen(); S.unread = 0;
      const badge = document.querySelector(".nav .badge"); if (badge) badge.remove();
      if (!el) return;
      el.innerHTML = (items.length ? items.map((n) => '<div class="card row" style="cursor:default"><div class="thumb" style="width:44px;height:44px">' + ic("bell") +
        '</div><div class="grow"><div class="title" style="' + (n.read ? "font-weight:600" : "") + '">' + esc(n.title) + "</div>" + (n.body ? '<div class="sub">' + esc(n.body) + "</div>" : "") +
        '<div class="sub">' + ago(n.at) + "</div></div></div>").join("") : '<div class="empty"><span class="big">' + ic("bell", 46) + "</span>لا توجد إشعارات بعد</div>") +
        '<button class="fab" id="compose">' + ic("send", 18) + " " + (B.isAdmin ? "إشعار للعملاء" : "رسالة للإدارة") + "</button>";
      $("#compose").onclick = compose;
    } catch (e) { if (el) el.innerHTML = '<div class="empty">' + esc(e.message) + "</div>"; }
  }

  function compose() {
    openSheet("<h3>" + (B.isAdmin ? "إشعار لكل العملاء" : "رسالة للإدارة") + '</h3><label class="lbl">العنوان</label><input class="input" id="nt"><label class="lbl">النص</label><textarea class="input" id="nb"></textarea><button class="btn" id="ns">' + ic("send", 18) + " إرسال</button>");
    $("#ns").onclick = async () => {
      const title = $("#nt").value.trim(); if (!title) return toast("اكتب العنوان", true);
      try { await B.notify({ toRole: B.isAdmin ? "customer" : "admin", title, body: $("#nb").value.trim() }); closeSheet(); toast("تم الإرسال ✓"); loadNotes(); }
      catch (e) { toast(e.message, true); }
    };
  }

  async function checkUnread() {
    if (B.kind === "none" || !B.signedIn) return;
    try {
      const n = (await B.notifications()).filter((x) => !x.read).length;
      if (n !== S.unread) { S.unread = n; if (S.tab !== "notes") { const btn = document.querySelector('[data-tab="notes"]'); if (btn) { const old = btn.querySelector(".badge"); if (old) old.remove(); if (n) btn.insertAdjacentHTML("beforeend", '<span class="badge">' + n + "</span>"); } } }
    } catch (e) {}
  }

  // Push (Capacitor plugin, added by the build when Firebase is set up).
  async function setupPush() {
    const cap = window.Capacitor;
    const push = cap && cap.Plugins && cap.Plugins.PushNotifications;
    if (!push || !(C.backend || {}).push) return;
    try {
      let perm = await push.checkPermissions();
      if (perm.receive === "prompt") perm = await push.requestPermissions();
      if (perm.receive !== "granted") return;
      await push.addListener("registration", (t) => B.registerDevice(t.value).catch(() => {}));
      await push.addListener("pushNotificationReceived", (n) => { toast((n.title || "") + (n.body ? " — " + n.body : "")); checkUnread(); });
      await push.register();
    } catch (e) { /* push is optional */ }
  }

  let started = false;
  function afterSignIn() {
    if (started) return;
    started = true;
    setupPush();
    checkUnread();
    setInterval(checkUnread, 30000);
    setInterval(() => { if (S.tab.startsWith("t:") && $("#sheet").hidden) loadRows(S.table, true); }, 20000);
  }

  // Onboarding carousel, shown once: slides from Alpha (app.onboarding), or made from the app when theme.onboarding is on.
  function onboarding() {
    const key = "alpha_onb_" + (C.app.slug || "app");
    let slides = Array.isArray(C.app.onboarding) ? C.app.onboarding : null;
    if (!slides && (C.theme || {}).onboarding) {
      slides = [{ title: C.app.title, text: C.app.subtitle || "كل ما تحتاجه في مكان واحد", icon: "sparkle" }]
        .concat((C.tables || []).filter((t) => t.owner !== "admin").slice(0, 2).map((t) => ({ title: t.label, text: "تصفّح " + t.label + " وتابع كل جديد", icon: t.icon })));
    }
    try { if (!slides || !slides.length || localStorage.getItem(key)) return; } catch (e) { return; }
    document.body.insertAdjacentHTML("beforeend", '<div class="onb" id="onb"><div class="slides">' + slides.map((x, i) => '<div class="slide">' + art("", "onb" + i + x.title, x.icon || "sparkle", x.image || "", 84) +
      "<h2>" + esc(x.title) + "</h2><p>" + esc(x.text || "") + "</p></div>").join("") + '</div><div class="foot"><div class="dots">' + slides.map((_, i) => "<i" + (i ? "" : ' class="on"') + "></i>").join("") +
      '</div><button class="linkbtn" id="onb-skip" style="width:auto">تخطي</button><button class="btn" id="onb-next">التالي</button></div></div>');
    const box = $("#onb"), track = $("#onb .slides"), dots = box.querySelectorAll(".dots i");
    const at = () => Math.round(Math.abs(track.scrollLeft) / track.clientWidth);
    const done = () => { try { localStorage.setItem(key, "1"); } catch (e) {} box.remove(); };
    track.addEventListener("scroll", () => { const i = at(); dots.forEach((d, j) => d.classList.toggle("on", i === j)); $("#onb-next").textContent = i === slides.length - 1 ? "ابدأ" : "التالي"; });
    $("#onb-skip").onclick = done;
    $("#onb-next").onclick = () => { const i = at(); if (i >= slides.length - 1) return done(); track.scrollTo({ left: (document.documentElement.dir === "rtl" ? -1 : 1) * (i + 1) * track.clientWidth, behavior: "smooth" }); };
  }

  (async function start() {
    onboarding();
    try {
      await B.init();
      if (B.signedIn) afterSignIn();
      go("home");
      setTimeout(checkUpdate, 1500);
    } catch (e) {
      $("#app").innerHTML = '<div class="wrap"><div class="empty"><span class="big">' + ic("cloud", 46) + "</span>" + esc(e.message) + '<br><br><button class="btn sm" onclick="location.reload()">إعادة المحاولة</button></div></div>';
    }
  })();
})();
