import 'dart:convert';

import 'package:http/http.dart' as http;

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

  /// Tables and columns for a business, in Alpha's schema format (validated before use).
  Future<DbSchema> designSchema(String description, {required bool pair}) async {
    final prompt = '''
You design the database of ${pair ? 'two connected mobile apps (a CUSTOMER app and an ADMIN app)' : 'a mobile app'}.
Business / app description (Arabic or English):
$description

Reply with JSON only: {"tables": [ ... ]}. Each table:
{"name": "english_snake_case", "label": "Arabic name", "icon": one of ["list","shopping_bag","receipt","star","restaurant","delivery","medical","calendar","event","place","school","campaign","book","chat","person","wallet","checklist","home","car","phone","photo","store","work","payments"],
 "owner": "catalog" (everyone reads, admin writes: products, services, menu) | "customer" (each customer sees only their rows: orders, bookings) | "public" (everyone reads, each edits own: reviews, messages) | "admin" (admin only: expenses, staff),
 "columns": [{"name": "english_snake_case", "label": "Arabic", "type": "text|longtext|int|decimal|bool|date|datetime|image|phone|email|choice", "required": true/false, "options": ["..."] (choice only), "default": "...", "adminOnly": true for fields only the admin sets (like status), "show": true/false (show in lists)}],
 "notify": {"onInsert": "admin|customer|none", "onUpdate": "owner|admin|customer|none"}}
Rules: 2 to 6 tables, 3 to 8 columns each, never columns named id, created_at, updated_at, customer_id.
Orders/bookings: notify admin on insert and the owner on update, with a status choice column that is adminOnly.
''';
    final text = await ask(prompt);
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) throw Exception('الرد لم يكن JSON');
    final j = jsonDecode(text.substring(start, end + 1)) as Map;
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
