import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/text_import_service.dart';
import '../l10n/app_strings.dart';
import '../ui/home_page.dart';
import 'reader_edit_store.dart';

class ReaderEditApp extends StatelessWidget {
  const ReaderEditApp({
    required this.store,
    this.textImportService = const FileSelectorTextImportService(),
    super.key,
  });

  final ReaderEditStore store;
  final TextImportService textImportService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ReaderEdit',
          locale: Locale(store.languageCode),
          supportedLocales: const [Locale('zh'), Locale('en')],
          localizationsDelegates: const [
            AppStringsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: _lightTheme,
          darkTheme: _darkTheme,
          themeMode: store.darkMode ? ThemeMode.dark : ThemeMode.light,
          home: HomePage(store: store, importService: textImportService),
        );
      },
    );
  }
}

const _seed = Color(0xFF5A4AE3);
const _paper = Color(0xFFFCF8F1);
const _ink = Color(0xFF23212B);

final ThemeData _lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.light,
        surface: _paper,
      ).copyWith(
        primary: const Color(0xFF5142CF),
        onPrimary: Colors.white,
        secondary: const Color(0xFFD96C42),
        onSurface: _ink,
        surfaceContainerLowest: const Color(0xFFFFFCF7),
        surfaceContainerLow: const Color(0xFFF6F0E8),
        surfaceContainer: const Color(0xFFEDE6DF),
        outline: const Color(0xFF77717E),
      ),
  scaffoldBackgroundColor: _paper,
  textTheme: _textTheme(Brightness.light),
  appBarTheme: const AppBarTheme(
    backgroundColor: _paper,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFFFFCF7),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFD8D0C8)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFD8D0C8)),
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: const Color(0xFFFFFCF7),
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFFE2DAD2)),
    ),
  ),
);

final ThemeData _darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF9A8CFF),
        brightness: Brightness.dark,
        surface: const Color(0xFF17151C),
      ).copyWith(
        primary: const Color(0xFFB9AEFF),
        onPrimary: const Color(0xFF251B79),
        secondary: const Color(0xFFFFB393),
        surfaceContainerLowest: const Color(0xFF111016),
        surfaceContainerLow: const Color(0xFF211E27),
        surfaceContainer: const Color(0xFF2A2631),
        outline: const Color(0xFF958E9C),
      ),
  scaffoldBackgroundColor: const Color(0xFF17151C),
  textTheme: _textTheme(Brightness.dark),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF17151C),
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF211E27),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF49434F)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF49434F)),
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: const Color(0xFF211E27),
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFF3A3541)),
    ),
  ),
);

TextTheme _textTheme(Brightness brightness) {
  final color = brightness == Brightness.light ? _ink : const Color(0xFFF4EEF7);
  return TextTheme(
    displaySmall: TextStyle(
      fontSize: 36,
      height: 1.12,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.2,
      color: color,
    ),
    headlineMedium: TextStyle(
      fontSize: 26,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: color,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: color,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w700,
      color: color,
    ),
    bodyLarge: TextStyle(fontSize: 17, height: 1.65, color: color),
    bodyMedium: TextStyle(fontSize: 15, height: 1.5, color: color),
    labelLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: color,
    ),
  );
}
