import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_theme.dart';
import 'controller.dart';
import 'copy.dart';
import 'repository.dart';
import 'screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final systemLanguage =
      WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  runApp(
    SteadyApp(
      controller: AppController(
        JsonFileRepository(
          defaultLocaleCode: systemLanguage == 'en' ? 'en' : 'zh',
        ),
      ),
    ),
  );
}

class SteadyApp extends StatefulWidget {
  const SteadyApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<SteadyApp> createState() => _SteadyAppState();
}

class _SteadyAppState extends State<SteadyApp> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final localeCode = widget.controller.snapshot.localeCode;
        final copy = AppCopy(localeCode);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (_) => copy.appName,
          locale: Locale(localeCode),
          supportedLocales: const [Locale('zh'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.system,
          home: BootstrapView(controller: widget.controller, copy: copy),
        );
      },
    );
  }
}
