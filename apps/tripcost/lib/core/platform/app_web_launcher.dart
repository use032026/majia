import 'package:stmini_flutter/stmini_flutter.dart';

/// The shared entry point for online pages opened inside RhinoSmart.
final appWebLauncher = AppWebLauncher();

final class AppWebLauncher {
  Future<void>? _initialization;

  Future<void> open(
    Uri uri, {
    String? title,
    bool showNavigationBar = true,
  }) async {
    if (StminiFlutter.runtimeMode != StminiRuntimeMode.web) {
      throw StateError('RhinoSmart requires the online Web runtime.');
    }
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      throw ArgumentError.value(
        uri,
        'uri',
        'An absolute HTTPS URL is required.',
      );
    }
    // Initialize for a page-opening request, including cold start after the
    // user enabled Web startup. Concurrent opens share initialization; a failed
    // initialization can be tried again.
    await (_initialization ??= _initialize());
    await StminiFlutter.openWeb(
      uri.toString(),
      title: title,
      showNavigationBar: showNavigationBar,
    );
  }

  Future<void> _initialize() async {
    try {
      await StminiFlutter.initialize(
        bridgeContext: const {'packageName': 'com.tripcost.lite'},
      );
    } on Object {
      _initialization = null;
      rethrow;
    }
  }
}
