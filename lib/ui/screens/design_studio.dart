import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state.dart';
import '../../app/theme.dart';
import '../../generator/presets.dart';
import '../../models/project.dart';
import '../../models/schema.dart';
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
          hero: hero, list: list, nav: nav, deco: deco, look: style != null || hero != null || list != null || nav != null || deco != null ? 'custom' : null);

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
        const SectionTitle('الطابع', subtitle: 'تصميم كامل: الأشكال والبطاقات والقوائم والتنقل معاً'),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: looks.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _LookCard(look: looks[i], selected: theme.look == looks[i].id, onTap: () => onChanged(looks[i].apply(theme))),
          ),
        ),
        const SectionTitle('تخصيص الطابع'),
        _TokenChips(label: 'شكل الرأس', values: heroShapes, value: theme.hero, onPick: (v) => onChanged(_copy(hero: v))),
        _TokenChips(label: 'البطاقات', values: cardStyles, value: theme.style, onPick: (v) => onChanged(_copy(style: v))),
        _TokenChips(label: 'القوائم', values: listStyles, value: theme.list, onPick: (v) => onChanged(_copy(list: v))),
        _TokenChips(label: 'شريط التنقل', values: navStyles, value: theme.nav, onPick: (v) => onChanged(_copy(nav: v))),
        _TokenChips(label: 'خلفية', values: decoStyles, value: theme.deco, onPick: (v) => onChanged(_copy(deco: v))),
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
              OutlinedButton.icon(
                onPressed: () {
                  final draft = Project.fromJson(p.toJson())
                    ..theme = _theme
                    ..headline = _headline.text.trim()
                    ..subtitle = _subtitle.text.trim();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => PreviewScreen(project: draft)));
                },
                icon: const Icon(Icons.play_circle_rounded, color: AlphaColors.teal),
                label: const Text('معاينة فورية للتصميم'),
              ),
              const SizedBox(height: 12),
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

/// A look as a small visual sample: its colors, header shape and card style.
class _LookCard extends StatelessWidget {
  const _LookCard({required this.look, required this.selected, required this.onTap});
  final Look look;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final seed = hexColor(look.seed);
    final accent = hexColor(look.accent, AlphaColors.teal);
    final dark = look.mode == 'dark';
    final bg = dark ? const Color(0xFF10121C) : (look.style == 'brutal' ? const Color(0xFFFFF8EC) : const Color(0xFFF2F4F9));
    final brutal = look.style == 'brutal';
    final r = look.radius * 0.5;
    Widget card(double w) => Container(
          width: w,
          height: 18,
          decoration: BoxDecoration(
            color: look.style == 'outline' ? Colors.transparent : (dark ? Colors.white.withValues(alpha: 0.09) : Colors.white),
            borderRadius: BorderRadius.circular(r * 0.6),
            border: brutal
                ? Border.all(color: Colors.black, width: 1.5)
                : (look.style == 'outline' ? Border.all(color: dark ? seed.withValues(alpha: 0.6) : Colors.black26) : null),
            boxShadow: brutal
                ? const [BoxShadow(color: Colors.black, offset: Offset(2, 2))]
                : look.style == 'neu'
                    ? const [BoxShadow(color: Color(0xFFC9D0DC), offset: Offset(3, 3), blurRadius: 5), BoxShadow(color: Colors.white, offset: Offset(-3, -3), blurRadius: 5)]
                    : look.style == 'soft'
                        ? [BoxShadow(color: seed.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 3))]
                        : null,
          ),
        );
    final header = switch (look.hero) {
      'minimal' => Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 50, height: 7, color: dark ? Colors.white70 : Colors.black87),
            const SizedBox(height: 5),
            Container(width: 16, height: 2, color: seed),
          ]),
        ),
      'card' => Container(
          margin: const EdgeInsets.all(7),
          height: 32,
          decoration: BoxDecoration(gradient: LinearGradient(colors: [seed, accent]), borderRadius: BorderRadius.circular(r)),
        ),
      'block' => Container(height: 40, decoration: BoxDecoration(color: seed, border: const Border(bottom: BorderSide(color: Colors.black, width: 2)))),
      'glow' => SizedBox(
          height: 40,
          child: Stack(children: [
            Positioned(top: -20, right: -10, child: Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, color: seed.withValues(alpha: 0.6), boxShadow: [BoxShadow(color: seed, blurRadius: 30)]))),
          ]),
        ),
      _ => ClipPath(
          clipper: _MiniClipper(look.hero),
          child: Container(height: 44, decoration: BoxDecoration(gradient: LinearGradient(colors: [seed, accent]))),
        ),
    };
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 112,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? Colors.white : AlphaColors.line, width: selected ? 2.5 : 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            color: bg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [card(94), const SizedBox(height: 5), card(70)]),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  color: Colors.black.withValues(alpha: 0.55),
                  child: Text(look.name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniClipper extends CustomClipper<Path> {
  _MiniClipper(this.shape);
  final String shape;

  @override
  Path getClip(Size s) {
    final p = Path();
    switch (shape) {
      case 'wave':
        p
          ..lineTo(0, s.height - 8)
          ..cubicTo(s.width * 0.3, s.height + 4, s.width * 0.6, s.height - 16, s.width, s.height - 6)
          ..lineTo(s.width, 0);
      case 'diagonal':
        p
          ..lineTo(0, s.height)
          ..lineTo(s.width, s.height * 0.6)
          ..lineTo(s.width, 0);
      case 'curve':
        p
          ..lineTo(0, s.height - 10)
          ..quadraticBezierTo(s.width / 2, s.height + 8, s.width, s.height - 10)
          ..lineTo(s.width, 0);
      default:
        p.addRRect(RRect.fromRectAndCorners(Offset.zero & s, bottomLeft: const Radius.circular(14), bottomRight: const Radius.circular(14)));
        return p;
    }
    return p..close();
  }

  @override
  bool shouldReclip(covariant _MiniClipper old) => old.shape != shape;
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
