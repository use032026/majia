import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../config/brand_config.dart';
import '../debug/debug_log_filter.dart';

/// ST 网络层基础
/// 对齐 iOS STService + STNetworkManager 的请求头
///
/// 请求头来源（iOS STVersionTwoRequest.requestRequireParams）：
///   X-Platform     : 固定 "IOS"
///   X-Pkg-Name     : 构造时通过 pkgName 传入
///   X-App-Channel  : 固定 "AppStore"
///   X-Brand        : 固定 "APPLE"
///   X-App-Version  : 构造时默认 fallback，startup 后通过 setAppVersion() 更新（PackageInfo）
///   X-Version      : 构造时默认 fallback，startup 后通过 setSystemVersion() 更新（device_info_plus）
///   X-Device-Model : 构造时默认 fallback，startup 后通过 setDeviceModel() 更新（device_info_plus）
///   X-Language     : 构造时默认 fallback，startup 后通过 setLanguage() 更新（locale）
///   X-Request-Id   : 持久化设备 UUID（DeviceIdManager），首次 fallback 随机生成
///   X-Timestamp    : 每个请求实时生成（拦截器）
///   nonce_str      : 每个请求实时生成（拦截器，iOS STRequest.appendRequestId）
///   Authorization  : 登录后通过 setAuthToken() 设置（iOS requestAuthTokenCallback）
class STDio {
  late final Dio _dio;
  final String baseUrl;
  final String pkgName;
  String? _authToken;

  // 动态请求头字段（startup 后更新为实际值）
  String _appVersion = '1.0.7';
  String _systemVersion = '18.7.7';
  String _deviceModel = 'iPhone11,8';
  String _language = 'zh-Hans';
  String _requestId;
  String? _registerToken;
  STSessionInvalidationHandler? _sessionInvalidationHandler;
  STAuthTokenRefreshHandler? _authTokenRefreshHandler;

