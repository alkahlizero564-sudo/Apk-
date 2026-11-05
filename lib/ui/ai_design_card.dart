import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/state.dart';
import '../app/theme.dart';
import '../models/project.dart';
import 'screens/preview.dart';
import 'widgets.dart';

/// Design first (like APK Fact): the AI draws each app as a clickable prototype of ALL its screens, following a
/// professional design standard; the owner opens it full screen, asks for changes in words, undoes, or starts over.
/// The approved prototype is what the real app is then written from, in any language.
class AiDesignCard extends StatefulWidget {
  const AiDesignCard({super.key, required this.draft, required this.onDesigned, this.autoStart = false});

  /// The project as it would be saved now (its understanding, data, sign-in, apps).
  final Project Function() draft;
  final ValueChanged<AiDesign> onDesigned;
  final bool autoStart;

  @override
  State<AiDesignCard> createState() => _AiDesignCardState();
}

class _AiDesignCardState extends State<AiDesignCard> {
  bool _busy = false;
  String _status = '';
  String _app = '';
  final _change = TextEditingController();
  final Map<String, List<String>> _history = {}; // per app, for «تراجع»

  @override
  void initState() {
    super.initState();
    final p = widget.draft();
    _app = p.apps.isEmpty ? p.base : p.apps.first.slug;
    if (widget.autoStart && !p.design.hasPrototype) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final ai = await context.read<AppState>().ai();
        if (mounted && ai.available) _designAll();
      });
    }
  }

  AiDesign _copy(Project p) => AiDesign.fromJson(p.design.toJson());

  void _push(String slug, String html) {
    final h = _history.putIfAbsent(slug, () => []);
    h.add(html);
    if (h.length > 6) h.removeAt(0);
  }

  /// Every app of the project; for a pair the admin app takes the customer app's brand.
  Future<void> _designAll() async {
    final s = context.read<AppState>();
    final ai = await s.ai();
    if (!ai.available) {
      if (mounted) showMessage(context, 'أضف مفتاح Claude أو Gemini في الإعدادات', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      var p = widget.draft();
      final d = _copy(p);
      var brand = '';
      for (final a in p.apps) {
        setState(() => _status = p.apps.length > 1 ? 'يصمّم ${a.roleLabel}…' : 'يصمّم كل الشاشات…');
        final old = d.screens[a.slug] ?? '';
        if (old.isNotEmpty) _push(a.slug, old);
        final html = await ai.designPrototype(p, a, brandFrom: brand, change: _change.text.trim());
        d.screens[a.slug] = html;
        brand = brand.isEmpty ? html : brand;
        widget.onDesigned(d);
        p = widget.draft();
      }
      _change.clear();
      if (mounted) _open();
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// One app's design changed as the owner wrote.
  Future<void> _revise() async {
    final text = _change.text.trim();
    if (text.isEmpty) return showMessage(context, 'اكتب ما تريد تغييره في التصميم', error: true);
    final ai = await context.read<AppState>().ai();
    final p = widget.draft();
    final app = p.apps.firstWhere((a) => a.slug == _app, orElse: () => p.apps.first);
    final current = p.design.screens[app.slug] ?? '';
    setState(() {
      _busy = true;
      _status = 'يعدّل التصميم…';
    });
    try {
      final html = await ai.designPrototype(p, app, current: current, change: text);
      _push(app.slug, current);
      final d = _copy(p)..screens[app.slug] = html;
      widget.onDesigned(d);
      _change.clear();
      if (mounted) _open();
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _undo() {
    final h = _history[_app];
    if (h == null || h.isEmpty) return;
    final d = _copy(widget.draft())..screens[_app] = h.removeLast();
    widget.onDesigned(d);
    setState(() {});
  }

  void _open() {
    final p = widget.draft();
    final i = p.apps.indexWhere((a) => a.slug == _app);
    // The preview opens on the chosen app (a pair can switch apps inside it).
    final ordered = Project.fromJson(p.toJson());
    if (i > 0) ordered.apps.insert(0, ordered.apps.removeAt(i));
    Navigator.push(context, MaterialPageRoute(builder: (_) => PreviewScreen(project: ordered)));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.draft();
    final has = p.design.hasPrototype;
    final native = p.lang == Lang.flutter || p.lang == Lang.python || p.lang == Lang.kotlin;
    return GlassCard(
      gradient: LinearGradient(colors: [AlphaColors.violet.withValues(alpha: 0.32), AlphaColors.pink.withValues(alpha: 0.12)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(children: [
            Icon(Icons.auto_awesome_rounded, color: AlphaColors.amber),
            SizedBox(width: 8),
            Expanded(child: Text('التصميم أولاً: الذكاء الاصطناعي يرسم التطبيق', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          ]),
          const SizedBox(height: 6),
          Text(
            'يرسم كل شاشات ${p.isPair ? 'التطبيقين' : 'التطبيق'} كنموذج تضغط عليه وتتنقل فيه: الشاشات الخاصة بفكرتك، بيانات واقعية، '
            'وحالات الفراغ والتحميل، بمعايير تصميم احترافية${native ? ' (Material 3 كما سيكون في ${p.lang.label})' : ''}. '
            'راجعه وعدّله بالكلام، وعند الإنشاء يُكتب التطبيق الحقيقي ليطابقه تماماً.',
            style: const TextStyle(color: AlphaColors.muted, fontSize: 12.5, height: 1.6),
          ),
          const SizedBox(height: 12),
          if (_busy)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(_status, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('قد يأخذ دقيقة أو دقيقتين', style: TextStyle(color: AlphaColors.muted, fontSize: 12)),
              ]),
            )
          else if (!has) ...[
            TextField(
              controller: _change,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'ملاحظات للتصميم (اختياري): ألوان، أسلوب، شاشة مهمة…'),
            ),
            const SizedBox(height: 10),
            GradientButton(label: 'صمّم التطبيق بالذكاء الاصطناعي', icon: Icons.brush_rounded, onPressed: _designAll),
          ] else ...[
            if (p.apps.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SegmentedButton<String>(
                  segments: [for (final a in p.apps) ButtonSegment(value: a.slug, label: Text(a.roleLabel))],
                  selected: {_app},
                  onSelectionChanged: (v) => setState(() => _app = v.first),
                ),
              ),
            FilledButton.icon(
              onPressed: _open,
              icon: const Icon(Icons.fullscreen_rounded),
              label: const Text('افتح التصميم وجرّبه'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: AlphaColors.teal, foregroundColor: Colors.black),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _change,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'عدّل التصميم بالكلام: مثلاً اجعل الرئيسية فيها عروض، ألوان أغمق، زر الطلب أكبر…'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _revise,
                  icon: const Icon(Icons.edit_rounded, color: AlphaColors.amber),
                  label: const Text('عدّل'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'تراجع',
                onPressed: (_history[_app]?.isNotEmpty ?? false) ? _undo : null,
                icon: const Icon(Icons.undo_rounded),
              ),
              const SizedBox(width: 4),
              IconButton.outlined(tooltip: 'صمّم من جديد', onPressed: _designAll, icon: const Icon(Icons.refresh_rounded)),
            ]),
            TextButton(
              onPressed: () => widget.onDesigned(AiDesign()),
              child: const Text('بدون تصميم بالذكاء (مدرسة تصميم جاهزة)'),
            ),
          ],
        ],
      ),
    );
  }
}
