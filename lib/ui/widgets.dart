import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/project.dart';
import '../models/schema.dart';

/// Background with soft aurora glows behind every screen.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: AlphaColors.bg)),
        Positioned(top: -120, right: -80, child: _glow(AlphaColors.violet, 320)),
        Positioned(top: 160, left: -140, child: _glow(AlphaColors.teal, 280)),
        Positioned(bottom: -120, right: -60, child: _glow(AlphaColors.blue, 300)),
        Positioned.fill(child: child),
      ],
    );
  }

  Widget _glow(Color c, double size) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [c.withValues(alpha: 0.28), c.withValues(alpha: 0)]),
          ),
        ),
      );
}

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.gradient, this.margin});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  gradient: gradient,
                  color: gradient == null ? Colors.white.withValues(alpha: 0.045) : null,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AlphaColors.line),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed, this.icon, this.busy = false, this.gradient = AlphaColors.aurora});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.55,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AlphaColors.violet.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 8))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
                          Flexible(
                            child: Text(label,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.subtitle});
  final String text;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!, style: const TextStyle(color: AlphaColors.muted, fontSize: 13)),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      );
}

class LangBadge extends StatelessWidget {
  const LangBadge(this.lang, {super.key, this.big = false});
  final Lang lang;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final c = Color(lang.color);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: big ? 12 : 8, vertical: big ? 6 : 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(99), border: Border.all(color: c.withValues(alpha: 0.4))),
      child: Text(lang.label, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: big ? 14 : 11)),
    );
  }
}

IconData langIcon(Lang l) => switch (l) {
      Lang.html => Icons.html_rounded,
      Lang.php => Icons.dns_rounded,
      Lang.flutter => Icons.flutter_dash_rounded,
      Lang.python => Icons.terminal_rounded,
      Lang.kotlin => Icons.android_rounded,
    };

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = AlphaColors.violet, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(99)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
            Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      );
}

/// The Alpha mark: an "α" in an aurora rounded square.
class AlphaLogo extends StatelessWidget {
  const AlphaLogo({super.key, this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: AlphaColors.aurora,
          borderRadius: BorderRadius.circular(size * 0.3),
          boxShadow: [BoxShadow(color: AlphaColors.violet.withValues(alpha: 0.5), blurRadius: size * 0.5, offset: Offset(0, size * 0.12))],
        ),
        alignment: Alignment.center,
        child: Text('α', style: TextStyle(color: Colors.white, fontSize: size * 0.6, fontWeight: FontWeight.w900, height: 1.05, fontFamily: 'Tajawal')),
      );
}

Color hexColor(String hex, [Color fallback = AlphaColors.violet]) {
  final h = hex.replaceAll('#', '');
  final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return v == null ? fallback : Color(v);
}

String colorHex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

IconData tableIcon(String name) => switch (name) {
      'shopping_bag' => Icons.shopping_bag_rounded,
      'receipt' => Icons.receipt_long_rounded,
      'star' => Icons.star_rounded,
      'restaurant' => Icons.restaurant_rounded,
      'delivery' => Icons.delivery_dining_rounded,
      'medical' => Icons.medical_services_rounded,
      'calendar' => Icons.calendar_month_rounded,
      'event' => Icons.event_available_rounded,
      'place' => Icons.place_rounded,
      'school' => Icons.school_rounded,
      'campaign' => Icons.campaign_rounded,
      'book' => Icons.menu_book_rounded,
      'chat' => Icons.chat_bubble_rounded,
      'person' => Icons.person_rounded,
      'wallet' => Icons.account_balance_wallet_rounded,
      'checklist' => Icons.checklist_rounded,
      'home' => Icons.home_rounded,
      'settings' => Icons.settings_rounded,
      'car' => Icons.directions_car_rounded,
      'phone' => Icons.phone_rounded,
      'photo' => Icons.photo_rounded,
      'store' => Icons.storefront_rounded,
      'work' => Icons.work_rounded,
      'payments' => Icons.payments_rounded,
      'add' => Icons.add_rounded,
      _ => Icons.view_list_rounded,
    };