  STDio({required this.baseUrl, required this.pkgName})
    : _requestId = const Uuid().v4().toUpperCase() {
    final platform = kIsWeb
        ? 'Web'
        : (defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'Android');
    // 对齐 iOS User-Agent: "ST/{pkgName}/{version} ({device}; {system})"
    final userAgent =
        'ST/$pkgName/$_appVersion ($_deviceModel; $_systemVersion)';

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          // 对齐 iOS STVersionTwoRequest.requestRequireParams()
          // 静态值直接放在 BaseOptions 中
          'X-Platform': platform,
          'X-Pkg-Name': pkgName,
          'X-App-Channel': 'AppStore',
          'X-Brand': 'APPLE',
          'User-Agent': userAgent,
        },
      ),
    );

    // 添加拦截器：自动添加 nonce_str、timestamp、request-id、authorization
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final domain = options.uri.host.isNotEmpty
              ? options.uri.host
              : (Uri.tryParse(options.baseUrl)?.host ?? options.baseUrl);
          debugPrint('[Request] $domain');

          // 添加 nonce_str（对齐 iOS STRequest.appendRequestId: nonce_str=<timestamp_ms>）
          // iOS 对所有请求追加 nonce_str 参数，服务器据此校验，缺少则返回 code 402
          final tsMs = DateTime.now().millisecondsSinceEpoch;
          options.queryParameters['nonce_str'] = tsMs.toString();

          // 添加 timestamp（对齐 iOS X-Timestamp）
          final timestamp = (tsMs / 1000).floor();
          options.headers['X-Timestamp'] = timestamp.toString();

          // 添加 request-id（对齐 iOS STSDKUtility.appDeviceUUID → 持久化设备 UUID）
          // 在构造时初始化一次，整个会话保持一致（M11 修复）
          options.headers['X-Request-Id'] = _requestId;

          // 添加动态请求头（在拦截器中设置，确保 startup 后更新的值生效）
          options.headers['X-App-Version'] = _appVersion;
          options.headers['X-Version'] = _systemVersion;
          options.headers['X-Device-Model'] = _deviceModel;
          options.headers['X-Language'] = _language;

          // 同步 User-Agent（在动态值更新后刷新）
          options.headers['User-Agent'] =
              'ST/$pkgName/$_appVersion ($_deviceModel; $_systemVersion)';

          // 添加 Authorization 头（对齐 iOS: STVersionTwoRequest.requestAuthTokenCallback）
          final authorization = _authorizationHeaderValue;
          if (authorization != null) {
            options.headers['Authorization'] = authorization;
          }
          if (tradeAccountSwitchDiagnosticsEnabled() &&
              options.path.contains('/transaction/accounts')) {
            debugPrint(
              '[TradeAccountSwitch][request_auth] '
              'method=${options.method} path=${options.path} '
              'auth=${debugSecretFingerprint(_authToken)}',
            );
          }

          // 添加 RegisterToken 头（对齐 iOS: STVersionTwoRequest: registerToken）
          if (_registerToken != null && _registerToken!.isNotEmpty) {
            options.headers['RegisterToken'] = _registerToken!;
          }

          handler.next(options);
        },
        onResponse: (response, handler) async {
          final retryResponse = await _refreshAuthAndRetryIfNeeded(response);
          if (retryResponse != null) {
            handler.resolve(retryResponse);
            return;
          }
          _notifySessionInvalidationIfNeeded(response.data);
          handler.next(response);
        },
        onError: (error, handler) {
          _notifySessionInvalidationIfNeeded(error.response?.data);
          handler.next(error);
        },
      ),
    );

    _dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true),
    );
  }

  /// 设置认证 Token（对齐 iOS STLoginManager.infoModel.token）
  void setAuthToken(String? token) {
    _authToken = token;
  }

  void setSessionInvalidationHandler(STSessionInvalidationHandler? handler) {
    _sessionInvalidationHandler = handler;
  }

  void setAuthTokenRefreshHandler(STAuthTokenRefreshHandler? handler) {
    _authTokenRefreshHandler = handler;
  }

  /// WebSocket 握手头（对齐 iOS `XTWebSocket.initWebSocket` 使用的
  /// `STVersionTwoRequest.requestRequireParams()` + Authorization）。
  Map<String, dynamic> buildWebSocketHeaders() {
    final platform = kIsWeb
        ? 'Web'
        : (defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'Android');
    final tsMs = DateTime.now().millisecondsSinceEpoch;
    final headers = <String, dynamic>{
      'X-Request-Id': _requestId,
      'X-Platform': platform,
      'X-Version': _systemVersion,
      'X-Brand': 'APPLE',
      'X-App-Version': _appVersion,
      'X-Timestamp': (tsMs / 1000).floor().toString(),
      'X-Device-Model': _deviceModel,
      'X-Language': _language,
      'X-Pkg-Name': pkgName,
      'X-App-Channel': 'AppStore',
    };
    final authorization = _authorizationHeaderValue;
    if (authorization != null) {
      headers['Authorization'] = authorization;
    }
    return headers;
  }

  /// 设置 RegisterToken 头（对齐 iOS: STVersionTwoRequest: registerToken）
  void setRegisterToken(String? token) {
    _registerToken = token;
  }

  /// 设置 X-Request-Id（对齐 iOS AppDeviceIdTool — 持久化设备 UUID，每次启动保持一致）
  void setRequestId(String id) {
    _requestId = id;
  }

  /// 设置 X-App-Version（对齐 iOS STSDKUtility.appVersion → CFBundleShortVersionString）
  void setAppVersion(String version) {
    _appVersion = version;
  }

  /// 设置 X-Version（对齐 iOS STSDKUtility.systemVersion → UIDevice.systemVersion）
  void setSystemVersion(String version) {
    _systemVersion = version;
  }

  /// 设置 X-Device-Model（对齐 iOS STSDKUtility.systemModel → uname.machine）
  void setDeviceModel(String model) {
    _deviceModel = model;
  }

  /// 设置 X-Language（对齐 iOS STBundle.requestHeaderLanguageParam）
  void setLanguage(String language) {
    _language = language;
  }

  /// 当前请求语言（用于 query 参数 `lang`，对齐 iOS requestHeaderLanguageParam）
  String get currentLanguage => _language;

  String get currentRequestId => _requestId;

  String get currentAppVersion => _appVersion;

  String get currentSystemVersion => _systemVersion;

  String get currentDeviceModel => _deviceModel;

  /// 当前登录 token（TUS 上传 metadata 需要与 iOS `STUploadFileTool` 保持一致）。
  String? get currentAuthToken => _authToken;

  Dio get client => _dio;

  String? get _authorizationHeaderValue {
    final token = _authToken?.trim();
    if (token == null || token.isEmpty) return null;
    if (token.toLowerCase().startsWith('bearer ')) return token;
    return 'Bearer $token';
  }

  Future<Response<dynamic>?> _refreshAuthAndRetryIfNeeded(
    Response<dynamic> response,
  ) async {
    final requestOptions = response.requestOptions;
    if (requestOptions.extra[_stAuthRetryExtraKey] == true) return null;

    final data = stAuthTokenRefreshDataFromPayload(response.data);
    if (data == null) return null;

    final token = data['token'] as String;
    _authToken = token;
    final handler = _authTokenRefreshHandler;
    if (handler != null) {
      await handler(data);
    }

    final retryHeaders = Map<String, dynamic>.from(requestOptions.headers);
    retryHeaders['Authorization'] = _authorizationHeaderValue ?? token;
    final retryExtra = Map<String, dynamic>.from(requestOptions.extra);
    retryExtra[_stAuthRetryExtraKey] = true;

    return _dio.fetch<dynamic>(
      requestOptions.copyWith(headers: retryHeaders, extra: retryExtra),
    );
  }

  void _notifySessionInvalidationIfNeeded(dynamic data) {
    final handler = _sessionInvalidationHandler;
    if (handler == null) return;
    final reason = stSessionInvalidationReasonFromPayload(data);
    if (reason == null) return;
    unawaited(
      handler(reason).catchError((Object e, StackTrace stackTrace) {
        debugPrint('⚠️ session invalidation handler failed: $e');
      }),
    );
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get<T>(path, queryParameters: queryParameters);
  }

  Future<Response<T>> post<T>(String path, {dynamic data}) {
    return _dio.post<T>(path, data: data);
  }
}

