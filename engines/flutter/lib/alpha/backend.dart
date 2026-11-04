// What every data backend of the engine does (on the phone, Supabase or Firestore).
import 'config.dart';

typedef Rec = Map<String, dynamic>;

class BackendError implements Exception {
  BackendError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Sign-in refused because the email is not confirmed yet: the app shows the code screen.
class NeedsConfirmation implements Exception {
  NeedsConfirmation(this.email);
  final String email;
  @override
  String toString() => 'أكّد بريدك أولاً بالرمز الذي وصلك.';
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.data = const {},
  });
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  final Map<String, dynamic> data;
}

abstract class Backend {
  Backend(this.config);
  final AlphaConfig config;

  /// Restores the saved session; afterwards [signedIn] says if the login screen is needed.
  Future<void> init();

  bool get signedIn;
  String? get userId;
  String? get email;
  String? get displayName;

  /// Admin rights: the admin app (for listed admins), or a listed admin in a single app.
  bool get isAdmin;

  Future<void> signIn(String email, String password);
  /// Makes the account; returns true when the email must be confirmed first (code, or link with Firebase).
  Future<bool> signUp(String name, String phone, String email, String password);

  /// Confirms the email with the 6-digit code (Firebase: checks that the link was opened) and signs in.
  Future<void> verifyCode(String email, String code, String password) async {}

  /// Sends the confirmation code (or link) again.
  Future<void> resendCode(String email) async {}

  /// Firebase confirms with a link in the email instead of a code.
  bool get confirmsWithLink => false;
  Future<void> signOut();

  /// Rows of a table, newest first. Customers only get their own rows of "customer" tables.
  Future<List<Rec>> list(TableCfg table);
  Future<Rec> insert(TableCfg table, Rec values);
  Future<void> update(TableCfg table, String id, Rec values);
  Future<void> delete(TableCfg table, String id);

  Future<List<AppNotification>> notifications();
  Future<void> markRead(String id);

  /// A message from this app to the other one (admins → every customer, customers → the admins).
  Future<void> notify({required String toRole, String? toUser, required String title, required String body});

  /// Row counts per table (admin dashboard).
  Future<Map<String, int>> stats();

  Future<void> registerDevice(String token);

  /// The app name sent with the device token: which of the two apps this phone runs.
  String get appRole => config.role;

  bool isMine(Rec row) => row['customer_id'] == null || row['customer_id'] == userId;

  /// Values ready to save: empty fields removed, numbers and booleans typed.
  Rec clean(TableCfg table, Rec values) {
    final out = <String, dynamic>{};
    for (final c in table.columns) {
      if (!values.containsKey(c.name)) continue;
      if (c.adminOnly && !isAdmin) continue;
      var v = values[c.name];
      if (v is String) {
        v = v.trim();
        if (v.isEmpty) {
          v = null;
        } else if (c.type == 'int') {
          v = int.tryParse(v.replaceAll(',', '')) ?? v;
        } else if (c.type == 'decimal') {
          v = double.tryParse(v.replaceAll(',', '')) ?? v;
        }
      }
      out[c.name] = v;
    }
    return out;
  }
}
