import 'package:flutter/material.dart';

/// Alpha's own look (same design language as APK Fact): a near-black night, calm solid surfaces with thin borders,
/// one strong violet → blue brand gradient, teal as the second accent.
class AlphaColors {
  static const bg = Color(0xFF07080E);
  static const bg2 = Color(0xFF0B0D15); // fields, sheets
  static const surface = Color(0xFF10121B);
  static const surface2 = Color(0xFF171A26);
  static const line = Color(0xFF22263A);
  static const text = Color(0xFFF3F5FB);
  static const muted = Color(0xFF9097AD);
  static const violet = Color(0xFF6E4BFF);
  static const violetSoft = Color(0xFF1C1840);
  static const blue = Color(0xFF2563EB);
  static const teal = Color(0xFF2DD4BF);
  static const pink = Color(0xFFF472B6);
  static const amber = Color(0xFFFBBF24);
  static const ok = Color(0xFF4ADE80);
  static const bad = Color(0xFFF87171);
  static const okBg = Color(0xFF0E2A22);
  static const badBg = Color(0xFF3A1418);
  static const infoBg = Color(0xFF151937);
  static const infoLine = Color(0xFF2A3163);
  static const infoText = Color(0xFFA9B6FF);

  /// The brand gradient (hero card, main buttons, the + button).
  static const aurora = LinearGradient(
    colors: [violet, blue],
    begin: AlignmentDirectional.topEnd,
    end: AlignmentDirectional.bottomStart,
  );

  static const sunrise = LinearGradient(
    colors: [Color(0xFFF472B6), violet],
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
  );
}

/// Radii of the design language.
class AlphaRadius {
  static const field = 14.0;
  static const button = 16.0;
  static const card = 22.0;
}

ThemeData alphaTheme() {
  const r = BorderRadius.all(Radius.circular(AlphaRadius.button));
  const rf = BorderRadius.all(Radius.circular(AlphaRadius.field));
  final scheme = ColorScheme.fromSeed(
    seedColor: AlphaColors.violet,
    brightness: Brightness.dark,
    primary: AlphaColors.violet,
    secondary: AlphaColors.teal,
    surface: AlphaColors.surface,
  );
  final base = ThemeData(useMaterial3: true, brightness: Brightness.dark, colorScheme: scheme, fontFamily: 'Plex');
  return base.copyWith(
    scaffoldBackgroundColor: AlphaColors.bg,
    textTheme: base.textTheme.apply(bodyColor: AlphaColors.text, displayColor: AlphaColors.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontFamily: 'Plex', fontSize: 20, fontWeight: FontWeight.w700, color: AlphaColors.text),
    ),
    cardTheme: const CardThemeData(
      color: AlphaColors.surface,
      elevation: 0,
      margin: EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AlphaRadius.card)), side: BorderSide(color: AlphaColors.line)),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AlphaColors.bg2,
      border: OutlineInputBorder(borderRadius: rf, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: rf, borderSide: BorderSide(color: AlphaColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: rf, borderSide: BorderSide(color: AlphaColors.violet, width: 1.6)),
      labelStyle: TextStyle(color: AlphaColors.muted),
      hintStyle: TextStyle(color: AlphaColors.muted),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const RoundedRectangleBorder(borderRadius: r),
        backgroundColor: AlphaColors.violet,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontFamily: 'Plex', fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: AlphaColors.line),
        backgroundColor: AlphaColors.surface,
        foregroundColor: AlphaColors.text,
        shape: const RoundedRectangleBorder(borderRadius: r),
        textStyle: const TextStyle(fontFamily: 'Plex', fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: const ChipThemeData(
      side: BorderSide(color: AlphaColors.line),
      backgroundColor: AlphaColors.surface,
      selectedColor: AlphaColors.violetSoft,
      shape: StadiumBorder(),
      labelStyle: TextStyle(fontFamily: 'Plex', fontWeight: FontWeight.w600),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AlphaColors.bg2,
      indicatorColor: AlphaColors.violet.withValues(alpha: 0.22),
      height: 70,
      labelTextStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: 'Plex', fontSize: 12, fontWeight: FontWeight.w700)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: AlphaColors.surface,
        selectedBackgroundColor: AlphaColors.violetSoft,
        selectedForegroundColor: AlphaColors.text,
        side: const BorderSide(color: AlphaColors.line),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AlphaColors.violet : AlphaColors.surface2),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AlphaColors.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AlphaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AlphaRadius.card)), side: BorderSide(color: AlphaColors.line)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: r)),
    dividerTheme: const DividerThemeData(color: AlphaColors.line),
  );
}
