import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/state.dart';
import '../app/theme.dart';
import '../models/project.dart';
import 'screens/preview.dart';
import 'widgets.dart';

/// The AI designs the whole interface from the description; the owner previews it at once and asks for changes.
/// HTML / PHP: the preview is the real app. Flutter / Python / Kotlin: the preview is the AI's mockup and the real code is
/// written to match it when the app is built.
class AiDesignCard extends StatefulWidget {
  const AiDesignCard({super.key, required this.draft, required this.brief, required this.onDesigned, required this.onClear, this.autoStart = false});

  /// The project as it would be saved now (for the AI's context and the preview).
  final Project Function() draft;
  final String brief;
  final void Function(AiDesign design, ThemeSpec theme, String headline, String subtitle) onDesigned;
  final VoidCallback onClear;
  final bool autoStart;

  @override
  State<AiDesignCard> createState() => _AiDesignCardState();
}

class _AiDesignCardState extends State<AiDesignCard> {
  bool _busy = false;
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.autoStart && widget.draft().design.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final ai = await context.read<AppState>().ai();
        if (mounted && ai.available) _design();
      });
    }
  }

  Future<void> _design() async {
    final ai = await context.read<AppState>().ai();
    if (!ai.available) {
      if (mounted) showMessage(context, 'أضف مفتاح Claude أو Gemini في الإعدادات', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final p = widget.draft();
      final r = await ai.designUi(widget.brief.isEmpty ? p.description : widget.brief, p, note: _note.text.trim(), previous: p.design);
      if (!mounted) return;
      widget.onDesigned(r.design, r.theme, r.headline, r.subtitle);
      _note.clear();
      _preview();
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _preview() => Navigator.push(context, MaterialPageRoute(builder: (_) => PreviewScreen(project: widget.draft())));

  @override
  Widget build(BuildContext context) {
    final p = widget.draft();
    final d = p.design;
    final native = p.lang == Lang.flutter || p.lang == Lang.python || p.lang == Lang.kotlin;
    return GlassCard(
      gradient: LinearGradient(colors: [AlphaColors.violet.withValues(alpha: 0.32), AlphaColors.pink.withValues(alpha: 0.12)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(children: [
            Icon(Icons.auto_awesome_rounded, color: AlphaColors.amber),
            SizedBox(width: 8),
            Expanded(child: Text('واجهات يصمّمها الذكاء الاصطناعي', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          ]),
          const SizedBox(height: 6),
          Text(
            native
                ? 'يصمّم كل الشاشات من وصفك كمصمم خبير (ألوان، خطوط، أشكال، حركة). ترى معاينة فورية للشكل الآن، وعند البناء يكتب الذكاء الاصطناعي كود ${p.lang.label} بنفس التصميم.'
                : 'يصمّم كل الشاشات من وصفك كمصمم خبير (ألوان، خطوط، أشكال، حركة بمكتبات GSAP و AOS وغيرها). المعاينة الفورية هي التطبيق الحقيقي.',
            style: const TextStyle(color: AlphaColors.muted, fontSize: 12.5, height: 1.6),
          ),
          const SizedBox(height: 12),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Column(children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('يصمّم الواجهات… قد يأخذ دقيقة', style: TextStyle(fontWeight: FontWeight.w700)),
              ]),
            )
          else if (d.isEmpty)
            GradientButton(label: 'صمّم الواجهات بالذكاء الاصطناعي', icon: Icons.brush_rounded, onPressed: _design)
          else ...[
            if (d.summary.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
                child: Text(d.summary, style: const TextStyle(height: 1.6)),
              ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _preview,
              icon: const Icon(Icons.play_circle_rounded),
              label: Text(native ? 'معاينة فورية للشكل (بالذكاء الاصطناعي)' : 'معاينة فورية'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: AlphaColors.teal, foregroundColor: Colors.black),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'تريد شيئاً مختلفاً؟ مثلاً: أغمق، ألوان ذهبية، بطاقات أكبر، حركة أكثر'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _design,
                  icon: const Icon(Icons.refresh_rounded, color: AlphaColors.amber),
                  label: const Text('صمّم من جديد'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: widget.onClear, child: const Text('مدرسة جاهزة بدلاً منه')),
            ]),
          ],
        ],
      ),
    );
  }
}