/// A live miniature of the app being designed: the look's header shape, cards, list style and bottom bar.
class PhonePreview extends StatelessWidget {
  const PhonePreview({super.key, required this.theme, required this.title, required this.schema, this.role = 'single', this.width = 220});
  final ThemeSpec theme;
  final String title;
  final DbSchema schema;
  final String role;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final seed = hexColor(t.seed);
    final accent = hexColor(t.accent, AlphaColors.teal);
    final dark = t.mode != 'light';
    final brutal = t.style == 'brutal';
    final ink = const Color(0xFF0B0B0F);
    final bg = t.style == 'neu'
        ? (dark ? const Color(0xFF1B1E2B) : const Color(0xFFE9EDF5))
        : brutal && !dark
            ? const Color(0xFFFFF8EC)
            : (dark ? Color.lerp(const Color(0xFF0A0B14), seed, 0.06)! : const Color(0xFFF4F5FA));
    final text = dark ? Colors.white : const Color(0xFF0F172A);
    final muted = dark ? Colors.white60 : Colors.black54;
    final s = width / 220;
    final r = t.radius * s * 0.55;
    final tables = schema.tables.where((x) => role == 'admin' || x.owner != TableOwner.admin).toList();
    final first = tables.isEmpty ? null : tables.first;

    BoxDecoration card({bool highlight = false}) {
      if (highlight && !brutal) return BoxDecoration(gradient: LinearGradient(colors: [seed, accent]), borderRadius: BorderRadius.circular(r));
      return switch (t.style) {
        'brutal' => BoxDecoration(color: highlight ? accent : Colors.white, borderRadius: BorderRadius.circular(r * 0.5),
            border: Border.all(color: ink, width: 1.4 * s), boxShadow: [BoxShadow(color: ink, offset: Offset(2.5 * s, 2.5 * s))]),
        'neu' => BoxDecoration(color: bg, borderRadius: BorderRadius.circular(r), boxShadow: dark
            ? const [BoxShadow(color: Color(0xFF12141D), offset: Offset(3, 3), blurRadius: 6), BoxShadow(color: Color(0xFF242839), offset: Offset(-3, -3), blurRadius: 6)]
            : const [BoxShadow(color: Color(0xFFC9D0DC), offset: Offset(3, 3), blurRadius: 6), BoxShadow(color: Colors.white, offset: Offset(-3, -3), blurRadius: 6)]),
        'outline' => BoxDecoration(borderRadius: BorderRadius.circular(r), border: Border.all(color: dark ? seed.withValues(alpha: 0.6) : Colors.black26, width: s)),
        'soft' => BoxDecoration(color: dark ? const Color(0xFF151827) : Colors.white, borderRadius: BorderRadius.circular(r),
            boxShadow: [BoxShadow(color: seed.withValues(alpha: 0.16), blurRadius: 10, offset: const Offset(0, 4))]),
        'flat' => BoxDecoration(color: dark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE9ECF3), borderRadius: BorderRadius.circular(r)),
        _ => BoxDecoration(color: dark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(r),
            border: Border.all(color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.08))),
      };
    }

    Widget bar(double w, Color c, [double h = 5]) => Container(width: w * s, height: h * s, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)));

    // Header
    final plain = t.hero == 'minimal';
    final headerText = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(title.isEmpty ? 'تطبيقي' : title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: plain ? text : (t.hero == 'block' ? ink : Colors.white), fontWeight: t.type == 'light' ? FontWeight.w300 : FontWeight.w900, fontSize: 15 * s)),
      SizedBox(height: 2 * s),
      Text(role == 'admin' ? 'لوحة التحكم' : 'أهلاً بك', style: TextStyle(color: plain ? muted : Colors.white70, fontSize: 9 * s)),
      if (plain) ...[SizedBox(height: 6 * s), bar(18, seed, 2.5)],
    ]);
    Widget header = switch (t.hero) {
      'minimal' => Padding(padding: EdgeInsets.fromLTRB(14 * s, 26 * s, 14 * s, 8 * s), child: headerText),
      'card' => Container(
          margin: EdgeInsets.fromLTRB(8 * s, 22 * s, 8 * s, 0),
          padding: EdgeInsets.all(12 * s),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [seed, accent]), borderRadius: BorderRadius.circular(r + 4 * s)),
          child: SizedBox(width: double.infinity, child: headerText)),
      'block' => Container(
          padding: EdgeInsets.fromLTRB(14 * s, 26 * s, 14 * s, 14 * s),
          decoration: BoxDecoration(color: seed, border: Border(bottom: BorderSide(color: ink, width: 1.6 * s))),
          child: SizedBox(width: double.infinity, child: headerText)),
      'glow' => Stack(clipBehavior: Clip.hardEdge, children: [
          Positioned(top: -30 * s, right: -20 * s, child: Container(width: 110 * s, height: 110 * s, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [seed.withValues(alpha: 0.7), seed.withValues(alpha: 0)])))),
          Padding(padding: EdgeInsets.fromLTRB(14 * s, 26 * s, 14 * s, 14 * s), child: SizedBox(width: double.infinity, child: headerText)),
        ]),
      _ => ClipPath(
          clipper: _PreviewHeaderClipper(t.hero),
          child: Container(
            padding: EdgeInsets.fromLTRB(14 * s, 26 * s, 14 * s, (t.hero == 'blob' ? 16 : 28) * s),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [seed, Color.lerp(seed, accent, 0.75)!])),
            child: SizedBox(width: double.infinity, child: headerText),
          ),
        ),
    };

    // Rows
    Widget row(int i) => Container(
          margin: EdgeInsets.symmetric(vertical: 3 * s, horizontal: 3 * s),
          padding: EdgeInsets.all(6 * s),
          decoration: t.list == 'compact' ? null : card(),
          child: Row(children: [
            Container(
              width: 22 * s,
              height: 22 * s,
              decoration: BoxDecoration(
                  color: brutal ? accent : seed.withValues(alpha: 0.15),
                  shape: t.list == 'compact' ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: t.list == 'compact' ? null : BorderRadius.circular(6 * s),
                  border: brutal ? Border.all(color: ink, width: s) : null),
              child: Icon(tableIcon(first?.icon ?? 'list'), color: brutal ? ink : seed, size: 11 * s),
            ),
            SizedBox(width: 6 * s),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bar(56, text.withValues(alpha: 0.75)), SizedBox(height: 3 * s), bar(36, muted.withValues(alpha: 0.5), 4)])),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5 * s, vertical: 2 * s),
              decoration: BoxDecoration(color: seed.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(99)),
              child: Text(['جديد', 'تم', 'مؤكد'][i % 3], style: TextStyle(color: seed, fontSize: 7 * s, fontWeight: FontWeight.w800)),
            ),
          ]),
        );
    Widget gridCell() => Expanded(
          child: Container(
            margin: EdgeInsets.all(3 * s),
            height: 58 * s,
            clipBehavior: Clip.antiAlias,
            decoration: card(),
            child: Column(children: [
              Expanded(child: Container(width: double.infinity, decoration: BoxDecoration(gradient: LinearGradient(colors: [seed.withValues(alpha: 0.25), accent.withValues(alpha: 0.25)])),
                  child: Icon(tableIcon(first?.icon ?? 'list'), color: seed, size: 14 * s))),
              Padding(padding: EdgeInsets.all(4 * s), child: bar(30, text.withValues(alpha: 0.7), 4)),
            ]),
          ),
        );
    final list = first == null
        ? <Widget>[Padding(padding: EdgeInsets.all(10 * s), child: Text('أضف جداول', style: TextStyle(color: muted, fontSize: 10 * s)))]
        : t.list == 'grid'
            ? [Row(children: [gridCell(), gridCell()]), Row(children: [gridCell(), gridCell()])]
            : t.list == 'compact'
                ? [Container(margin: EdgeInsets.all(3 * s), decoration: card(), child: Column(children: [row(0), Divider(height: 1, color: muted.withValues(alpha: 0.2)), row(1), Divider(height: 1, color: muted.withValues(alpha: 0.2)), row(2)]))]
                : [for (var i = 0; i < 3; i++) row(i)];

    // Bottom bar
    final icons = [Icons.space_dashboard_rounded, for (final x in tables.take(2)) tableIcon(x.icon), Icons.person_rounded];
    Widget nav;
    if (t.nav == 'pill') {
      nav = Container(
        margin: EdgeInsets.fromLTRB(16 * s, 0, 16 * s, 10 * s),
        padding: EdgeInsets.all(3 * s),
        decoration: BoxDecoration(color: text.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(99)),
        child: Row(children: [
          for (var i = 0; i < icons.length; i++)
            Expanded(
              flex: i == 0 ? 3 : 2,
              child: Container(
                height: 20 * s,
                decoration: BoxDecoration(gradient: i == 0 ? LinearGradient(colors: [seed, accent]) : null, borderRadius: BorderRadius.circular(99)),
                child: Icon(icons[i], size: 11 * s, color: i == 0 ? Colors.white : bg.withValues(alpha: 0.7)),
              ),
            ),
        ]),
      );
    } else {
      final items = Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        for (var i = 0; i < icons.length; i++)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 3 * s),
            decoration: BoxDecoration(
                color: i == 0 ? (brutal ? accent : seed.withValues(alpha: 0.18)) : null,
                borderRadius: BorderRadius.circular(brutal ? 4 * s : 99),
                border: i == 0 && brutal ? Border.all(color: ink, width: s) : null),
            child: Icon(icons[i], size: 13 * s, color: i == 0 ? (brutal ? ink : seed) : muted),
          ),
      ]);
      nav = t.nav == 'floating'
          ? Container(
              margin: EdgeInsets.fromLTRB(8 * s, 0, 8 * s, 8 * s),
              height: 30 * s,
              decoration: BoxDecoration(color: dark ? const Color(0xFF1A1D2B) : Colors.white, borderRadius: BorderRadius.circular(r + 4 * s),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12 * s, offset: Offset(0, 4 * s))]),
              child: items)
          : Container(
              height: 36 * s,
              decoration: BoxDecoration(
                  color: dark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
                  border: Border(top: BorderSide(color: brutal ? ink : muted.withValues(alpha: 0.15), width: brutal ? 1.6 * s : 1))),
              child: items);
    }

    // Background decoration
    final decoPaint = switch (t.deco) {
      'dots' => BoxDecoration(color: bg, image: null),
      _ => BoxDecoration(color: bg),
    };

    return Container(
      width: width,
      height: width * 2.05,
      padding: EdgeInsets.all(6 * s),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2B),
        borderRadius: BorderRadius.circular(34 * s),
        border: Border.all(color: Colors.white24, width: 1.2),
        boxShadow: [BoxShadow(color: seed.withValues(alpha: 0.35), blurRadius: 40, offset: const Offset(0, 16))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28 * s),
        child: DecoratedBox(
          decoration: decoPaint,
          child: Stack(children: [
            if (t.deco == 'dots' || t.deco == 'grid')
              Positioned.fill(child: CustomPaint(painter: _MiniDeco(t.deco, dark))),
            if (t.deco == 'blobs' || t.deco == 'glow')
              Positioned(top: -40 * s, right: -40 * s, child: Container(width: 160 * s, height: 160 * s,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [seed.withValues(alpha: 0.3), seed.withValues(alpha: 0)])))),
            Column(children: [
              header,
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(8 * s),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (first != null)
                      Container(
                        margin: EdgeInsets.all(3 * s),
                        padding: EdgeInsets.all(8 * s),
                        decoration: card(highlight: true),
                        child: Row(children: [
                          Icon(tableIcon(first.icon), color: brutal ? ink : Colors.white, size: 14 * s),
                          SizedBox(width: 6 * s),
                          Text('12', style: TextStyle(color: brutal ? ink : Colors.white, fontWeight: FontWeight.w900, fontSize: 13 * s)),
                          const Spacer(),
                          Text(first.label, style: TextStyle(color: brutal ? ink : Colors.white70, fontSize: 8 * s)),
                        ]),
                      ),
                    SizedBox(height: 3 * s),
                    ...list,
                    const Spacer(),
                  ]),
                ),
              ),
              nav,
            ]),
          ]),
        ),
      ),
    );
  }
}

