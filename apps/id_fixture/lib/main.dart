import 'package:flutter/widgets.dart';
import 'services/app_settings.dart';
import 'services/platform_services.dart';
import 'ui/app.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  binding.deferFirstFrame();
  try {
    final settings = await AppSettings.load();
    runApp(
      IdFixtureApp(
        settings: settings,
        services: const NativePlatformServices(),
      ),
    );
  } finally {
    binding.allowFirstFrame();
  }
}
