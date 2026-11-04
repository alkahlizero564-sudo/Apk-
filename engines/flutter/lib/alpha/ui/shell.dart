import 'dart:async';

import 'package:flutter/material.dart';

import '../backend.dart';
import '../config.dart';
import '../wiring.dart';
import 'icons.dart';
import 'pages.dart';
import 'widgets.dart';

/// Start-up (session, login) and the main screen with its tabs.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.config, required this.messenger});
  final AlphaConfig config;
  final GlobalKey<ScaffoldMessengerState> messenger;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final Backend _backend = createBackend(widget.config);
  bool _ready = false;
  String? _error;
  int _tab = 0;
  int _unread = 0;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => (_error = null, _ready = false));
    try {
      await _backend.init();
      if (!mounted) return;
      setState(() => _ready = true);
      _afterSignIn();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _afterSignIn() {
    if (!_backend.signedIn) return;
    if (widget.config.push) setupPush(_backend, widget.config, widget.messenger);
    _checkUnread();
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _checkUnread());
  }

  Future<void> _checkUnread() async {
    if (widget.config.backendType == 'none' || !_backend.signedIn) return;
    try {
      final items = await _backend.notifications();
      final unread = items.where((n) => !n.read).length;
      if (mounted && unread != _unread) setState(() => _unread = unread);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    if (_error != null) {
      return Scaffold(body: ErrorBox(message: _error!, onRetry: _start));
    }
    if (!_ready) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 56, color: c.seed),
              const SizedBox(height: 16),
              Text(c.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 18),
              const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
            ],
          ),
        ),
      );
    }
    if (!_backend.signedIn) {
      return LoginPage(
        backend: _backend,
        onDone: () {
          setState(() => _tab = 0);
          _afterSignIn();
        },
      );
    }
    if (c.role == 'admin' && !_backend.isAdmin) {
      return NotAdminPage(backend: _backend, onSignedOut: () => setState(() {}));
    }

    final tables = c.visibleTables(_backend.isAdmin);
    final hasNotifications = c.backendType != 'none';
    final pages = <({String label, IconData icon, Widget page})>[
      (
        label: 'الرئيسية',
        icon: Icons.space_dashboard_rounded,
        page: DashboardPage(backend: _backend, onOpenTable: (i) => setState(() => _tab = i + 1)),
      ),
      for (final t in tables.take(3)) (label: t.label, icon: iconFor(t.icon), page: TableTab(backend: _backend, table: t)),
      if (hasNotifications)
        (
          label: 'الإشعارات',
          icon: Icons.notifications_rounded,
          page: NotificationsPage(backend: _backend, onSeen: () => setState(() => _unread = 0)),
        ),
      (label: 'حسابي', icon: Icons.person_rounded, page: ProfilePage(backend: _backend, onSignedOut: () => setState(() {}))),
    ];
    final extra = tables.skip(3).toList();
    if (_tab >= pages.length) _tab = 0;
    final current = pages[_tab];

    return Scaffold(
      appBar: _tab == 0
          ? null
          : AppBar(
              title: Text(current.label),
              actions: [
                if (extra.isNotEmpty)
                  PopupMenuButton<TableCfg>(
                    icon: const Icon(Icons.more_horiz_rounded),
                    itemBuilder: (_) => [
                      for (final t in extra)
                        PopupMenuItem(value: t, child: ListTile(leading: Icon(iconFor(t.icon)), title: Text(t.label))),
                    ],
                    onSelected: (t) => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TableTabPage(backend: _backend, table: t)),
                    ),
                  ),
              ],
            ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(key: ValueKey(_tab), child: current.page),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          for (final p in pages)
            NavigationDestination(
              icon: p.label == 'الإشعارات' && _unread > 0
                  ? Badge(label: Text('$_unread'), child: Icon(p.icon))
                  : Icon(p.icon),
              label: p.label,
            ),
        ],
      ),
    );
  }
}

class TableTabPage extends StatelessWidget {
  const TableTabPage({super.key, required this.backend, required this.table});
  final Backend backend;
  final TableCfg table;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text(table.label)), body: TableTab(backend: backend, table: table));
}
