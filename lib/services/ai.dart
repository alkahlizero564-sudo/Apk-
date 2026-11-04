import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/project.dart';
import '../models/schema.dart';

/// AI on the phone (Claude or Gemini, with the user's own keys): designs a database from a description.
/// Writing app code with AI runs in GitHub Actions (generate.yml), where the build can fix it.
class AiDesigner {
  AiDesigner({required this.claudeKey, required this.geminiKeys});
  final String claudeKey;
  final List<String> geminiKeys;

  bool get available => claudeKey.isNotEmpty || geminiKeys.isNotEmpty;

  Future<String> _claude(String prompt) async {
    final res = await http
        .post(Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {'x-api-key': claudeKey, 'anthropic-version': '2023-06-01', 'content-type': 'application/json'},
            body: jsonEncode({
              'model': 'claude-sonnet-5-5',
              'max_tokens': 8000,
              'messages': [
                {'role': 'user', 'content': prompt}
              ],
            }))
        .timeout(const Duration(minutes: 3));
    if (res.statusCode >= 300) throw Exception('Claude (${res.statusCode}): ${res.body}');
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
    return ((j['content'] as List).where((b) => b['type'] == 'text').map((b) => b['text'])).join();
  }

  Future<String> _gemini(String prompt, String geminiKey) async {
    final res = await http
        .post(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent'),
            headers: {'x-goog-api-key': geminiKey, 'content-type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {'responseMimeType': 'application/json', 'temperature': 0.3},
            }))
        .timeout(const Duration(minutes: 3));
    if (res.statusCode >= 300) throw Exception('Gemini (${res.statusCode}): ${res.body}');
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
    return ((j['candidates'] as List).first['content']['parts'] as List).map((p) => p['text']).join();
  }

  Future<String> ask(String prompt) async {
    Object? last;
    if (claudeKey.isNotEmpty) {
      try {
        return await _claude(prompt);
      } catch (e) {
        last = e;
      }
    }
    // Each Gemini key in turn: a key out of quota does not stop the work.
    for (final key in geminiKeys) {
      try {
        return await _gemini(prompt, key);
      } catch (e) {
        last = e;
      }
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

Pick colors that fit the business and its customers (premium, modern, good contrast). Reply with JSON only:
{"seed": "#RRGGBB" (main color), "accent": "#RRGGBB" (second color of the gradient), "mode": "dark|light",
 "style": "glass|soft|flat", "radius": 8-28, "headline": "big Arabic title of the home screen",
 "subtitle": "short Arabic line under it", "reason": "one Arabic sentence: why this look"}
""";
    final j = _json(await ask(prompt));
    String hex(Object? v, String d) => RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch('$v') ? '$v'.toUpperCase() : d;
    final theme = ThemeSpec(
      preset: 'ai',
      seed: hex(j['seed'], '#6E4BFF'),
      accent: hex(j['accent'], '#2DD4BF'),
      mode: j['mode'] == 'light' ? 'light' : 'dark',
      style: ['glass', 'soft', 'flat'].contains(j['style']) ? '${j['style']}' : 'glass',
      radius: ((j['radius'] as num?)?.toDouble() ?? 18).clamp(4, 32),
    );
    return (theme: theme, headline: '${j['headline'] ?? ''}', subtitle: '${j['subtitle'] ?? ''}', reason: '${j['reason'] ?? ''}');
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
        kind: j['kind'] == 'pair' ? ProjectKind.pair : ProjectKind.single,
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
      kind == ProjectKind.pair ? 'النوع: تطبيقان متصلان (عميل + إدارة)' : 'النوع: تطبيق واحد',
      section('شاشات العميل', screensCustomer),
      section('شاشات الإدارة', screensAdmin),
      section('البيانات', data),
      section('الإشعارات', notifications),
      'تسجيل الدخول: ${auth.label}',
    ].where((e) => e.isNotEmpty).join('\n');
  }
}
