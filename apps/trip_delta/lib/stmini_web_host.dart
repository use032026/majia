import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stmini_flutter/stmini_flutter.dart';
import 'web_launch_splash.dart';

/// The host adapter keeps the Web-only plugin boundary replaceable in tests.
abstract interface class TripWebRuntime {
  bool get isSupported;
  Future<void> initialize(Map<String, dynamic> context);
  void setBridgeHandler(WebBridgeHandler? handler);
  Future<void> open(
    String url, {
    String? title,
    required bool showNavigationBar,
  });
  Future<void> close();
  Future<int> notifySessionChanged(String reason);
}

class StminiTripWebRuntime implements TripWebRuntime {
  const StminiTripWebRuntime();

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<void> initialize(Map<String, dynamic> context) async {
    if (isSupported) {
      await StminiFlutter.initialize(bridgeContext: context);
    }
  }

  @override
  void setBridgeHandler(WebBridgeHandler? handler) {
    if (isSupported) StminiFlutter.setWebBridgeHandler(handler);
  }

  @override
  Future<void> open(
    String url, {
    String? title,
    required bool showNavigationBar,
  }) {
    if (!isSupported) throw UnsupportedError('Web integration is iOS only');
    return StminiFlutter.openWeb(
      url,
      title: title,
      showNavigationBar: showNavigationBar,
    );
  }

  @override
  Future<void> close() {
    if (!isSupported) throw UnsupportedError('Web integration is iOS only');
    return StminiFlutter.closeWeb();
  }

  @override
  Future<int> notifySessionChanged(String reason) {
    if (!isSupported) throw UnsupportedError('Web integration is iOS only');
    return StminiFlutter.notifyWebSessionChanged(reason);
  }
}

/// One app-owned service for the ordinary online Web container.
///
/// The default URL follows the user's confirmed reference; callers may supply
/// another explicit HTTPS home for an isolated environment.
/// Native code validates main-frame/current-document origins before invoking
/// this handler. Internal app routes additionally require the home origin.
/// This service owns no event subscriptions and never reads trip/account data.
class TripDeltaWebHost {
  TripDeltaWebHost({
    String homeUrl = defaultHomeUrl,
    this.sessionDomainSubstring = defaultSessionDomainSubstring,
    TripWebRuntime runtime = const StminiTripWebRuntime(),
  }) : homeUri =
           _httpsUri(homeUrl) ??
           (throw ArgumentError.value(homeUrl, 'homeUrl', 'Requires HTTPS')),
       _runtime = runtime;

  static const defaultHomeUrl =
      'https://h5.globalsmartchoose.com/polymer/h5app/#/';
  static const defaultSessionDomainSubstring = 'globalsmartchoose';

  final Uri homeUri;
  final String sessionDomainSubstring;
  final TripWebRuntime _runtime;
  Future<void>? _initializing;
  bool _ready = false;
  bool _disposed = false;

  Future<void> initialize() {
    if (_disposed) return Future.error(StateError('Web host is disposed'));
    if (!_runtime.isSupported) return Future.value();
    if (_ready) return Future.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      _runtime.setBridgeHandler(handleBridge);
      await _runtime.initialize({
        'packageName': 'com.globalsmartchoose.app',
        'webSecurity': {
          'allowInsecureHTTP': false,
          'bridgeOrigins': [homeUri.origin],
          'sessionDomainSubstring': sessionDomainSubstring,
        },
        'webLoading': const {
          'readyEvent': 'futrenapp:startup-complete',
          'failureEvent': 'futrenapp:startup-failed',
          'launchImages': webLaunchImages,
          'languageStorage': {
            'valueKey': 'language',
            'manualKey': 'language_user_set',
          },
        },
      });
      if (_disposed) throw StateError('Web host is disposed');
      _ready = true;
    } finally {
      _initializing = null;
    }
  }

  Future<void> openHome({bool showNavigationBar = true}) async {
    if (!_runtime.isSupported) {
      throw UnsupportedError('Web integration is iOS only');
    }
    await initialize();
    if (_disposed) throw StateError('Web host is disposed');
    await _runtime.open(
      homeUri.toString(),
      showNavigationBar: showNavigationBar,
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _ready = false;
    if (_runtime.isSupported) _runtime.setBridgeHandler(null);
  }

  Future<Map<String, dynamic>> handleBridge(WebBridgeRequest request) async {
    if (!_runtime.isSupported) return _failure('当前平台未接入网页宿主');
    if (_disposed) return _failure('网页宿主已关闭');
    final params = request.params;
    try {
      switch (request.method) {
        case 'applog':
          // Acknowledge diagnostics without logging page-controlled secrets.
          return _success();
        case 'close':
          await _runtime.close();
          return _success();
        case 'web_notifySessionChanged':
          final rawReason = params['reason'];
          if (rawReason != null && rawReason is! String) {
            return _failure('会话通知参数无效');
          }
          final reason = (rawReason as String?)?.trim();
          if (reason != null && reason.length > 128) {
            return _failure('会话通知参数无效');
          }
          final count = await _runtime.notifySessionChanged(
            reason == null || reason.isEmpty ? 'sessionChanged' : reason,
          );
          return _success({'notified': count});
        case 'open':
          return await _openRoute(request);
        default:
          return _failure('网页请求不受支持');
      }
    } catch (_) {
      return _failure('原生网页操作失败');
    }
  }

  Future<Map<String, dynamic>> _openRoute(WebBridgeRequest request) async {
    final params = request.params;
    final router = params['router'];
    if (router is! String ||
        !router.startsWith('/') ||
        router.startsWith('//') ||
        router.contains('\\') ||
        RegExp(r'[\x00-\x20\x7f]').hasMatch(router)) {
      return _failure('网页路由无效');
    }
    if (router == '/web') {
      final link = params['link'];
      final uri = link is String ? _httpsUri(link) : null;
      final title = params['title'];
      if (uri == null || (title != null && title is! String)) {
        return _failure('网页地址无效');
      }
      await _runtime.open(
        uri.toString(),
        title: title as String?,
        showNavigationBar: _navigationBarVisible(params['isNeedNavigationBar']),
      );
      return _success();
    }
    final origin = _httpsUri(request.origin);
    if (origin == null || origin.origin != homeUri.origin) {
      return _failure('当前网页不能打开应用路由');
    }
    final routeParams = Map<String, dynamic>.from(params)..remove('methodId');
    if (router == '/login' || router == '/mine/login') {
      routeParams['isBack'] = '1';
    }
    final encoded = base64Url
        .encode(utf8.encode(jsonEncode(routeParams)))
        .replaceAll('=', '');
    final url = homeUri.replace(
      fragment:
          '/?__mini_child=1&__mini_route_child=1&__mini_open_route=$encoded',
    );
    // Each explicit open is independent, including identical consecutive URLs.
    await _runtime.open(url.toString(), showNavigationBar: false);
    return _success();
  }

  static Uri? _httpsUri(String value) {
    if (value.isEmpty ||
        value != value.trim() ||
        value.contains('\\') ||
        RegExp(r'[\x00-\x20\x7f]').hasMatch(value)) {
      return null;
    }
    final uri = Uri.tryParse(value);
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri
        : null;
  }

  static bool _navigationBarVisible(Object? value) => switch (value) {
    true || 1 || '1' || 'true' || 'yes' => true,
    _ => false,
  };

  static Map<String, dynamic> _success([Map<String, dynamic>? data]) => {
    'code': '1',
    'data': data ?? <String, dynamic>{},
  };

  static Map<String, dynamic> _failure(String message) => {
    'code': '0',
    'data': {'msg': message},
  };
}
