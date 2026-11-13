import 'dart:async';

import 'package:flutter/services.dart';
import 'src/runtime_mode.dart';

export 'src/runtime_mode.dart';

/// Cross-platform entry point for STMini.
///
/// The plugin is deliberately limited to generic Mini-program capabilities:
/// verified ZIP packages, `mini://` opening, local package reuse, native
/// loading UI, lifecycle events and the framework Mini APIs. Business APIs
/// such as accounts, trading and authorisation belong to the embedding app.
class StminiFlutter {
  StminiFlutter._();

  /// 运行形态仅由分支专属配置提供；入口文件不重复维护 `mini/web` 常量，
  /// 以免共享 Bridge 改动与运行形态声明发生无意义冲突。
  static const runtimeMode = configuredStminiRuntimeMode;

  static const MethodChannel _methods = MethodChannel('stmini_flutter/methods');
  static const EventChannel _events = EventChannel('stmini_flutter/events');
  static WebBridgeHandler? _webBridgeHandler;

  /// Native lifecycle/install/open diagnostic events.
  static Stream<StminiEvent> get events => _events
      .receiveBroadcastStream()
      .where((value) => value is Map)
      .map(
        (value) => StminiEvent.fromMap(Map<String, dynamic>.from(value as Map)),
      );

  /// Configures the native STMini host once before opening a Mini.
  ///
  /// [loadingImage] is an optional image name from the host application's
  /// resources. If omitted STMini uses its packaged fallback loading UI.
  ///
  /// [bridgeContext] is optional host-owned, JSON-compatible context for
  /// generic H5 bridge APIs. A host may provide `packageName`, `userInfo`,
  /// `config`, and an `authStorageKey` when its Mini persists a JSON auth
  /// snapshot through the storage bridge. `packageName` defaults to an empty
  /// string; STMini never embeds a business package identifier.
  ///
  /// Every allowed top-level ordinary Web page may use the common native
  /// bridge. Iframes and messages from a document that no longer matches the
  /// displayed page are rejected. HTTP stays disabled unless
  /// `webSecurity.allowInsecureHTTP` is true; that local-testing opt-in also
  /// permits top-level HTTP pages to use the bridge.
  static Future<void> initialize({
    String? loadingImage,
    Map<String, dynamic>? bridgeContext,
  }) {
    return _methods.invokeMethod<void>('initialize', {
      if (loadingImage != null && loadingImage.isNotEmpty)
        'loadingImage': loadingImage,
      if (bridgeContext != null) 'bridgeContext': bridgeContext,
    });
  }

  /// Installs a handler for requests from an allowed top-level ordinary Web
  /// page. It is never called for local Mini package pages.
  ///
  /// The page origin is native-derived from the committed top-level document;
  /// it cannot be supplied or overridden by H5. Return a map containing
  /// optional `code` and `data`. A failure must use
  /// `{'code': '0', 'data': {'msg': '...'}}`; malformed values are normalized
  /// by native code before reaching `CMSJsCallBack`.
  static void setWebBridgeHandler(WebBridgeHandler? handler) {
    _webBridgeHandler = handler;
    _methods.setMethodCallHandler(_handleNativeWebBridgeCall);
  }

  static Future<dynamic> _handleNativeWebBridgeCall(MethodCall call) async {
    if (call.method != 'webBridgeRequest') {
      throw MissingPluginException('Unsupported native method: ${call.method}');
    }
    final handler = _webBridgeHandler;
    if (handler == null) {
      return const {
        'code': '0',
        'data': {'msg': '宿主未处理该网页请求'},
      };
    }
    final raw = Map<Object?, Object?>.from(call.arguments as Map? ?? const {});
    final request = WebBridgeRequest.fromMap(raw);
    try {
      final response = await handler(request);
      return response ??
          const {
            'code': '0',
            'data': {'msg': '宿主未处理该网页请求'},
          };
    } catch (_) {
      return const {
        'code': '0',
        'data': {'msg': '宿主处理网页请求失败'},
      };
    }
  }

