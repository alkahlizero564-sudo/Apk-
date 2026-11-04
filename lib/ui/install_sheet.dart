import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/state.dart';
import '../app/theme.dart';
import '../services/installer.dart';
import 'widgets.dart';

/// Downloads an app (a release tag, or the newest release with a tag prefix) and opens the installer,
/// showing the progress. Nothing is opened in GitHub.
Future<void> installFromRelease(BuildContext context, {String? tag, String? prefix, required String title}) async {
  final s = context.read<AppState>();
  final installer = await s.installer();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _InstallSheet(installer: installer, tag: tag, prefix: prefix, title: title),
  );
}

class _InstallSheet extends StatefulWidget {
  const _InstallSheet({required this.installer, this.tag, this.prefix, required this.title});
  final Installer installer;
  final String? tag;
  final String? prefix;
  final String title;

  @override
  State<_InstallSheet> createState() => _InstallSheetState();
}

class _InstallSheetState extends State<_InstallSheet> {
  double? _progress;
  String _status = 'يبحث عن آخر نسخة…';
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final rel = widget.tag != null ? await widget.installer.release(widget.tag!) : await widget.installer.latest(widget.prefix!);
      if (rel == null) throw Exception('لا توجد نسخة مبنية بعد. اضغط «ابنِ» أولاً.');
      setState(() => _status = 'يحمّل ${rel['name'] ?? rel['tag_name']}…');
      final file = await widget.installer.download(rel, onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      setState(() => _status = 'يفتح المثبّت…');
      await Installer.install(file);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.install_mobile_rounded, color: AlphaColors.teal, size: 30),
                const SizedBox(width: 12),
                Expanded(child: Text('تثبيت ${widget.title}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
              ],
            ),
            const SizedBox(height: 18),
            if (_error == null) ...[
              LinearProgressIndicator(value: _progress, minHeight: 8, borderRadius: BorderRadius.circular(99)),
              const SizedBox(height: 10),
              Text(_progress == null ? _status : '$_status ${(_progress! * 100).round()}%', style: const TextStyle(color: AlphaColors.muted)),
              const SizedBox(height: 8),
              const Text('أول مرة: سيطلب أندرويد السماح بالتثبيت من Alpha، وافق ثم اضغط «تثبيت».',
                  style: TextStyle(color: AlphaColors.muted, fontSize: 12, height: 1.5)),
            ] else ...[
              Text(_error!, style: const TextStyle(color: AlphaColors.bad, height: 1.5)),
              const SizedBox(height: 14),
              OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
            ],
          ],
        ),
      );
}

/// A card on the home screen when a newer Alpha was built.
class AlphaUpdateCard extends StatelessWidget {
  const AlphaUpdateCard({super.key, required this.version});
  final String version;

  @override
  Widget build(BuildContext context) => GlassCard(
        gradient: LinearGradient(colors: [AlphaColors.teal.withValues(alpha: 0.3), AlphaColors.blue.withValues(alpha: 0.12)]),
        onTap: () => installFromRelease(context, prefix: 'alpha-v', title: 'Alpha $version'),
        child: Row(
          children: [
            const Icon(Icons.system_update_rounded, color: AlphaColors.teal, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تحديث جديد لـ Alpha', style: TextStyle(fontWeight: FontWeight.w800)),
                  Text('النسخة $version جاهزة. اضغط للتثبيت.', style: const TextStyle(color: AlphaColors.muted, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.download_rounded),
          ],
        ),
      );
}
