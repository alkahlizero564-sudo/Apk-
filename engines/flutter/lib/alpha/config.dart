// The app's description made in Alpha (apps/<app>/alpha.json), read once at start-up.
import 'dart:convert';

import 'package:flutter/material.dart';

import 'config_data.dart';

class ColumnCfg {
  ColumnCfg(Map<String, dynamic> j)
      : name = '${j['name']}',
        label = '${j['label'] ?? j['name']}',
        type = '${j['type'] ?? 'text'}',
        required = j['required'] == true,
        options = ((j['options'] as List?) ?? const []).map((e) => '$e').toList(),
        defaultValue = j['default']?.toString(),
        show = j['show'] != false,
        adminOnly = j['adminOnly'] == true;

  final String name;
  final String label;
  final String type;
  final bool required;
  final List<String> options;
  final String? defaultValue;
  final bool show;
  final bool adminOnly;

  bool get isNumber => type == 'int' || type == 'decimal';
}

class TableCfg {
  TableCfg(Map<String, dynamic> j)
      : name = '${j['name']}',
        label = '${j['label'] ?? j['name']}',
        icon = '${j['icon'] ?? 'list'}',
        owner = '${j['owner'] ?? 'customer'}',
        columns = ((j['columns'] as List?) ?? const [])
            .map((c) => ColumnCfg((c as Map).cast<String, dynamic>()))
            .toList(),
        notifyOnInsert = '${((j['notify'] as Map?) ?? const {})['onInsert'] ?? 'none'}',
        notifyOnUpdate = '${((j['notify'] as Map?) ?? const {})['onUpdate'] ?? 'none'}';

  final String name;
  final String label;
  final String icon;
  final String owner; // catalog | customer | public | admin
  final List<ColumnCfg> columns;
  final String notifyOnInsert;
  final String notifyOnUpdate;

  bool get hasOwner => owner == 'customer' || owner == 'public';

  ColumnCfg? get titleColumn {
    for (final c in columns) {
      if (c.type == 'text' || c.type == 'choice') return c;
    }
    return columns.isEmpty ? null : columns.first;
  }

  ColumnCfg? get imageColumn {
    for (final c in columns) {
      if (c.type == 'image') return c;
    }
    return null;
  }

  ColumnCfg? get badgeColumn {
    for (final c in columns) {
      if (c.type == 'choice' && c.adminOnly) return c;
    }
    for (final c in columns) {
      if (c.type == 'choice') return c;
    }
    return null;
  }

  ColumnCfg? get priceColumn {
    for (final c in columns) {
      if (c.type == 'decimal') return c;
    }
    return null;
  }

  /// Can the user of this app add rows?
  bool canAdd(bool admin) => admin || owner == 'customer' || owner == 'public';

  bool canEdit(bool admin, bool mine) => admin || ((owner == 'customer' || owner == 'public') && mine);
}

class AlphaConfig {
  AlphaConfig(Map<String, dynamic> j)
      : raw = j,
        title = '${(j['app'] as Map?)?['title'] ?? 'Alpha'}',
        slug = '${(j['app'] as Map?)?['slug'] ?? 'app'}',
        role = '${(j['app'] as Map?)?['role'] ?? 'single'}',
        rtl = (j['app'] as Map?)?['rtl'] != false,
        headline = '${(j['app'] as Map?)?['headline'] ?? ''}',
        subtitle = '${(j['app'] as Map?)?['subtitle'] ?? ''}',
        theme = ((j['theme'] as Map?) ?? const {}).cast<String, dynamic>(),
        backend = ((j['backend'] as Map?) ?? const {}).cast<String, dynamic>(),
        tables = ((j['tables'] as List?) ?? const [])
            .map((t) => TableCfg((t as Map).cast<String, dynamic>()))
            .toList();

  static final AlphaConfig instance = AlphaConfig((jsonDecode(alphaConfigJson) as Map).cast<String, dynamic>());

  final Map<String, dynamic> raw;
  final String title;
  final String slug;
  final String role; // single | customer | admin
  final bool rtl;
  final String headline;
  final String subtitle;
  final Map<String, dynamic> theme;
  final Map<String, dynamic> backend;
  final List<TableCfg> tables;

  String get backendType => '${backend['type'] ?? 'none'}';
  String get prefix => '${backend['prefix'] ?? slug.replaceAll('-', '_')}';
  String get auth => '${backend['auth'] ?? 'none'}';
  bool get push => backend['push'] == true;
  bool get needsAccount => auth == 'email_password' || auth == 'email_code';

  /// Sign-up is confirmed with a 6-digit code sent to the email (a link with Firebase).
  bool get emailCode => auth == 'email_code';
  Map<String, dynamic> get firebase => ((backend['firebase'] as Map?) ?? const {}).cast<String, dynamic>();

  /// Tables this app shows: the customer app hides admin-only tables.
  List<TableCfg> visibleTables(bool admin) =>
      tables.where((t) => t.owner != 'admin' || admin || role == 'admin').toList();

  Color get seed => parseColor('${theme['seed'] ?? '#6E4BFF'}', const Color(0xFF6E4BFF));
  Color get accent => parseColor('${theme['accent'] ?? '#2DD4BF'}', const Color(0xFF2DD4BF));
  String get style => '${theme['style'] ?? 'glass'}';

  // Design tokens chosen in Alpha (a "look" sets them all).
  String get hero => '${theme['hero'] ?? 'blob'}';
  String get listStyle => '${theme['list'] ?? 'cards'}';
  String get navStyle => '${theme['nav'] ?? 'floating'}';
  String get deco => '${theme['deco'] ?? 'none'}';
  bool get lightTitles => theme['type'] == 'light';
  double get radius => (theme['radius'] as num?)?.toDouble() ?? 18;
  ThemeMode get themeMode => switch ('${theme['mode']}') {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };
}

Color parseColor(String hex, Color fallback) {
  final h = hex.replaceAll('#', '').trim();
  final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return v == null ? fallback : Color(v);
}
