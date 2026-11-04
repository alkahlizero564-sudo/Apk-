// Code the owner pastes: which language it is, where it goes in the app, and which packages it needs.
import 'dart:convert';

import '../models/project.dart';

/// The language of a pasted piece of code, or null when it is not clear.
Lang? detectLang(String code) {
  final c = code.trimLeft();
  if (c.isEmpty) return null;
  if (c.contains("package:flutter/") || RegExp(r'\bvoid\s+main\s*\(').hasMatch(c) && c.contains('runApp(')) return Lang.flutter;
  if (c.startsWith('<?php') || c.contains('<?php')) return Lang.php;
  if (RegExp(r'^\s*(import\s+flet|from\s+flet)', multiLine: true).hasMatch(c)) return Lang.python;
  if (RegExp(r'^\s*(package\s+[\w.]+|import\s+androidx\.)', multiLine: true).hasMatch(c) && c.contains('fun ')) return Lang.kotlin;
  if (RegExp(r'<!doctype html|<html|<body', caseSensitive: false).hasMatch(c)) return Lang.html;
  if (RegExp(r'^\s*(def |import |from \w+ import)', multiLine: true).hasMatch(c)) return Lang.python;
  return null;
}

/// The file of the app's custom/ folder the pasted code replaces (the main file of the language).
String customPath(Lang lang) => switch (lang) {
      Lang.flutter => 'lib/main.dart',
      Lang.html => 'index.html',
      Lang.php => 'index.php',
      Lang.python => 'main.py',
      Lang.kotlin => 'MainActivity.kt',
    };

/// Files to commit for pasted code: the code itself, plus the packages it imports (from the checked list)
/// for Flutter (custom/packages.txt) and Python (custom/requirements.txt).
Map<String, String> customFiles(String slug, Lang lang, String code, Map<String, dynamic> libraries) {
  final files = <String, String>{'apps/$slug/custom/${customPath(lang)}': code.endsWith('\n') ? code : '$code\n'};
  final allowed = ((libraries[lang.id] as Map?)?['packages'] as List? ?? const []).map((p) => '${(p as Map)['name']}').toSet();
  if (lang == Lang.flutter) {
    final used = RegExp(r'''import\s+['"]package:([a-z0-9_]+)/''').allMatches(code).map((m) => m.group(1)!).toSet()
      ..removeWhere((p) => p == 'flutter' || p == 'app');
    final pkgs = used.where(allowed.contains).toList()..sort();
    if (pkgs.isNotEmpty) files['apps/$slug/custom/packages.txt'] = '${pkgs.join('\n')}\n';
  }
  if (lang == Lang.python) {
    final used = RegExp(r'^\s*(?:import|from)\s+([a-zA-Z0-9_]+)', multiLine: true).allMatches(code).map((m) => m.group(1)!.toLowerCase());
    final map = {'requests': 'requests', 'dateutil': 'python-dateutil', 'pytz': 'pytz', 'arrow': 'arrow', 'humanize': 'humanize', 'markdown': 'markdown'};
    final reqs = {'flet==1.0.5', for (final u in used) if (map[u] != null && allowed.contains(map[u])) map[u]!};
    files['apps/$slug/custom/requirements.txt'] = '${reqs.join('\n')}\n';
  }
  return files;
}

/// libraries.json as a map (helper for callers that loaded the asset text).
Map<String, dynamic> parseLibraries(String text) => (jsonDecode(text) as Map).cast<String, dynamic>();
