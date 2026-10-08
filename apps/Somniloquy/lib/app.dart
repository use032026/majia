import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'controllers/app_controller.dart';
import 'ui/home_shell.dart';

class SomniloquyApp extends StatelessWidget {
  const SomniloquyApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Somniloquy',
        locale: Locale(controller.localeCode),
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        themeMode: ThemeMode.system,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: HomeShell(controller: controller),
      ),
    );
  }
}

ThemeData _theme(Brightness brightness) {
  const night = Color(0xFF11152B);
  const coral = Color(0xFFFF8E7A);
  const moon = Color(0xFF8CA8FF);
  const paper = Color(0xFFF3F1EA);
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: moon,
    brightness: brightness,
    primary: dark ? const Color(0xFFAFC0FF) : night,
    secondary: coral,
    surface: dark ? const Color(0xFF171B32) : paper,
    error: dark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF0C1022)
        : const Color(0xFFF8F6F0),
    textTheme: ThemeData(brightness: brightness).textTheme.copyWith(
      headlineLarge: TextStyle(
        fontSize: 34,
        height: 1.08,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: dark ? const Color(0xFFF4F2ED) : night,
      ),
      headlineSmall: const TextStyle(
        fontSize: 24,
        height: 1.18,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
      bodyMedium: const TextStyle(fontSize: 15, height: 1.45),
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: dark ? const Color(0xFF171B32) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF1C213B) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: dark ? const Color(0xFF12162A) : Colors.white,
      indicatorColor: dark
          ? moon.withValues(alpha: 0.25)
          : const Color(0xFFDCE3FF),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.6),
    ),
  );
}
