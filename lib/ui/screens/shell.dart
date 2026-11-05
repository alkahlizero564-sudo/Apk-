import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../owner_picker.dart';
import '../widgets.dart';
import 'activity.dart';
import 'home.dart';
import 'libraries.dart';
import 'settings.dart';
import 'wizard.dart';

/// The four sections, with a floating bottom bar and the raised «+» (new app) in its middle.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  Future<void> _newApp() async {
    final c = await pickNewProject(context);
    if (c == null || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => WizardScreen(kind: c.kind, clientName: c.clientName, clientRef: c.client?.ref ?? '')));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onOpenSettings: () => setState(() => _tab = 3), onNewApp: _newApp),
      const ActivityScreen(),
      const LibrariesScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      extendBody: true,
      body: AuroraBackground(child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          height: 86,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                height: 70,
                decoration: BoxDecoration(
                  color: AlphaColors.surface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: AlphaColors.line),
                  boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 30, offset: Offset(0, 12))],
                ),
                child: Row(children: [
                  _NavItem(icon: Icons.home_rounded, label: 'الرئيسية', on: _tab == 0, onTap: () => setState(() => _tab = 0)),
                  _NavItem(icon: Icons.bolt_rounded, label: 'البناء', on: _tab == 1, onTap: () => setState(() => _tab = 1)),
                  const SizedBox(width: 76),
                  _NavItem(icon: Icons.widgets_rounded, label: 'المكتبات', on: _tab == 2, onTap: () => setState(() => _tab = 2)),
                  _NavItem(icon: Icons.settings_rounded, label: 'الإعدادات', on: _tab == 3, onTap: () => setState(() => _tab = 3)),
                ]),
              ),
              Positioned(
                top: 0,
                child: Semantics(
                  button: true,
                  label: 'تطبيق جديد',
                  child: GestureDetector(
                    onTap: _newApp,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AlphaColors.aurora,
                        border: Border.all(color: AlphaColors.bg, width: 5),
                        boxShadow: [BoxShadow(color: AlphaColors.violet.withValues(alpha: 0.5), blurRadius: 22, offset: const Offset(0, 8))],
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.on, required this.onTap});
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(color: on ? AlphaColors.violetSoft : Colors.transparent, borderRadius: BorderRadius.circular(99)),
              child: Icon(icon, size: 24, color: on ? Colors.white : AlphaColors.muted),
            ),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? AlphaColors.text : AlphaColors.muted)),
          ]),
        ),
      );
}
