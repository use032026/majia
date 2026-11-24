import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'backup.dart';
import 'onboarding.dart';
import 'screens.dart';
import 'store.dart';
import 'stmini_web_host.dart';
import 'trip_theme.dart';
import 'web_startup.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    runApp(
      TripDeltaStartup(
        session: StminiWebRootSession(),
        tripBuilder: () => TripDeltaApp(store: FileTripStore()),
      ),
    );
  } else {
    runApp(TripDeltaApp(store: FileTripStore()));
  }
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => MaterialApp(
        title: 'Trip Delta',
        debugShowCheckedModeBanner: false,
        theme: tripDeltaTheme(Brightness.light),
        darkTheme: tripDeltaTheme(Brightness.dark),
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
