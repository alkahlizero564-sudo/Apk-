// Made with Alpha. The screens, data and rules come from alpha/config_data.dart (the app's design in Alpha).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'alpha/config.dart';
import 'alpha/ui/shell.dart';
import 'alpha/ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AlphaApp());
}

class AlphaApp extends StatelessWidget {
  const AlphaApp({super.key});
  static final messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    final c = AlphaConfig.instance;
    return MaterialApp(
      title: c.title,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messenger,
      theme: buildTheme(c, Brightness.light),
      darkTheme: buildTheme(c, Brightness.dark),
      themeMode: c.themeMode,
      locale: Locale(c.rtl ? 'ar' : 'en'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: AppShell(config: c, messenger: messenger),
    );
  }
}
