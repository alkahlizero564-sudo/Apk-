import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state.dart';
import '../../app/theme.dart';
import '../../generator/presets.dart';
import '../../models/project.dart';
import '../../models/schema.dart';
import '../widgets.dart';

const _swatches = [
  '#6E4BFF', '#7C3AED', '#4F46E5', '#2563EB', '#0EA5E9', '#06B6D4', '#14B8A6', '#10B981', '#22C55E', '#84CC16',
  '#EAB308', '#F59E0B', '#F97316', '#EF4444', '#E11D48', '#EC4899', '#D946EF', '#78716C', '#334155', '#18181B',
];

/// Colors, mode, style and corner radius of the generated apps, with a live phone preview.
class DesignEditor extends StatelessWidget {
  const DesignEditor({super.key, required this.theme, required this.title, required this.schema, required this.onChanged, this.pair = false});
  final ThemeSpec theme;
  final String title;
  final DbSchema schema;
  final bool pair;
  final ValueChanged<ThemeSpec> onChanged;

  ThemeSpec _copy({String? preset, String? seed, String? accent, String? mode, String? style, double? radius, String? layout}) => ThemeSpec(
        preset: preset ?? theme.preset,
        seed: seed ?? theme.seed,
        accent: accent ?? theme.accent,
        mode: mode ?? theme.mode,
        style: style ?? theme.style,
        radius: radius ?? theme.radius,
        layout: layout ?? theme.layout,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Wrap(
            spacing: 12,
            alignment: WrapAlignment.center,
            children: [
              PhonePreview(theme: theme, title: title, schema: schema, role: pair ? 'customer' : 'single', width: pair ? 150 : 200),
              if (pair) PhonePreview(theme: theme, title: '$title - الإدارة', schema: schema, role: 'admin', width: 150),
            ],
          ),
        ),
        const SectionTitle('قوالب الألوان'),
        SizedBox(
          height: 86,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: themePresets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final p = themePresets[i];
              final on = theme.preset == p.id;
              return GestureDetector(
                onTap: () => onChanged(p.toSpec(radius: theme.radius, layout: theme.layout)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 78,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [hexColor(p.seed), hexColor(p.accent)]),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: on ? Colors.white : Colors.transparent, width: 2.5),
                  ),
                  alignment: AlignmentDirectional.bottomStart,
                  padding: const EdgeInsets.all(8),
                  child: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              );
            },
          ),
        ),
        const SectionTitle('اللون الأساسي'),
        _Swatches(value: theme.seed, onPick: (c) => onChanged(_copy(seed: c, preset: 'custom'))),
        const SectionTitle('اللون الثاني (التدرّج)'),
        _Swatches(value: theme.accent, onPick: (c) => onChanged(_copy(accent: c, preset: 'custom'))),
        const SectionTitle('الوضع'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'dark', label: Text('داكن'), icon: Icon(Icons.dark_mode_rounded)),
            ButtonSegment(value: 'light', label: Text('فاتح'), icon: Icon(Icons.light_mode_rounded)),
            ButtonSegment(value: 'system', label: Text('حسب الهاتف'), icon: Icon(Icons.brightness_auto_rounded)),
          ],
          selected: {theme.mode},
          onSelectionChanged: (v) => onChanged(_copy(mode: v.first)),
        ),
        const SectionTitle('أسلوب البطاقات'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'glass', label: Text('زجاجي')),
            ButtonSegment(value: 'soft', label: Text('ناعم بظل')),
            ButtonSegment(value: 'flat', label: Text('مسطّح')),
          ],
          selected: {theme.style},
          onSelectionChanged: (v) => onChanged(_copy(style: v.first)),
        ),
        SectionTitle('استدارة الزوايا', trailing: Text('${theme.radius.round()}', style: const TextStyle(color: AlphaColors.muted))),
        Slider(value: theme.radius, min: 4, max: 32, divisions: 28, onChanged: (v) => onChanged(_copy(radius: v))),
      ],
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({required this.value, required this.onPick});
  final String value;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final c in _swatches)
            GestureDetector(
              onTap: () => onPick(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: hexColor(c),
                  shape: BoxShape.circle,
                  border: Border.all(color: value.toUpperCase() == c ? Colors.white : Colors.white12, width: value.toUpperCase() == c ? 3 : 1),
                ),
                child: value.toUpperCase() == c ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
              ),
            ),
        ],
      );
}

/// The design of an existing project; saving commits it and the next build uses it.
class DesignStudioScreen extends StatefulWidget {
  const DesignStudioScreen({super.key, required this.project});
  final Project project;

  @override
  State<DesignStudioScreen> createState() => _DesignStudioScreenState();
}

class _DesignStudioScreenState extends State<DesignStudioScreen> {
  late ThemeSpec _theme = ThemeSpec.fromJson(widget.project.theme.toJson());
  late final _headline = TextEditingController(text: widget.project.headline);
  late final _subtitle = TextEditingController(text: widget.project.subtitle);
  bool _busy = false;

  Future<void> _save({bool build = false}) async {
    final s = context.read<AppState>();
    final p = widget.project
      ..theme = _theme
      ..headline = _headline.text.trim()
      ..subtitle = _subtitle.text.trim();
    setState(() => _busy = true);
    try {
      await s.save(p, message: 'Alpha: design of ${p.title}');
      if (build && s.hasGitHub) await s.buildAll(p);
      if (!mounted) return;
      showMessage(context, build ? 'حُفظ التصميم وبدأ البناء' : 'حُفظ التصميم');
      Navigator.pop(context);
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
      appBar: AppBar(title: const Text('استوديو التصميم')),
      body: AuroraBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
            children: [
              DesignEditor(theme: _theme, title: p.title, schema: p.schema, pair: p.isPair, onChanged: (t) => setState(() => _theme = t)),
              const SectionTitle('نصوص الواجهة الرئيسية'),
              TextField(controller: _headline, decoration: const InputDecoration(labelText: 'العنوان الكبير (اختياري)')),
              const SizedBox(height: 10),
              TextField(controller: _subtitle, decoration: const InputDecoration(labelText: 'السطر الثاني (اختياري)')),
              const SizedBox(height: 20),
              GradientButton(label: 'احفظ وابنِ', icon: Icons.rocket_launch_rounded, busy: _busy, onPressed: () => _save(build: true)),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: _busy ? null : () => _save(), child: const Text('احفظ فقط')),
            ],
          ),
        ),
      ),
    );
  }
}
