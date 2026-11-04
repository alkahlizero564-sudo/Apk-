// Supabase over its REST API (auth, PostgREST, RPC). The database rules (RLS) are made by Alpha's SQL.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'backend.dart';
import 'config.dart';

class SupabaseBackend extends Backend {
  SupabaseBackend(super.config);

  late SharedPreferences _prefs;
  Map<String, dynamic>? _session;
  String _role = 'customer';
  String? _name;

  String get _url => '${config.backend['url'] ?? ''}'.replaceAll(RegExp(r'/+$'), '');
  String get _key => '${config.backend['anonKey'] ?? ''}';
  String get _p => config.prefix;

  Map<String, String> _headers({bool json = true}) => {
        'apikey': _key,
        'Authorization': 'Bearer ${_session?['access_token'] ?? _key}',
        if (json) 'Content-Type': 'application/json',
      };

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (_url.isEmpty || _key.isEmpty) {
      throw BackendError('السيرفر لم يُجهّز بعد. افتح Alpha واضغط «تجهيز قاعدة البيانات» ثم ابنِ التطبيق مرة أخرى.');
    }
    final saved = _prefs.getString('alpha_session');
    if (saved != null) {
      _session = (jsonDecode(saved) as Map).cast<String, dynamic>();
      try {
        await _refreshIfNeeded(force: true);
      } catch (_) {
        _session = null;
        await _prefs.remove('alpha_session');
      }
    }
    if (_session == null && !config.needsAccount) {
      await _anonymous();
    }
    if (_session != null) await _loadProfile();
  }

  Future<void> _anonymous() async {
    final res = await http.post(Uri.parse('$_url/auth/v1/signup'), headers: _headers(), body: '{}');
    if (res.statusCode >= 300) {
      throw BackendError('تعذر فتح حساب للجهاز (${res.statusCode}). فعّل Anonymous sign-ins في Supabase من Alpha.');
    }
    await _saveSession(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> _saveSession(Map<String, dynamic> s) async {
    final expiresIn = (s['expires_in'] as num?)?.toInt() ?? 3600;
    s['expires_at_ms'] = DateTime.now().millisecondsSinceEpoch + expiresIn * 1000;
    _session = s;
    await _prefs.setString('alpha_session', jsonEncode(s));
  }

  Future<void> _refreshIfNeeded({bool force = false}) async {
    final s = _session;
    if (s == null) return;
    final exp = (s['expires_at_ms'] as num?)?.toInt() ?? 0;
    if (!force && exp - DateTime.now().millisecondsSinceEpoch > 60000) return;
    final res = await http.post(Uri.parse('$_url/auth/v1/token?grant_type=refresh_token'),
        headers: {'apikey': _key, 'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': s['refresh_token']}));
    if (res.statusCode >= 300) throw BackendError('انتهت الجلسة، سجّل الدخول مرة أخرى.');
    await _saveSession(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> _loadProfile() async {
    try {
      final rows = await _get('${_p}_profiles?select=role,full_name&id=eq.$userId');
      if (rows.isNotEmpty) {
        _role = '${rows.first['role'] ?? 'customer'}';
        _name = rows.first['full_name'] as String?;
      }
    } catch (_) {
      _role = 'customer';
    }
  }

  String _explain(http.Response res) {
    var msg = res.body;
    try {
      final j = jsonDecode(res.body);
      if (j is Map) msg = '${j['msg'] ?? j['message'] ?? j['error_description'] ?? j['error'] ?? res.body}';
    } catch (_) {}
    final m = msg.toLowerCase();
    if (m.contains('invalid login')) return 'البريد أو كلمة المرور غير صحيحة.';
    if (m.contains('already registered') || m.contains('already been registered')) return 'هذا البريد مسجّل من قبل، سجّل الدخول.';
    if (m.contains('password should be')) return 'كلمة المرور قصيرة (6 أحرف على الأقل).';
    if (m.contains('email not confirmed')) return 'أكّد بريدك أولاً من الرسالة التي وصلتك.';
    if (m.contains('row-level security') || res.statusCode == 403) return 'ليست لديك صلاحية لهذه العملية.';
    if (m.contains('jwt expired')) return 'انتهت الجلسة، أعد المحاولة.';
    return 'خطأ من السيرفر (${res.statusCode}): $msg';
  }

  Future<List<Rec>> _get(String path) async {
    await _refreshIfNeeded();
    final res = await http.get(Uri.parse('$_url/rest/v1/$path'), headers: _headers(json: false));
    if (res.statusCode >= 300) throw BackendError(_explain(res));
    return (jsonDecode(res.body) as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  @override
  bool get signedIn => _session != null;
  @override
  String? get userId => (_session?['user'] as Map?)?['id'] as String?;
  @override
  String? get email {
    final e = (_session?['user'] as Map?)?['email'] as String?;
    return (e == null || e.isEmpty) ? null : e;
  }

  @override
  String? get displayName => _name;

  @override
  bool get isAdmin => config.role != 'customer' && _role == 'admin';

  @override
  Future<void> signIn(String email, String password) async {
    final res = await http.post(Uri.parse('$_url/auth/v1/token?grant_type=password'),
        headers: {'apikey': _key, 'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password}));
    if (res.statusCode >= 300) throw BackendError(_explain(res));
    await _saveSession(jsonDecode(res.body) as Map<String, dynamic>);
    await _loadProfile();
  }

  @override
  Future<void> signUp(String name, String email, String password) async {
    final res = await http.post(Uri.parse('$_url/auth/v1/signup'),
        headers: {'apikey': _key, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'data': {'full_name': name.trim()},
        }));
    if (res.statusCode >= 300) throw BackendError(_explain(res));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['access_token'] == null) {
      // Email confirmation is on in this project: sign in after confirming.
      await signIn(email, password);
      return;
    }
    await _saveSession(body);
    await _loadProfile();
  }

  @override
  Future<void> signOut() async {
    try {
      await http.post(Uri.parse('$_url/auth/v1/logout'), headers: _headers());
    } catch (_) {}
    _session = null;
    _role = 'customer';
    await _prefs.remove('alpha_session');
    if (!config.needsAccount) await _anonymous();
  }

  String _t(TableCfg t) => '${_p}_${t.name}';

  @override
  Future<List<Rec>> list(TableCfg table) async {
    var q = '${_t(table)}?select=*&order=created_at.desc&limit=500';
    // Customers see only their rows of private tables (RLS enforces it too).
    if (table.owner == 'customer' && !isAdmin) q += '&customer_id=eq.$userId';
    return _get(q);
  }

  @override
  Future<Rec> insert(TableCfg table, Rec values) async {
    await _refreshIfNeeded();
    final res = await http.post(Uri.parse('$_url/rest/v1/${_t(table)}'),
        headers: {..._headers(), 'Prefer': 'return=representation'}, body: jsonEncode(clean(table, values)));
    if (res.statusCode >= 300) throw BackendError(_explain(res));
    final rows = jsonDecode(res.body) as List;
    return rows.isEmpty ? <String, dynamic>{} : (rows.first as Map).cast<String, dynamic>();
  }

  @override
  Future<void> update(TableCfg table, String id, Rec values) async {
    await _refreshIfNeeded();
    final res = await http.patch(Uri.parse('$_url/rest/v1/${_t(table)}?id=eq.$id'),
        headers: {..._headers(), 'Prefer': 'return=minimal'}, body: jsonEncode(clean(table, values)));
    if (res.statusCode >= 300) throw BackendError(_explain(res));
  }

  @override
  Future<void> delete(TableCfg table, String id) async {
    await _refreshIfNeeded();
    final res = await http.delete(Uri.parse('$_url/rest/v1/${_t(table)}?id=eq.$id'), headers: _headers());
    if (res.statusCode >= 300) throw BackendError(_explain(res));
  }

  @override
  Future<List<AppNotification>> notifications() async {
    final uid = userId;
    if (uid == null) return [];
    final roles = switch (config.role) { 'customer' => ['customer'], 'admin' => ['admin'], _ => ['customer', if (isAdmin) 'admin'] };
    final or = ['to_user.eq.$uid', ...roles.map((r) => 'to_role.eq.$r')].join(',');
    final rows = await _get('${_p}_notifications?select=*&or=($or)&order=created_at.desc&limit=60');
    final seen = DateTime.tryParse(_prefs.getString('alpha_seen') ?? '') ?? DateTime(2000);
    return rows.map((r) {
      final at = DateTime.tryParse('${r['created_at']}') ?? DateTime.now();
      return AppNotification(
        id: '${r['id']}',
        title: '${r['title'] ?? ''}',
        body: '${r['body'] ?? ''}',
        createdAt: at.toLocal(),
        read: !at.isAfter(seen),
        data: ((r['data'] as Map?) ?? const {}).cast<String, dynamic>(),
      );
    }).toList();
  }

  @override
  Future<void> markRead(String id) => _prefs.setString('alpha_seen', DateTime.now().toUtc().toIso8601String());

  @override
  Future<void> notify({required String toRole, String? toUser, required String title, required String body}) async {
    await _refreshIfNeeded();
    final res = await http.post(Uri.parse('$_url/rest/v1/${_p}_notifications'),
        headers: {..._headers(), 'Prefer': 'return=minimal'},
        body: jsonEncode({
          if (toUser != null) 'to_user': toUser else 'to_role': toRole,
          'title': title,
          'body': body,
          'created_by': userId,
        }));
    if (res.statusCode >= 300) throw BackendError(_explain(res));
  }

  @override
  Future<Map<String, int>> stats() async {
    await _refreshIfNeeded();
    final res = await http.post(Uri.parse('$_url/rest/v1/rpc/${_p}_stats'), headers: _headers(), body: '{}');
    if (res.statusCode >= 300) throw BackendError(_explain(res));
    final j = (jsonDecode(res.body) as Map).cast<String, dynamic>();
    return j.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  @override
  Future<void> registerDevice(String token) async {
    await _refreshIfNeeded();
    await http.post(Uri.parse('$_url/rest/v1/rpc/${_p}_register_device'),
        headers: _headers(), body: jsonEncode({'device_token': token, 'app_name': appRole, 'device_platform': 'android'}));
  }
}
