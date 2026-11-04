import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/state.dart';
import '../../app/theme.dart';
import '../../models/project.dart';
import '../widgets.dart';
import 'activity.dart';
import 'db_studio.dart';
import 'design_studio.dart';

class ProjectScreen extends StatelessWidget {
  const ProjectScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = s.byId(projectId);
    if (p == null) return const Scaffold(body: Center(child: Text('المشروع غير موجود')));
    final runs = s.runsFor(p);
    final ready = s.serverReady(p);
    final seed = hexColor(p.theme.seed);
    final accent = hexColor(p.theme.accent, AlphaColors.teal);
    return Scaffold(
      body: AuroraBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            if (s.hasGitHub) await s.refreshRemote();
          },
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 210,
                backgroundColor: AlphaColors.bg2,
                actions: [
                  IconButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ProjectSettings(project: p))),
                    icon: const Icon(Icons.settings_rounded),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  background: Container(
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [seed, accent], begin: Alignment.topRight, end: Alignment.bottomLeft)),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 56, 20, 56),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _HeaderChip(langIcon(p.lang), p.lang.label),
                            _HeaderChip(p.isPair ? Icons.connecting_airports_rounded : Icons.phone_android_rounded, p.isPair ? 'عميل + إدارة' : 'تطبيق واحد'),
                            _HeaderChip(Icons.table_chart_rounded, '${p.schema.tables.length} جداول'),
                            if (p.backend != BackendType.none) _HeaderChip(Icons.storage_rounded, p.backend.label),
                            if (p.push) const _HeaderChip(Icons.notifications_active_rounded, 'إشعارات'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                sliver: SliverList.list(
                  children: [
                    if (p.backend != BackendType.none)
                      GlassCard(
                        gradient: LinearGradient(colors: [
                          (ready ? AlphaColors.ok : AlphaColors.amber).withValues(alpha: 0.22),
                          (ready ? AlphaColors.ok : AlphaColors.amber).withValues(alpha: 0.06),
                        ]),
                        child: Row(
                          children: [
                            Icon(ready ? Icons.verified_rounded : Icons.cloud_sync_rounded, color: ready ? AlphaColors.ok : AlphaColors.amber, size: 30),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(ready ? 'السيرفر جاهز ومتصل' : 'السيرفر لم يُجهّز بعد', style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text(
                                    ready
                                        ? (p.supabaseUrl.isNotEmpty ? p.supabaseUrl : '${p.backend.label}: الجداول والصلاحيات والدخول')
                                        : 'اضغط «تجهيز السيرفر»: الجداول + الصلاحيات + الدخول + الإشعارات ثم البناء',
                                    style: const TextStyle(color: AlphaColors.muted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SectionTitle('التطبيقات'),
                    for (final a in p.apps) _AppCard(project: p, app: a),
                    const SectionTitle('الأدوات'),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1,
                      children: [
                        _Tool(Icons.palette_rounded, 'التصميم', AlphaColors.pink,
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => DesignStudioScreen(project: p)))),
                        _Tool(Icons.table_chart_rounded, 'البيانات والصلاحيات', AlphaColors.teal,
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => DbStudioScreen(project: p)))),
                        if (p.backend != BackendType.none)
                          _Tool(Icons.dns_rounded, 'تجهيز السيرفر', AlphaColors.blue, () => _run(context, () => s.setupServer(p), 'بدأ تجهيز السيرفر ثم البناء')),
                        if (p.backend == BackendType.supabase)
                          _Tool(Icons.notifications_active_rounded, 'إشعار تجريبي', AlphaColors.amber, () => _testNotification(context, p)),
                        _Tool(Icons.rocket_launch_rounded, 'ابنِ الكل', AlphaColors.violet, () => _run(context, () => s.buildAll(p), 'بدأ بناء ${p.apps.length} تطبيق')),
                        _Tool(Icons.auto_awesome_rounded, 'عدّل بالذكاء', AlphaColors.amber, () => _aiChange(context, p)),
                      ],
                    ),
                    SectionTitle('سجل البناء', trailing: IconButton(onPressed: s.refreshRuns, icon: const Icon(Icons.refresh_rounded))),
                    if (runs.isEmpty)
                      const GlassCard(child: Text('لا عمليات بعد لهذا المشروع.', style: TextStyle(color: AlphaColors.muted))),
                    for (final r in runs.take(8)) RunTile(run: r),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _run(BuildContext context, Future<void> Function() action, String ok) async {
    try {
      await action();
      if (context.mounted) showMessage(context, ok);
    } catch (e) {
      if (context.mounted) showMessage(context, '$e', error: true);
    }
  }

  static Future<void> _testNotification(BuildContext context, Project p) async {
    final s = context.read<AppState>();
    final title = TextEditingController(text: 'إشعار تجريبي من Alpha');
    final body = TextEditingController(text: 'الإشعارات بين التطبيقين تعمل ✓');
    var role = p.isPair ? 'customer' : 'customer';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('إرسال إشعار'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'customer', label: Text('للعملاء')), ButtonSegment(value: 'admin', label: Text('للإدارة'))],
                selected: {role},
                onSelectionChanged: (v) => set(() => role = v.first),
              ),
              const SizedBox(height: 12),
              TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان')),
              const SizedBox(height: 8),
              TextField(controller: body, decoration: const InputDecoration(labelText: 'النص')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('إرسال')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(context, () => s.sendTestNotification(p, toRole: role, title: title.text, body: body.text), 'أُرسل: يظهر في التطبيقات وكإشعار Push');
  }

  static Future<void> _aiChange(BuildContext context, Project p) async {
    final s = context.read<AppState>();
    var app = p.apps.first;
    final text = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + MediaQuery.viewInsetsOf(c).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('عدّل التطبيق بالذكاء الاصطناعي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('يكتب الكود فوق محرّك Alpha (البيانات والدخول والإشعارات تبقى)، ثم يبنيه ويصلح أي خطأ تلقائياً.',
                  style: TextStyle(color: AlphaColors.muted, fontSize: 13, height: 1.5)),
              const SizedBox(height: 12),
              if (p.apps.length > 1)
                SegmentedButton<String>(
                  segments: [for (final a in p.apps) ButtonSegment(value: a.slug, label: Text(a.roleLabel))],
                  selected: {app.slug},
                  onSelectionChanged: (v) => set(() => app = p.apps.firstWhere((a) => a.slug == v.first)),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: text,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'مثال: اجعل الرئيسية سلايدر عروض، وصفحة المنتجات شبكة صور بسلة مشتريات وزر طلب عبر واتساب',
                ),
              ),
              const SizedBox(height: 12),
              GradientButton(label: 'اكتب الكود وابنِ', icon: Icons.auto_awesome_rounded, onPressed: () => Navigator.pop(c, true)),
            ],
          ),
        ),
      ),
    );
    if (ok != true || text.text.trim().isEmpty || !context.mounted) return;
    await _run(context, () => s.generateWithAi(app, text.text.trim()), 'الذكاء الاصطناعي يكتب الكود في GitHub Actions ثم يبنيه');
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(99)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 5),
            Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      );
}

