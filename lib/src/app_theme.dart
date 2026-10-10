import 'package:flutter/material.dart';

const Color ink = Color(0xFF1F2926);
const Color mineral = Color(0xFF315E54);
const Color cinnabar = Color(0xFFB44C38);
const Color paper = Color(0xFFF4EFE3);

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: mineral,
    brightness: Brightness.light,
    primary: mineral,
    secondary: cinnabar,
    surface: paper,
  );
  return _baseTheme(
    scheme,
  ).copyWith(scaffoldBackgroundColor: const Color(0xFFF8F5EC));
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF8BB8AA),
    brightness: Brightness.dark,
    primary: const Color(0xFFA8CFC3),
    secondary: const Color(0xFFE69B86),
    surface: const Color(0xFF242A27),
  );
  return _baseTheme(
    scheme,
  ).copyWith(scaffoldBackgroundColor: const Color(0xFF171C1A));
}

ThemeData _baseTheme(ColorScheme scheme) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    dividerColor: scheme.outlineVariant.withValues(alpha: 0.55),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 36,
        height: 1.18,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.1,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        height: 1.4,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.6),
      bodyMedium: TextStyle(fontSize: 14, height: 1.55),
      labelLarge: TextStyle(
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
