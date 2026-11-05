import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/project.dart';
import '../generator/ai_edit.dart';
import '../generator/design_contract.dart';
import '../generator/presets.dart';
import '../models/schema.dart';

/// AI on the phone (Claude or Gemini, with the user's own keys): designs a database from a description.
/// Writing app code with AI runs in GitHub Actions (generate.yml), where the build can fix it.
class AiDesigner {
  AiDesigner({required this.claudeKey, required this.geminiKeys, this.geminiModel = defaultGeminiModel, this.geminiFirst = false});

  static const defaultGeminiModel = 'gemini-3.8-flash';
  final String claudeKey;
  final List<String> geminiKeys;
  final String geminiModel;

  /// The owner chose Gemini as the main model (otherwise Claude is tried first when it has a key).
  final bool geminiFirst;

  /// Every Gemini model the key can use to write text (the picker in the settings).
  static Future<List<({String id, String name, String description})>> listGeminiModels(String key) async {
    final out = <({String id, String name, String description})>[];
    var pageToken = '';
    do {
      final res = await http.get(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?pageSize=1000${pageToken.isEmpty ? '' : '&pageToken=$pageToken'}'),
          headers: {'x-goog-api-key': key}).timeout(const Duration(seconds: 30));
      if (res.statusCode >= 300) {
        throw Exception(res.statusCode == 400 || res.statusCode == 403 ? 'مفتاح Gemini غير صحيح' : 'Gemini (${res.statusCode})');
      }
      final j = (jsonDecode(utf8.decode(res.bodyBytes)) as Map).cast<String, dynamic>();
      for (final m in (j['models'] as List? ?? const [])) {
        final methods = ((m['supportedGenerationMethods'] as List?) ?? const []).map((e) => '$e');
        if (!methods.contains('generateContent')) continue;
        final id = '${m['name']}'.replaceFirst('models/', '');
        if (id.contains('embedding') || id.contains('aqa') || id.contains('imagen') || id.contains('tts')) continue;
        out.add((id: id, name: '${m['displayName'] ?? id}', description: '${m['description'] ?? ''}'));
      }
      pageToken = '${j['nextPageToken'] ?? ''}';
    } while (pageToken.isNotEmpty);
    // Newest and "pro" first, then by name.
    int rank(String id) => (id.contains('pro') ? 0 : id.contains('flash-lite') ? 2 : 1);
    out.sort((a, b) {
      final r = rank(a.id).compareTo(rank(b.id));
      return r != 0 ? r : b.id.compareTo(a.id);
    });
    return out;
  }

  bool get available => claudeKey.isNotEmpty || geminiKeys.isNotEmpty;

  Future<String> _claude(String prompt, {int maxTokens = 8000}) async {
    final res = await http
        .post(Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {'x-api-key': claudeKey, 'anthropic-version': '2023-06-01', 'content-type': 'application/json'},
            body: jsonEncode({
              'model': 'claude-sonnet-5-5',
              'max_tokens': maxTokens,
              'messages': [
                {'role': 'user', 'content': prompt}
              ],
            }))
        .timeout(const Duration(minutes: 5));
    if (res.statusCode >= 300) throw Exception('Claude (${res.statusCode}): ${res.body}');
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
    return ((j['content'] as List).where((b) => b['type'] == 'text').map((b) => b['text'])).join();
  }