  /// Opens an online Mini using the shared `mini://<miniId>` contract.
  ///
  /// The link may carry `downloadUrl`, version and display parameters. The
  /// native STMini container owns download, verification, atomic installation,
  /// local package reuse and its loading animation.
  static Future<void> openMini(String link) {
    return _methods.invokeMethod<void>('openMini', {'link': link});
  }

  /// Presents an external HTTPS page in STMini's reusable native H5
  /// container. `webSecurity.allowInsecureHTTP` explicitly permits HTTP for
  /// local testing in every build mode.
  /// The page is independent of any Mini ZIP package.
  ///
  /// [showNavigationBar] defaults to true so the host always provides a
  /// native back affordance. Set it to false only when the page owns its own
  /// complete navigation and close behaviour.
  static Future<void> openWeb(
    String url, {
    String? title,
    bool showNavigationBar = true,
  }) {
    return _methods.invokeMethod<void>('openWeb', {
      'url': url,
      if (title != null && title.isNotEmpty) 'title': title,
      'showNavigationBar': showNavigationBar,
    });
  }

  /// Closes an ordinary online-Web page when the current host selected the
  /// Web-only runtime. Complete Mini hosts use [closeMini] instead.
  static Future<void> closeWeb() => _methods.invokeMethod<void>('closeWeb');

  /// Delivers a credential-free session-change signal to sibling online Web
  /// pages after the host has persisted their shared auth snapshot.
  /// Complete Mini packages use `mini_notifySessionChanged` directly.
  static Future<int> notifyWebSessionChanged(String reason) async =>
      (await _methods.invokeMethod<int>('notifyWebSessionChanged', {
        'reason': reason,
      })) ??
      0;

  /// Dismisses the currently presented Mini container, if any.
  static Future<void> closeMini() => _methods.invokeMethod<void>('closeMini');

  /// Returns only fully verified and runnable local Mini packages.
  static Future<List<StminiPackage>> installedPackages() async {
    final packages =
        await _methods.invokeListMethod<Map>('installedPackages') ?? const [];
    return packages
        .map((value) => StminiPackage.fromMap(Map<String, dynamic>.from(value)))
        .toList(growable: false);
  }

  /// Returns whether the native iOS or Android host module is available.
  static Future<bool> get isAvailable async =>
      (await _methods.invokeMethod<bool>('isAvailable')) ?? false;
}

/// A native-verified, explicitly authorized ordinary Web request.
class WebBridgeRequest {
  const WebBridgeRequest({
    required this.method,
    required this.params,
    required this.origin,
  });

  factory WebBridgeRequest.fromMap(Map<Object?, Object?> value) {
    final rawParams = value['params'];
    return WebBridgeRequest(
      method: value['method'] as String? ?? '',
      params: rawParams is Map
          ? Map<String, dynamic>.from(rawParams)
          : const <String, dynamic>{},
      // Native only sends normalized https://host[:port]. Do not infer an
      // origin from params or any H5-controlled URL field.
      origin: value['origin'] as String? ?? '',
    );
  }

  final String method;
  final Map<String, dynamic> params;
  final String origin;
}

typedef WebBridgeHandler =
    FutureOr<Map<String, dynamic>?> Function(WebBridgeRequest request);

class StminiEvent {
  const StminiEvent({required this.name, required this.payload});

  factory StminiEvent.fromMap(Map<String, dynamic> value) => StminiEvent(
    name: value['name'] as String? ?? 'unknown',
    payload: Map<String, dynamic>.from(value['payload'] as Map? ?? const {}),
  );

  final String name;
  final Map<String, dynamic> payload;
}

class StminiPackage {
  const StminiPackage({
    required this.miniId,
    required this.miniName,
    required this.iconUrl,
    required this.launchLink,
    this.version = '',
  });

  factory StminiPackage.fromMap(Map<String, dynamic> value) => StminiPackage(
    miniId: value['miniId'] as String? ?? '',
    miniName: value['miniName'] as String? ?? '',
    iconUrl: value['iconUrl'] as String? ?? '',
    launchLink: value['launchLink'] as String? ?? '',
    version: value['version'] as String? ?? '',
  );

  final String miniId;
  final String miniName;
  final String iconUrl;
  final String launchLink;

  /// Verified package version supplied by the native package manifest.
  final String version;
}
