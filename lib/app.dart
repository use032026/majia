import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'state/app_controller.dart';
import 'ui/root_view.dart';

class AppPalette {
  static const paper = Color(0xFFF5F1E8);
  static const ink = Color(0xFF17324D);
  static const steady = Color(0xFF2E6F6D);
  static const recovery = Color(0xFFA64332);
  static const checkpoint = Color(0xFFF2C66D);
  static const darkPaper = Color(0xFF101820);
  static const darkSurface = Color(0xFF182531);
}

class PaceJarApp extends StatelessWidget {
  const PaceJarApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'PaceJar',
          locale: Locale(controller.localeCode),
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: controller.darkMode ? ThemeMode.dark : ThemeMode.light,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          home: RootView(controller: controller),
        );
      },
    );
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppPalette.ink,
          brightness: brightness,
          surface: dark ? AppPalette.darkSurface : AppPalette.paper,
        ).copyWith(
          primary: dark ? const Color(0xFF9BC9C5) : AppPalette.ink,
          secondary: dark ? const Color(0xFF87C9C2) : AppPalette.steady,
          error: dark ? const Color(0xFFFFB4A0) : AppPalette.recovery,
          surfaceContainerLowest: dark
              ? AppPalette.darkPaper
              : const Color(0xFFFFFCF6),
          surfaceContainerLow: dark
              ? const Color(0xFF14202A)
              : const Color(0xFFFBF7EF),
          surfaceContainer: dark
              ? AppPalette.darkSurface
              : const Color(0xFFFFFCF6),
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? AppPalette.darkPaper : AppPalette.paper,
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
          height: 1.08,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.45),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(height: 72),
    );
  }
}