  Future<String> _gemini(String prompt, String geminiKey, {bool json = true, double temperature = 0.3}) async {
    final res = await http
        .post(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$geminiModel:generateContent'),
            headers: {'x-goog-api-key': geminiKey, 'content-type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {if (json) 'responseMimeType': 'application/json', 'temperature': temperature},
            }))
        .timeout(const Duration(minutes: 5));
    if (res.statusCode >= 300) throw Exception('Gemini (${res.statusCode}): ${res.body}');
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
    return ((j['candidates'] as List).first['content']['parts'] as List).map((p) => p['text']).join();
  }

  /// [json]: the answer is JSON (default); otherwise free text such as fenced code files.
  Future<String> ask(String prompt, {bool json = true, double temperature = 0.3, int maxTokens = 8000}) async {
    Object? last;
    Future<String?> tryClaude() async {
      if (claudeKey.isEmpty) return null;
      try {
        return await _claude(prompt, maxTokens: maxTokens);
      } catch (e) {
        last = e;
        return null;
      }
    }

    Future<String?> tryGemini() async {
      // Each Gemini key in turn: a key out of quota does not stop the work.
      for (final key in geminiKeys) {
        try {
          return await _gemini(prompt, key, json: json, temperature: temperature);
        } catch (e) {
          last = e;
        }
      }
      return null;
    }

    final order = geminiFirst ? [tryGemini, tryClaude] : [tryClaude, tryGemini];
    for (final attempt in order) {
      final text = await attempt();
      if (text != null) return text;
    }
    throw Exception(last == null ? 'أضف مفتاح Claude أو Gemini في الإعدادات.' : '$last');
  }


  Map<String, dynamic> _json(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) throw Exception('الرد لم يكن JSON');
    return (jsonDecode(text.substring(start, end + 1)) as Map).cast<String, dynamic>();
  }

  /// Step "الفهم": only understanding what the owner wants (no design, no tables yet).
  Future<Understanding> understand(String description, {String code = ''}) async {
    final prompt = """
You are the requirements analyst of Alpha, an app builder. Your ONLY job now is to understand what the owner wants.
Do not design colors and do not write code. Write everything in Arabic (keep technical names in English).

The owner's description:
$description
${code.trim().isEmpty ? '' : '\nThe owner also pasted existing code they want to build (understand what it does):\n```\n${code.length > 12000 ? code.substring(0, 12000) : code}\n```\n'}
Reply with JSON only:
{"title": "short app name (Arabic ok)", "slug": "short english id, lowercase and dashes",
 "summary": "2-4 sentences: what the app is, for whom, the main flow",
 "kind": "single" or "pair" (pair = a customer app + an admin app that talk to each other, e.g. orders/bookings managed by the business),
 "lang": "flutter|html|php|python|kotlin" (best fit; flutter by default; the language of the pasted code if any),
 "screens_customer": ["screen: what the user does there", ...],
 "screens_admin": ["screen: what the admin does there", ...] (empty for a single app without admin),
 "data": ["entity: its fields", ...],
 "notifications": ["when → who is notified", ...],
 "auth": "none" | "email_password" | "email_code" (email_code when accounts with name, phone and email must be verified),
 "questions": ["anything unclear the owner should decide", ...]}
""";
    return Understanding.fromJson(_json(await ask(prompt)));
  }

  /// Step "التصميم": only the look, from the approved understanding.
  Future<({ThemeSpec theme, String headline, String subtitle, String reason})> designTheme(String brief) async {
    final prompt = """
You are the UI designer of Alpha. Your ONLY job now is the visual identity of this app (no data, no code).
The approved understanding of the app:
$brief

Pick ONE design school (the complete visual language) that fits the business and its customers. Be bold and specific:
a kids or food brand suits clay/brutal/sketch, luxury suits swiss/spatial, tech suits glass/cyber/hud/aurora, a content or media app
suits kinetic or a reels feed, an assistant suits chat, a single-action app (timer, panic button, quick order) suits zero.
${looks.map((l) => '- ${l.id}: ${l.name}: ${l.hint}').join('\n')}
Layouts you can change: home = tiles|bento|carousel|feed (full-screen vertical reels)|chat|focus; list = cards|compact|grid|timeline|reels;
nav = bar|floating|pill; sheet = sheet|page. Fonts: cairo, tajawal, plex, readex, messiri, kufi, changa, lalezar (display).
Then pick colors that fit (premium, modern, good contrast). Reply with JSON only:
{"look": one of the ids above, "seed": "#RRGGBB" (main color), "accent": "#RRGGBB" (second color), "mode": "dark|light",
 "home": optional layout, "list": optional, "nav": optional, "font": optional font id, "onboarding": true if a welcome carousel helps,
 "headline": "big Arabic title of the home screen",
 "subtitle": "short Arabic line under it", "reason": "one Arabic sentence: why this school"}
""";
    final j = _json(await ask(prompt));
    String hex(Object? v, String d) => RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch('$v') ? '$v'.toUpperCase() : d;
    final look = lookById('${j['look']}') ?? lookById('material')!;
    String? one(Object? v, Map<String, String> ok) => v != null && '$v'.isNotEmpty && ok.containsKey('$v') ? '$v' : null;
    // The school sets shapes, cards, lists and navigation; the AI's colors and layout choices are kept on top of it.
    final theme = look.apply(ThemeSpec()).copyWith(
      preset: 'ai',
      seed: hex(j['seed'], look.seed),
      accent: hex(j['accent'], look.accent),
      mode: j['mode'] == 'light' ? 'light' : (j['mode'] == 'dark' ? 'dark' : look.mode),
      home: one(j['home'], homeLayouts),
      list: one(j['list'], listStyles),
      nav: one(j['nav'], navStyles),
      font: one(j['font'], fontChoices),
      onboarding: j['onboarding'] == true,
    );
    return (theme: theme, headline: '${j['headline'] ?? ''}', subtitle: '${j['subtitle'] ?? ''}', reason: '${j['reason'] ?? ''}');
  }

  // ---------- design first (like APK Fact) ----------

  static String? _brief;
  static Future<String> designBrief() async => _brief ??= (await rootBundle.loadString('factory/design_brief.md'))
      .replaceFirst(RegExp(r'^<!--.*?-->\s*', dotAll: true), '');

  static const _platform = {
    Lang.html: 'a modern mobile web app (it ships as a WebView app)',
    Lang.php: 'a mobile-first PHP web app (server-made pages, opened inside an Android app)',
    Lang.flutter: 'a Flutter Material 3 app: use Material 3 shapes, components, elevation and motion so the design maps 1:1 to Flutter widgets',
    Lang.python: 'a Python Flet (Material 3) app: use Material 3 components only, so every element maps to a Flet control',
    Lang.kotlin: 'a native Android app in Kotlin with Jetpack Compose Material 3: use Material 3 components, shapes and motion so every element maps 1:1 to a Compose composable',
  };

  static const _designer = '''You are a world-class mobile product designer and senior front-end engineer.
This is the DESIGN STAGE only: focus entirely on the user interface, visual design and user experience.
No real backend: use realistic sample data inside the page.

Deliver ONE self-contained HTML file (inline CSS and JS, no external files, fonts or images) that is a
high-fidelity, clickable prototype of the WHOLE app:
- Every main screen of the app, each as its own view, connected with working navigation (bottom bar, tabs,
  buttons, back arrows, sheets and dialogs open and close).
- A slim, elegant "screens" switcher fixed at the very top (element with id="alpha-screens"): a horizontally
  scrollable row of small pills with each screen's name, so the reviewer can jump to any screen. Keep it
  visually separate from the app (dark translucent bar). Everything else is the app itself.
- Show key states too: at least one empty state and one loading skeleton (reachable from the switcher).
- Phone-first layout (360-430px wide, full height), right-to-left with Arabic text when the description is
  in Arabic.
''';

  String _role(AppUnit a) => switch (a.role) {
        'admin' => 'This is the ADMIN / management app of the business: dashboard with KPI cards and charts, managing every record, statuses, reports, customers list, notifications inbox, settings.',
        'customer' => 'This is the CUSTOMER app of the business: browse, create and follow their own records, notifications inbox, profile.',
        _ => 'One app that does everything for its owner.',
      };

  String _appFacts(Project p) {
    final tables = p.schema.tables.map((t) => '- ${t.label} (${t.name}): ${t.columns.map((c) => '${c.label} [${c.type.id}${c.options.isEmpty ? '' : ': ${c.options.join('/')}'}]').join('، ')}').join('\n');
    final auth = switch (p.auth) {
      AuthMode.none => 'No sign-in: the app opens straight to its main screen.',
      AuthMode.emailPassword => 'Sign-in and sign-up screens: name, phone, email, password.',
      AuthMode.emailCode => 'Sign-up with name, phone and email, then a 6-digit email code (6 separate boxes, resend timer), then sign-in.',
    };
    return 'The real data of the app (use these sections and fields, with realistic Arabic sample values):\n$tables\n$auth'
        '${p.backend != BackendType.none ? '\nIt has a notifications inbox (new orders, status changes...).' : ''}';
  }

  String _extractHtml(String text) {
    final m = RegExp(r'```html\s*\n([\s\S]*?)```').firstMatch(text);
    var html = (m?.group(1) ?? text).trim();
    final i = html.toLowerCase().indexOf('<!doctype');
    if (i > 0) html = html.substring(i);
    if (!html.toLowerCase().contains('<html') || html.length < 1500) throw Exception('لم يكتمل التصميم من الذكاء الاصطناعي، جرّب مرة أخرى');
    return html;
  }

  /// The whole app as a clickable high-fidelity prototype (one HTML file), from its approved understanding.
  /// [brandFrom]: the other app's approved design (pair): same brand. [current] + [change]: revise a design.
  Future<String> designPrototype(Project p, AppUnit app, {String brandFrom = '', String current = '', String change = ''}) async {
    final standard = await designBrief();
    final system = '$_designer\n$standard\nReply with ONLY the file inside a single ```html code block.';
    final base = 'App name: ${app.title}\nDesign it as ${_platform[p.lang]}.\n${_role(app)}\n';
    String prompt;
    if (current.isNotEmpty) {
      prompt = '$system\n\n$base\nCurrent design:\n```html\n$current\n```\n\nChange requested by the owner (apply it fully and precisely; '
          'keep everything else as it is unless the change needs it; keep the screens switcher):\n$change\n';
    } else {
      prompt = '$system\n\n$base\nWhat the app is and does (approved by the owner):\n${p.brief.isEmpty ? p.description : p.brief}\n\n${_appFacts(p)}\n'
          '${p.isPair ? '\nDesign ONLY the ${app.role == 'admin' ? 'ADMIN' : 'CUSTOMER'} app; the other app of the pair is designed separately.\n' : ''}'
          '${brandFrom.isEmpty ? '' : '\nThis app belongs to the same business as the design below. Use the SAME brand: palette, fonts, corner radius, icon style and component look, so the two apps feel like one product:\n```html\n${brandFrom.length > 40000 ? brandFrom.substring(0, 40000) : brandFrom}\n```\n'}'
          '${change.isEmpty ? '' : '\nThe owner also wants: $change\n'}';
    }
    return _extractHtml(await ask(prompt, json: false, temperature: current.isEmpty ? 0.7 : 0.5, maxTokens: 32000));
  }

  /// Step "التصميم": the AI itself designs the whole interface of the app from its description, as a senior UI designer:
  /// the visual layer (design.css), motion with the design libraries (design.js) and a spec for the native languages.
  /// [note]: what the owner wants different from the last proposal.
  Future<({AiDesign design, ThemeSpec theme, String headline, String subtitle})> designUi(String brief, Project p, {String note = '', AiDesign? previous}) async {
    final native = p.lang == Lang.flutter || p.lang == Lang.python || p.lang == Lang.kotlin;
    final prompt = """
You are a world-class mobile UI designer and front-end engineer (Dribbble / Apple Design Award level). Design the COMPLETE
interface of this app, unique to its brand and its customers. Not a template: a distinctive, professional, modern look,
with strong typography, considered spacing, depth, shapes and tasteful motion. Arabic, right-to-left.

The app (approved understanding):
$brief

Who it is for: ${p.kind.label} (${p.kind.hint}). Language it is built in: ${p.lang.label}.
Sections (tables) the app shows: ${p.schema.tables.map((t) => '${t.label} (${t.columns.map((c) => c.label).join('، ')})').join(' | ')}
${note.isEmpty ? '' : '\nThe owner saw your previous design and wants: $note\n'}${previous == null || previous.isEmpty ? '' : '\nPrevious design summary: ${previous.summary}\n'}
You restyle a tested app engine. It draws the markup below; you write ONLY CSS and optional JS on top of it (never new HTML):
$designContract

Write these 4 files, each in its own fenced block with the file name after the language:

```json design.json
{"school": base school to start from (${looks.map((l) => l.id).join('|')}), "home": tiles|bento|carousel|feed|chat|focus,
 "list": cards|compact|grid|timeline|reels, "nav": bar|floating|pill, "sheet": sheet|page, "font": cairo|tajawal|plex|readex|messiri|kufi|changa,
 "seed": "#RRGGBB", "accent": "#RRGGBB", "mode": "light|dark", "onboarding": true|false,
 "headline": "big Arabic title of the home", "subtitle": "short Arabic line", "summary": "one Arabic sentence describing the design"}
```
```css design.css
/* every selector starts with :root.ai (e.g. :root.ai .card, :root.ai.light .hero), so it wins over the base school */
```
```js design.js
// window.AlphaDesign = { onRender({screen, root}) { ... } }  (screen: home|list|rows|featured|sheet|login|notes|me)
```
```markdown spec.md
(the design written precisely enough for a developer to rebuild it natively in Flutter / Jetpack Compose / Flet:
palette with hex, typography (font, sizes, weights), radii, shadows, spacing, every screen's layout and components,
the bottom bar, cards, list rows, buttons, inputs, empty states, and the motion with durations and curves)
```

Rules:
- CSS: 6-16 KB. Restyle EVERY part: hero (use .o1/.o2 for shapes, maybe .marq or svg.wave), tiles, featured rail, rows,
  pills, prices, chips, search, buttons, fab, nav, sheet, forms, login, empty states, toast, the .deco background.
  Keep text readable (contrast 4.5:1), keep tap targets ≥ 44px, never hide or disable [data-tab], #add, #compose, .fab,
  .nav, .btn, inputs or the sheet. No @import, no external URLs (only gradients and inline data: SVG). RTL-safe (use
  inset-inline-start/end, margin-inline). Respect @media (prefers-reduced-motion: reduce).
- JS: optional, at most 6 KB, only decoration and motion (entrance animations, stagger, parallax, tilt, typing headline,
  confetti after a save button tap...). Idempotent: mark what you initialised (el.dataset.ai = 1) because onRender runs on
  every screen change. Never change data, never fetch, never remove or move engine elements, wrap risky code in try/catch.
  Only the listed libraries (they exist as globals only if you use them by name).
${native ? '- The spec matters most: the real app is ${p.lang.label} code written from it; the CSS is its instant preview.' : '- The CSS and JS ARE the real app (${p.lang.label}); the spec documents it.'}
""";
    final text = await ask(prompt, json: false, temperature: 0.85, maxTokens: 16000);
    final files = codeFiles(text);
    final css = files['design.css'] ?? files['css'] ?? '';
    if (css.trim().length < 400) throw Exception('لم يكتمل التصميم من الذكاء الاصطناعي، جرّب مرة أخرى');
    Map<String, dynamic> tok = const {};
    try {
      tok = _json(files['design.json'] ?? files['json'] ?? '{}');
    } catch (_) {}
    String? one(Object? v, Map<String, String> ok) => v != null && ok.containsKey('$v') && '$v'.isNotEmpty ? '$v' : null;
    String hex(Object? v, String d) => RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch('$v') ? '$v'.toUpperCase() : d;
    final base = lookById('${tok['school'] ?? ''}') ?? lookById('material')!;
    final theme = base.apply(p.theme).copyWith(
      preset: 'ai',
      seed: hex(tok['seed'], base.seed),
      accent: hex(tok['accent'], base.accent),
      mode: tok['mode'] == 'dark' ? 'dark' : (tok['mode'] == 'light' ? 'light' : base.mode),
      home: one(tok['home'], homeLayouts),
      list: one(tok['list'], listStyles),
      nav: one(tok['nav'], navStyles),
      sheet: one(tok['sheet'], sheetStyles),
      font: one(tok['font'], fontChoices) ?? '',
      onboarding: tok['onboarding'] == true,
    );
    final design = AiDesign(
      css: sanitizeDesignCss(css),
      js: files['design.js'] ?? files['js'] ?? '',
      spec: files['spec.md'] ?? files['markdown'] ?? '',
      summary: '${tok['summary'] ?? ''}',
    );
    return (design: design, theme: theme, headline: '${tok['headline'] ?? ''}', subtitle: '${tok['subtitle'] ?? ''}');
  }

  /// Changing an app that already exists (and may be installed): add, remove or change anything the owner asks.
  /// The AI only proposes; Alpha shows the exact differences and applies them when the owner agrees.
  Future<AiEdit> planEdit(Project p, String request) async {
    final now = jsonEncode({
      'title': p.title,
      'headline': p.headline,
      'subtitle': p.subtitle,
      'kind': p.isPair ? 'pair (customer app + admin app)' : 'single app',
      'language': p.lang.id,
      'backend': p.backend.id,
      'auth': p.auth.id,
      'push': p.push,
      'theme': {
        'school': p.theme.school.isEmpty ? (lookById(p.theme.look)?.id ?? '') : p.theme.school,
        'seed': p.theme.seed, 'accent': p.theme.accent, 'mode': p.theme.mode, 'home': p.theme.home, 'list': p.theme.list,
        'nav': p.theme.nav, 'sheet': p.theme.sheet, 'font': p.theme.font, 'onboarding': p.theme.onboarding,
      },
      'tables': p.schema.toJson(),
    });
    final prompt = """
You are the change engineer of Alpha, an app factory. The app below is already built and INSTALLED on phones; the owner
wants to change it. Do exactly what they ask (add, remove, rename, move, recolor...), and nothing else.
What the app is about:
${p.brief.isEmpty ? p.description : p.brief}

The app now (JSON):
$now

The owner's request (Arabic or English):
$request

Rules:
- Data: if the request touches data (sections/tables, fields/columns, choices, permissions, notifications), return "tables" =
  the COMPLETE new list in exactly the same format as above. Keep every existing table and column name unchanged unless the
  owner asks to remove it (names are database names: renaming = only change "label"). New names: english_snake_case.
  Never columns named id, created_at, updated_at, customer_id. Types: text|longtext|int|decimal|bool|date|datetime|image|phone|email|choice.
  Owners: catalog|customer|public|admin. Notify: admin|customer|owner|none. Icons: ${tableIcons.join(', ')}.
  If data does not change, "tables": null.
- Design: "theme" holds ONLY what changes: school (${looks.map((l) => l.id).join('|')}), seed/accent (#RRGGBB), mode (dark|light|system),
  home (tiles|bento|carousel|feed|chat|focus), list (cards|compact|grid|timeline|reels), nav (bar|floating|pill), sheet (sheet|page),
  font (cairo|tajawal|plex|readex|messiri|kufi|changa|lalezar), onboarding (true|false).
- Texts: title (the name under the icon), headline (big home title), subtitle: only when they change.
- auth (none|email_password|email_code) and push (true|false): only when they change.
- If the request needs something the engine above cannot express (a cart, a map, a custom screen or calculation, a
  special flow, a WhatsApp button...), describe it precisely in "code_request" (it is then written as code on top of the app,
  keeping its data, sign-in and notifications). Otherwise "code_request": "".
- If something is truly unclear, still make the best change and put the question in "questions".
Reply with JSON only:
{"summary": "one Arabic sentence: what will change", "changes": ["short Arabic line per change"],
 "title": null, "headline": null, "subtitle": null, "theme": {}, "tables": null, "auth": null, "push": null,
 "code_request": "", "questions": []}
""";
    return AiEdit.fromJson(request, _json(await ask(prompt)));
  }

  /// Tables and columns for a business, in Alpha's schema format (validated before use).
  Future<DbSchema> designSchema(String description, {required bool pair}) async {
    final prompt = '''
You are the database designer of Alpha. Your ONLY job now is the data (no colors, no code).
You design the database of ${pair ? 'two connected mobile apps (a CUSTOMER app and an ADMIN app)' : 'a mobile app'}.
The approved understanding of the app (Arabic or English):
$description

Reply with JSON only: {"tables": [ ... ]}. Each table:
{"name": "english_snake_case", "label": "Arabic name", "icon": one of ["list","shopping_bag","receipt","star","restaurant","delivery","medical","calendar","event","place","school","campaign","book","chat","person","wallet","checklist","home","car","phone","photo","store","work","payments"],
 "owner": "catalog" (everyone reads, admin writes: products, services, menu) | "customer" (each customer sees only their rows: orders, bookings) | "public" (everyone reads, each edits own: reviews, messages) | "admin" (admin only: expenses, staff),
 "columns": [{"name": "english_snake_case", "label": "Arabic", "type": "text|longtext|int|decimal|bool|date|datetime|image|phone|email|choice", "required": true/false, "options": ["..."] (choice only), "default": "...", "adminOnly": true for fields only the admin sets (like status), "show": true/false (show in lists)}],
 "notify": {"onInsert": "admin|customer|none", "onUpdate": "owner|admin|customer|none"}}
Rules: 2 to 6 tables, 3 to 8 columns each, never columns named id, created_at, updated_at, customer_id.
Orders/bookings: notify admin on insert and the owner on update, with a status choice column that is adminOnly.
''';
    final j = _json(await ask(prompt));
    final schema = DbSchema.fromJson(j['tables'] as List?);
    // Choice columns without options would break the SQL: fix them instead of failing.
    for (final t in schema.tables) {
      for (final c in t.columns) {
        if (c.type == ColumnType.choice && c.options.isEmpty) c.type = ColumnType.text;
      }
      if (t.owner == TableOwner.catalog && t.notifyOnUpdate == NotifyTarget.owner) t.notifyOnUpdate = NotifyTarget.none;
    }
    schema.tables.removeWhere((t) => t.columns.isEmpty);
    return schema;
  }
}

