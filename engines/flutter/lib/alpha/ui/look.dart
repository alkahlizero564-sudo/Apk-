// The visual language of the app, from the design tokens chosen in Alpha: surfaces (cards), the home header
// shape, background decoration and the bottom navigation style. Every screen draws through these helpers.
import 'dart:ui';

import 'package:flutter/material.dart';

import '../config.dart';
import 'theme.dart';

const ink = Color(0xFF0B0B0F);

bool _dark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

/// Page background for the card style (neumorphism and brutalism need their own).
Color pageColor(AlphaConfig c, bool dark) {
  if (c.style == 'neu') return dark ? const Color(0xFF1B1E2B) : const Color(0xFFE9EDF5);
  if (c.style == 'brutal' && !dark) return const Color(0xFFFFF8EC);
  return dark ? Color.lerp(const Color(0xFF0A0B14), c.seed, 0.05)! : const Color(0xFFF4F5FA);
}

/// The decoration of a card in the chosen style.
BoxDecoration surface(BuildContext context, AlphaConfig c, {bool highlight = false}) {
  final dark = _dark(context);
  final r = BorderRadius.circular(c.radius);
  if (highlight && c.style != 'brutal') {
    return BoxDecoration(
      gradient: brandGradient(c),
      borderRadius: r,
      boxShadow: [BoxShadow(color: c.seed.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 12))],
    );
  }
  switch (c.style) {
    case 'brutal':
      return BoxDecoration(
        color: highlight ? c.accent : (dark ? const Color(0xFF1C1C22) : Colors.white),
        borderRadius: r,
        border: Border.all(color: dark ? Colors.white : ink, width: 2.5),
        boxShadow: [BoxShadow(color: dark ? Colors.white : ink, offset: const Offset(5, 5))],
      );
    case 'neu':
      final bg = pageColor(c, dark);
      return BoxDecoration(
        color: bg,
        borderRadius: r,
        boxShadow: dark
            ? const [BoxShadow(color: Color(0xFF12141D), offset: Offset(8, 8), blurRadius: 16), BoxShadow(color: Color(0xFF242839), offset: Offset(-8, -8), blurRadius: 16)]
            : const [BoxShadow(color: Color(0xFFC9D0DC), offset: Offset(9, 9), blurRadius: 18), BoxShadow(color: Colors.white, offset: Offset(-9, -9), blurRadius: 18)],
      );
    case 'outline':
      return BoxDecoration(
        borderRadius: r,
        border: Border.all(color: dark ? c.seed.withValues(alpha: 0.45) : ink.withValues(alpha: 0.16), width: 1.5),
        boxShadow: dark ? [BoxShadow(color: c.seed.withValues(alpha: 0.22), blurRadius: 24, spreadRadius: -8, offset: const Offset(0, 10))] : null,
      );
    case 'flat':
      return BoxDecoration(color: dark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFEEF0F6), borderRadius: r);
    case 'soft':
      return BoxDecoration(
        color: dark ? const Color(0xFF151827) : Colors.white,
        borderRadius: r,
        boxShadow: [BoxShadow(color: (dark ? Colors.black : c.seed).withValues(alpha: dark ? 0.35 : 0.12), blurRadius: 30, offset: const Offset(0, 12))],
      );
    default: // glass
      return BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.07) : Colors.white.withValues(alpha: 0.75),
        borderRadius: r,
        border: Border.all(color: (dark ? Colors.white : ink).withValues(alpha: 0.09)),
      );
  }
}

/// A tappable surface in the chosen style.
class Surface extends StatelessWidget {
  const Surface({super.key, required this.config, required this.child, this.onTap, this.padding = const EdgeInsets.all(14), this.highlight = false, this.margin});
  final AlphaConfig config;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final bool highlight;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final deco = surface(context, config, highlight: highlight);
    Widget box = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(config.radius),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (config.style == 'glass' && !highlight) {
      box = ClipRRect(
        borderRadius: BorderRadius.circular(config.radius),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), child: box),
      );
    }
    return Container(margin: margin ?? const EdgeInsets.symmetric(vertical: 6), decoration: deco, child: box);
  }
}

/// Text color on top of the highlight surface.
Color onHighlight(AlphaConfig c) => c.style == 'brutal' ? ink : Colors.white;

