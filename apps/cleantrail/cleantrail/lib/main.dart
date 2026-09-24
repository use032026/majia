import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/app_localizations.dart';
import 'app/app_theme.dart';
import 'data/file_project_store.dart';
import 'data/language_store.dart';
import 'data/native_csv_gateway.dart';
import 'data/onboarding_store.dart';
import 'domain/quality_engine.dart';
import 'state/workbench_controller.dart';
import 'ui/onboarding_page.dart';
import 'ui/workbench_home.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final languageStore = FileLanguageStore();
  final onboardingStore = FileOnboardingStore();
  final initialLocale = await loadInitialLocale(
    store: languageStore,
    systemLocale: binding.platformDispatcher.locale,
  );
  final hasCompletedOnboarding = await loadOnboardingCompleted(onboardingStore);
  runApp(
    CleanTrailApp(
      controller: WorkbenchController(
        engine: const QualityEngine(),
        store: FileProjectStore(),
        gateway: NativeCsvGateway(),
      ),
      initialLocale: initialLocale,
      languageStore: languageStore,
      onboardingStore: onboardingStore,
      showOnboarding: !hasCompletedOnboarding,
    ),
  );
}

Locale localeForSystem(Locale? systemLocale) {
  return systemLocale?.languageCode.toLowerCase() == 'zh'
      ? const Locale('zh')
      : const Locale('en');
}

Future<Locale> loadInitialLocale({
  required LanguageStore store,
  required Locale? systemLocale,
}) async {
  try {
    final savedLanguage = await store.load();
    if (savedLanguage == 'zh' || savedLanguage == 'en') {
      return Locale(savedLanguage!);
    }
  } on Object {
    // Language preferences should never prevent the app from starting.
  }

  final locale = localeForSystem(systemLocale);
  try {
    await store.save(locale.languageCode);
  } on Object {
    // Continue with the resolved system language if persistence is unavailable.
  }
  return locale;
}

Future<bool> loadOnboardingCompleted(OnboardingStore store) async {
  try {
    return await store.isCompleted();
  } on Object {
    return false;
  }
}

class CleanTrailApp extends StatefulWidget {
  const CleanTrailApp({
    required this.controller,
    this.initialLocale,
    this.languageStore,
    this.onboardingStore,
    this.showOnboarding = false,
    super.key,
  });

  final WorkbenchController controller;
  final Locale? initialLocale;
  final LanguageStore? languageStore;
  final OnboardingStore? onboardingStore;
  final bool showOnboarding;

  @override
  State<CleanTrailApp> createState() => _CleanTrailAppState();
}

class _CleanTrailAppState extends State<CleanTrailApp> {
  Locale? _locale;
  late bool _showOnboarding;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
    _showOnboarding = widget.showOnboarding;
    widget.controller.load();
  }

  void _changeLocale(Locale locale) {
    setState(() => _locale = locale);
    final store = widget.languageStore;
    if (store != null) unawaited(_saveLocale(store, locale));
  }

  Future<void> _saveLocale(LanguageStore store, Locale locale) async {
    try {
      await store.save(locale.languageCode);
    } on Object {
      // Keep the in-memory selection usable even if persistence fails.
    }
  }

  void _finishOnboarding() {
    setState(() => _showOnboarding = false);
    final store = widget.onboardingStore;
    if (store != null) unawaited(_markOnboardingCompleted(store));
  }

  Future<void> _markOnboardingCompleted(OnboardingStore store) async {
    try {
      await store.markCompleted();
    } on Object {
      // The workbench remains available if this lightweight preference fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => context.s.appName,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supported) {
        if (_locale != null) return _locale;
        return localeForSystem(locale);
      },
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: _showOnboarding
          ? OnboardingPage(onFinished: _finishOnboarding)
          : WorkbenchHome(
              controller: widget.controller,
              onLocaleChanged: _changeLocale,
            ),
    );
  }
}
