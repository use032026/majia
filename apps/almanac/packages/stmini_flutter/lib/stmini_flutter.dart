import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'src/safe_event_stream.dart';
import 'src/stmini_event.dart';
import 'src/stmini_package.dart';
import 'src/runtime_mode.dart';

export 'src/stmini_event.dart';
export 'src/stmini_package.dart';
export 'src/stmini_local_view.dart';
export 'src/runtime_mode.dart';

/// iOS local Mini runtime; Android foundation with strict inventory/renderer.
class StminiFlutter {
  StminiFlutter._();
  static String get runtimeStage =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'mini' : 'foundation';
  static const runtimeMode = configuredStminiRuntimeMode;
  static String get miniPackageMode =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? 'download_install_update'
      : 'local_only';
  static bool get miniPackageDownloadAvailable =>
      defaultTargetPlatform == TargetPlatform.iOS;
  static bool get miniPackageInstallAvailable =>
      defaultTargetPlatform == TargetPlatform.iOS;
  static bool get miniPackageUpdateAvailable =>
      defaultTargetPlatform == TargetPlatform.iOS;
  static WebBridgeHandler? _webBridgeHandler;
  static const _methods = MethodChannel('stmini_flutter/methods');
  static final Stream<StminiEvent> _events = SafeStminiEventStream();

  /// Shared native diagnostics, using main's `{name, payload}` contract.
  /// Activation/envelope failures are stream errors. The last listener must
  /// await cancellation to handle a native cancellation failure locally.
  static Stream<StminiEvent> get events => _events;

  /// Configures the native foundation. Only the Deynu packageName context is configured by this embedding app.
  /// No page is opened and no business provider is installed by initialization.
  static Future<void> initialize({
    String? loadingImage,
    Map<String, dynamic>? bridgeContext,
  }) {
    // iOS ordinary Web may forward a request as soon as native initialization
    // completes. Install the failure-capable receiver before crossing that
    // boundary, even when the host has never configured a business provider.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _installWebBridgeMethodHandler();
    }
    return _methods.invokeMethod<void>('initialize', {
      if (loadingImage != null) 'loadingImage': loadingImage,
      if (bridgeContext != null) 'bridgeContext': bridgeContext,
    });
  }

  /// Opens a verified Mini on iOS. Explicit HTTPS package links may download,
  /// validate and atomically install/update; mandatory floors never fall back
  /// to an incompatible package. Android foundation remains unsupported.
  /// The application must explicitly supply a link; initialization never opens one.
  static Future<void> openMini(String link) =>
      _methods.invokeMethod<void>('openMini', {'link': link});

  /// Presents an ordinary HTTPS Web page on iOS, without Mini privileges.
  /// Rapid host opens replace pending pages; superseded or cancelled opens fail.
  /// Display options preserve the supplied URL. A covering modal makes host
  /// open/close fail with web_covered until the owned page is revealed.
  /// Android foundation reports unsupported_capability.
  static Future<void> openWeb(
    String url, {
    String? title,
    bool showNavigationBar = true,
  }) => _methods.invokeMethod<void>('openWeb', {
    'url': url,
    if (title != null && title.isNotEmpty) 'title': title,
    'showNavigationBar': showNavigationBar,
  });

  static Future<void> closeMini() => _methods.invokeMethod<void>('closeMini');
  static Future<void> closeWeb() => _methods.invokeMethod<void>('closeWeb');
  static Future<bool> get isAvailable async =>
      (await _methods.invokeMethod<bool>('isAvailable')) == true;

  /// Renews only a stable visible iOS Web document; covered pages return zero.
  static Future<int> notifyWebSessionChanged(String reason) async {
    final count = await _methods.invokeMethod<int>('notifyWebSessionChanged', {
      'reason': reason,
    });
    if (count == null || count < 0) {
      throw const FormatException('Invalid session notification count.');
    }
    return count;
  }

  /// Only native-verified ordinary Web documents can reach this callback.
  /// No handler means a defined failure, never an invented business success.
  static void setWebBridgeHandler(WebBridgeHandler? handler) {
    _webBridgeHandler = handler;
    _installWebBridgeMethodHandler();
  }

  static void _installWebBridgeMethodHandler() {
    _methods.setMethodCallHandler((call) async {
      if (call.method != 'webBridgeRequest') {
        throw MissingPluginException('Unsupported native request.');
      }
      final request = WebBridgeRequest.fromMap(call.arguments);
      final activeHandler = _webBridgeHandler;
      if (activeHandler == null) {
        return const {
          'code': '0',
          'data': {'msg': 'Host did not handle the web request.'},
        };
      }
      try {
        return await activeHandler(request) ??
            const {
              'code': '0',
              'data': {'msg': 'Host did not handle the web request.'},
            };
      } catch (_) {
        return const {
          'code': '0',
          'data': {'msg': 'Host web request failed.'},
        };
      }
    });
  }

  /// Reads validated local metadata only. Rendering uses StminiLocalView and
  /// independently revalidates package identity and local resource boundaries.
  /// A missing or malformed native reply is a failure, never an empty inventory.
  static Future<List<StminiPackage>> installedPackages() async {
    final value = await _methods.invokeMethod<Object?>('installedPackages');
    if (value is! List || value.length > 256) {
      throw const FormatException('Invalid local inventory response.');
    }
    final ids = <String>{};
    final packages = <StminiPackage>[];
    for (final item in value) {
      if (item is! Map) {
        throw const FormatException('Invalid local inventory item.');
      }
      final package = StminiPackage.fromMap(item);
      if (!ids.add(package.miniId)) {
        throw const FormatException('Duplicate local inventory identity.');
      }
      packages.add(package);
    }
    return List<StminiPackage>.unmodifiable(packages);
  }

  /// Actual native stage/identity/language state; not a complete-runtime claim.
  static Future<Map<String, dynamic>> get foundationState async {
    final value = await _methods.invokeMapMethod<String, dynamic>(
      'foundationState',
    );
    if (value == null) {
      throw StateError('Native STMini foundation did not return its state.');
    }
    return Map<String, dynamic>.unmodifiable(value);
  }
}

/// Origin is native-derived from the committed main document, never H5 params.
final class WebBridgeRequest {
  WebBridgeRequest._(this.method, this.params, this.origin);
  factory WebBridgeRequest.fromMap(Object? value) {
    if (value is! Map ||
        value['method'] is! String ||
        value['params'] is! Map ||
        value['origin'] is! String) {
      throw const FormatException('Invalid native web request.');
    }
    final origin = value['origin'] as String;
    final uri = Uri.tryParse(origin);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.path.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Invalid native web origin.');
    }
    return WebBridgeRequest._(
      value['method'] as String,
      Map<String, dynamic>.unmodifiable(
        Map<String, dynamic>.from(value['params'] as Map),
      ),
      origin,
    );
  }
  final String method;
  final Map<String, dynamic> params;
  final String origin;
}

typedef WebBridgeHandler =
    FutureOr<Map<String, dynamic>?> Function(WebBridgeRequest request);
