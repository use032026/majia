import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trip_cost/core/platform/app_web_launcher.dart';
import 'package:trip_cost/core/platform/online_web_config.dart';
import 'package:trip_cost/features/startup/data/web_startup_mode_store.dart';

final webStartupModeStoreProvider = Provider<WebStartupModeStore>((ref) {
  return SharedPreferencesWebStartupModeStore();
});

final appWebLauncherProvider = Provider<AppWebLauncher>(
  (ref) => appWebLauncher,
);

final webStartupControllerProvider = Provider<WebStartupController>((ref) {
  return WebStartupController(
    store: ref.watch(webStartupModeStoreProvider),
    launcher: ref.watch(appWebLauncherProvider),
  );
});

final class WebStartupModeSaveException implements Exception {
  const WebStartupModeSaveException(this.cause);

  final Object cause;
}

final class WebStartupController {
  WebStartupController({
    required WebStartupModeStore store,
    required AppWebLauncher launcher,
  }) : _store = store,
       _launcher = launcher;

  static final pageUri = Uri.parse(onlineWebHomeUrl);

  final WebStartupModeStore _store;
  final AppWebLauncher _launcher;
  Future<void>? _opening;

  Future<bool> isEnabled() async {
    try {
      return await _store.isEnabled();
    } on Object {
      return false;
    }
  }

  Future<void> enableAndOpen() async {
    try {
      await _store.setEnabled(true);
    } on Object catch (error) {
      throw WebStartupModeSaveException(error);
    }
    await open();
  }

  Future<void> open() => _opening ??= _openPage();

  Future<void> _openPage() async {
    try {
      await _launcher.open(pageUri, showNavigationBar: false);
    } finally {
      _opening = null;
    }
  }
}