/// Background decoration behind every screen.
class DecoBackground extends StatelessWidget {
  const DecoBackground({super.key, required this.config, required this.child});
  final AlphaConfig config;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = _dark(context);
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: pageColor(config, dark))),
        if (config.deco != 'none') Positioned.fill(child: CustomPaint(painter: _DecoPainter(config, dark))),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _DecoPainter extends CustomPainter {
  _DecoPainter(this.c, this.dark);
  final AlphaConfig c;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    switch (c.deco) {
      case 'dots':
        final p = Paint()..color = (dark ? Colors.white : ink).withValues(alpha: 0.12);
        for (double y = 8; y < size.height; y += 18) {
          for (double x = 8; x < size.width; x += 18) {
            canvas.drawCircle(Offset(x, y), 1.3, p);
          }
        }
      case 'grid':
        final p = Paint()
          ..color = (dark ? Colors.white : ink).withValues(alpha: 0.07)
          ..strokeWidth = 1;
        for (double y = 0; y < size.height; y += 28) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
        for (double x = 0; x < size.width; x += 28) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        }
      default: // blobs, glow
        final strength = c.deco == 'glow' ? 0.28 : 0.22;
        void glow(Offset o, double r, Color color) => canvas.drawCircle(
            o, r, Paint()..shader = RadialGradient(colors: [color.withValues(alpha: strength), color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: o, radius: r)));
        glow(Offset(size.width, 0), size.width * 0.9, c.seed);
        glow(Offset(0, size.height * 0.6), size.width * 0.8, c.accent);
    }
  }

  @override
  bool shouldRepaint(covariant _DecoPainter old) => old.c != c || old.dark != dark;
}

/// The home header in the chosen shape.
class LookHero extends StatelessWidget {
  const LookHero({super.key, required this.config, required this.title, this.subtitle, this.badge, this.icon});
  final AlphaConfig config;
  final String title;
  final String? subtitle;
  final String? badge;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = config;
    final top = MediaQuery.paddingOf(context).top;
    final dark = _dark(context);
    final plain = c.hero == 'minimal';
    final block = c.hero == 'block';
    final glow = c.hero == 'glow';
    final fg = plain ? Theme.of(context).colorScheme.onSurface : (block ? ink : Colors.white);
    final titleStyle = TextStyle(
      color: fg,
      fontSize: c.lightTitles ? 34 : (block ? 34 : 28),
      fontWeight: c.lightTitles ? FontWeight.w300 : FontWeight.w900,
      letterSpacing: c.lightTitles ? 0.6 : -0.3,
      height: 1.15,
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (badge != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: block ? c.accent : (plain ? c.seed.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.18)),
              borderRadius: BorderRadius.circular(99),
              border: block ? Border.all(color: ink, width: 2) : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) Icon(icon, size: 14, color: plain ? c.seed : fg),
              if (icon != null) const SizedBox(width: 6),
              Text(badge!, style: TextStyle(color: plain ? c.seed : fg, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        if (glow)
          ShaderMask(
            shaderCallback: (r) => LinearGradient(colors: [Colors.white, Color.lerp(Colors.white, c.accent, 0.6)!]).createShader(r),
            child: Text(title, style: titleStyle.copyWith(color: Colors.white)),
          )
        else
          Text(title, style: titleStyle),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: TextStyle(color: fg.withValues(alpha: plain ? 0.6 : 0.88), fontSize: 14)),
        ],
        if (plain) ...[
          const SizedBox(height: 18),
          Container(width: 48, height: 3, decoration: BoxDecoration(color: c.seed, borderRadius: BorderRadius.circular(3))),
        ],
      ],
    );

    if (c.hero == 'card') {
      return Padding(
        padding: EdgeInsets.fromLTRB(16, top + 14, 16, 0),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: brandGradient(c),
            borderRadius: BorderRadius.circular(c.radius + 8),
            boxShadow: [BoxShadow(color: c.seed.withValues(alpha: 0.32), blurRadius: 30, offset: const Offset(0, 16))],
          ),
          child: Stack(children: [
            PositionedDirectional(end: -40, bottom: -60, child: Transform.rotate(angle: 0.45, child: _square(160, Colors.white.withValues(alpha: 0.14)))),
            Padding(padding: const EdgeInsets.all(24), child: SizedBox(width: double.infinity, child: content)),
          ]),
        ),
      );
    }

    final padded = Padding(
      padding: EdgeInsets.fromLTRB(22, top + 26, 22, switch (c.hero) { 'wave' => 64, 'curve' => 54, 'diagonal' => 64, 'minimal' => 14, _ => 32 }),
      child: SizedBox(width: double.infinity, child: content),
    );

    final decorations = <Widget>[
      if (c.hero == 'blob') ...[
        PositionedDirectional(top: -90, end: -60, child: _circle(220, Colors.white.withValues(alpha: 0.16))),
        PositionedDirectional(bottom: -70, start: -30, child: _circle(140, Colors.white.withValues(alpha: 0.10))),
      ],
      if (c.hero == 'diagonal') PositionedDirectional(top: 20, end: -40, child: Transform.rotate(angle: 0.785, child: _square(180, Colors.transparent, border: Colors.white.withValues(alpha: 0.25)))),
      if (block) PositionedDirectional(bottom: 16, end: 18, child: Container(width: 54, height: 54, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle, border: Border.all(color: ink, width: 3)))),
      if (glow) ...[
        PositionedDirectional(top: -80, end: -60, child: _blurred(300, c.seed.withValues(alpha: 0.55))),
        PositionedDirectional(bottom: -100, start: -60, child: _blurred(240, c.accent.withValues(alpha: 0.35))),
      ],
    ];

    final Decoration bg = switch (c.hero) {
      'minimal' || 'glow' => const BoxDecoration(),
      'block' => BoxDecoration(color: c.seed, border: const Border(bottom: BorderSide(color: ink, width: 3))),
      'blob' => BoxDecoration(
          gradient: brandGradient(c),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(c.radius + 16)),
          boxShadow: [BoxShadow(color: c.seed.withValues(alpha: dark ? 0.25 : 0.38), blurRadius: 40, offset: const Offset(0, 18))],
        ),
      _ => BoxDecoration(gradient: brandGradient(c)),
    };

    Widget hero = Container(
      clipBehavior: c.hero == 'blob' ? Clip.antiAlias : Clip.none,
      decoration: bg,
      child: Stack(clipBehavior: Clip.hardEdge, children: [...decorations, padded]),
    );
    final clipper = switch (c.hero) {
      'wave' => _WaveClipper(),
      'curve' => _CurveClipper(),
      'diagonal' => _DiagonalClipper(),
      'glow' || 'block' || 'minimal' => _RectClipper(),
      _ => null,
    };
    if (clipper != null) hero = ClipPath(clipper: clipper, child: hero);
    return hero;
  }

  static Widget _circle(double s, Color color) => Container(width: s, height: s, decoration: BoxDecoration(color: color, shape: BoxShape.circle));

  static Widget _square(double s, Color color, {Color? border}) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(40), border: border == null ? null : Border.all(color: border, width: 2)),
      );

  static Widget _blurred(double s, Color color) =>
      ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60), child: _circle(s, color));
}

