import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/state.dart';
import '../../app/theme.dart';
import '../../services/github.dart';
import '../widgets.dart';

/// Every workflow run (builds, server setups, AI code), refreshed while something is running.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      final s = context.read<AppState>();
      if (s.hasGitHub && s.runs.any((r) => r.running)) s.refreshRuns();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: s.refreshRuns,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            const Text('البناء والعمليات', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const Text('كل عملية تعمل مجاناً في GitHub Actions: تجهيز السيرفر، كتابة الكود، البناء والتوقيع والنشر.',
                style: TextStyle(color: AlphaColors.muted, height: 1.6)),
            const SizedBox(height: 10),
            if (!s.hasGitHub)
              const GlassCard(child: Text('اربط GitHub من الإعدادات لرؤية عمليات البناء.', style: TextStyle(color: AlphaColors.muted))),
            if (s.error != null) GlassCard(child: Text(s.error!, style: const TextStyle(color: AlphaColors.bad))),
            for (final r in s.runs) RunTile(run: r),
          ],
        ),
      ),
    );
  }
}

class RunTile extends StatelessWidget {
  const RunTile({super.key, required this.run});
  final WorkflowRun run;

  @override
  Widget build(BuildContext context) {
    final color = run.running ? AlphaColors.amber : (run.ok ? AlphaColors.ok : (run.conclusion == 'cancelled' ? AlphaColors.muted : AlphaColors.bad));
    final icon = switch (run.workflow) {
      'backend.yml' => Icons.dns_rounded,
      'generate.yml' => Icons.auto_awesome_rounded,
      'alpha.yml' => Icons.verified_rounded,
      _ => Icons.android_rounded,
    };
    return GlassCard(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => RunDetails(run: run),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: run.running
                ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: color))
                : Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(run.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  '${run.running ? 'يعمل الآن' : (run.ok ? 'نجح' : (run.conclusion == 'cancelled' ? 'أُلغي' : 'فشل'))} · ${_ago(run.updatedAt)}',
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded, color: AlphaColors.muted),
        ],
      ),
    );
  }
}

String _ago(DateTime d) {
  final m = DateTime.now().difference(d).inMinutes;
  if (m < 1) return 'الآن';
  if (m < 60) return 'قبل $m د';
  if (m < 1440) return 'قبل ${m ~/ 60} س';
  return '${d.year}/${d.month}/${d.day}';
}

class RunDetails extends StatefulWidget {
  const RunDetails({super.key, required this.run});
  final WorkflowRun run;

  @override
  State<RunDetails> createState() => _RunDetailsState();
}

class _RunDetailsState extends State<RunDetails> {
  List<JobStep>? _steps;
  String? _log;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final gh = await context.read<AppState>().github();
      final steps = await gh.steps(widget.run.id);
      String? log;
      if (!widget.run.running && !widget.run.ok) log = await gh.failureLog(widget.run.id);
      if (mounted) setState(() => (_steps = steps, _log = log));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.run;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
      children: [
        Text(r.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(r.workflow, style: const TextStyle(color: AlphaColors.muted)),
        const SizedBox(height: 14),
        if (_error != null) Text(_error!, style: const TextStyle(color: AlphaColors.bad)),
        if (_steps == null && _error == null) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
        for (final st in _steps ?? const <JobStep>[])
          if (!st.name.startsWith('Post ') && st.name != 'Set up job' && st.name != 'Complete job')
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    st.status != 'completed'
                        ? (st.status == 'in_progress' ? Icons.autorenew_rounded : Icons.radio_button_unchecked_rounded)
                        : switch (st.conclusion) { 'success' => Icons.check_circle_rounded, 'skipped' => Icons.remove_circle_outline_rounded, _ => Icons.cancel_rounded },
                    size: 20,
                    color: st.status != 'completed'
                        ? AlphaColors.amber
                        : switch (st.conclusion) { 'success' => AlphaColors.ok, 'skipped' => AlphaColors.muted, _ => AlphaColors.bad },
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(st.name, style: TextStyle(color: st.conclusion == 'skipped' ? AlphaColors.muted : null))),
                ],
              ),
            ),
        if (_log != null && _log!.isNotEmpty) ...[
          const SectionTitle('سبب الفشل'),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF0A0C14), borderRadius: BorderRadius.circular(14)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(_log!, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFFFCA5A5))),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _log!));
              showMessage(context, 'نُسخ السجل');
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('انسخ السجل'),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(r.url), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('افتح في GitHub'),
              ),
            ),
            if (!r.running && !r.ok) ...[
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    final s = context.read<AppState>();
                    try {
                      final gh = await s.github();
                      await gh.rerun(r.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                        showMessage(context, 'أُعيد التشغيل');
                      }
                      await s.refreshRuns();
                    } catch (e) {
                      if (context.mounted) showMessage(context, '$e', error: true);
                    }
                  },
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('أعد المحاولة'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
