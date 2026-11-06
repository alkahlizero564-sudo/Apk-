// The new screen-design engine (replaces the old "one giant AI HTML file" that was slow and failed):
// the AI returns a small JSON PLAN of the app's screens; this file renders it locally into a polished,
// interactive HTML prototype. No truncation, no long wait — the render is instant and always valid.
//
// The same plan is what the native-code step builds from, and the rendered HTML is Alpha's instant preview.

import 'dart:convert';

import '../models/schema.dart';

/// One screen of the app: a name, an icon, whether it is a bottom-nav tab, and an ordered list of blocks.
class PlanScreen {
  PlanScreen({required this.name, required this.icon, required this.tab, required this.blocks});
  final String name;
  final String icon;
  final bool tab;
  final List<Map<String, dynamic>> blocks;

  factory PlanScreen.fromJson(Map<String, dynamic> j) => PlanScreen(
        name: '${j['name'] ?? 'شاشة'}',
        icon: '${j['icon'] ?? 'home'}',
        tab: j['tab'] != false,
        blocks: ((j['blocks'] as List?) ?? const [])
            .whereType<Map>()
            .map((b) => b.cast<String, dynamic>())
            .toList(),
      );

  Map<String, dynamic> toJson() => {'name': name, 'icon': icon, 'tab': tab, 'blocks': blocks};
}

/// The whole design of one app: palette, type, shape and its screens.
class ScreenPlan {
  ScreenPlan({
    required this.title,
    required this.mode,
    required this.primary,
    required this.accent,
    required this.font,
    required this.radius,
    required this.nav,
    required this.screens,
  });

  final String title;
  final String mode; // light | dark
  final String primary;
  final String accent;
  final String font; // cairo | tajawal | plex | readex | messiri | kufi | changa
  final int radius;
  final String nav; // bar | floating | pill
  final List<PlanScreen> screens;

  static String _hex(Object? v, String d) => RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch('$v') ? '$v'.toUpperCase() : d;

