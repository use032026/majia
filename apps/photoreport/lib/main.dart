import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_controller.dart';
import 'ui/app_theme.dart';
import 'ui/onboarding_screen.dart';
import 'ui/project_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferredLocale = await LanguagePreference.load();
  final onboardingComplete = await OnboardingPreference.load();
  runApp(
    PhotoReportApp(
      initialPreferredLocale: preferredLocale,
      initialOnboardingComplete: onboardingComplete,
    ),
  );
}

class PhotoReportApp extends StatefulWidget {
  const PhotoReportApp({
    this.initialPreferredLocale,
    this.initialOnboardingComplete = true,
    super.key,
  });

  final Locale? initialPreferredLocale;
  final bool initialOnboardingComplete;

  @override
  State<PhotoReportApp> createState() => _PhotoReportAppState();
}

class _PhotoReportAppState extends State<PhotoReportApp> {
  late final PhotoReportController controller;
  late Locale? preferredLocale;
  late bool onboardingComplete;

  @override
  void initState() {
    super.initState();
    preferredLocale = widget.initialPreferredLocale == null
        ? null
        : AppLocalizations.resolve(widget.initialPreferredLocale);
    onboardingComplete = widget.initialOnboardingComplete;
    controller = PhotoReportController()..initialize();
  }

  void setLocale(Locale? value) {
    final resolved = value == null ? null : AppLocalizations.resolve(value);
    if (resolved?.languageCode == preferredLocale?.languageCode) return;
    setState(() => preferredLocale = resolved);
    unawaited(
      resolved == null
          ? LanguagePreference.clear()
          : LanguagePreference.save(resolved),
    );
  }

  void finishOnboarding() {
    if (onboardingComplete) return;
    setState(() => onboardingComplete = true);
    unawaited(OnboardingPreference.complete());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JOVFX',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      locale: preferredLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (locale, supportedLocales) =>
          AppLocalizations.resolve(
            locale ?? WidgetsBinding.instance.platformDispatcher.locale,
          ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) {
          final effectiveLocale = AppLocalizations.resolve(
            Localizations.localeOf(context),
          );
          AppLocalizations.activeLocale = effectiveLocale;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: onboardingComplete
                ? ProjectListScreen(
                    key: const ValueKey('project-list'),
                    controller: controller,
                    preferredLocale: preferredLocale,
                    onLocaleChanged: setLocale,
                  )
                : OnboardingScreen(
                    key: const ValueKey('onboarding'),
                    locale: effectiveLocale,
                    preferredLocale: preferredLocale,
                    onLocaleChanged: setLocale,
                    onFinished: finishOnboarding,
                  ),
          );
        },
      ),
    );
  }
}
