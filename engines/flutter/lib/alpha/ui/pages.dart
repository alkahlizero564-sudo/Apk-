import 'package:flutter/material.dart';

import '../backend.dart';
import '../config.dart';
import 'icons.dart';
import 'table_page.dart';
import 'theme.dart';
import 'widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.backend, required this.onDone});
  final Backend backend;
  final VoidCallback onDone;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _signup = false;
  bool _busy = false;
  bool _hide = true;

  AlphaConfig get c => widget.backend.config;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (_signup) {
        await widget.backend.signUp(_name.text, _email.text, _pass.text);
      } else {
        await widget.backend.signIn(_email.text, _pass.text);
      }
      widget.onDone();
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          Container(height: 320, decoration: BoxDecoration(gradient: brandGradient(c))),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                      child: Icon(c.role == 'admin' ? Icons.admin_panel_settings_rounded : Icons.lock_person_rounded,
                          color: Colors.white, size: 42),
                    ),
                    const SizedBox(height: 12),
                    Text(c.title, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(c.role == 'admin' ? 'لوحة الإدارة' : (_signup ? 'أنشئ حسابك' : 'مرحباً بعودتك'),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
                    const SizedBox(height: 26),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _form,
                          child: Column(
                            children: [
                              if (_signup) ...[
                                TextFormField(
                                  controller: _name,
                                  decoration: const InputDecoration(labelText: 'الاسم', prefixIcon: Icon(Icons.person_rounded)),
                                  validator: (v) => (v ?? '').trim().length < 2 ? 'اكتب اسمك' : null,
                                ),
                                const SizedBox(height: 12),
                              ],
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                textDirection: TextDirection.ltr,
                                decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.alternate_email_rounded)),
                                validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'بريد غير صحيح',
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _pass,
                                obscureText: _hide,
                                textDirection: TextDirection.ltr,
                                decoration: InputDecoration(
                                  labelText: 'كلمة المرور',
                                  prefixIcon: const Icon(Icons.key_rounded),
                                  suffixIcon: IconButton(
                                    icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                                    onPressed: () => setState(() => _hide = !_hide),
                                  ),
                                ),
                                validator: (v) => (v ?? '').length < 6 ? '6 أحرف على الأقل' : null,
                                onFieldSubmitted: (_) => _submit(),
                              ),
                              const SizedBox(height: 18),
                              FilledButton(
                                onPressed: _busy ? null : _submit,
                                child: _busy
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                                    : Text(_signup ? 'إنشاء الحساب' : 'دخول'),
                              ),
                              if (c.role != 'admin')
                                TextButton(
                                  onPressed: () => setState(() => _signup = !_signup),
                                  child: Text(_signup ? 'عندي حساب، سجّل دخولي' : 'ما عندي حساب؟ أنشئ واحداً'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (c.role == 'admin')
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text('الدخول للإدارة بالبريد المسجّل كمدير فقط',
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.backend, required this.onOpenTable});
  final Backend backend;
  final void Function(int index) onOpenTable;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, int>? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!widget.backend.isAdmin) return;
    try {
      final s = await widget.backend.stats();
      if (mounted) setState(() => _stats = s);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.backend;
    final c = b.config;
    final tables = c.visibleTables(b.isAdmin);
    final name = b.displayName;
    final hello = name == null || name.isEmpty ? 'أهلاً بك' : 'أهلاً $name';
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          HeroHeader(
            config: c,
            title: c.headline.isNotEmpty ? c.headline : c.title,
            subtitle: c.subtitle.isNotEmpty ? c.subtitle : (b.isAdmin ? 'لوحة التحكم' : hello),
            trailing: Icon(b.isAdmin ? Icons.insights_rounded : Icons.auto_awesome_rounded, color: Colors.white, size: 40),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Text(b.isAdmin ? 'نظرة عامة' : 'الأقسام', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.35,
              mainAxisSpacing: 4,
              crossAxisSpacing: 8,
              children: [
                for (var i = 0; i < tables.length; i++)
                  StatTile(
                    icon: iconFor(tables[i].icon),
                    label: tables[i].label,
                    value: _stats == null ? '›' : '${_stats![tables[i].name] ?? 0}',
                    onTap: () => widget.onOpenTable(i),
                  ),
                if (_stats?['_customers'] != null)
                  StatTile(icon: Icons.groups_rounded, label: 'العملاء', value: '${_stats!['_customers']}'),
              ],
            ),
          ),
          const SizedBox(height: 90),
        ],
      ),
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.backend, required this.onSeen});
  final Backend backend;
  final VoidCallback onSeen;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<AppNotification>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.backend.notifications();
      if (!mounted) return;
      setState(() => (_items = items, _error = null));
      await widget.backend.markRead('');
      widget.onSeen();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _compose() async {
    final title = TextEditingController();
    final body = TextEditingController();
    final b = widget.backend;
    final toAdmins = !b.isAdmin;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(toAdmins ? 'رسالة للإدارة' : 'إشعار لكل العملاء'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان')),
            const SizedBox(height: 10),
            TextField(controller: body, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'النص')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إرسال')),
        ],
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    try {
      await b.notify(toRole: toAdmins ? 'admin' : 'customer', title: title.text.trim(), body: body.text.trim());
      if (mounted) toast(context, 'تم الإرسال ✓');
      await _load();
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canSend = widget.backend.config.backendType != 'none';
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canSend
          ? FloatingActionButton(heroTag: 'compose', onPressed: _compose, child: const Icon(Icons.send_rounded))
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _error != null && _items == null
            ? ListView(children: [ErrorBox(message: _error!, onRetry: _load)])
            : _items == null
                ? const Center(child: CircularProgressIndicator())
                : _items!.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 80),
                        EmptyState(icon: Icons.notifications_none_rounded, text: 'لا توجد إشعارات بعد'),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: _items!.length,
                        itemBuilder: (_, i) {
                          final n = _items![i];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: cs.primary.withValues(alpha: n.read ? 0.08 : 0.2),
                                child: Icon(n.read ? Icons.notifications_rounded : Icons.notifications_active_rounded, color: cs.primary),
                              ),
                              title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w600 : FontWeight.w900)),
                              subtitle: Text(n.body.isEmpty ? timeAgo(n.createdAt) : '${n.body}\n${timeAgo(n.createdAt)}'),
                              isThreeLine: n.body.isNotEmpty,
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.backend, required this.onSignedOut});
  final Backend backend;
  final VoidCallback onSignedOut;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = backend.config;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: cs.primary,
                  child: Text(((backend.displayName ?? backend.email ?? 'A').characters.first).toUpperCase(),
                      style: TextStyle(color: cs.onPrimary, fontSize: 24, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(backend.displayName ?? (backend.email == null ? 'مستخدم' : backend.email!.split('@').first),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      if (backend.email != null) Text(backend.email!, style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      StatusPill(backend.isAdmin ? 'مدير' : 'عميل'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Column(
            children: [
              ListTile(leading: const Icon(Icons.apps_rounded), title: const Text('التطبيق'), trailing: Text(c.title)),
              ListTile(
                leading: const Icon(Icons.cloud_rounded),
                title: const Text('البيانات'),
                trailing: Text(switch (c.backendType) { 'supabase' => 'Supabase', 'firebase' => 'Firebase', _ => 'على الجهاز' }),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_rounded),
                title: const Text('الإشعارات'),
                trailing: Text(c.push ? 'مفعّلة' : 'داخل التطبيق'),
              ),
            ],
          ),
        ),
        if (c.needsAccount && backend.signedIn) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await backend.signOut();
              onSignedOut();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('تسجيل الخروج'),
          ),
        ],
        const SizedBox(height: 24),
        Center(child: Text('صُنع بواسطة Alpha', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))),
      ],
    );
  }
}

/// The admin app opened with an account that is not an admin.
class NotAdminPage extends StatelessWidget {
  const NotAdminPage({super.key, required this.backend, required this.onSignedOut});
  final Backend backend;
  final VoidCallback onSignedOut;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: EmptyState(
          icon: Icons.gpp_bad_rounded,
          text: 'الحساب ${backend.email ?? ''} ليس مديراً.\nأضف بريده كمدير في Alpha ثم سجّل الدخول مرة أخرى.',
          action: FilledButton(
            onPressed: () async {
              await backend.signOut();
              onSignedOut();
            },
            child: const Text('تسجيل الخروج'),
          ),
        ),
      );
}

class TableTab extends StatelessWidget {
  const TableTab({super.key, required this.backend, required this.table});
  final Backend backend;
  final TableCfg table;

  @override
  Widget build(BuildContext context) => TablePage(key: ValueKey(table.name), backend: backend, table: table);
}