  factory ScreenPlan.fromJson(Map<String, dynamic> j, {String fallbackTitle = 'التطبيق'}) {
    final screens = ((j['screens'] as List?) ?? const []).whereType<Map>().map((s) => PlanScreen.fromJson(s.cast<String, dynamic>())).toList();
    if (screens.isEmpty) throw const FormatException('plan has no screens');
    const fonts = {'cairo', 'tajawal', 'plex', 'readex', 'messiri', 'kufi', 'changa'};
    return ScreenPlan(
      title: '${j['title'] ?? fallbackTitle}',
      mode: j['mode'] == 'light' ? 'light' : 'dark',
      primary: _hex(j['primary'], '#6E4BFF'),
      accent: _hex(j['accent'], '#2DD4BF'),
      font: fonts.contains(j['font']) ? '${j['font']}' : 'tajawal',
      radius: ((j['radius'] as num?)?.round() ?? 20).clamp(0, 30),
      nav: const ['bar', 'floating', 'pill'].contains(j['nav']) ? '${j['nav']}' : 'floating',
      screens: screens,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'mode': mode,
        'primary': primary,
        'accent': accent,
        'font': font,
        'radius': radius,
        'nav': nav,
        'screens': screens.map((s) => s.toJson()).toList(),
      };

  String encode() => const JsonEncoder.withIndent(' ').convert(toJson());
}

/// The block types the AI may use, with what each shows — put verbatim into the AI prompt so the plan is buildable.
const planBlockGuide = '''
Each screen has "blocks" (ordered). Each block is an object with a "type" and, when it shows data, a "table" (a table
name from the data). Use these block types only:
- {"type":"hero","title":"..","subtitle":".."}  big header with the app/screen title
- {"type":"stats","table":".."} or {"type":"stats","items":[{"label":"..","value":".."}]}  small number cards (dashboards)
- {"type":"search","table":".."}  a search field
- {"type":"filters","table":".."}  a row of filter chips (uses the table's choice column)
- {"type":"featured","table":".."}  a horizontal carousel of highlighted items (use for a home with a catalog)
- {"type":"grid","table":".."}  a 2-column card grid with image, title and price (stores, galleries)
- {"type":"list","table":".."}  a vertical list of rows (orders, bookings, messages, tasks)
- {"type":"timeline","table":".."}  a vertical timeline (status history, activity)
- {"type":"form","table":".."}  an add/edit form built from the table's columns
- {"type":"profile"}  an account header with avatar, name and settings rows
- {"type":"section","title":".."}  a section heading between blocks
- {"type":"banner","title":"..","subtitle":".."}  a highlighted promo/notice card
- {"type":"buttons","items":[{"label":"..","icon":".."}]}  a row of action buttons
- {"type":"empty","text":".."}  an illustrated empty state
Icons (for screens and buttons): home, search, cart, receipt, star, restaurant, calendar, person, bell, settings,
wallet, chart, book, chat, add, heart, map, camera, list.
''';

// ---------------------------------------------------------------------------- the renderer

const _fontFamily = {
  'cairo': "'A-cairo'",
  'tajawal': "'A-tajawal'",
  'plex': "'A-plex'",
  'readex': "'A-readex'",
  'messiri': "'A-messiri'",
  'kufi': "'A-kufi'",
  'changa': "'A-changa'",
};

const _icons = {
  'home': 'M3 10.5 12 3l9 7.5V21h-6v-6H9v6H3z',
  'search': 'M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16zM21 21l-4.3-4.3',
  'cart': 'M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4zM3 6h18M16 10a4 4 0 0 1-8 0',
  'receipt': 'M4 2v20l3-2 3 2 3-2 3 2 3-2 1 .7V2l-3 2-3-2-3 2-3-2-3 2zM8 8h8M8 12h8M8 16h5',
  'star': 'm12 2 3.1 6.3 6.9 1-5 4.9 1.2 6.8L12 17.8 5.8 21l1.2-6.8-5-4.9 6.9-1z',
  'restaurant': 'M3 2v7a3 3 0 0 0 6 0V2M6 2v20M18 2c-2 0-3 2.5-3 6s1 5 3 5v9',
  'calendar': 'M3 5h18v16H3zM3 10h18M8 3v4M16 3v4',
  'person': 'M20 21a8 8 0 0 0-16 0M12 13a5 5 0 1 0 0-10 5 5 0 0 0 0 10z',
  'bell': 'M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9M10.3 21a1.9 1.9 0 0 0 3.4 0',
  'settings': 'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z',
  'wallet': 'M3 7a2 2 0 0 1 2-2h14v4M3 7v12a2 2 0 0 0 2 2h16V9H5a2 2 0 0 1-2-2zM16 15h.01',
  'chart': 'M3 3v18h18M7 14v4M12 9v9M17 5v13',
  'book': 'M4 19.5A2.5 2.5 0 0 1 6.5 17H20V2H6.5A2.5 2.5 0 0 0 4 4.5zM4 19.5A2.5 2.5 0 0 0 6.5 22H20v-5',
  'chat': 'M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z',
  'add': 'M12 5v14M5 12h14',
  'heart': 'M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1-1.1a5.5 5.5 0 0 0-7.8 7.8l9 8.6 9-8.6a5.5 5.5 0 0 0 0-7.8z',
  'map': 'M12 22s7-6.2 7-12a7 7 0 0 0-14 0c0 5.8 7 12 7 12zM12 12.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z',
  'camera': 'M3 7h4l2-2h6l2 2h4v13H3zM12 17a4 4 0 1 0 0-8 4 4 0 0 0 0 8z',
  'list': 'M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01',
};

String _esc(Object? v) => '$v'.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
String _ic(String n, [int s = 22]) =>
    '<svg width="$s" height="$s" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="${_icons[n] ?? _icons['list']}"/></svg>';

/// Renders the plan into a complete, self-contained, interactive HTML prototype of the app.
/// [schema] gives the real sections and fields so screens show the owner's own data.
String renderPlan(ScreenPlan plan, {required DbSchema schema, bool rtl = true}) {
  final tables = {for (final t in schema.tables) t.name: t};
  final r = plan.radius;
  final light = plan.mode == 'light';
  final font = _fontFamily[plan.font] ?? "'A-tajawal'";
  final tabs = plan.screens.where((s) => s.tab).toList();
  final navScreens = tabs.isEmpty ? plan.screens.take(4).toList() : tabs.take(5).toList();

  final sb = StringBuffer();
  for (var i = 0; i < plan.screens.length; i++) {
    final s = plan.screens[i];
    sb.writeln('<section class="screen${i == 0 ? ' on' : ''}" data-screen="$i">');
    for (final b in s.blocks) {
      sb.writeln(_block(b, plan, tables, s));
    }
    sb.writeln('<div style="height:110px"></div></section>');
  }

  final nav = StringBuffer('<nav class="nav">');
  for (var i = 0; i < plan.screens.length; i++) {
    if (!navScreens.contains(plan.screens[i])) continue;
    final s = plan.screens[i];
    nav.write('<button data-go="$i"><i>${_ic(s.icon, 22)}</i><span>${_esc(s.name)}</span></button>');
  }
  nav.write('</nav>');

  // The review switcher (#alpha-screens): jump to any screen. It is not part of the app.
  final sw = StringBuffer('<div id="alpha-screens">');
  for (var i = 0; i < plan.screens.length; i++) {
    sw.write('<button data-go="$i"${i == 0 ? ' class="on"' : ''}>${i + 1}. ${_esc(plan.screens[i].name)}</button>');
  }
  sw.write('</div>');

  return '''<!doctype html>
<html lang="${rtl ? 'ar' : 'en'}" dir="${rtl ? 'rtl' : 'ltr'}" class="${light ? 'light' : ''}">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${_esc(plan.title)}</title>
<style>${_css(plan, r, light, font)}</style></head>
<body>
$sw
<main id="app" class="nav-${plan.nav}">
$sb
$nav
</main>
<script>
(function(){
  var go=function(i){
    document.querySelectorAll('.screen').forEach(function(s){s.classList.toggle('on', s.dataset.screen==i)});
    document.querySelectorAll('[data-go]').forEach(function(b){b.classList.toggle('on', b.dataset.go==i)});
    window.scrollTo(0,0);
  };
  document.querySelectorAll('[data-go]').forEach(function(b){b.onclick=function(){go(b.dataset.go)}});
})();
</script>
</body></html>''';
}

String _css(ScreenPlan plan, int r, bool light, String font) {
  final bg = light ? '#F4F5FA' : '#0C0D13';
  final surface = light ? '#FFFFFF' : '#16171F';
  final surface2 = light ? '#EEF0F6' : '#1F212B';
  final line = light ? 'rgba(20,20,40,.10)' : 'rgba(255,255,255,.09)';
  final tx = light ? '#15131E' : '#F3F4FB';
  final mut = light ? '#6B6880' : '#9A97AE';
  return '''
@import url("fonts/fonts.css");
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
html,body{margin:0;background:$bg;color:$tx;font-family:$font,system-ui,"Segoe UI",Tahoma,sans-serif;line-height:1.5}
:root{--p:${plan.primary};--a:${plan.accent};--bg:$bg;--s:$surface;--s2:$surface2;--l:$line;--tx:$tx;--mut:$mut;--r:${r}px;
  --grad:linear-gradient(135deg,${plan.primary},${plan.accent})}
#alpha-screens{position:sticky;top:0;z-index:30;display:flex;gap:6px;overflow-x:auto;padding:8px 12px;background:rgba(0,0,0,.55);backdrop-filter:blur(8px);scrollbar-width:none}
#alpha-screens::-webkit-scrollbar{display:none}
#alpha-screens button{flex:none;border:0;border-radius:99px;padding:6px 12px;font:inherit;font-size:12px;font-weight:700;color:#fff;background:rgba(255,255,255,.12);cursor:pointer}
#alpha-screens button.on{background:var(--grad)}
#app{max-width:460px;margin:0 auto;min-height:100vh;position:relative;padding-bottom:0}
.screen{display:none;padding:0 0 10px}
.screen.on{display:block;animation:up .35s cubic-bezier(.2,.8,.2,1)}
@keyframes up{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:none}}
.wrap{padding:0 16px}
.hero{position:relative;overflow:hidden;color:#fff;background:var(--grad);padding:calc(26px + env(safe-area-inset-top)) 20px 26px;border-radius:0 0 calc(var(--r) + 10px) calc(var(--r) + 10px)}
.hero h1{margin:0;font-size:27px;font-weight:800;letter-spacing:-.01em}
.hero p{margin:7px 0 0;opacity:.9;font-size:14px}
.hero .o1{position:absolute;inset-inline-end:-50px;top:-50px;width:170px;height:170px;border-radius:50%;background:rgba(255,255,255,.12)}
.hero .o2{position:absolute;inset-inline-end:40px;bottom:-40px;width:90px;height:90px;border-radius:50%;background:rgba(255,255,255,.10)}
.sec{display:flex;align-items:center;justify-content:space-between;margin:22px 2px 12px}
.sec h3{margin:0;font-size:18px;font-weight:800}
.sec a{color:var(--p);font-size:13px;font-weight:700;text-decoration:none}
.card{background:var(--s);border:1px solid var(--l);border-radius:var(--r);padding:14px;box-shadow:0 1px 2px rgba(0,0,0,.04),0 10px 24px rgba(0,0,0,.05)}
.stats{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-top:14px}
.stat{display:flex;flex-direction:column;gap:2px}
.stat .ic{width:40px;height:40px;border-radius:12px;display:grid;place-items:center;color:var(--p);background:color-mix(in srgb,var(--p) 14%,transparent);margin-bottom:8px}
.stat b{font-size:26px;font-weight:800;letter-spacing:-.02em}
.stat span{color:var(--mut);font-size:13px}
.search{display:flex;align-items:center;gap:10px;background:var(--s);border:1px solid var(--l);border-radius:99px;padding:12px 16px;color:var(--mut);margin-top:14px}
.chips{display:flex;gap:8px;overflow-x:auto;padding:14px 0 4px;scrollbar-width:none}
.chips::-webkit-scrollbar{display:none}
.chip{flex:none;border:1px solid var(--l);border-radius:99px;padding:8px 16px;font-size:13px;font-weight:700;color:var(--mut);background:var(--s)}
.chip.on{background:var(--grad);color:#fff;border-color:transparent}
.rail{display:flex;gap:12px;overflow-x:auto;padding:4px 16px 6px;margin:0 -16px;scrollbar-width:none}
.rail::-webkit-scrollbar{display:none}
.feat{flex:none;width:74%;max-width:300px;border-radius:var(--r);overflow:hidden;background:var(--s);border:1px solid var(--l)}
.feat .img{height:140px;background:var(--grad);display:grid;place-items:center;color:rgba(255,255,255,.9)}
.feat .b{padding:12px 14px}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-top:4px}
.tile{border-radius:var(--r);overflow:hidden;background:var(--s);border:1px solid var(--l)}
.tile .img{aspect-ratio:1;background:var(--grad);display:grid;place-items:center;color:rgba(255,255,255,.9)}
.tile .b{padding:10px 12px}
.title{font-weight:800;font-size:15px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.meta{display:flex;align-items:center;gap:8px;margin-top:7px}
.price{color:var(--p);font-weight:800;margin-inline-start:auto}
.pill{font-size:12px;font-weight:700;padding:3px 10px;border-radius:99px;background:color-mix(in srgb,var(--a) 16%,transparent);color:var(--a)}
.row{display:flex;align-items:center;gap:12px;background:var(--s);border:1px solid var(--l);border-radius:var(--r);padding:12px;margin-top:10px}
.row .thumb{width:52px;height:52px;border-radius:14px;background:var(--grad);display:grid;place-items:center;color:#fff;flex:none}
.row .grow{flex:1;min-width:0}
.row .sub{color:var(--mut);font-size:13px;margin-top:2px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.tl{position:relative;padding-inline-start:26px;margin-top:12px}
.tl::before{content:"";position:absolute;inset-inline-start:8px;top:6px;bottom:6px;width:2px;background:var(--grad);opacity:.5}
.tl .row::before{content:"";position:absolute;inset-inline-start:2px;width:12px;height:12px;border-radius:50%;background:var(--bg);border:3px solid var(--p);margin-top:18px}
.field{margin-top:12px}
.field label{display:block;font-size:13px;font-weight:700;color:var(--mut);margin:0 4px 6px}
.field .inp{background:var(--s);border:1px solid var(--l);border-radius:14px;padding:13px 15px;color:var(--mut)}
.btn{display:flex;align-items:center;justify-content:center;gap:8px;border:0;border-radius:14px;padding:15px;font:inherit;font-size:15px;font-weight:800;color:#fff;background:var(--grad);width:100%;margin-top:16px}
.btns{display:flex;gap:10px;margin-top:14px}
.btns .btn{margin-top:0}
.btns .ghost{background:var(--s);color:var(--tx);border:1px solid var(--l)}
.banner{background:var(--grad);color:#fff;border-radius:var(--r);padding:18px;margin-top:14px}
.banner h4{margin:0 0 4px;font-size:17px}
.banner p{margin:0;opacity:.9;font-size:13px}
.empty{text-align:center;color:var(--mut);padding:40px 16px}
.empty .big{width:80px;height:80px;border-radius:26px;display:inline-grid;place-items:center;color:var(--p);background:color-mix(in srgb,var(--p) 12%,transparent);margin-bottom:12px}
.prof{display:flex;align-items:center;gap:14px;margin-top:14px}
.prof .av{width:62px;height:62px;border-radius:50%;background:var(--grad);display:grid;place-items:center;color:#fff;font-size:24px;font-weight:800}
.kv{display:flex;justify-content:space-between;padding:13px 0;border-bottom:1px solid var(--l)}
.kv span:last-child{color:var(--mut)}
.fab{position:absolute;inset-inline-start:18px;bottom:96px;width:56px;height:56px;border-radius:50%;background:var(--grad);color:#fff;display:grid;place-items:center;box-shadow:0 10px 24px color-mix(in srgb,var(--p) 45%,transparent)}
.nav{position:sticky;bottom:0;display:flex;justify-content:space-around;gap:4px;padding:8px 8px calc(8px + env(safe-area-inset-bottom));background:color-mix(in srgb,var(--s) 92%,transparent);backdrop-filter:blur(16px);border-top:1px solid var(--l)}
.nav button{flex:1;border:0;background:none;color:var(--mut);font:inherit;font-size:11px;font-weight:700;display:flex;flex-direction:column;align-items:center;gap:3px;padding:4px}
.nav i{width:52px;height:30px;display:grid;place-items:center;border-radius:99px}
.nav button.on{color:var(--p)}
.nav button.on i{background:color-mix(in srgb,var(--p) 16%,transparent)}
.nav-floating .nav{position:fixed;left:14px;right:14px;bottom:calc(12px + env(safe-area-inset-bottom));max-width:432px;margin:0 auto;border-radius:24px;border:1px solid var(--l);box-shadow:0 16px 40px rgba(0,0,0,.3)}
.nav-pill .nav{position:fixed;left:50%;transform:translateX(-50%);bottom:calc(14px + env(safe-area-inset-bottom));width:min(92%,420px);border-radius:99px;background:color-mix(in srgb,var(--tx) 92%,transparent);border:0}
.nav-pill .nav button{color:color-mix(in srgb,var(--bg) 60%,transparent)}
.nav-pill .nav button.on{color:#fff}
.nav-pill .nav button.on i{background:var(--grad)}
''';
}

// ---- blocks ----

String _block(Map<String, dynamic> b, ScreenPlan plan, Map<String, DbTable> tables, PlanScreen screen) {
  final type = '${b['type']}';
  DbTable? t;
  final tn = '${b['table'] ?? ''}';
  if (tn.isNotEmpty) t = tables[tn];
  t ??= tables.values.isNotEmpty ? tables.values.first : null;
  switch (type) {
    case 'hero':
      return '<header class="hero"><span class="o1"></span><span class="o2"></span>'
          '<h1>${_esc(b['title'] ?? screen.name)}</h1><p>${_esc(b['subtitle'] ?? plan.title)}</p></header>';
    case 'stats':
      return '<div class="wrap"><div class="stats">${_stats(b, t)}</div></div>';
    case 'search':
      return '<div class="wrap"><div class="search">${_ic('search', 18)}<span>بحث${t != null ? ' في ${_esc(t.label)}' : ''}…</span></div></div>';
    case 'filters':
      return '<div class="wrap">${_filters(t)}</div>';
    case 'featured':
      return '<div class="wrap"><div class="sec"><h3>مميّز${t != null ? ' · ${_esc(t.label)}' : ''}</h3><a>الكل</a></div></div><div class="rail">${_featured(t)}</div>';
    case 'grid':
      return '<div class="wrap">${_sec(t?.label ?? 'العناصر')}<div class="grid">${_grid(t)}</div></div>';
    case 'list':
      return '<div class="wrap">${_sec(t?.label ?? 'القائمة')}${_list(t, false)}</div>';
    case 'timeline':
      return '<div class="wrap">${_sec(t?.label ?? 'النشاط')}<div class="tl">${_list(t, true)}</div></div>';
    case 'form':
      return '<div class="wrap">${_sec('إضافة${t != null ? ' إلى ${_esc(t.label)}' : ''}')}${_form(t)}</div>';
    case 'profile':
      return '<div class="wrap">${_profile(plan)}</div>';
    case 'section':
      return '<div class="wrap">${_sec('${b['title'] ?? ''}')}</div>';
    case 'banner':
      return '<div class="wrap"><div class="banner"><h4>${_esc(b['title'] ?? 'عرض')}</h4><p>${_esc(b['subtitle'] ?? '')}</p></div></div>';
    case 'buttons':
      return '<div class="wrap">${_buttons(b)}</div>';
    case 'empty':
      return '<div class="wrap"><div class="empty"><div class="big">${_ic(screen.icon, 36)}</div><div>${_esc(b['text'] ?? 'لا يوجد شيء بعد')}</div></div></div>';
    default:
      return '';
  }
}

String _sec(String title, {bool all = true}) => '<div class="sec"><h3>${_esc(title)}</h3>${all ? '<a>الكل</a>' : ''}</div>';

// Sample values for a column, in the owner's language.
List<String> _samples(DbColumn c) {
  switch (c.type) {
    case ColumnType.decimal:
      return ['45', '120', '18.50'];
    case ColumnType.integer:
      return ['3', '12', '7'];
    case ColumnType.boolean:
      return ['نعم', 'لا', 'نعم'];
    case ColumnType.date:
      return ['٢٠٢٦/٠٦/١٢', 'اليوم', 'غداً'];
    case ColumnType.datetime:
      return ['اليوم ٣:٣٠ م', 'أمس', 'الأحد ١٠ ص'];
    case ColumnType.phone:
      return ['+249 90 123 4567', '+249 91 222 3333', ''];
    case ColumnType.email:
      return ['user@mail.com', '', ''];
    case ColumnType.choice:
      return c.options.isNotEmpty ? c.options : ['جديد', 'قيد التنفيذ', 'تم'];
    default:
      return c.options.isNotEmpty ? c.options : ['${c.label} الأول', '${c.label} الثاني', '${c.label} الثالث'];
  }
}

String _val(DbTable? t, ColumnType type, int i, {bool title = false}) {
  if (t == null) return ['عنصر ${i + 1}', 'عنصر ${i + 2}', 'عنصر ${i + 3}'][i % 3];
  final cols = t.columns;
  DbColumn? col;
  if (title) {
    col = t.titleColumn;
  } else {
    for (final c in cols) {
      if (c.type == type) {
        col = c;
        break;
      }
    }
  }
  if (col == null) return title ? '${t.label} ${i + 1}' : '';
  final s = _samples(col);
  return s[i % s.length];
}

String _stats(Map<String, dynamic> b, DbTable? t) {
  final items = (b['items'] as List?)?.whereType<Map>().toList();
  final data = items != null && items.isNotEmpty
      ? items.take(4).map((m) => ('${m['value'] ?? '0'}', '${m['label'] ?? ''}')).toList()
      : [('128', t?.label ?? 'العناصر'), ('24', 'اليوم'), ('٣٤٥٠', 'الإجمالي'), ('٨', 'جديد')];
  final icons = ['chart', 'receipt', 'wallet', 'star'];
  final sb = StringBuffer();
  for (var i = 0; i < data.length; i++) {
    sb.write('<div class="card stat"><div class="ic">${_ic(icons[i % icons.length], 20)}</div><b>${_esc(data[i].$1)}</b><span>${_esc(data[i].$2)}</span></div>');
  }
  return sb.toString();
}

String _filters(DbTable? t) {
  final opts = t == null ? <String>[] : (t.columns.firstWhere((c) => c.type == ColumnType.choice, orElse: () => t.columns.isEmpty ? DbColumn(name: 'x', label: '') : t.columns.first).options);
  final chips = ['الكل', ...(opts.isEmpty ? ['الأحدث', 'المميّز', 'الأعلى'] : opts)];
  final sb = StringBuffer('<div class="chips">');
  for (var i = 0; i < chips.length; i++) {
    sb.write('<div class="chip${i == 0 ? ' on' : ''}">${_esc(chips[i])}</div>');
  }
  sb.write('</div>');
  return sb.toString();
}

String _featured(DbTable? t) {
  final sb = StringBuffer();
  for (var i = 0; i < 4; i++) {
    sb.write('<div class="feat"><div class="img">${_ic('star', 40)}</div><div class="b"><div class="title">${_esc(_val(t, ColumnType.text, i, title: true))}</div>'
        '<div class="meta"><span class="pill">${_esc(_val(t, ColumnType.choice, i))}</span><span class="price">${_esc(_val(t, ColumnType.decimal, i))}${t != null && t.columns.any((c) => c.type == ColumnType.decimal) ? ' ج' : ''}</span></div></div></div>');
  }
  return sb.toString();
}

String _grid(DbTable? t) {
  final sb = StringBuffer();
  for (var i = 0; i < 4; i++) {
    final price = _val(t, ColumnType.decimal, i);
    sb.write('<div class="tile"><div class="img">${_ic('star', 34)}</div><div class="b"><div class="title">${_esc(_val(t, ColumnType.text, i, title: true))}</div>'
        '<div class="meta">${price.isEmpty ? '' : '<span class="price">${_esc(price)} ج</span>'}</div></div></div>');
  }
  return sb.toString();
}

String _list(DbTable? t, bool timeline) {
  final sb = StringBuffer();
  for (var i = 0; i < 4; i++) {
    final badge = _val(t, ColumnType.choice, i);
    final price = _val(t, ColumnType.decimal, i);
    sb.write('<div class="row"><div class="thumb">${_ic(timeline ? 'calendar' : 'receipt', 22)}</div>'
        '<div class="grow"><div class="title">${_esc(_val(t, ColumnType.text, i, title: true))}</div>'
        '<div class="sub">${_esc(_val(t, ColumnType.text, i + 1))}</div></div>'
        '<div style="text-align:center">${badge.isEmpty ? '' : '<span class="pill">${_esc(badge)}</span>'}${price.isEmpty ? '' : '<div class="price" style="margin-top:6px">${_esc(price)} ج</div>'}</div></div>');
  }
  return sb.toString();
}

String _form(DbTable? t) {
  final cols = t?.columns.take(5).toList() ?? [];
  final sb = StringBuffer();
  if (cols.isEmpty) {
    for (final l in ['الاسم', 'التفاصيل', 'الكمية']) {
      sb.write('<div class="field"><label>$l</label><div class="inp">اكتب هنا…</div></div>');
    }
  } else {
    for (final c in cols) {
      sb.write('<div class="field"><label>${_esc(c.label)}</label><div class="inp">${_esc(_samples(c).first)}</div></div>');
    }
  }
  sb.write('<button class="btn">${_ic('add', 18)} حفظ</button>');
  return sb.toString();
}

String _profile(ScreenPlan plan) {
  return '<div class="card"><div class="prof"><div class="av">${_esc(plan.title.isEmpty ? 'A' : plan.title.substring(0, 1))}</div>'
      '<div><div class="title" style="font-size:18px">سارة محمد</div><div class="sub" style="color:var(--mut)">عضو منذ ٢٠٢٦</div></div></div></div>'
      '<div class="card" style="margin-top:12px">'
      '<div class="kv"><span>الإشعارات</span><span>مفعّلة</span></div>'
      '<div class="kv"><span>اللغة</span><span>العربية</span></div>'
      '<div class="kv" style="border:0"><span>المظهر</span><span>${plan.mode == 'light' ? 'فاتح' : 'داكن'}</span></div></div>'
      '<div class="btns"><button class="btn ghost">${_ic('settings', 18)} الإعدادات</button></div>';
}

String _buttons(Map<String, dynamic> b) {
  final items = (b['items'] as List?)?.whereType<Map>().toList() ?? [];
  if (items.isEmpty) return '';
  final sb = StringBuffer('<div class="btns">');
  for (var i = 0; i < items.length && i < 3; i++) {
    sb.write('<button class="btn${i > 0 ? ' ghost' : ''}">${_ic('${items[i]['icon'] ?? 'add'}', 18)} ${_esc(items[i]['label'] ?? '')}</button>');
  }
  sb.write('</div>');
  return sb.toString();
}
