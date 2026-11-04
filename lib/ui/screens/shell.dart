import 'package:flutter/material.dart';

import '../widgets.dart';
import 'activity.dart';
import 'home.dart';
import 'libraries.dart';
import 'settings.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onOpenSettings: () => setState(() => _tab = 3)),
      const ActivityScreen(),
      const LibrariesScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      extendBody: true,
      body: AuroraBackground(child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.auto_awesome_mosaic_outlined), selectedIcon: Icon(Icons.auto_awesome_mosaic_rounded), label: 'المشاريع'),
          NavigationDestination(icon: Icon(Icons.bolt_outlined), selectedIcon: Icon(Icons.bolt_rounded), label: 'البناء'),
          NavigationDestination(icon: Icon(Icons.widgets_outlined), selectedIcon: Icon(Icons.widgets_rounded), label: 'المكتبات'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune_rounded), label: 'الإعدادات'),
        ],
      ),
    );
  }
}
