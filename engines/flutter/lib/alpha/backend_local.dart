// Data kept on the phone (apps without a server). The owner of the phone has every right.
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'backend.dart';
import 'config.dart';

class LocalBackend extends Backend {
  LocalBackend(super.config);

  late SharedPreferences _prefs;

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (_prefs.getString('alpha_uid') == null) await _prefs.setString('alpha_uid', _id());
  }

  String _id() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  String _key(String table) => 'alpha_rows_$table';

  List<Rec> _read(String table) {
    final raw = _prefs.getString(_key(table));
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<void> _write(String table, List<Rec> rows) => _prefs.setString(_key(table), jsonEncode(rows));

  @override
  bool get signedIn => true;
  @override
  String? get userId => _prefs.getString('alpha_uid');
  @override
  String? get email => null;
  @override
  String? get displayName => _prefs.getString('alpha_name');
  @override
  bool get isAdmin => true;

  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signUp(String name, String email, String password) async => _prefs.setString('alpha_name', name);
  @override
  Future<void> signOut() async {}

  @override
  Future<List<Rec>> list(TableCfg table) async {
    final rows = _read(table.name);
    rows.sort((a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));
    return rows;
  }

  Rec _defaults(TableCfg table) {
    final out = <String, dynamic>{};
    for (final c in table.columns) {
      final d = c.defaultValue;
      if (d == null || d.isEmpty) continue;
      out[c.name] = switch (c.type) {
        'int' => int.tryParse(d),
        'decimal' => double.tryParse(d),
        'bool' => d == 'true',
        'date' => d == 'today' || d == 'now' ? DateTime.now().toIso8601String().substring(0, 10) : d,
        'datetime' => d == 'now' ? DateTime.now().toIso8601String() : d,
        _ => d,
      };
    }
    return out;
  }

  @override
  Future<Rec> insert(TableCfg table, Rec values) async {
    final rows = _read(table.name);
    final now = DateTime.now().toIso8601String();
    final row = <String, dynamic>{
      ..._defaults(table),
      ...clean(table, values),
      'id': _id(),
      'created_at': now,
      'updated_at': now,
      'customer_id': userId,
    };
    rows.add(row);
    await _write(table.name, rows);
    return row;
  }

  @override
  Future<void> update(TableCfg table, String id, Rec values) async {
    final rows = _read(table.name);
    final i = rows.indexWhere((r) => r['id'] == id);
    if (i < 0) throw BackendError('العنصر غير موجود');
    rows[i] = {...rows[i], ...clean(table, values), 'updated_at': DateTime.now().toIso8601String()};
    await _write(table.name, rows);
  }

  @override
  Future<void> delete(TableCfg table, String id) async {
    final rows = _read(table.name)..removeWhere((r) => r['id'] == id);
    await _write(table.name, rows);
  }

  @override
  Future<List<AppNotification>> notifications() async => const [];
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> notify({required String toRole, String? toUser, required String title, required String body}) async {}

  @override
  Future<Map<String, int>> stats() async => {for (final t in config.tables) t.name: _read(t.name).length};

  @override
  Future<void> registerDevice(String token) async {}
}
