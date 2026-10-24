import 'package:flutter/material.dart';

const paper = Color(0xFFFBF9F8);
const rust = Color(0xFFA23E18);
const ink = Color(0xFF1B1C1C);
const mono = 'JetBrainsMono';

ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: rust, brightness: brightness)
      .copyWith(
        primary: dark ? const Color(0xFFF1EFED) : ink,
        onPrimary: dark ? ink : Colors.white,
        secondary: dark ? const Color(0xFFFEA17D) : rust,
        surface: dark ? const Color(0xFF171817) : paper,
        surfaceContainerLow: dark
            ? const Color(0xFF222322)
            : const Color(0xFFF2F0EF),
        surfaceContainerHighest: dark
            ? const Color(0xFF343633)
            : const Color(0xFFE9E6E3),
        outlineVariant: dark
            ? const Color(0xFF41443F)
            : const Color(0xFFDEDAD6),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: 'Geist',
    visualDensity: VisualDensity.standard,
    textTheme: TextTheme(
      displaySmall: TextStyle(
        fontSize: 42,
        height: 1.08,
        letterSpacing: -1.8,
        fontWeight: FontWeight.w500,
        color: scheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 29,
        height: 1.15,
        letterSpacing: -0.9,
        fontWeight: FontWeight.w500,
        color: scheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        letterSpacing: -0.5,
        fontWeight: FontWeight.w500,
        color: scheme.onSurface,
      ),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: scheme.onSurface),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.5,
        color: scheme.onSurfaceVariant,
      ),
      labelSmall: TextStyle(
        fontSize: 10,
        letterSpacing: 1.1,
        fontFamily: mono,
        color: scheme.onSurfaceVariant,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleSpacing: 20,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Geist',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 48),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.surfaceContainerHighest,
      height: 72,
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 3,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 0.7,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
