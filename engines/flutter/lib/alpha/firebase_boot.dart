// Firebase started from the options in the app's config (written by the backend workflow from
// google-services.json), so no Gradle plugin is needed.
import 'package:firebase_core/firebase_core.dart';

import 'config.dart';

Future<void> bootFirebase(AlphaConfig config) async {
  if (Firebase.apps.isNotEmpty) return;
  final f = config.firebase;
  if ('${f['apiKey'] ?? ''}'.isEmpty || '${f['appId'] ?? ''}'.isEmpty) {
    throw StateError('Firebase is not set up for this app yet (open Alpha > the project > تجهيز السيرفر).');
  }
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: '${f['apiKey']}',
      appId: '${f['appId']}',
      messagingSenderId: '${f['senderId'] ?? ''}',
      projectId: '${f['projectId'] ?? ''}',
      storageBucket: f['storageBucket'] as String?,
    ),
  );
}
