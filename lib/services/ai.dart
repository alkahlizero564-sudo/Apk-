import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Models tried in turn when one is not available or busy (like APK Fact).
  static const claudeModels = ['claude-sonnet-5-5', 'claude-opus-5-5', 'claude-haiku-5-5'];
  static const geminiFallbacks = ['gemini-3.8-flash', 'gemini-3.5-flash', 'gemini-3.5-flash-lite'];

  Future<String> _claude(String model, String prompt, {int maxTokens = 8000}) async {
    final res = await http
        .post(Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {'x-api-key': claudeKey, 'anthropic-version': '2023-06-01', 'content-type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'max_tokens': maxTokens,
              'messages': [
                {'role': 'user', 'content': prompt}
              ],
            }))
        .timeout(const Duration(minutes: 6));
    if (res.statusCode >= 300) throw AiCallError('Claude', res.statusCode, res.body);
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
    final text = ((j['content'] as List).where((b) => b['type'] == 'text').map((b) => b['text'])).join();
    if (text.trim().isEmpty) throw AiCallError('Claude', 0, 'empty answer');
    return text;
  }

  Future<String> _gemini(String model, String prompt, String geminiKey, {bool json = true, double temperature = 0.3}) async {
    final res = await http
        .post(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'),
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
        .timeout(const Duration(minutes: 6));
    if (res.statusCode >= 300) throw AiCallError('Gemini', res.statusCode, res.body);
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
    final cands = (j['candidates'] as List?) ?? const [];
    final parts = cands.isEmpty ? const [] : (((cands.first as Map)['content'] as Map?)?['parts'] as List?) ?? const [];
    final text = parts.map((p) => '${(p as Map)['text'] ?? ''}').join();
    if (text.trim().isEmpty) throw AiCallError('Gemini', 0, 'empty answer (${cands.isEmpty ? 'blocked' : (cands.first as Map)['finishReason']})');
    return text;
  }

  /// Asks the AI. Every model and every key is tried in turn (a busy model, a key out of quota or a model that
  /// is not available does not stop the work), then everything once more after a short wait.
  /// [json]: the answer is JSON (default); otherwise free text such as fenced code files.
  Future<String> ask(String prompt, {bool json = true, double temperature = 0.3, int maxTokens = 8000}) async {
    if (!available) throw Exception('أضف مفتاح Claude أو Gemini في الإعدادات.');
    AiCallError? last;
    final gModels = [geminiModel, ...geminiFallbacks.where((m) => m != geminiModel)];
    Future<String?> tryClaude() async {
      if (claudeKey.isEmpty) return null;
      for (final m in claudeModels) {
        try {
          return await _claude(m, prompt, maxTokens: maxTokens);
        } on AiCallError catch (e) {
          last = e;
          if (e.badKey) return null; // a wrong key: the other provider
        } catch (e) {
          last = AiCallError('Claude', 0, '$e');
        }
      }
      return null;
    }

    Future<String?> tryGemini() async {
      for (final m in gModels) {
        for (final key in geminiKeys) {
          try {
            return await _gemini(m, prompt, key, json: json, temperature: temperature);
          } on AiCallError catch (e) {
            last = e;
            if (e.status == 404) break; // this model is not available: the next model
          } catch (e) {
            last = AiCallError('Gemini', 0, '$e');
          }
        }
      }
      return null;
    }

    final order = geminiFirst ? [tryGemini, tryClaude] : [tryClaude, tryGemini];
    for (var round = 0; round < 2; round++) {
      for (final attempt in order) {
        final text = await attempt();
        if (text != null) return text;
      }
      if (round == 0) await Future<void>.delayed(const Duration(seconds: 4));
    }
    throw Exception(last?.arabic ?? 'لم يرد الذكاء الاصطناعي، حاول بعد قليل.');
  }



  Map<String, dynamic> _json(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) throw Exception('الرد لم يكن JSON');
    return (jsonDecode(text.substring(start, end + 1)) as Map).cast<String, dynamic>();
  }

  // ---------- understanding (like APK Fact) ----------

  static const _analyst = """You are a senior product manager. The owner describes a mobile app idea in their own words, often
briefly. Your job is to understand EXACTLY what they have in mind, not to invent a different app.
- Keep their idea, domain, names, texts, numbers, prices, currencies, colors and language exactly as they wrote them.
- Turn it into a clear, complete list of requirements a developer can build and check one by one.
- Where the idea is short, fill the gaps with what such an app normally needs, but stay inside their idea.
- If they pasted code, understand what that code does: the requirements describe THAT app.
- Ask ONLY about things that really change the app and that you cannot reasonably decide yourself (0 to 5 questions).
  Each question gets 2 to 4 short ready answers (the most likely first).
- Write everything in the owner's language (Arabic when they wrote Arabic, in the same dialect style), short and simple,
  no technical words.""";

  static const _pairLine = 'This is a SYSTEM of two connected apps sharing one online database: a CUSTOMER app (the people who use the '
      'service) and an ADMIN app (the business that manages everything). Start every screen, feature and data item with '
      '«الزبون: », «الإدارة: » or «الاثنين: » to say which app it belongs to, and cover both apps fully.';

  static const _specFormat = """Reply with JSON only, no markdown:
{"title": "short app name in the owner's words", "slug": "short english id, lowercase and dashes",
 "summary": "one or two sentences: what the app is and who uses it",
 "screens": ["each screen and what is on it"],
 "features": ["each feature or behavior, one short checkable sentence"],
 "data": ["what the app saves, with its fields"],
 "texts": ["exact names, texts, prices, numbers or colors the owner mentioned"],
 "notifications": ["when → who is notified (only if the app needs it)"],
 "kind": "single" or "pair" (pair only when the idea needs a customer app AND a business/admin app),
 "lang": "flutter|html|php|python|kotlin" (the language of pasted code; otherwise the best fit),
 "auth": "none" | "email_password" | "email_code" (only what the owner's words ask for; none when they did not ask),
 "questions": [{"q": "question", "options": ["answer 1", "answer 2"]}]}""";

  /// Step "الفهم": the idea (even one line) or pasted code becomes a checklist of requirements + short questions.
  Future<Understanding> understand(String description, {String code = '', ProjectKind? kind, Lang? lang}) async {
    final prompt = '$_analyst\n${kind == ProjectKind.pair ? '$_pairLine\n' : ''}'
        '${lang == null ? '' : 'It will be built as ${_platform[lang]}.\n'}\n'
        "THE OWNER'S IDEA (their exact words, the highest priority):\n$description\n"
        '${code.trim().isEmpty ? '' : '\nTHE CODE THEY PASTED (build this app):\n```\n${code.length > 15000 ? code.substring(0, 15000) : code}\n```\n'}'
        '\n$_specFormat';
    return Understanding.fromJson(_json(await ask(prompt)));
  }

  /// The owner removed items, answered questions and wrote corrections: the full updated list.
  Future<Understanding> refine(String description, Understanding u, {required List<(String, String)> answers, String notes = '', ProjectKind? kind}) async {
    final current = u.toJson()..remove('questions');
    var prompt = '$_analyst\n${kind == ProjectKind.pair ? '$_pairLine\n' : ''}\n'
        "THE OWNER'S IDEA (their exact words):\n$description\n\n"
        "YOUR CURRENT LIST (the owner already removed what they don't want; do not add those back):\n${const JsonEncoder.withIndent(' ').convert(current)}\n";
    if (answers.isNotEmpty) prompt += "\nTHE OWNER'S ANSWERS (apply each one to the list):\n${answers.map((x) => '- ${x.$1} → ${x.$2}').join('\n')}\n";
    if (notes.trim().isNotEmpty) prompt += "\nTHE OWNER'S CORRECTIONS AND ADDITIONS (apply exactly):\n${notes.trim()}\n";
    prompt += '\nReturn the full updated list in the same JSON format. Ask new questions only if something important is still '
        'unclear (usually none). Do not ask again what was answered.\n$_specFormat';
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

  /// «معاينة فورية قبل الإنشاء» (like APK Fact): straight from the description, one HTML file that IS the app (HTML,
  /// PHP) or a faithful interactive imitation of it (Flutter / Kotlin / Python, Material 3). Cached per description.
  Future<String> instantPreview(Lang lang, String description, {bool fresh = false}) async {
    final key = 'ip_${lang.id}_${description.hashCode}';
    final prefs = await SharedPreferences.getInstance();
    if (!fresh) {
      final hit = prefs.getString(key);
      if (hit != null && hit.isNotEmpty) return hit;
    }
    final what = switch (lang) {
      Lang.html || Lang.php => 'Build the app itself as ONE complete, self-contained HTML file (inline CSS and JS).',
      _ => 'Build an interactive PREVIEW of a ${switch (lang) { Lang.flutter => 'Flutter (Material 3)', Lang.kotlin => 'native Android Kotlin Jetpack Compose (Material 3)', _ => 'Python Flet (Material 3)' }} '
          'mobile app as ONE self-contained HTML file (inline CSS and JS) that looks and behaves like that native app: '
          'Material 3 components, app bar, bottom navigation, cards, FAB, ripple-like pressed states.',
    };
    final prompt = 'You are an expert mobile app designer and front-end developer. $what '
        'Mobile-first full-height layout, no external resources (inline SVG or emoji icons), working navigation, '
        'buttons, forms and lists with realistic sample data, localStorage for state. RTL Arabic when the request is Arabic.\n\n'
        '${await designBrief()}\nReply with ONLY the file inside a single ```html code block.\n\nApp description:\n$description';
    final html = _extractHtml(await ask(prompt, json: false, temperature: 0.5, maxTokens: 32000));
    await prefs.setString(key, html);
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
      prompt = '$system\n\n$base\nWhat the app is and does (the owner\'s own words first, then the checklist they approved; build EXACTLY this app, every item):\n${forApp(p.brief.isEmpty ? p.description : p.brief, p.isPair ? app.role : '')}\n\n${_appFacts(p)}\n'
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
Every data item in the approved checklist must have its table and fields, with the owner's own names; nothing that the idea does not need.
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
/// What the AI understood: a checklist the owner edits item by item (like APK Fact), plus a few suggestions.
class Understanding {
  Understanding({
    this.title = '',
    this.slug = '',
    this.summary = '',
    this.kind = ProjectKind.single,
    this.lang = Lang.flutter,
    List<String>? screens,
    List<String>? features,
    List<String>? data,
    List<String>? texts,
    List<String>? notifications,
    this.auth = AuthMode.none,
    List<UQuestion>? questions,
  })  : screens = screens ?? [],
        features = features ?? [],
        data = data ?? [],
        texts = texts ?? [],
        notifications = notifications ?? [],
        questions = questions ?? [];

  String title;
  String slug;
  String summary;
  ProjectKind kind;
  Lang lang;
  List<String> screens;
  List<String> features;
  List<String> data;
  List<String> texts;
  List<String> notifications;
  AuthMode auth;
  List<UQuestion> questions;

  static const sections = {
    'screens': 'الشاشات',
    'features': 'الميزات والوظائف',
    'data': 'البيانات التي يحفظها التطبيق',
    'texts': 'الأسماء والنصوص والأرقام والألوان',
    'notifications': 'الإشعارات',
  };

  List<String> list(String key) => switch (key) {
        'screens' => screens,
        'features' => features,
        'data' => data,
        'texts' => texts,
        _ => notifications,
      };

  static List<String> _list(Object? v) => ((v as List?) ?? const []).map((e) => '$e'.trim()).where((e) => e.isNotEmpty).take(40).toList();

  factory Understanding.fromJson(Map<String, dynamic> j) {
    final u = Understanding(
      title: '${j['title'] ?? ''}',
      slug: '${j['slug'] ?? ''}',
      summary: '${j['summary'] ?? ''}',
      kind: ProjectKind.parse(j['kind'] as String?),
      lang: Lang.parse('${j['lang']}'),
      screens: _list(j['screens'] ?? [..._list(j['screens_customer']), ..._list(j['screens_admin'])]),
      features: _list(j['features']),
      data: _list(j['data']),
      texts: _list(j['texts']),
      notifications: _list(j['notifications']),
      auth: AuthMode.parse('${j['auth']}'),
      questions: ((j['questions'] as List?) ?? const [])
          .map((q) => q is Map ? UQuestion('${q['q'] ?? ''}'.trim(), _list(q['options']).take(4).toList()) : UQuestion('$q'.trim(), const []))
          .where((q) => q.q.isNotEmpty)
          .take(5)
          .toList(),
    );
    if (u.summary.isEmpty && u.screens.isEmpty && u.features.isEmpty) throw Exception('لم يصل فهم الفكرة كاملاً، حاول مرة أخرى');
    return u;
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'slug': slug,
        'summary': summary,
        'screens': screens,
        'features': features,
        'data': data,
        'texts': texts,
        'notifications': notifications,
        'kind': kind.name,
        'lang': lang.id,
        'auth': auth.id,
        'questions': [for (final q in questions) {'q': q.q, 'options': q.options}],
      };

  /// The approved list as text (APK Fact's «المواصفات» block): the design, the data, the code and the request check
  /// after generation follow it item by item.
  String specText() {
    final out = ['=== المواصفات التي وافق عليها صاحب التطبيق (نفّذها كلها بنداً بنداً، ولا تبنِ تطبيقاً مختلفاً) ==='];
    if (summary.isNotEmpty) out.add('الفكرة: $summary');
    for (final e in sections.entries) {
      final items = list(e.key);
      if (items.isNotEmpty) out.addAll(['${e.value}:', ...items.map((x) => '- $x')]);
    }
    return out.join('\n');
  }

  /// What every later step works from: the owner's exact words first, then the approved list.
  String toBrief(String ownerWords) => [
        '=== فكرة صاحب التطبيق بكلماته (الأولوية الأعلى) ===',
        ownerWords.trim(),
        '',
        specText(),
      ].join('\n');
}

class UQuestion {
  UQuestion(this.q, this.options);
  final String q;
  final List<String> options;
}

/// For one app of a pair: its own items («الزبون:» / «الإدارة:») and the shared ones («الاثنين:»).
String forApp(String text, String role) {
  final other = role == 'customer' ? 'الإدارة' : role == 'admin' ? 'الزبون' : '';
  if (other.isEmpty) return text;
  final drop = RegExp('^\\s*-\\s*«?\\s*$other\\s*(:\\s*»|»\\s*:|:)');
  return text.split('\n').where((l) => !drop.hasMatch(l)).join('\n');
}

/// A failed AI call, with a clear Arabic reason for the owner.
class AiCallError implements Exception {
  AiCallError(this.provider, this.status, this.body);
  final String provider;
  final int status;
  final String body;

  bool get badKey => status == 401 || status == 403;

  String get arabic => switch (status) {
        401 || 403 => 'مفتاح $provider غير صحيح أو لا يملك صلاحية. راجعه في الإعدادات.',
        404 => 'نموذج $provider غير متاح لهذا المفتاح. اختر نموذجاً آخر في الإعدادات.',
        429 => 'انتهت حصة مفتاح $provider مؤقتاً. أضف مفتاحاً آخر أو انتظر قليلاً.',
        0 => 'لم يصل رد من $provider ($body). تأكد من الإنترنت وحاول مرة أخرى.',
        _ when status >= 500 => 'خدمة $provider مزدحمة الآن. حاول بعد دقيقة.',
        _ => '$provider ($status): ${body.length > 300 ? body.substring(0, 300) : body}',
      };

  @override
  String toString() => arabic;
}
