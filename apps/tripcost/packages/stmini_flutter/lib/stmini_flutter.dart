import 'dart:async';

import 'package:flutter/services.dart';
import 'src/runtime_mode.dart';

export 'src/runtime_mode.dart';

/// Cross-platform entry point for the Web-only STMini Flutter plugin.
///
/// This package presents ordinary online Web documents. It intentionally does
/// not download, install, cache, or route local packages.
class StminiFlutter {
  StminiFlutter._();

  /// 运行形态仅由分支专属配置提供；入口文件不重复维护 `mini/web` 常量，
  /// 以免共享 Bridge 改动与运行形态声明发生无意义冲突。
  static const runtimeMode = configuredStminiRuntimeMode;

  static const MethodChannel _methods = MethodChannel('stmini_flutter/methods');
  static const EventChannel _events = EventChannel('stmini_flutter/events');
  static WebBridgeHandler? _webBridgeHandler;

  /// Ordinary Web presentation events (`web_open_requested`, `web_opened`,
  /// and `web_closed`). No Mini lifecycle or package events are emitted.
  static Stream<StminiEvent> get events => _events
      .receiveBroadcastStream()
      .where((value) => value is Map)
      .map(
        (value) => StminiEvent.fromMap(Map<String, dynamic>.from(value as Map)),
      );

  /// Configures ordinary Web navigation. Every allowed top-level document can
  /// use the native bridge; iframes and stale documents remain rejected.
  static Future<void> initialize({Map<String, dynamic>? bridgeContext}) {
    return _methods.invokeMethod<void>('initialize', {
      if (bridgeContext != null) 'bridgeContext': bridgeContext,
    });
  }

  /// Installs the host handler for an explicitly authorized online Web page.
  /// Native derives [WebBridgeRequest.origin] from the committed top-level
  /// document; it never accepts an origin sent by H5.
  static void setWebBridgeHandler(WebBridgeHandler? handler) {
    _webBridgeHandler = handler;
    _methods.setMethodCallHandler(_handleNativeWebBridgeCall);
  }

  static Future<dynamic> _handleNativeWebBridgeCall(MethodCall call) async {
    if (call.method != 'webBridgeRequest') {
      throw MissingPluginException('Unsupported native method: ${call.method}');
    }
    final handler = _webBridgeHandler;
    if (handler == null) return _failure('宿主未处理该网页请求');
    final raw = Map<Object?, Object?>.from(call.arguments as Map? ?? const {});
    try {
      return await handler(WebBridgeRequest.fromMap(raw)) ??
          _failure('宿主未处理该网页请求');
    } catch (_) {
      return _failure('宿主处理网页请求失败');
    }
  }

  static const Map<String, dynamic> _unhandled = {
    'code': '0',
    'data': {'msg': '宿主未处理该网页请求'},
  };

  static Map<String, dynamic> _failure(String message) =>
      message == '宿主未处理该网页请求'
      ? _unhandled
      : {
          'code': '0',
          'data': {'msg': message},
        };

  /// Opens an external HTTPS page. To permit HTTP for a local environment,
  /// set `webSecurity.allowInsecureHTTP` in [initialize]'s bridge context and
  /// configure the host platform's network policy. [showNavigationBar]
  /// defaults to true.
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

  /// Closes the active ordinary Web presentation, if any.
  static Future<void> closeWeb() => _methods.invokeMethod<void>('closeWeb');

  /// Delivers a credential-free session-change signal to sibling online Web
  /// pages after the host has persisted their shared auth snapshot.
  static Future<int> notifyWebSessionChanged(String reason) async =>
      (await _methods.invokeMethod<int>('notifyWebSessionChanged', {
        'reason': reason,
      })) ??
      0;

  /// Returns whether the native iOS or Android Web module is available.
  static Future<bool> get isAvailable async =>
      (await _methods.invokeMethod<bool>('isAvailable')) ?? false;
}

/// A native-verified request from an explicitly authorized ordinary Web page.
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
