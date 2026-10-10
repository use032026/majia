import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_controller.dart';
import 'app_strings.dart';
import 'app_theme.dart';
import 'screens/almanac_screens.dart';

class AlmanacApp extends StatelessWidget {
  const AlmanacApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
        final locale = controller.resolveLocale(systemLocale);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Almanac',
          locale: locale,
          supportedLocales: const <Locale>[Locale('zh', 'CN'), Locale('en')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: controller.flutterThemeMode,
          home: _homeFor(locale),
        );
      },
    );
  }

  Widget _homeFor(Locale locale) {
    final strings = AppStrings(locale);
    if (controller.hasLoadFailure) {
      return RecoveryScreen(controller: controller, strings: strings);
    }
    if (!controller.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!controller.data!.onboardingSeen) {
      return WelcomeScreen(controller: controller, strings: strings);
    }
    return HomeShell(controller: controller, strings: strings);
  }
}
