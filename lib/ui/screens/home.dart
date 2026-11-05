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
  const HomeScreen({super.key, required this.onOpenSettings, required this.onNewApp});
  final VoidCallback onOpenSettings;
  final VoidCallback onNewApp;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final running = s.runs.where((r) => r.running).length;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          if (s.hasGitHub) await s.refreshRemote();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 130),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('أهلاً بيك 👋', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                      SizedBox(height: 2),
                      Text('شنو التطبيق الجاي اللي حنبنيه؟', style: TextStyle(color: AlphaColors.muted, fontSize: 15)),
                    ],
                  ),
                ),
                if (running > 0)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: Pill('يُبنى $running', color: AlphaColors.amber, icon: Icons.bolt_rounded),
                  ),
                const AlphaLogo(size: 42),
              ],
            ),
            const SizedBox(height: 16),
            if (!s.hasGitHub) _SetupCard(onOpenSettings: onOpenSettings),
            if (s.alphaUpdate != null) AlphaUpdateCard(version: s.alphaUpdate!),
            _Hero(onNewApp: onNewApp),
            const SizedBox(height: 6),
            GlassCard(
              borderColor: AlphaColors.teal.withValues(alpha: 0.35),
              onTap: () => _newPair(context),
              child: const Row(children: [
                IconTile(Icons.account_tree_rounded, color: AlphaColors.teal, size: 52),
                SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('تطبيقين متصلين', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    SizedBox(height: 3),
                    Text('زبون + إدارة على Supabase، دخول برمز البريد، وإشعارات حتى والتطبيق مقفول',
                        style: TextStyle(color: AlphaColors.muted, fontSize: 13, height: 1.5)),
                  ]),
                ),
                Icon(Icons.chevron_left_rounded, color: AlphaColors.muted),
              ]),
            ),
            const SizedBox(height: 6),
            Row(children: [
              for (final l in Lang.values) ...[
                if (l != Lang.values.first) const SizedBox(width: 8),
                Expanded(child: _LangTile(lang: l, count: s.projects.where((p) => p.lang == l).length)),
              ],
            ]),
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
                    IconTile(Icons.rocket_launch_rounded, size: 60),
                    SizedBox(height: 12),
                    Text('لسه ما في مشاريع', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    SizedBox(height: 6),
                    Text('اضغط «تطبيق جديد» أو زر + تحت، وصف فكرتك: Alpha يفهمها ويصمّمها ويبنيها.',
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

  Future<void> _newPair(BuildContext context) async {
    final c = await pickNewProject(context, kind: ProjectKind.pair);
    if (c == null || !context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => WizardScreen(kind: c.kind, clientName: c.clientName, clientRef: c.client?.ref ?? '')));
  }
}

/// The big brand card: what Alpha does, and the main action.
class _Hero extends StatelessWidget {
  const _Hero({required this.onNewApp});
  final VoidCallback onNewApp;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AlphaColors.violet, AlphaColors.blue], begin: AlignmentDirectional.topEnd, end: AlignmentDirectional.bottomStart),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: AlphaColors.violet.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 12))],
        ),
        child: Stack(children: [
          PositionedDirectional(
            end: -60,
            top: -70,
            child: Container(width: 190, height: 190, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08))),
          ),
          PositionedDirectional(
            start: 40,
            bottom: -90,
            child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(99)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text('ذكاء اصطناعي · تصميم · APK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
                ]),
              ),
              const SizedBox(height: 14),
              const Text('ابنِ تطبيقك في دقائق', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 8),
              Text('صف فكرتك أو الصق كودك، ونحن نفهمها ونصمّم الواجهات ونكتب الجداول والصلاحيات ونبني لك APK.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 14.5, height: 1.6)),
              const SizedBox(height: 18),
              Material(
                color: Colors.white,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: onNewApp,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_circle_rounded, color: AlphaColors.violet, size: 24),
                      SizedBox(width: 8),
                      Text('تطبيق جديد', style: TextStyle(color: AlphaColors.violet, fontWeight: FontWeight.w800, fontSize: 17)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      );
}

/// A language: its brand icon and how many projects use it.
class _LangTile extends StatelessWidget {
  const _LangTile({required this.lang, required this.count});
  final Lang lang;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AlphaColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AlphaColors.line),
        ),
        child: Column(children: [
          Icon(langIcon(lang), color: Color(lang.color), size: 22),
          const SizedBox(height: 8),
          Text(count == 0 ? '–' : '$count', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          FittedBox(child: Text(lang.label, style: const TextStyle(color: AlphaColors.muted, fontSize: 12, fontWeight: FontWeight.w600))),
        ]),
      );
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.onOpenSettings});
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => GlassCard(
        onTap: onOpenSettings,
        borderColor: AlphaColors.infoLine,
        child: const Row(
          children: [
            IconTile(Icons.key_rounded, color: AlphaColors.infoText),
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
