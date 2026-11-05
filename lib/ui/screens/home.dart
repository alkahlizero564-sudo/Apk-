import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state.dart';
import '../../app/theme.dart';
import '../../models/project.dart';
import '../install_sheet.dart';
import '../owner_picker.dart';
import '../widgets.dart';
import 'project.dart';
import 'wizard.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenSettings});
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final running = s.runs.where((r) => r.running).length;
    final apps = s.projects.fold<int>(0, (n, p) => n + p.apps.length);
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          if (s.hasGitHub) await s.refreshRemote();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
          children: [
            Row(
              children: [
                const AlphaLogo(size: 44),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Alpha', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                      Text('ابنِ تطبيقاً أو تطبيقين متصلين', style: TextStyle(color: AlphaColors.muted, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton.filledTonal(onPressed: onOpenSettings, icon: const Icon(Icons.tune_rounded)),
              ],
            ),
            const SizedBox(height: 18),
            if (!s.hasGitHub) _SetupCard(onOpenSettings: onOpenSettings),
            if (s.alphaUpdate != null) AlphaUpdateCard(version: s.alphaUpdate!),
            GlassCard(
              gradient: LinearGradient(colors: [AlphaColors.violet.withValues(alpha: 0.35), AlphaColors.teal.withValues(alpha: 0.18)]),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ماذا نبني اليوم؟', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text('اختر اللغة والتصميم وقاعدة البيانات، وAlpha يكتب الجداول والصلاحيات والإشعارات ويبني الـ APK.',
                      style: TextStyle(color: AlphaColors.muted, height: 1.6)),
                  const SizedBox(height: 16),
                  _QuickAction(
                    icon: Icons.add_circle_rounded,
                    title: 'أنشئ تطبيقاً',
                    gradient: AlphaColors.aurora,
                    onTap: () => _choose(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _Stat(icon: Icons.folder_special_rounded, value: '${s.projects.length}', label: 'مشروع')),
                const SizedBox(width: 10),
                Expanded(child: _Stat(icon: Icons.phone_android_rounded, value: '$apps', label: 'تطبيق')),
                const SizedBox(width: 10),
                Expanded(child: _Stat(icon: Icons.bolt_rounded, value: '$running', label: 'يُبنى الآن', color: running > 0 ? AlphaColors.amber : null)),
              ],
            ),
            SectionTitle('مشاريعك',
                subtitle: s.projects.isEmpty ? null : 'اضغط على مشروع للتصميم والبيانات والبناء',
                trailing: s.hasGitHub
                    ? TextButton.icon(
                        onPressed: () async {
                          try {
                            final n = await s.importFromRepo();
                            if (context.mounted) showMessage(context, n == 0 ? 'لا توجد مشاريع جديدة في المستودع' : 'أُضيف $n مشروع من المستودع');
                          } catch (e) {
                            if (context.mounted) showMessage(context, '$e', error: true);
                          }
                        },
                        icon: const Icon(Icons.cloud_download_rounded, size: 18),
                        label: const Text('من المستودع'),
                      )
                    : null),
            if (s.projects.isEmpty)
              const GlassCard(
                padding: EdgeInsets.all(28),
                child: Column(
                  children: [
                    Icon(Icons.rocket_launch_rounded, size: 46, color: AlphaColors.violet),
                    SizedBox(height: 12),
                    Text('لا مشاريع بعد', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    SizedBox(height: 6),
                    Text('ابدأ بتطبيق واحد أو بتطبيقين متصلين (عميل + إدارة) بقاعدة بيانات وإشعارات.',
                        textAlign: TextAlign.center, style: TextStyle(color: AlphaColors.muted, height: 1.6)),
                  ],
                ),
              ),
            for (final p in s.projects) _ProjectCard(project: p),
          ],
        ),
      ),
    );
  }

  /// «أنشئ تطبيقاً»: «لمين؟» (mine, or a client and the client's database), then one app or both.
  Future<void> _choose(BuildContext context) async {
    final c = await pickNewProject(context);
    if (c == null || !context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => WizardScreen(kind: c.kind, clientName: c.clientName, clientRef: c.client?.ref ?? '')));
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.onOpenSettings});
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => GlassCard(
        onTap: onOpenSettings,
        gradient: LinearGradient(colors: [AlphaColors.amber.withValues(alpha: 0.22), AlphaColors.pink.withValues(alpha: 0.12)]),
        child: const Row(
          children: [
            Icon(Icons.key_rounded, color: AlphaColors.amber, size: 30),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('اربط GitHub أولاً', style: TextStyle(fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('البناء يتم مجاناً في GitHub Actions. أضف التوكن والمستودع من الإعدادات.',
                      style: TextStyle(color: AlphaColors.muted, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded),
          ],
        ),
      );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.title, required this.gradient, required this.onTap});
  final IconData icon;
  final String title;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            height: 96,
            decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: Colors.white, size: 28),
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                ],
              ),
            ),
          ),
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label, this.color});
  final IconData icon;
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: color ?? AlphaColors.teal),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(color: AlphaColors.muted, fontSize: 12)),
          ],
        ),
      );
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = project;
    final runs = s.runsFor(p);
    final running = runs.any((r) => r.running);
    final last = runs.isEmpty ? null : runs.first;
    final seed = hexColor(p.theme.seed);
    return GlassCard(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectScreen(projectId: p.id))),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [seed, hexColor(p.theme.accent, AlphaColors.teal)]),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(p.isPair ? Icons.connecting_airports_rounded : langIcon(p.lang), color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    LangBadge(p.lang),
                    Pill(p.kind.label, color: AlphaColors.blue),
                    if (p.forClient) Pill('زبون: ${p.clientName}', color: AlphaColors.amber),
                    if (p.backend != BackendType.none) Pill(p.backend.label, color: AlphaColors.teal, icon: Icons.storage_rounded),
                    if (p.push) const Pill('إشعارات', color: AlphaColors.pink, icon: Icons.notifications_active_rounded),
                  ],
                ),
              ],
            ),
          ),
          if (running)
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AlphaColors.amber))
          else if (last != null)
            Icon(last.ok ? Icons.check_circle_rounded : Icons.error_rounded, color: last.ok ? AlphaColors.ok : AlphaColors.bad)
          else
            const Icon(Icons.chevron_left_rounded, color: AlphaColors.muted),
        ],
      ),
    );
  }
}
