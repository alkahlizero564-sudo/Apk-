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
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
                        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                      ],
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

/// A live miniature of the app being designed: same theme, tables and layout as the engines draw them.
class PhonePreview extends StatelessWidget {
  const PhonePreview({super.key, required this.theme, required this.title, required this.schema, this.role = 'single', this.width = 220});
  final ThemeSpec theme;
  final String title;
  final DbSchema schema;
  final String role;
  final double width;

  @override
  Widget build(BuildContext context) {
    final seed = hexColor(theme.seed);
    final accent = hexColor(theme.accent, AlphaColors.teal);
    final dark = theme.mode != 'light';
    final bg = dark ? Color.lerp(const Color(0xFF0B0D16), seed, 0.06)! : const Color(0xFFF5F6FB);
    final card = dark ? Colors.white.withValues(alpha: theme.style == 'glass' ? 0.07 : 0.05) : Colors.white;
    final text = dark ? Colors.white : const Color(0xFF0F172A);
    final muted = dark ? Colors.white60 : Colors.black54;
    final r = theme.radius * width / 390;
    final tables = schema.tables.where((t) => role == 'admin' || t.owner != TableOwner.admin).toList();
    final first = tables.isEmpty ? null : tables.first;
    final s = width / 220;
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
        child: ColoredBox(
          color: bg,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(14 * s, 26 * s, 14 * s, 16 * s),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [seed, Color.lerp(seed, accent, 0.75)!]),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(r + 8 * s)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.isEmpty ? 'تطبيقي' : title,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15 * s)),
                    SizedBox(height: 2 * s),
                    Text(role == 'admin' ? 'لوحة التحكم' : 'أهلاً بك', style: TextStyle(color: Colors.white70, fontSize: 9 * s)),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(8 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          for (final t in tables.take(2))
                            Expanded(
                              child: Container(
                                margin: EdgeInsets.all(3 * s),
                                padding: EdgeInsets.all(7 * s),
                                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(r * 0.8)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(tableIcon(t.icon), color: seed, size: 14 * s),
                                    SizedBox(height: 4 * s),
                                    Text('12', style: TextStyle(color: text, fontWeight: FontWeight.w900, fontSize: 12 * s)),
                                    Text(t.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 8 * s)),
                                  ],
                                ),
                              ),
                            ),
                          if (tables.isEmpty)
                            Expanded(child: Center(child: Text('أضف جداول', style: TextStyle(color: muted, fontSize: 10 * s)))),
                        ],
                      ),
                      SizedBox(height: 4 * s),
                      for (var i = 0; i < 3 && first != null; i++)
                        Container(
                          margin: EdgeInsets.symmetric(vertical: 3 * s, horizontal: 3 * s),
                          padding: EdgeInsets.all(6 * s),
                          decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(r * 0.8)),
                          child: Row(
                            children: [
                              Container(
                                width: 24 * s,
                                height: 24 * s,
                                decoration: BoxDecoration(color: seed.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(7 * s)),
                                child: Icon(tableIcon(first.icon), color: seed, size: 12 * s),
                              ),
                              SizedBox(width: 6 * s),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(height: 5 * s, width: 60 * s, decoration: BoxDecoration(color: text.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(3))),
                                    SizedBox(height: 3 * s),
                                    Container(height: 4 * s, width: 40 * s, decoration: BoxDecoration(color: muted.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(3))),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 5 * s, vertical: 2 * s),
                                decoration: BoxDecoration(color: seed.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(99)),
                                child: Text(['جديد', 'تم', 'مؤكد'][i], style: TextStyle(color: seed, fontSize: 7 * s, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              Container(
                height: 38 * s,
                decoration: BoxDecoration(color: dark ? Colors.white.withValues(alpha: 0.04) : Colors.white, border: Border(top: BorderSide(color: muted.withValues(alpha: 0.15)))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _nav(Icons.space_dashboard_rounded, seed, true, s),
                    for (final t in tables.take(2)) _nav(tableIcon(t.icon), muted, false, s),
                    _nav(Icons.notifications_rounded, muted, false, s),
                    _nav(Icons.person_rounded, muted, false, s),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nav(IconData i, Color c, bool on, double s) => Container(
        padding: EdgeInsets.symmetric(horizontal: 9 * s, vertical: 3 * s),
        decoration: BoxDecoration(color: on ? c.withValues(alpha: 0.18) : null, borderRadius: BorderRadius.circular(99)),
        child: Icon(i, size: 14 * s, color: c),
      );
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
