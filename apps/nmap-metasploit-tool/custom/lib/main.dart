import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'alpha/config.dart';
import 'alpha/wiring.dart';
import 'screens/home_screen.dart';
import 'screens/metasploit_screen.dart';
import 'screens/control_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = createBackend(AlphaConfig.instance);
  await backend.init();
  runApp(MyApp(backend: backend));
}

class MyApp extends StatelessWidget {
  final Backend backend;
  const MyApp({super.key, required this.backend});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تطبيق أداة Nmap',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'AE'),
      supportedLocales: const [Locale('ar', 'AE'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0C0D13),
        primaryColor: const Color(0xFF00FF66),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF66),
          secondary: Color(0xFF1F2937),
          surface: Color(0xFF16171F),
        ),
        fontFamily: 'Segoe UI',
      ),
      home: MainShell(backend: backend),
    );
  }
}

class MainShell extends StatefulWidget {
  final Backend backend;
  const MainShell({super.key, required this.backend});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    HomeScreen(backend: widget.backend),
    MetasploitScreen(backend: widget.backend),
    ControlScreen(backend: widget.backend),
    LogsScreen(backend: widget.backend),
    ProfileScreen(backend: widget.backend),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF16171F).withOpacity(0.92),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.09))),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navButton(0, 'الرئيسية', Icons.home_outlined, Icons.home),
                  _navButton(1, 'المنظومة', Icons.security_outlined, Icons.security),
                  _navButton(2, 'التحكم', Icons.settings_remote_outlined, Icons.settings_remote),
                  _navButton(3, 'السجل', Icons.list_alt_outlined, Icons.list_alt),
                  _navButton(4, 'حسابي', Icons.person_outline, Icons.person),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navButton(int index, String label, IconData iconOutlined, IconData iconFilled) {
    final isSelected = _currentIndex == index;
    const activeColor = Color(0xFF00FF66);
    final inactiveColor = const Color(0xFF9A97AE);

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 30,
                decoration: BoxDecoration(
                  color: isSelected ? activeColor.withOpacity(0.16) : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Icon(
                  isSelected ? iconFilled : iconOutlined,
                  color: isSelected ? activeColor : inactiveColor,
                  size: 22,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
