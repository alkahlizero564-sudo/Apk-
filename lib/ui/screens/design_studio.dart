import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state.dart';
import '../../app/theme.dart';
import '../../generator/presets.dart';
import '../../models/project.dart';
import '../../models/schema.dart';
import '../ai_design_card.dart';
import '../widgets.dart';
import 'preview.dart';

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

  ThemeSpec _copy({String? preset, String? seed, String? accent, String? mode, String? style, double? radius,
          String? hero, String? list, String? nav, String? deco}) =>
      theme.copyWith(preset: preset, seed: seed, accent: accent, mode: mode, style: style, radius: radius,
          hero: hero, list: list, nav: nav, deco: deco);

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
        const SectionTitle('مدرسة التصميم', subtitle: '٢٣ مدرسة، كل صورة من التطبيق الحقيقي. اختر واحدة ثم عدّل ما تريد'),
        for (var g = 0; g < lookGroups.length; g++) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Text(lookGroups[g], style: const TextStyle(color: AlphaColors.muted, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          SizedBox(
            height: 246,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final l in looks.where((l) => l.group == g))
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 10),
                    child: _LookCard(look: l, selected: (lookById(theme.school.isEmpty ? theme.look : theme.school)?.id) == l.id, onTap: () => onChanged(l.apply(theme))),
                  ),
              ],
            ),
          ),
        ],
        const SectionTitle('التخطيط'),
        _TokenChips(label: 'الشاشة الرئيسية', values: homeLayouts, value: theme.home, onPick: (v) => onChanged(theme.copyWith(home: v))),
        _TokenChips(label: 'القوائم', values: listStyles, value: theme.list, onPick: (v) => onChanged(_copy(list: v))),
        _TokenChips(label: 'شريط التنقل', values: navStyles, value: theme.nav, onPick: (v) => onChanged(_copy(nav: v))),
        _TokenChips(label: 'التفاصيل تفتح في', values: sheetStyles, value: theme.sheet, onPick: (v) => onChanged(theme.copyWith(sheet: v))),
        _TokenChips(label: 'الخط', values: fontChoices, value: theme.font, onPick: (v) => onChanged(theme.copyWith(font: v))),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: theme.onboarding,
          onChanged: (v) => onChanged(theme.copyWith(onboarding: v)),
          title: const Text('شاشات ترحيب عند أول فتح'),
          subtitle: const Text('Onboarding: صفحات تُسحب جانبياً تعرّف بالتطبيق', style: TextStyle(color: AlphaColors.muted, fontSize: 12)),
        ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('تفاصيل لتطبيقات Flutter و Kotlin و Python', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            children: [
              _TokenChips(label: 'شكل الرأس', values: heroShapes, value: theme.hero, onPick: (v) => onChanged(_copy(hero: v))),
              _TokenChips(label: 'البطاقات', values: cardStyles, value: theme.style, onPick: (v) => onChanged(_copy(style: v))),
              _TokenChips(label: 'خلفية', values: decoStyles, value: theme.deco, onPick: (v) => onChanged(_copy(deco: v))),
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
                onTap: () => onChanged(theme.copyWith(preset: p.id, seed: p.seed, accent: p.accent, mode: p.mode)),
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
  late AiDesign _design = AiDesign.fromJson(widget.project.design.toJson());
  bool _busy = false;

  Project _draft() => Project.fromJson(widget.project.toJson())
    ..theme = _theme
    ..design = _design
    ..headline = _headline.text.trim()
    ..subtitle = _subtitle.text.trim();

  Future<void> _save({bool build = false}) async {
    final s = context.read<AppState>();
    final p = widget.project
      ..theme = _theme
      ..design = _design
      ..headline = _headline.text.trim()
      ..subtitle = _subtitle.text.trim();
    setState(() => _busy = true);
    try {
      await s.save(p, message: 'Alpha: design of ${p.title}');
      if (build && s.hasGitHub) {
        if (_design.hasPrototype) {
          // The code is rewritten by the AI to match the approved design, then built.
          for (final a in p.apps) {
            await s.generateWithAi(a, buildFromDesignRequest);
          }
        } else {
          await s.buildAll(p);
        }
      }
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
              AiDesignCard(draft: _draft, onDesigned: (d) => setState(() => _design = d)),
              const SizedBox(height: 12),
              if (!_design.hasPrototype) ...[
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PreviewScreen(project: _draft()))),
                  icon: const Icon(Icons.play_circle_rounded, color: AlphaColors.teal),
                  label: const Text('معاينة فورية للتصميم'),
                ),
                const SizedBox(height: 12),
                DesignEditor(theme: _theme, title: p.title, schema: p.schema, pair: p.isPair, onChanged: (t) => setState(() => _theme = t)),
              ],
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

/// A school as its real screenshot (rendered from the engine) with its name and one line.
class _LookCard extends StatelessWidget {
  const _LookCard({required this.look, required this.selected, required this.onTap});
  final Look look;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 104,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 186,
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: selected ? AlphaColors.aurora : null,
                  color: selected ? null : AlphaColors.line,
                  boxShadow: selected ? [BoxShadow(color: hexColor(look.seed).withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6))] : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15.5),
                  child: Stack(fit: StackFit.expand, children: [
                    Image.asset(look.thumb, fit: BoxFit.cover, alignment: Alignment.topCenter,
                        errorBuilder: (_, _, _) => DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [hexColor(look.seed), hexColor(look.accent, AlphaColors.teal)])))),
                    if (selected)
                      const PositionedDirectional(top: 6, end: 6, child: CircleAvatar(radius: 11, backgroundColor: Colors.white, child: Icon(Icons.check_rounded, size: 16, color: Colors.black))),
                  ]),
                ),
              ),
              const SizedBox(height: 6),
              Text(look.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
              Text(look.hint, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AlphaColors.muted, fontSize: 10.5, height: 1.3)),
            ],
          ),
        ),
      );
}

/// One design token as a row of chips (e.g. the header shape).
class _TokenChips extends StatelessWidget {
  const _TokenChips({required this.label, required this.values, required this.value, required this.onPick});
  final String label;
  final Map<String, String> values;
  final String value;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AlphaColors.muted, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in values.entries)
                ChoiceChip(label: Text(e.value), selected: value == e.key, onSelected: (_) => onPick(e.key), visualDensity: VisualDensity.compact),
            ]),
          ],
        ),
      );
}
