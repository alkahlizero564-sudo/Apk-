// Firebase: Auth + Cloud Firestore. The security rules come from Alpha (firestore.rules of the project).
// Firestore has no database triggers, so the app itself writes the notifications the design asks for.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend.dart';
import 'config.dart';
import 'firebase_boot.dart';

class FirestoreBackend extends Backend {
  FirestoreBackend(super.config);

  late SharedPreferences _prefs;
  late FirebaseFirestore _db;
  late FirebaseAuth _auth;
  String _role = 'customer';
  String? _name;

  String get _p => config.prefix;
  CollectionReference<Map<String, dynamic>> _c(String name) => _db.collection('${_p}_$name');

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await bootFirebase(config);
    _db = FirebaseFirestore.instance;
    _auth = FirebaseAuth.instance;
    if (_auth.currentUser == null && !config.needsAccount) {
      await _auth.signInAnonymously();
    }
    if (_auth.currentUser != null) await _loadProfile();
  }

  Future<void> _loadProfile() async {
    final u = _auth.currentUser!;
    final ref = _c('profiles').doc(u.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'email': u.email,
        'full_name': u.displayName,
        'role': 'customer',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    final data = (await ref.get()).data() ?? const {};
    _role = '${data['role'] ?? 'customer'}';
    _name = data['full_name'] as String?;
    final mail = (u.email ?? '').toLowerCase();
    if (mail.isNotEmpty && _role != 'admin') {
      try {
        if ((await _c('admins').doc(mail).get()).exists) _role = 'admin';
      } catch (_) {}
    }
  }

  String _explain(Object e) {
    if (e is FirebaseAuthException) {
      return switch (e.code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' => 'البريد أو كلمة المرور غير صحيحة.',
        'email-already-in-use' => 'هذا البريد مسجّل من قبل، سجّل الدخول.',
        'weak-password' => 'كلمة المرور ضعيفة (6 أحرف على الأقل).',
        'invalid-email' => 'البريد غير صحيح.',
        'network-request-failed' => 'لا يوجد اتصال بالإنترنت.',
        _ => e.message ?? e.code,
      };
    }
    if (e is FirebaseException && e.code == 'permission-denied') return 'ليست لديك صلاحية لهذه العملية.';
    return '$e';
  }

  Future<T> _wrap<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      throw BackendError(_explain(e));
    }
  }

  @override
  bool get signedIn => _auth.currentUser != null;
  @override
  String? get userId => _auth.currentUser?.uid;
  @override
  String? get email => _auth.currentUser?.email;
  @override
  String? get displayName => _name ?? _auth.currentUser?.displayName;
  @override
  bool get isAdmin => config.role != 'customer' && _role == 'admin';

  @override
  Future<void> signIn(String email, String password) => _wrap(() async {
        await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
        await _loadProfile();
      });

  @override
  Future<void> signUp(String name, String email, String password) => _wrap(() async {
        final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
        await cred.user?.updateDisplayName(name.trim());
        await _c('profiles').doc(cred.user!.uid).set({
          'email': email.trim().toLowerCase(),
          'full_name': name.trim(),
          'role': 'customer',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
        await _loadProfile();
      });

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    _role = 'customer';
    if (!config.needsAccount) await _auth.signInAnonymously();
  }

  Rec _row(DocumentSnapshot<Map<String, dynamic>> d) => {...?d.data(), 'id': d.id};

  @override
  Future<List<Rec>> list(TableCfg table) => _wrap(() async {
        Query<Map<String, dynamic>> q = _c(table.name);
        if (table.owner == 'customer' && !isAdmin) q = q.where('customer_id', isEqualTo: userId);
        final snap = await q.orderBy('created_at', descending: true).limit(500).get();
        return snap.docs.map(_row).toList();
      });

  Rec _defaults(TableCfg table) {
    final out = <String, dynamic>{};
    for (final c in table.columns) {
      final d = c.defaultValue;
      if (d == null || d.isEmpty) continue;
      if (c.adminOnly && !isAdmin) continue; // the security rules refuse admin fields from customers
      out[c.name] = switch (c.type) {
        'int' => int.tryParse(d),
        'decimal' => double.tryParse(d),
        'bool' => d == 'true',
        'date' => d == 'today' || d == 'now' ? DateTime.now().toIso8601String().substring(0, 10) : d,
        'datetime' => d == 'now' ? DateTime.now().toUtc().toIso8601String() : d,
        _ => d,
      };
    }
    return out;
  }

  @override
  Future<Rec> insert(TableCfg table, Rec values) => _wrap(() async {
        final now = DateTime.now().toUtc().toIso8601String();
        final row = <String, dynamic>{
          ..._defaults(table),
          ...clean(table, values),
          'created_at': now,
          'updated_at': now,
          if (table.hasOwner) 'customer_id': userId,
        };
        final ref = await _c(table.name).add(row);
        await _afterChange(table, {...row, 'id': ref.id}, inserted: true);
        return {...row, 'id': ref.id};
      });

  @override
  Future<void> update(TableCfg table, String id, Rec values) => _wrap(() async {
        final data = {...clean(table, values), 'updated_at': DateTime.now().toUtc().toIso8601String()};
        await _c(table.name).doc(id).update(data);
        final full = _row(await _c(table.name).doc(id).get());
        await _afterChange(table, full, inserted: false);
      });

  @override
  Future<void> delete(TableCfg table, String id) => _wrap(() => _c(table.name).doc(id).delete());

  String _summary(TableCfg table, Rec row) {
    final parts = <String>[
      if (table.titleColumn != null && row[table.titleColumn!.name] != null) '${row[table.titleColumn!.name]}',
      for (final c in table.columns.where((c) => c.adminOnly))
        if (row[c.name] != null) '${row[c.name]}',
    ];
    return parts.join(' · ');
  }

  /// What the database triggers do on Supabase: notifications chosen in Alpha's database studio.
  Future<void> _afterChange(TableCfg table, Rec row, {required bool inserted}) async {
    final target = inserted ? table.notifyOnInsert : table.notifyOnUpdate;
    final title = '${table.label}: ${inserted ? 'جديد' : 'تحديث'}';
    try {
      if (target == 'admin') {
        await notify(toRole: 'admin', title: title, body: _summary(table, row));
      } else if (target == 'customer' && isAdmin) {
        await notify(toRole: 'customer', title: title, body: _summary(table, row));
      } else if (target == 'owner') {
        final owner = row['customer_id'] as String?;
        if (owner != null && owner != userId) {
          await notify(toRole: 'customer', toUser: owner, title: title, body: _summary(table, row));
        }
      }
    } catch (_) {
      // A notification that cannot be written never blocks saving the row.
    }
  }

  @override
  Future<List<AppNotification>> notifications() => _wrap(() async {
        final uid = userId;
        if (uid == null) return <AppNotification>[];
        final roles = switch (config.role) {
          'customer' => ['customer'],
          'admin' => ['admin'],
          _ => ['customer', if (isAdmin) 'admin'],
        };
        final results = await Future.wait([
          _c('notifications').where('to_user', isEqualTo: uid).limit(60).get(),
          _c('notifications').where('to_role', whereIn: roles).limit(60).get(),
        ]);
        final seen = DateTime.tryParse(_prefs.getString('alpha_seen') ?? '') ?? DateTime(2000);
        final byId = <String, AppNotification>{};
        for (final snap in results) {
          for (final d in snap.docs) {
            final r = d.data();
            if (r['to_user'] != null && r['to_user'] != uid) continue;
            final at = DateTime.tryParse('${r['created_at']}') ?? DateTime.now();
            byId[d.id] = AppNotification(
              id: d.id,
              title: '${r['title'] ?? ''}',
              body: '${r['body'] ?? ''}',
              createdAt: at.toLocal(),
              read: !at.isAfter(seen),
            );
          }
        }
        return byId.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });

  @override
  Future<void> markRead(String id) => _prefs.setString('alpha_seen', DateTime.now().toUtc().toIso8601String());

  @override
  Future<void> notify({required String toRole, String? toUser, required String title, required String body}) =>
      _wrap(() => _c('notifications').add({
            if (toUser != null) 'to_user': toUser else 'to_role': toRole,
            'title': title,
            'body': body,
            'created_by': userId,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          }));

  @override
  Future<Map<String, int>> stats() => _wrap(() async {
        final out = <String, int>{};
        for (final t in config.tables) {
          final agg = await _c(t.name).count().get();
          out[t.name] = agg.count ?? 0;
        }
        return out;
      });

  @override
  Future<void> registerDevice(String token) async {
    final uid = userId;
    if (uid == null) return;
    await _c('device_tokens').doc(token).set({
      'user_id': uid,
      'app': appRole,
      'platform': 'android',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
