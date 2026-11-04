import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/project.dart';

/// Keys and tokens stay in the phone's encrypted storage; projects in normal storage.
class Storage {
  static const _secure = FlutterSecureStorage();

  static const githubToken = 'github_token';
  static const claudeKey = 'claude_key';
  static const geminiKey = 'gemini_key';

  /// Up to four Gemini keys (phone storage name, repository secret name): when one runs out, the next is used.
  static const geminiKeys = [
    (local: 'gemini_key', secret: 'GEMINI_API_KEY'),
    (local: 'gemini_key_2', secret: 'GEMINI_API_KEY_2'),
    (local: 'gemini_key_3', secret: 'GEMINI_API_KEY_3'),
    (local: 'gemini_key_4', secret: 'GEMINI_API_KEY_4'),
  ];

  static Future<List<String>> geminiKeyValues() async =>
      [for (final k in geminiKeys) await secret(k.local)].where((v) => v.isNotEmpty).toList();
  static const supabaseToken = 'supabase_token';
  static const firebaseServiceAccount = 'firebase_sa';

  static Future<String> secret(String name) async {
    try {
      return await _secure.read(key: name) ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> setSecret(String name, String value) async {
    if (value.trim().isEmpty) {
      await _secure.delete(key: name);
    } else {
      await _secure.write(key: name, value: value.trim());
    }
  }

  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static Future<String> get(String key, [String fallback = '']) async => (await _prefs).getString(key) ?? fallback;

  static Future<void> set(String key, String value) async => (await _prefs).setString(key, value);

  static Future<List<Project>> projects() async {
    final raw = (await _prefs).getString('projects');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => Project.fromJson((e as Map).cast<String, dynamic>())).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveProjects(List<Project> list) async =>
      (await _prefs).setString('projects', jsonEncode(list.map((p) => p.toJson()).toList()));
}
