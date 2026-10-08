import 'package:flutter/material.dart';

class AppTheme {
  static const seed = Color(0xFFC55C4B);
  static const paper = Color(0xFFF7F1E8);
  static const ink = Color(0xFF2E2925);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      surface: paper,
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: paper,
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE18170),
      brightness: Brightness.dark,
      surface: const Color(0xFF201C1A),
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: const Color(0xFF171412),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF171412),
        foregroundColor: Color(0xFFF4ECE3),
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
    );
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      chipTheme: const ChipThemeData(showCheckmark: false),
      textTheme: const TextTheme(
        displaySmall: TextStyle(fontWeight: FontWeight.w700, height: 1.08),
        headlineSmall: TextStyle(fontWeight: FontWeight.w700, height: 1.18),
        titleLarge: TextStyle(fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(height: 1.55),
        bodyMedium: TextStyle(height: 1.45),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
