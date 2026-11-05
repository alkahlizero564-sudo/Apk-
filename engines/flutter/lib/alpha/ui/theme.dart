import 'package:flutter/material.dart';

import '../config.dart';
import 'look.dart';

ThemeData buildTheme(AlphaConfig c, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: c.seed,
    brightness: brightness,
    secondary: c.accent,
  );
  final r = BorderRadius.circular(c.radius);
  final glass = c.style == 'glass' || c.style == 'outline';
  final flat = c.style == 'flat';
  final brutal = c.style == 'brutal';
  final surface = pageColor(c, dark);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(surface: surface),
    // The page itself is painted by DecoBackground (color + decoration of the chosen look).
    scaffoldBackgroundColor: Colors.transparent,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: flat ? 0 : (glass ? 0 : 1),
      color: glass
          ? (dark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.85))
          : (dark ? Color.lerp(surface, Colors.white, 0.05) : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: r,
        side: brutal
            ? const BorderSide(color: Color(0xFF0B0B0F), width: 2.5)
            : BorderSide(color: scheme.outlineVariant.withValues(alpha: glass ? 0.35 : (flat ? 0.6 : 0.0))),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? Colors.white.withValues(alpha: 0.05) : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      border: OutlineInputBorder(borderRadius: r, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4))),
      focusedBorder: OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: scheme.primary, width: 1.6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: r),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: r)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(c.radius + 2)),
    ),
    chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99))),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: dark ? Color.lerp(surface, Colors.white, 0.04) : Colors.white,
      indicatorColor: scheme.primary.withValues(alpha: 0.18),
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface)),
    ),
    dialogTheme: DialogThemeData(backgroundColor: dark ? const Color(0xFF181B28) : Colors.white),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(c.radius + 10))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: r),
    ),
  );
}

/// The brand gradient used by headers and the primary call to action.
LinearGradient brandGradient(AlphaConfig c) => LinearGradient(
      colors: [c.seed, Color.lerp(c.seed, c.accent, 0.75)!],
      begin: AlignmentDirectional.topStart,
      end: AlignmentDirectional.bottomEnd,
    );