class _PreviewHeaderClipper extends CustomClipper<Path> {
  _PreviewHeaderClipper(this.shape);
  final String shape;

  @override
  Path getClip(Size s) {
    final p = Path();
    switch (shape) {
      case 'wave':
        p
          ..lineTo(0, s.height - 12)
          ..cubicTo(s.width * 0.3, s.height + 4, s.width * 0.6, s.height - 22, s.width, s.height - 10);
      case 'diagonal':
        p
          ..lineTo(0, s.height)
          ..lineTo(s.width, s.height * 0.72);
      case 'curve':
        p
          ..lineTo(0, s.height - 14)
          ..quadraticBezierTo(s.width / 2, s.height + 10, s.width, s.height - 14);
      default:
        p.addRRect(RRect.fromRectAndCorners(Offset.zero & s, bottomLeft: const Radius.circular(18), bottomRight: const Radius.circular(18)));
        return p;
    }
    p
      ..lineTo(s.width, 0)
      ..close();
    return p;
  }

  @override
  bool shouldReclip(covariant _PreviewHeaderClipper old) => old.shape != shape;
}

class _MiniDeco extends CustomPainter {
  _MiniDeco(this.kind, this.dark);
  final String kind;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = (dark ? Colors.white : Colors.black).withValues(alpha: kind == 'dots' ? 0.14 : 0.07)
      ..strokeWidth = 1;
    if (kind == 'dots') {
      for (double y = 6; y < size.height; y += 10) {
        for (double x = 6; x < size.width; x += 10) {
          canvas.drawCircle(Offset(x, y), 0.8, p);
        }
      }
    } else {
      for (double y = 0; y < size.height; y += 16) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      }
      for (double x = 0; x < size.width; x += 16) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MiniDeco old) => old.kind != kind || old.dark != dark;
}

