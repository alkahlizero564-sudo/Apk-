// Push notifications with Firebase Cloud Messaging: asks Android for the permission, registers this phone's
// token with the backend, and shows messages that arrive while the app is open.
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'backend.dart';
import 'config.dart';
import 'firebase_boot.dart';

@pragma('vm:entry-point')
Future<void> _onBackground(RemoteMessage message) async {}

Future<void> setupPush(Backend backend, AlphaConfig config, GlobalKey<ScaffoldMessengerState> messenger) async {
  try {
    await bootFirebase(config);
    FirebaseMessaging.onBackgroundMessage(_onBackground);
    final fm = FirebaseMessaging.instance;
    final perm = await fm.requestPermission(alert: true, badge: true, sound: true);
    if (perm.authorizationStatus == AuthorizationStatus.denied) return;
    // ignore: deprecated_member_use
    final token = await fm.getToken();
    if (token != null && backend.signedIn) await backend.registerDevice(token);
    // ignore: deprecated_member_use
    fm.onTokenRefresh.listen((t) {
      if (backend.signedIn) backend.registerDevice(t);
    });
    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n == null) return;
      messenger.currentState?.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text([n.title, n.body].whereType<String>().where((s) => s.isNotEmpty).join('\n')),
      ));
    });
  } catch (e) {
    debugPrint('push not available: $e');
  }
}