class _RectClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()..addRect(Offset.zero & s);
  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final h = s.height;
    return Path()
      ..lineTo(0, h - 30)
      ..cubicTo(s.width * 0.2, h + 10, s.width * 0.4, h - 52, s.width * 0.6, h - 26)
      ..cubicTo(s.width * 0.75, h - 6, s.width * 0.88, h - 8, s.width, h - 34)
      ..lineTo(s.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

class _CurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..lineTo(0, s.height - 40)
    ..quadraticBezierTo(s.width / 2, s.height + 30, s.width, s.height - 40)
    ..lineTo(s.width, 0)
    ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

class _DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..lineTo(0, s.height)
    ..lineTo(s.width, s.height * 0.74)
    ..lineTo(s.width, 0)
    ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

/// The bottom navigation in the chosen style: a classic bar, a floating bar, or a dark pill.
class LookNav extends StatelessWidget {
  const LookNav({super.key, required this.config, required this.items, required this.index, required this.onTap});
  final AlphaConfig config;
  final List<({IconData icon, String label, int badge})> items;
  final int index;
  final ValueChanged<int> onTap;

  Widget _icon(({IconData icon, String label, int badge}) i, Color color) =>
      i.badge > 0 ? Badge(label: Text('${i.badge}'), child: Icon(i.icon, color: color)) : Icon(i.icon, color: color);

  @override
  Widget build(BuildContext context) {
    final c = config;
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    if (c.navStyle == 'pill') {
      return Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, bottom + 14),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(99),
            boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 30, offset: Offset(0, 14))],
          ),
          child: Row(children: [
            for (var n = 0; n < items.length; n++)
              Expanded(
                flex: n == index ? 5 : 2,
                child: GestureDetector(
                  onTap: () => onTap(n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 46,
                    decoration: BoxDecoration(gradient: n == index ? brandGradient(c) : null, borderRadius: BorderRadius.circular(99)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _icon(items[n], n == index ? Colors.white : cs.surface.withValues(alpha: 0.7)),
                      if (n == index) ...[
                        const SizedBox(width: 6),
                        Flexible(child: Text(items[n].label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13))),
                      ],
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      );
    }
    final bar = NavigationBar(
      selectedIndex: index,
      onDestinationSelected: onTap,
      backgroundColor: c.navStyle == 'floating' ? Colors.transparent : null,
      elevation: 0,
      destinations: [for (final i in items) NavigationDestination(icon: _icon(i, cs.onSurfaceVariant), selectedIcon: _icon(i, cs.primary), label: i.label)],
    );
    if (c.navStyle != 'floating') {
      if (c.style == 'brutal') {
        return DecoratedBox(decoration: const BoxDecoration(border: Border(top: BorderSide(color: ink, width: 2.5))), child: bar);
      }
      return bar;
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottom + 12),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(c.radius + 8),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 30, offset: Offset(0, 14))],
        ),
        child: MediaQuery.removePadding(context: context, removeBottom: true, child: bar),
      ),
    );
  }
}
