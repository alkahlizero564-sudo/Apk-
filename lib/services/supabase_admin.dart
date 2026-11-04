import 'dart:convert';

import 'package:http/http.dart' as http;

class SupabaseProject {
  SupabaseProject(Map<String, dynamic> j)
      : ref = '${j['id'] ?? j['ref'] ?? ''}',
        name = '${j['name'] ?? ''}',
        region = '${j['region'] ?? ''}',
        status = '${j['status'] ?? ''}';
  final String ref;
  final String name;
  final String region;
  final String status;
}

/// Supabase Management API from the phone: run Alpha's SQL right away and read the project's keys.
class SupabaseAdmin {
  SupabaseAdmin(this.token);
  final String token;

  static const _api = 'https://api.supabase.com/v1';

  Future<dynamic> _req(String method, String path, [Object? body]) async {
    final req = http.Request(method, Uri.parse('$_api$path'))
      ..headers.addAll({'Authorization': 'Bearer $token', 'Content-Type': 'application/json'});
    if (body != null) req.body = jsonEncode(body);
    final res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 90)));
    if (res.statusCode >= 300) {
      var msg = res.body;
      try {
        final j = jsonDecode(res.body);
        if (j is Map) msg = '${j['message'] ?? j['error'] ?? res.body}';
      } catch (_) {}
      throw Exception(res.statusCode == 401 ? 'توكن Supabase غير صحيح.' : 'Supabase (${res.statusCode}): $msg');
    }
    return res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<List<SupabaseProject>> projects() async =>
      ((await _req('GET', '/projects')) as List).map((e) => SupabaseProject((e as Map).cast<String, dynamic>())).toList();

  /// Runs SQL; returns the rows of the last statement (if any).
  Future<List<Map<String, dynamic>>> sql(String ref, String query) async {
    final j = await _req('POST', '/projects/$ref/database/query', {'query': query});
    if (j is List) return j.map((e) => (e as Map).cast<String, dynamic>()).toList();
    return [];
  }

  Future<String?> anonKey(String ref) async {
    final keys = (await _req('GET', '/projects/$ref/api-keys')) as List;
    for (final k in keys) {
      if (k['name'] == 'anon' && k['api_key'] != null) return '${k['api_key']}';
    }
    for (final k in keys) {
      if (k['type'] == 'publishable' && k['api_key'] != null) return '${k['api_key']}';
    }
    return null;
  }

  /// Sign-in settings the generated apps need (accounts made without email confirmation; anonymous if asked).
  /// [mode]: none (anonymous accounts), email_password, or email_code (a 6-digit code confirms the email).
  Future<void> configureAuth(String ref, {required String mode}) => _req('PATCH', '/projects/$ref/config/auth', {
        'mailer_autoconfirm': mode != 'email_code',
        'external_email_enabled': true,
        if (mode == 'none') 'external_anonymous_users_enabled': true,
        if (mode == 'email_code') ...{
          'mailer_otp_length': 6,
          'mailer_otp_exp': 900,
          'mailer_subjects_confirmation': 'رمز تأكيد حسابك',
          'mailer_templates_confirmation_content':
              '<div dir="rtl" style="font-family:Tahoma,Arial,sans-serif;text-align:center;padding:24px"><h2>رمز تأكيد حسابك</h2>'
                  '<p>أدخل هذا الرمز في التطبيق لتأكيد بريدك:</p><p style="font-size:34px;letter-spacing:8px;font-weight:bold">{{ .Token }}</p>'
                  '<p style="color:#888">الرمز صالح لمدة 15 دقيقة.</p></div>',
        },
      });
}