void showMessage(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(text),
    backgroundColor: error ? const Color(0xFFB91C1C) : AlphaColors.surface2,
  ));
}

Future<bool> confirm(BuildContext context, String title, String body, {String ok = 'تأكيد'}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
        ],
      ),
    ) ==
    true;

/// Who the app is for: the owner, the customers, or both (two connected apps).
class KindPicker extends StatelessWidget {
  const KindPicker({super.key, this.value, required this.onPick, this.suggested});
  final ProjectKind? value;
  final ProjectKind? suggested;
  final ValueChanged<ProjectKind> onPick;

  static const icons = {
    ProjectKind.single: Icons.storefront_rounded,
    ProjectKind.pair: Icons.connecting_airports_rounded,
  };

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final k in ProjectKind.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onPick(k),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: value == k ? LinearGradient(colors: [AlphaColors.violet.withValues(alpha: 0.35), AlphaColors.teal.withValues(alpha: 0.15)]) : null,
                    color: value == k ? null : AlphaColors.surface.withValues(alpha: 0.6),
                    border: Border.all(color: value == k ? AlphaColors.violet : AlphaColors.line, width: value == k ? 1.5 : 1),
                  ),
                  child: Row(children: [
                    Icon(icons[k], color: value == k ? Colors.white : AlphaColors.muted, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(k.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          if (suggested == k) ...[const SizedBox(width: 8), const Pill('اقتراح الذكاء', color: AlphaColors.amber)],
                        ]),
                        const SizedBox(height: 2),
                        Text(k.hint, style: const TextStyle(color: AlphaColors.muted, fontSize: 12, height: 1.4)),
                      ]),
                    ),
                    if (value == k) const Icon(Icons.check_circle_rounded, color: AlphaColors.teal),
                  ]),
                ),
              ),
            ),
        ],
      );
}
