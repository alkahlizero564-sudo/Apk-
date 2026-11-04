import 'package:flutter/material.dart';

import '../config.dart';
import 'theme.dart';

/// The big gradient header at the top of the home screen.
class HeroHeader extends StatelessWidget {
  const HeroHeader({super.key, required this.config, required this.title, this.subtitle, this.trailing});
  final AlphaConfig config;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, MediaQuery.paddingOf(context).top + 18, 22, 26),
      decoration: BoxDecoration(
        gradient: brandGradient(config),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(config.radius + 14)),
        boxShadow: [BoxShadow(color: config.seed.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 12))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1.2)),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.icon, required this.label, required this.value, this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: cs.primary, size: 22),
              ),
              const SizedBox(height: 10),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 44, color: cs.primary),
            ),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15, height: 1.6)),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorBox extends StatelessWidget {
  const ErrorBox({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.cloud_off_rounded,
        text: message,
        action: OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
      );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key});
  final String text;

  Color _color(BuildContext context) {
    final t = text;
    if (RegExp('ملغي|مرفوض|cancel|reject').hasMatch(t)) return Colors.redAccent;
    if (RegExp('تم|وصل|مؤكد|done|deliver|confirm').hasMatch(t)) return Colors.green;
    if (RegExp('جديد|new|انتظار').hasMatch(t)) return Theme.of(context).colorScheme.primary;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final c = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

String formatValue(ColumnCfg c, dynamic v) {
  if (v == null) return '';
  switch (c.type) {
    case 'bool':
      return v == true || v == 'true' ? 'نعم' : 'لا';
    case 'decimal':
      final n = v is num ? v : num.tryParse('$v');
      if (n == null) return '$v';
      return n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);
    case 'datetime':
      final d = DateTime.tryParse('$v')?.toLocal();
      if (d == null) return '$v';
      return '${d.year}/${d.month}/${d.day}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    case 'date':
      final d = DateTime.tryParse('$v');
      return d == null ? '$v' : '${d.year}/${d.month}/${d.day}';
    default:
      return '$v';
  }
}

String timeAgo(DateTime d) {
  final s = DateTime.now().difference(d);
  if (s.inMinutes < 1) return 'الآن';
  if (s.inMinutes < 60) return 'قبل ${s.inMinutes} د';
  if (s.inHours < 24) return 'قبل ${s.inHours} س';
  if (s.inDays < 30) return 'قبل ${s.inDays} يوم';
  return '${d.year}/${d.month}/${d.day}';
}

void toast(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(text),
    backgroundColor: error ? Colors.red.shade700 : null,
  ));
}