class _Tool extends StatelessWidget {
  const _Tool(this.icon, this.label, this.color, this.onTap);
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GlassCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(10),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
          ],
        ),
      );
}

class _AppCard extends StatelessWidget {
  const _AppCard({required this.project, required this.app});
  final Project project;
  final AppUnit app;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final info = s.builds[app.slug];
    final running = s.runs.any((r) => r.running && r.title.endsWith(' ${app.slug}'));
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(app.role == 'admin' ? Icons.admin_panel_settings_rounded : Icons.storefront_rounded, color: AlphaColors.teal, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('${app.roleLabel} · ${app.slug}', style: const TextStyle(color: AlphaColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              if (running)
                const Pill('يُبنى…', color: AlphaColors.amber, icon: Icons.bolt_rounded)
              else if (info != null)
                Pill('v${info.version}', color: AlphaColors.ok),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: running
                      ? null
                      : () async {
                          try {
                            await s.build(app, notes: 'Built from Alpha');
                            if (context.mounted) showMessage(context, 'بدأ بناء ${app.title}');
                          } catch (e) {
                            if (context.mounted) showMessage(context, '$e', error: true);
                          }
                        },
                  icon: const Icon(Icons.build_rounded, size: 18),
                  label: const Text('ابنِ'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: info == null || info.apk.isEmpty ? null : () => launchUrl(Uri.parse(info.apk), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('تحميل APK'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectSettings extends StatefulWidget {
  const _ProjectSettings({required this.project});
  final Project project;

  @override
  State<_ProjectSettings> createState() => _ProjectSettingsState();
}

class _ProjectSettingsState extends State<_ProjectSettings> {
  late final _title = TextEditingController(text: widget.project.title);
  late final _admins = TextEditingController(text: widget.project.admins.join(', '));
  late final _server = TextEditingController(text: widget.project.serverUrl);
  late final _ref = TextEditingController(text: widget.project.supabaseRef);
  late final _names = {for (final a in widget.project.apps) a.slug: TextEditingController(text: a.title)};
  bool _busy = false;

  Future<void> _save() async {
    final s = context.read<AppState>();
    final p = widget.project
      ..title = _title.text.trim().isEmpty ? widget.project.title : _title.text.trim()
      ..admins = _admins.text.split(RegExp(r'[,\s]+')).where((e) => e.contains('@')).toList()
      ..serverUrl = _server.text.trim()
      ..supabaseRef = _ref.text.trim();
    for (final a in p.apps) {
      final t = _names[a.slug]!.text.trim();
      if (t.isNotEmpty) a.title = t;
    }
    setState(() => _busy = true);
    try {
      await s.save(p, message: 'Alpha: settings of ${p.title}');
      if (mounted) {
        showMessage(context, 'حُفظ');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات المشروع')),
      body: AuroraBackground(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'اسم المشروع')),
            const SectionTitle('الأسماء تحت الأيقونات'),
            for (final a in p.apps) ...[
              TextField(controller: _names[a.slug], decoration: InputDecoration(labelText: a.roleLabel)),
              const SizedBox(height: 10),
            ],
            const SectionTitle('المديرون'),
            TextField(
              controller: _admins,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'بريد المديرين (فاصلة بينهم)', prefixIcon: Icon(Icons.admin_panel_settings_rounded)),
            ),
            if (p.backend == BackendType.supabase) ...[
              const SectionTitle('Supabase', subtitle: 'اتركه فارغاً لاستخدام المشروع الافتراضي من الإعدادات'),
              TextField(controller: _ref, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'Project ref خاص بهذا المشروع')),
            ],
            if (p.lang == Lang.php) ...[
              const SectionTitle('عنوان سيرفر PHP', subtitle: 'ارفع ملف ‎-server.zip‎ من صفحة الإصدار على استضافتك، ثم ضع العنوان هنا وابنِ'),
              TextField(controller: _server, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'https://example.com/app/')),
            ],
            const SizedBox(height: 22),
            GradientButton(label: 'حفظ', icon: Icons.save_rounded, busy: _busy, onPressed: _save),
            const SizedBox(height: 30),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AlphaColors.bad),
              onPressed: () async {
                final s = context.read<AppState>();
                final nav = Navigator.of(context);
                if (!await confirm(context, 'حذف المشروع؟', 'يُحذف من Alpha ومن المستودع (الجداول في السيرفر تبقى).', ok: 'حذف')) return;
                try {
                  await s.remove(p, fromRepo: s.hasGitHub);
                  nav.popUntil((r) => r.isFirst);
                } catch (e) {
                  if (context.mounted) showMessage(context, '$e', error: true);
                }
              },
              icon: const Icon(Icons.delete_forever_rounded),
              label: const Text('حذف المشروع'),
            ),
          ],
        ),
      ),
    );
  }
}