/// What the AI understood from the description (step "الفهم"); the owner edits and approves it.
class Understanding {
  Understanding({
    this.title = '',
    this.slug = '',
    this.summary = '',
    this.kind = ProjectKind.single,
    this.lang = Lang.flutter,
    this.screensCustomer = const [],
    this.screensAdmin = const [],
    this.data = const [],
    this.notifications = const [],
    this.auth = AuthMode.none,
    this.questions = const [],
  });

  String title;
  String slug;
  String summary;
  ProjectKind kind;
  Lang lang;
  List<String> screensCustomer;
  List<String> screensAdmin;
  List<String> data;
  List<String> notifications;
  AuthMode auth;
  List<String> questions;

  static List<String> _list(Object? v) => ((v as List?) ?? const []).map((e) => '$e').where((e) => e.trim().isNotEmpty).toList();

  factory Understanding.fromJson(Map<String, dynamic> j) => Understanding(
        title: '${j['title'] ?? ''}',
        slug: '${j['slug'] ?? ''}',
        summary: '${j['summary'] ?? ''}',
        kind: ProjectKind.parse(j['kind'] as String?),
        lang: Lang.parse('${j['lang']}'),
        screensCustomer: _list(j['screens_customer']),
        screensAdmin: _list(j['screens_admin']),
        data: _list(j['data']),
        notifications: _list(j['notifications']),
        auth: AuthMode.parse('${j['auth']}'),
        questions: _list(j['questions']),
      );

  /// The brief every later step (design, data, code) works from.
  String toBrief() {
    String section(String title, List<String> items) => items.isEmpty ? '' : '$title:\n${items.map((e) => '- $e').join('\n')}\n';
    return [
      if (title.isNotEmpty) 'التطبيق: $title',
      if (summary.isNotEmpty) summary,
      'النوع: ${kind.label} (${kind.hint})',
      section('شاشات العميل', screensCustomer),
      section('شاشات الإدارة', screensAdmin),
      section('البيانات', data),
      section('الإشعارات', notifications),
      'تسجيل الدخول: ${auth.label}',
    ].where((e) => e.isNotEmpty).join('\n');
  }
}
