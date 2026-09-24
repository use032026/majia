import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_strings.dart';
import 'state/app_controller.dart';
import 'ui/app_theme.dart';
import 'ui/home_shell.dart';
import 'ui/onboarding_screen.dart';

class PlotProofApp extends StatelessWidget {
  const PlotProofApp({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        title: AppStrings(controller.locale).appName,
        debugShowCheckedModeBanner: false,
        locale: controller.locale,
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home:
            controller.hasCompletedOnboarding ||
                controller.hasRecoverableLoadError
            ? HomeShell(controller: controller)
            : OnboardingScreen(controller: controller),
      ),
    );
  }
}