enum STSessionInvalidationReason { loggedInOnAnotherDevice, loginStateInvalid }

typedef STSessionInvalidationHandler =
    Future<void> Function(STSessionInvalidationReason reason);

typedef STAuthTokenRefreshHandler =
    Future<void> Function(Map<String, dynamic> data);

const String _stAuthRetryExtraKey = 'st_iOS_401_auth_retry';

Map<String, dynamic>? stAuthTokenRefreshDataFromPayload(dynamic payload) {
  if (payload is! Map) return null;
  final raw = payload['code'];
  final code = raw is num ? raw.toInt() : int.tryParse('$raw');
  if (code != 401) return null;
  final data = payload['data'];
  if (data is! Map) return null;
  final normalized = Map<String, dynamic>.from(data);
  final token = normalized['token']?.toString().trim();
  if (token == null || token.isEmpty) return null;
  normalized['token'] = token;
  return normalized;
}

STSessionInvalidationReason? stSessionInvalidationReasonFromPayload(
  dynamic payload,
) {
  if (payload is! Map) return null;
  final raw = payload['code'];
  final code = raw is num ? raw.toInt() : int.tryParse('$raw');
  return switch (code) {
    110016 => STSessionInvalidationReason.loggedInOnAnotherDevice,
    402 || 403 => STSessionInvalidationReason.loginStateInvalid,
    _ => null,
  };
}

/// Provider - 使用 BrandConfig 中的域名 + violet/api 前缀
/// 自动根据编译模式选择 Debug/Profile/Release 域名和包名
final stDioProvider = Provider<STDio>((ref) {
  final brand = BrandConfig.jufu();
  final domain = brand.apiBaseUrlForBuildMode;
  final pkgName = brand.packageNameForBuildMode;

  return STDio(baseUrl: '$domain/violet', pkgName: pkgName);
});
