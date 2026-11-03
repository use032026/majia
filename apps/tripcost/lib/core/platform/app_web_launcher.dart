import 'package:stmini_flutter/stmini_flutter.dart';
import 'package:trip_cost/core/platform/online_web_bridge.dart';
import 'package:trip_cost/core/platform/online_web_config.dart';

/// The shared entry point for online pages opened inside RhinoSmart.
final appWebLauncher = AppWebLauncher();

final class AppWebLauncher {
  Future<void>? _initialization;
  late final OnlineWebBridge _bridge = OnlineWebBridge(
    homeUri: Uri.parse(onlineWebHomeUrl),
    openPage: (uri, {title, required showNavigationBar}) =>
        StminiFlutter.openWeb(
          uri.toString(),
          title: title,
          showNavigationBar: showNavigationBar,
        ),
    closePage: StminiFlutter.closeWeb,
    notifySessionChanged: StminiFlutter.notifyWebSessionChanged,
  );

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
      StminiFlutter.setWebBridgeHandler(_bridge.handle);
      await StminiFlutter.initialize(
        bridgeContext: const {
          'packageName': 'com.tripcost.lite',
          'authStorageKey': 'futrenapp:auth-storage:v1',
          'bridgeUserInfoStorage': {
            'storageKey': 'futrenapp:cache-storage:v1',
            'valueKey': 'user',
            'nestedKey': 'userInfo',
          },
          'webSecurity': {'allowInsecureHTTP': false},
        },
      );
    } on Object {
      _initialization = null;
      rethrow;
    }
  }
}
