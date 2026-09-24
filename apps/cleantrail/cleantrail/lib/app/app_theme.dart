import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _teal = Color(0xFF0B6B63);
  static const _amber = Color(0xFFE1A43B);

  static ThemeData get light => _theme(
    brightness: Brightness.light,
    background: const Color(0xFFF4F0E6),
    surface: const Color(0xFFFFFCF5),
    ink: const Color(0xFF142B2A),
  );

  static ThemeData get dark => _theme(
    brightness: Brightness.dark,
    background: const Color(0xFF101817),
    surface: const Color(0xFF192321),
    ink: const Color(0xFFE9F1EE),
  );

  static ThemeData _theme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color ink,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _teal,
      brightness: brightness,
      primary: brightness == Brightness.light ? _teal : const Color(0xFF71D3C8),
      secondary: _amber,
      surface: surface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      cupertinoOverrideTheme: cupertino.NoDefaultCupertinoThemeData(
        brightness: brightness,
        primaryColor: scheme.primary,
        primaryContrastingColor: scheme.onPrimary,
        barBackgroundColor: surface,
        scaffoldBackgroundColor: background,
        applyThemeToAll: true,
      ),
      scaffoldBackgroundColor: background,
      textTheme: Typography.material2021(platform: TargetPlatform.iOS).black
          .apply(bodyColor: ink, displayColor: ink, fontFamily: '.SF Pro Text'),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        modalBarrierColor: Colors.black.withValues(
          alpha: brightness == Brightness.light ? 0.32 : 0.58,
        ),
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.45),
        dragHandleSize: const Size(36, 5),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
