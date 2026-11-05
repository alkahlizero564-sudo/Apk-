// What the AI designer gets to work with: the exact markup of every screen the engine draws (HTML apps, PHP apps and
// Alpha's instant preview), the variables, the fonts and the libraries. Its CSS / JS restyle this markup; they never
// replace it, so data, sign-in, notifications and updates keep working.

const designContract = r'''
ROOT: <html class="[light] s-<school> home-<tiles|bento|carousel|feed|chat|focus> list-<cards|compact|grid|timeline|reels>
       nav-<bar|floating|pill> sheet-<sheet|page> ai" dir="rtl" lang="ar">
BODY: <div class="deco"> (fixed full-screen background layer, behind everything, empty: style it freely), <div id="app">,
      the sheet, the toast. Arabic, right-to-left, phone sized (360-430px wide).

HOME (home-tiles | home-bento | home-carousel):
  <header class="hero"> <i class="o o1"></i><i class="o o2"></i> (two empty decorative elements: shapes, blobs, rings...)
     <div class="hb"><svg/>badge text</div> <h1>big title</h1> <p>line</p>
     <div class="hs"><div><b>12</b><span>label</span></div>…</div> (admin numbers, may be absent)
     <div class="marq"><span>title ✦ title ✦ …</span><span>…</span></div> (moving title strip, display:none unless you show it)
     <svg class="wave">…</svg> (bottom wave, display:none unless you show it)
  </header>
  <div class="wrap">
     <div class="section"><h3>section title</h3><button>الكل</button></div>
     <div class="grid"> <div class="card tile tap hl"> (first tile is highlighted .hl; a lone last tile gets .wide)
         <div class="ic"><svg/></div><b>count</b><span>section name</span> [<svg class="spark"/> bento only]</div> … </div>
     <div class="rail" id="feat"> (horizontal featured cards)
         <div class="card feat tap"><div class="cv art"><svg class="bg"/><span><svg/></span>[<img>]</div>
           <div class="fb"><div class="title">name</div><div class="meta"><span class="pill">status</span><span class="price">25</span></div></div></div>
  </div>
HOME home-feed: <div class="reel-top">title</div><div class="reels" id="rows"><section class="reel"><div class="rbg art">…</div>
     <div class="rb"><div class="title"/><div class="sub"/><div class="meta"/></div><div class="side"><button/>×3</div></section>…</div>
HOME home-chat: hero, then <div class="wrap"><div class="chat"><div class="bubble ai"><div class="bi"><svg/>name</div>text</div>
     <div class="bubble me">text</div><div class="suggest"><span class="chip">…</span></div></div></div>
     <div class="composer"><input id="cq"><button id="cs"><svg/></button></div>
HOME home-focus: <div class="focus"><button class="orb" id="orb"><svg/></button><h1>hello</h1><p>line</p><div class="quick"><span class="chip"/>…</div></div>

LIST SCREEN (a table): <div class="topbar"><h2>title</h2></div>
  <div class="wrap"><div class="search"><svg/><input class="input" id="q"></div>
     <div class="chips"><span class="chip on">الكل</span><span class="chip">…</span></div>
     <div id="rows"> <div class="card row tap"><div class="thumb art"><svg class="bg"/><span><svg/></span>[<img>]</div>
        <div class="grow"><div class="when">time</div><div class="title">name</div><div class="sub">details</div>
        <div class="meta"><span class="pill ok|bad|warn">status</span><span class="price">25</span></div></div></div> … </div></div>
  <button class="fab" id="add"><svg/> إضافة</button>
  (list-compact: rows in one card with dividers; list-grid: 2 columns, picture on top; list-timeline: line + dots;
   list-reels: full-screen vertical feed like home-feed)
NOTIFICATIONS: topbar + <div class="wrap" id="notes"> card rows + <button class="fab" id="compose">
ACCOUNT: topbar + <div class="card row"><div class="avatar">A</div><div class="grow"><div class="title"/><div class="sub"/></div></div>
  <div class="card"><div class="kv"><span>key</span><span>value</span></div>…</div> <button class="btn ghost">
BOTTOM NAV (nav-bar: full width at the bottom; nav-floating: inset 14px with radius; nav-pill: centered with
  left:50%; transform:translateX(-50%); width:min(90%,420px) — when you move the bar, set left/right/transform/width yourself):
  <nav class="nav"><button data-tab="…" class="on"><i><svg/></i>label<span class="badge">3</span></button>…</nav>
SHEET (details / forms): <div class="sheet" id="sheet"><div class="sheet-card"><div class="handle"></div><div id="sheet-body">
  <div class="cover art"/><h3>title</h3><div class="kv"/>… <label class="lbl"/><input class="input"/><select class="input"/>
  <textarea class="input"/><div class="switch"/> <button class="btn">save</button><button class="linkbtn"/></div></div></div>
LOGIN: <div class="login"><header class="hero"><i class="o o1"/><i class="o o2"/><div class="avatar"><svg/></div><h1/><p/></header>
  <div class="card"><label class="lbl"/><input class="input"/>… <button class="btn"/><button class="linkbtn"/></div></div>
ONBOARDING: <div class="onb"><div class="slides"><div class="slide"><div class="art"/><h2/><p/></div>…</div>
  <div class="foot"><div class="dots"><i class="on"/><i/></div><button class="linkbtn"/><button class="btn"/></div></div>
OTHER: <div class="toast [bad]">, <div class="empty"><span class="big"><svg/></span>text</div>, <button class="btn sm|ghost">,
  <button class="iconbtn">, .spinner, .boot (loading).
PHP apps use the same classes (hero, grid/tile, topbar, search, chips, card row/thumb/title/sub/meta/pill/price, nav with
  <a><button>, fab, login, kv, empty, btn) on server-made pages (no chat/feed/focus/onboarding there).

VARIABLES (on :root, override them under :root.ai; your palette in :root.ai wins over the theme colors): --seed --accent (theme colors) --grad (gradient) --r (radius)
  --font --display (fonts) --bg --surface --surface2 --line --line2 --tx (text) --mut (muted) --ok --bad --warn
  --shadow --shadow-lg --btn-r --chip-r --border --on-seed (text on seed) --hero-tx (text on hero) --title-w --title-size.
  Light mode adds the class "light" on <html>; write :root.ai.light { … } for it when the app may be light.
FONTS (already loaded, Arabic + Latin): 'A-cairo' 400/700/900, 'A-tajawal' 400/700/800, 'A-plex' 300/400/700,
  'A-readex' 300/400/600, 'A-messiri' 400/700, 'A-kufi' 400/700/900, 'A-changa' 400/700/800, 'A-lalezar' 400 (display only).
LIBRARIES for design.js (globals, loaded only when your JS names them): gsap + ScrollTrigger, AOS (with its CSS),
  Typed, VanillaTilt, confetti (canvas-confetti), rough (rough.js, hand-drawn SVG/canvas).
''';

/// The fenced files of an AI answer: ```css design.css … ``` → {'design.css': …} (also keyed by the language alone).
Map<String, String> codeFiles(String text) {
  final out = <String, String>{};
  for (final m in RegExp(r'```([A-Za-z0-9_+-]*)[ \t]*([^\n`]*)\n([\s\S]*?)```').allMatches(text)) {
    final lang = m.group(1)!.trim().toLowerCase();
    final name = m.group(2)!.trim();
    final body = m.group(3)!;
    if (name.isNotEmpty) out[name] = body;
    if (lang.isNotEmpty) out.putIfAbsent(lang, () => body);
  }
  return out;
}

/// The AI's CSS may not reach the network (no @import, no remote url()); everything else is kept.
String sanitizeDesignCss(String css) => css
    .replaceAll(RegExp(r'@import[^;]*;', caseSensitive: false), '')
    .replaceAllMapped(RegExp(r'url\(\s*([^)]*)\)', caseSensitive: false),
        (m) => RegExp(r'''^['"]?\s*data:''').hasMatch(m.group(1)!.trim()) ? m.group(0)! : 'none');
