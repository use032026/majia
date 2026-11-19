import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'backup.dart';
import 'onboarding.dart';
import 'screens.dart';
import 'store.dart';
import 'stmini_web_host.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    TripDeltaApp(
      store: FileTripStore(),
      webHost: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
          ? TripDeltaWebHost()
          : null,
    ),
  );
}

class TripDeltaApp extends StatefulWidget {
  const TripDeltaApp({
    super.key,
    required this.store,
    this.backupGateway,
    this.webHost,
  });
  final TripStore store;
  final BackupGateway? backupGateway;
  final TripDeltaWebHost? webHost;

  @override
  State<TripDeltaApp> createState() => _TripDeltaAppState();
}

class _TripDeltaAppState extends State<TripDeltaApp> {
  late final AppController controller;

  @override
  void initState() {
    super.initState();
    controller = AppController(widget.store);
    controller.load();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        // Prepare only. The trip home stays visible and no Web page opens.
        await widget.webHost?.initialize();
      } catch (_) {
        // Web availability must never prevent offline trip access. A later
        // explicit programmatic open can retry initialization and report errors.
      }
    });
  }

  @override
  void dispose() {
    widget.webHost?.dispose();
    controller.dispose();
    super.dispose();
  }

  ThemeData theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    const teal = Color(0xFF006D68);
    final scheme = ColorScheme.fromSeed(
      seedColor: teal,
      brightness: brightness,
      surface: dark ? const Color(0xFF17201F) : const Color(0xFFF8F7F2),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => MaterialApp(
        title: 'Trip Delta',
        debugShowCheckedModeBanner: false,
        theme: theme(Brightness.light),
        darkTheme: theme(Brightness.dark),
        themeMode: ThemeMode.system,
        locale: switch (controller.data.language) {
          'zh' => const Locale('zh'),
          'en' => const Locale('en'),
          _ => null,
        },
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: controller.loading
            ? const BrandSplash()
            : controller.loadError == null &&
                  !controller.data.onboardingComplete
            ? OnboardingScreen(controller: controller)
            : HomeScreen(
                controller: controller,
                backupGateway: widget.backupGateway ?? SystemBackupGateway(),
              ),
      ),
    );
  }
}
