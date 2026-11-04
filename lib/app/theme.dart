import 'package:flutter/material.dart';

/// Alpha's own look: deep night background, aurora gradient (violet → blue → teal), glass surfaces.
class AlphaColors {
  static const bg = Color(0xFF06070D);
  static const bg2 = Color(0xFF0B0D18);
  static const surface = Color(0xFF111426);
  static const surface2 = Color(0xFF171B31);
  static const line = Color(0x1FFFFFFF);
  static const text = Color(0xFFF2F4FF);
  static const muted = Color(0xFF8D94B3);
  static const violet = Color(0xFF7C5CFF);
  static const blue = Color(0xFF3B82F6);
  static const teal = Color(0xFF2DD4BF);
  static const pink = Color(0xFFF472B6);
  static const amber = Color(0xFFFBBF24);
  static const ok = Color(0xFF34D399);
  static const bad = Color(0xFFF87171);

  static const aurora = LinearGradient(
    colors: [violet, blue, teal],
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
  );

  static const sunrise = LinearGradient(
    colors: [Color(0xFFF472B6), Color(0xFF7C5CFF)],
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
  );
}

ThemeData alphaTheme() {
  const r = BorderRadius.all(Radius.circular(18));
  final scheme = ColorScheme.fromSeed(
    seedColor: AlphaColors.violet,
    brightness: Brightness.dark,
    primary: AlphaColors.violet,
    secondary: AlphaColors.teal,
    surface: AlphaColors.surface,
  );
  final base = ThemeData(useMaterial3: true, brightness: Brightness.dark, colorScheme: scheme, fontFamily: 'Tajawal');
  return base.copyWith(
    scaffoldBackgroundColor: AlphaColors.bg,
    textTheme: base.textTheme.apply(bodyColor: AlphaColors.text, displayColor: AlphaColors.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontFamily: 'Tajawal', fontSize: 20, fontWeight: FontWeight.w800, color: AlphaColors.text),
    ),
    cardTheme: const CardThemeData(
      color: AlphaColors.surface,
      elevation: 0,
      margin: EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: r, side: BorderSide(color: AlphaColors.line)),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0x0FFFFFFF),
      border: OutlineInputBorder(borderRadius: r, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: AlphaColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: AlphaColors.violet, width: 1.6)),
      labelStyle: TextStyle(color: AlphaColors.muted),
      hintStyle: TextStyle(color: AlphaColors.muted),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const RoundedRectangleBorder(borderRadius: r),
        textStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: AlphaColors.line),
        shape: const RoundedRectangleBorder(borderRadius: r),
        textStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: const ChipThemeData(
      side: BorderSide(color: AlphaColors.line),
      shape: StadiumBorder(),
      labelStyle: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AlphaColors.bg2,
      indicatorColor: AlphaColors.violet.withValues(alpha: 0.22),
      height: 70,
      labelTextStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.w700)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AlphaColors.bg2,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: AlphaColors.surface2),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: r)),
    dividerTheme: const DividerThemeData(color: AlphaColors.line),
  );
}
