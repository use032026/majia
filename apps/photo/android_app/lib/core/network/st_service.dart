import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/category_market_paging.dart';
import '../config/brand_config.dart';
import '../crypto/st_hmac_sha256.dart';
import '../debug/debug_log_filter.dart';
import '../models/h5_address_payload.dart';
import '../models/user_state.dart';
import '../services/session_invalidation_coordinator.dart';
import '../services/wallet_deposit_withdraw_contract.dart';
import '../services/user_preference_prefs.dart';
import '../../shared/widgets/st_localized_prompt.dart';
import 'st_dio.dart';

class STBusinessResponseException implements Exception {
  STBusinessResponseException({
    required this.code,
    required this.message,
    required this.response,
  });

  factory STBusinessResponseException.fromResponse(Map<String, dynamic> json) {
    final rawCode = json['code'];
    final code = rawCode is num
        ? rawCode.toInt()
        : int.tryParse('$rawCode') ?? -1;
    final message = json['message']?.toString() ?? '';
    return STBusinessResponseException(
      code: code,
      message: message,
      response: Map<String, dynamic>.from(json),
    );
  }

  final int code;
  final String message;
  final Map<String, dynamic> response;

  bool get isLoggedInOnAnotherDevice => code == 110016;

  @override
  String toString() => 'STBusinessResponseException($code, $message)';
}

/// ST 业务服务层
/// 完全对齐 iOS STService 各 Category API 路径
/// baseUrl = '$domain/violet'（在 STDio 中配置）
/// iOS violet/api/... → Flutter /api/...
/// iOS violet/marketdata/... → Flutter /marketdata/...
/// iOS violet/h5/... → Flutter /h5/...
class STService {
  final STDio dio;

  STService(this.dio);

  /// iOS GET 请求里 `need_points` 为 NSNumber，序列化多为 `1`/`0`；用 `"true"` 时部分环境不识别，热门/自选接口会返回空列表。
  static String _needPointsQuery(bool needPoints) => needPoints ? '1' : '0';

  static Map<String, Object?> _tradeAccountSwitchRequestDebug(
    Map<String, dynamic> data,
  ) {
    final account = data['account'];
    final accountMap = account is Map ? Map<String, dynamic>.from(account) : {};
    return {
      'account_id': accountMap['id'],
      'account_type': accountMap['type'],
      'platform': accountMap['platform'],
      'status': accountMap['status'],
      'app_id': data['app_id'],
      'request_platform': data['platform'],
      'login_type': data['login_type'],
    };
  }

  static Map<String, Object?> _tradeAccountSwitchResponseDebug(
    Map<String, dynamic> root,
  ) {
    final data = root['data'];
    final dataMap = data is Map ? Map<String, dynamic>.from(data) : null;
    return {
      'code': root['code'],
      'message': root['message'],
      'data_type': data.runtimeType.toString(),
      'data_keys': dataMap?.keys.toList(growable: false),
      'token': debugSecretFingerprint(dataMap?['token']),
      'refresh_token': debugSecretFingerprint(dataMap?['refresh_token']),
      'transaction_account':
          dataMap?['transaction_account'] ?? dataMap?['transactionAccount'],
      'transaction_account_type':
          dataMap?['transaction_account_type'] ??
          dataMap?['transactionAccountType'],
      'is_active': dataMap?['is_active'] ?? dataMap?['isActive'],
    };
  }

  static const List<String> _symbolArrayKeys = [
    'symbols',
    'list',
    'items',
    'records',
    'rows',
  ];

  static Map<String, dynamic> _requireBusinessSuccess(
    Object? raw,
    String fallbackMessage,
  ) {
    final root = raw is Map<String, dynamic>
        ? raw
        : raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final code = root['code'];
    final ok = code == null || code == 0 || code == '0';
    if (!ok) {
      throw Exception(root['message']?.toString() ?? fallbackMessage);
    }
    return root;
  }

  /// 从 `get_symbols_data` 等业务返回的 **data 层** Map 中取出品种数组（键名因环境而异）。
  static List<dynamic> symbolArrayFromMarketDataMap(
    Map<String, dynamic> dataMap,
  ) {
    for (final k in _symbolArrayKeys) {
      final v = dataMap[k];
      if (v is List) return List<dynamic>.from(v);
    }
    return <dynamic>[];
  }

  /// 解析 `get_symbols_data` 返回体：标准 `{ code, data: { symbols, next_offset } }`，或 `data` 为 JSON 字符串、
  /// 或已是带 `symbols`/`list` 的扁平 Map（对齐 iOS `STJSONResponse` 取 `data` 后再读列表）。
  static Map<String, dynamic> marketListDataFromRoot(
    Map<String, dynamic> root,
  ) {
    final code = root['code'];
    if (code is int && code != 0) {
      debugPrint('⚠️ get_symbols_data code=$code message=${root['message']}');
    }
    final d = root['data'];
    if (d is Map) {
      return Map<String, dynamic>.from(d);
    }
    if (d is String && d.isNotEmpty) {
      try {
        final decoded = jsonDecode(d);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
        if (decoded is List) {
          return <String, dynamic>{'symbols': List<dynamic>.from(decoded)};
        }
      } catch (e) {
        debugPrint('⚠️ marketListDataFromRoot data decode: $e');
      }
    }
    if (d is List<dynamic>) {
      return <String, dynamic>{'symbols': d};
    }
    for (final k in _symbolArrayKeys) {
      if (root[k] is List) {
        return Map<String, dynamic>.from(root);
      }
    }
    return <String, dynamic>{};
  }

  /// 解析 `get_hot_symbol` / `get_symbol_watch_list` / `get_watch_symbol` 等与 iOS `STJSONResponse.data[@"symbols"]` 对齐。
  static List<dynamic> _symbolsListFromResponseRoot(Map<String, dynamic> root) {
    final code = root['code'];
    if (code is int && code != 0) {
      debugPrint('⚠️ market list API code=$code message=${root['message']}');
    }
    final data = root['data'];
    if (data is List<dynamic>) return data;
    if (data is Map) {
      final nested = symbolArrayFromMarketDataMap(
        Map<String, dynamic>.from(data),
      );
      if (nested.isNotEmpty) return nested;
    }
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is List) return List<dynamic>.from(decoded);
        if (decoded is Map) {
          final nested = symbolArrayFromMarketDataMap(
            Map<String, dynamic>.from(decoded),
          );
          if (nested.isNotEmpty) return nested;
        }
      } catch (e) {
        debugPrint('⚠️ _symbolsListFromResponseRoot data decode: $e');
      }
    }
    final top = symbolArrayFromMarketDataMap(root);
    if (top.isNotEmpty) return top;
    return <dynamic>[];
  }

  static List<dynamic> _listFromResponseRoot(
    Map<String, dynamic> root,
    List<String> keys,
  ) {
    List<dynamic> pickFromMap(Map<String, dynamic> map) {
      for (final key in keys) {
        final value = map[key];
        if (value is List<dynamic>) return List<dynamic>.from(value);
        if (value is List) return List<dynamic>.from(value);
      }
      return const <dynamic>[];
    }

    final data = root['data'];
    if (data is List<dynamic>) return List<dynamic>.from(data);
    if (data is List) return List<dynamic>.from(data);
    if (data is Map) {
      final nested = pickFromMap(Map<String, dynamic>.from(data));
      if (nested.isNotEmpty) return nested;
    }
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is List) return List<dynamic>.from(decoded);
        if (decoded is Map) {
          final nested = pickFromMap(Map<String, dynamic>.from(decoded));
          if (nested.isNotEmpty) return nested;
        }
      } catch (e) {
        debugPrint('⚠️ _listFromResponseRoot data decode: $e');
      }
    }
    final top = pickFromMap(root);
    if (top.isNotEmpty) return top;
    return <dynamic>[];
  }

  /// 从服务响应中提取列表，兼容返回 list / map 中嵌套 list / JSON 字符串等形态。
  ///
  /// 返回 `[]` 表示无法识别可用的列表。
  static List<dynamic> _extractListFromResponse(
    dynamic response, {
    List<String> candidateKeys = const ['data'],
    bool wrapSingleMap = true,
  }) {
    final normalized = _decodeJsonIfNeeded(response);
    if (normalized is List<dynamic>) {
      return List<dynamic>.from(normalized);
    }
    if (normalized is! Map<String, dynamic>) {
      return const [];
    }

    final map = Map<String, dynamic>.from(normalized);
    for (final key in candidateKeys) {
      final raw = map[key];
      final decoded = _decodeJsonIfNeeded(raw);
      if (decoded is List<dynamic>) return List<dynamic>.from(decoded);
      if (decoded is List) return List<dynamic>.from(decoded);
      if (decoded is Map) {
        final nested = _extractListFromResponse(
          Map<String, dynamic>.from(decoded),
          candidateKeys: candidateKeys,
          wrapSingleMap: false,
        );
        if (nested.isNotEmpty) return nested;
        if (wrapSingleMap) return <dynamic>[Map<String, dynamic>.from(decoded)];
      }
    }
    return const [];
  }

  /// 尝试将 JSON 字符串解码为 Dart 对象，否则原样返回。
  static dynamic _decodeJsonIfNeeded(dynamic value) {
    if (value is String && value.isNotEmpty) {
      try {
        return jsonDecode(value);
      } catch (_) {
        return value;
      }
    }
    return value;
  }

  static Map<String, dynamic> _dataMapFromResponseRoot(
    Map<String, dynamic> root,
  ) {
    if (!root.containsKey('data')) return root;
    final data = _decodeJsonIfNeeded(root['data']);
    if (data is Map) return Map<String, dynamic>.from(data);
    return root;
  }

  // ==================== 启动 & 配置 ====================

  /// 获取主题配置（对齐 iOS: violet/api）
  /// 返回值为 response.data（仅 code==0 时）
  Future<Map<String, dynamic>?> getStartupThemeConfig() async {
    final res = await dio.get('/api');
    final json = res.data;
    if (json is! Map<String, dynamic>) return null;

    final code = json['code'];
    if (code is num && code.toInt() != 0) {
      debugPrint('⚠️ getStartupThemeConfig code=$code: ${json['message']}');
      return null;
    }

    final dynamic data = json['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (e) {
        debugPrint('⚠️ getStartupThemeConfig data decode failed: $e');
      }
    }
    return null;
  }

  /// 获取 App 配置（对齐 iOS: violet/api/appconfiguration/schema?is_h5_app=0）
  /// 返回的 Map 是 response.data（unwrap 后的配置数据），失败返回 null
  Future<Map<String, dynamic>?> getAppConfig({
    required String brandCode,
  }) async {
    final res = await dio.get(
      '/api/appconfiguration/schema',
      queryParameters: {'is_h5_app': 0},
    );
    final json = res.data as Map<String, dynamic>;
    // iOS 解析为 STJSONResponse，取 data 字段
    final code = json['code'] as int? ?? -1;
    if (code == 0) {
      final data = json['data'];
      if (data is Map<String, dynamic>) return data;
      if (data is String && data.isNotEmpty) {
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (e) {
          debugPrint('⚠️ getAppConfig data JSON decode: $e');
        }
      }
      return null;
    }
    debugPrint('⚠️ getAppConfig returned code=$code: ${json['message']}');
    throw STBusinessResponseException.fromResponse(json);
  }

  /// 版本更新检查（对齐 iOS: violet/api/account/v2/version-update）
  Future<Map<String, dynamic>> checkVersion({
    String system = 'IOS',
    String localVersion = '',
    String pkgId = '',
    String language = 'zh-Hans',
    String channel = 'AppStore',
  }) async {
    final res = await dio.get(
      '/api/account/v2/version-update',
      queryParameters: {
        'system': system,
        'local_version': localVersion,
        'pkg_id': pkgId,
        'language': language,
        'channel': channel,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// 版本更新通知（对齐 iOS: violet/api/account/version-update-notify）
  Future<Map<String, dynamic>> requestVersionUpdateNotify({
    String system = 'IOS',
    String pkgId = '',
    String channel = 'AppStore',
    required String updateVersion,
  }) async {
    final res = await dio.post(
      '/api/account/version-update-notify',
      data: {
        'system': system,
        'pkg_id': pkgId,
        'channel': channel,
        'update_version': updateVersion,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// H5 地址配置（对齐 iOS: violet/h5/config）
  /// 兼容扁平 Map 与 `{ code, data: { ... } }` 包一层，避免换环境后合并进 h5Config 结构不对。
  static Map<String, dynamic> h5AddressDataFromRoot(dynamic raw) {
    return normalizeH5AddressPayload(raw);
  }

  Future<Map<String, dynamic>> getH5Addresses() async {
    final res = await dio.get('/h5/config');
    return h5AddressDataFromRoot(res.data);
  }

  /// 获取页面配置（含卡片列表）（对齐 iOS: violet/api/appconfiguration/page）
  Future<Map<String, dynamic>> getPageInfo(Map<String, dynamic> params) async {
    final res = await dio.get(
      '/api/appconfiguration/page',
      queryParameters: params,
    );
    return res.data as Map<String, dynamic>;
  }

  /// 页面配置 data 层（对齐 iOS requestPageInfo completion 的 response 字典）
  /// Android 等平台可能将 `data` 序列化为 JSON 字符串，这里一并解析。
  Future<Map<String, dynamic>?> fetchPageConfiguration({
    required int pageId,
  }) async {
    try {
      final res = await dio.get(
        '/api/appconfiguration/page',
        queryParameters: {'page_id': pageId},
      );
      final json = res.data as Map<String, dynamic>;
      final code = json['code'] as int? ?? -1;
      if (code != 0) {
        debugPrint('⚠️ fetchPageConfiguration code=$code: ${json['message']}');
        return null;
      }
      final data = json['data'];
      if (data is Map<String, dynamic>) return data;
      if (data is String && data.isNotEmpty) {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return null;
    } catch (e, st) {
      debugPrint('⚠️ fetchPageConfiguration error: $e\n$st');
      return null;
    }
  }

  // ==================== 认证 & 登录 ====================

  /// `STLoginSendVerCodeType`（短信），数值对齐 iOS 枚举
  static const int smsVerCodeTypeFindPassword = 1;
  static const int smsVerCodeTypeRegister = 2;
  static const int smsVerCodeTypeBindPhone = 3;
  static const int smsVerCodeTypeLogin = 6;

  /// 邮箱验证码 `type`（`requestEmailVercodeWithParams`）
  static const int emailVerCodeTypeFindPassword = 1;
  static const int emailVerCodeTypeRegister = 2;
  static const int emailVerCodeTypeLogin = 6;
  static const int emailVerCodeTypeBindEmail = 9;

  /// 匿名登录（对齐 iOS: violet/api/account/login → POST body 含 app_id + platform）
  /// iOS 使用 requestWithLoginType:STLoginTypeAnonymousLogin
  /// 所有登录类型统一添加: parm[@"app_id"] = @(1); parm[@"platform"] = @"mobile";
  Future<Map<String, dynamic>> anonymousLogin() async {
    final res = await dio.post(
      '/api/account/login',
      data: {'app_id': 1, 'platform': 'mobile'},
    );
    return res.data as Map<String, dynamic>;
  }

  /// 短信/Firebase 验证通道配置（对齐 iOS `STService+Login` → `requestPhoneVeryMethod`）
  Future<Map<String, dynamic>> getPhoneVerificationMethod() async {
    final res = await dio.get('/api/user/get/phone_verification_method');
    return res.data as Map<String, dynamic>;
  }

  /// 注册推送设备（对齐 iOS: violet/api/user/register_device）
  Future<Map<String, dynamic>> registerDeviceToken(String fcmToken) async {
    final token = fcmToken.trim();
    if (token.isEmpty) {
      return const {'code': 0, 'data': <String, dynamic>{}};
    }
    final res = await dio.post(
      '/api/user/register_device',
      data: {'fcm_token': token},
    );
    return res.data as Map<String, dynamic>;
  }

  /// 手机号 + 密码登录（对齐 iOS `STLoginTypeAccountPassword_Phone`）
  Future<Map<String, dynamic>> loginPhonePassword({
    required String telAreaCode,
    required String tel,
    required String plainPassword,
  }) async {
    final res = await dio.post(
      '/api/account/login',
      data: {
        'app_id': 1,
        'platform': 'mobile',
        'tel_area_code': telAreaCode,
        'tel': tel,
        'password': stHmacSha256Hex(plainPassword),
        'login_type': 0,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// 手机号 + 短信验证码登录（对齐 iOS `STLoginTypePhoneVerCode_Phone`）
  Future<Map<String, dynamic>> loginPhoneSms({
    required String telAreaCode,
    required String tel,
    required String verifyCode,
    int isGoogleJwt = 0,
  }) async {
    final res = await dio.post(
      '/api/account/login',
      data: {
        'app_id': 1,
        'platform': 'mobile',
        'tel_area_code': telAreaCode,
        'tel': tel,
        'verify_code': verifyCode,
        'login_type': 0,
        'is_google_jwt': isGoogleJwt,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// 注册（对齐 iOS `requestWithRegisterType:STRegisterTypePhone` → violet/api/account/register）
  Future<Map<String, dynamic>> register({
    required String telAreaCode,
    required String tel,
    required String plainPassword,
    required String verifyCode,
    String firstName = '',
    String lastName = '',
    String country = '',
    String language = 'zh-Hans',
    String identityDocumentType = '',
    String identityDocumentNumber = '',
    int isGoogleJwt = 0,
  }) async {
    final res = await dio.post(
      '/api/account/register',
      data: {
        'tel_area_code': telAreaCode,
        'tel': tel,
        'password': stHmacSha256Hex(plainPassword),
        'verify_code': verifyCode,
        'group_id': 1,
        'first_name': firstName,
        'last_name': lastName,
        'country': country,
        'language': language,
        'identity_document_type': identityDocumentType,
        'identity_document_number': identityDocumentNumber,
        'is_google_jwt': isGoogleJwt,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// 邮箱注册（对齐 iOS `STRegisterTypeEmail`）
  Future<Map<String, dynamic>> registerEmail({
    required String email,
    required String plainPassword,
    required String verifyCode,
    String language = 'zh-Hans',
    int isGoogleJwt = 0,
  }) async {
    final res = await dio.post(
      '/api/account/register',
      data: {
        'email': email.trim(),
        'password': stHmacSha256Hex(plainPassword),
        'verify_code': verifyCode,
        'group_id': 1,
        'language': language,
        'is_google_jwt': isGoogleJwt,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// 邮箱 + 密码登录（对齐 iOS `STLoginTypeAccountPassword_Email`，`login_type`: 1）
  Future<Map<String, dynamic>> loginEmailPassword({
    required String email,
    required String plainPassword,
  }) async {
    final res = await dio.post(
      '/api/account/login',
      data: {
        'app_id': 1,
        'platform': 'mobile',
        'email': email.trim(),
        'password': stHmacSha256Hex(plainPassword),
        'login_type': 1,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// 邮箱 + 验证码登录（对齐 iOS 邮箱验证码登录）
  Future<Map<String, dynamic>> loginEmailSms({
    required String email,
    required String verifyCode,
    int isGoogleJwt = 0,
  }) async {
    final res = await dio.post(
      '/api/account/login',
      data: {
        'app_id': 1,
        'platform': 'mobile',
        'email': email.trim(),
        'verify_code': verifyCode,
        'login_type': 1,
        'is_google_jwt': isGoogleJwt,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// 退出登录（对齐 iOS: violet/api/user/logout）
  Future<Map<String, dynamic>> logout() async {
    final res = await dio.post('/api/user/logout');
    return res.data as Map<String, dynamic>;
  }

  /// 发送短信验证码（对齐 iOS `requestSMSVerCodeWithParams` → GET violet/api/account/sms_vcode）
  /// `type`：`STLoginSendVerCodeType`（2 注册、3 绑定手机、6 登录 …）
  Future<Map<String, dynamic>> requestSmsVerCode(
    Map<String, dynamic> queryParameters,
  ) async {
    final res = await dio.get(
      '/api/account/sms_vcode',
      queryParameters: queryParameters,
    );
    return res.data as Map<String, dynamic>;
  }

  /// 发送邮箱验证码（对齐 iOS `requestEmailVercodeWithParams` → GET violet/api/account/email_vcode）
  Future<Map<String, dynamic>> requestEmailVerCode(
    Map<String, dynamic> queryParameters,
  ) async {
    final res = await dio.get(
      '/api/account/email_vcode',
      queryParameters: queryParameters,
    );
    return res.data as Map<String, dynamic>;
  }

  /// 申请验证码 session（对齐 iOS `requestVcodeSessionWithParams`）
  Future<Map<String, dynamic>> requestVcodeSession() async {
    final res = await dio.post('/api/account/vcode_session', data: {});
    return res.data as Map<String, dynamic>;
  }

  /// 注册配置列表（对齐 iOS `requestRegisterConfigWithCompletion`）
  Future<Map<String, dynamic>> getRegisterConfigList() async {
    final res = await dio.get('/api/register/config/list');
    return res.data as Map<String, dynamic>;
  }

  /// 开始注册 / 多步注册（对齐 iOS `requestRegisterStartWithParams`）
  Future<Map<String, dynamic>> registerStart(
    Map<String, dynamic> params,
  ) async {
    final body = Map<String, dynamic>.from(params);
    body.putIfAbsent('is_google_jwt', () => 0);
    final pwd = body['password']?.toString() ?? '';
    if (pwd.isNotEmpty) {
      body['password'] = stHmacSha256Hex(pwd);
    }
    final res = await dio.post('/api/register/start', data: body);
    return res.data as Map<String, dynamic>;
  }

  /// 注册步骤提交（对齐 iOS `requestRegisterStepWithParams`）
  Future<Map<String, dynamic>> registerStep(Map<String, dynamic> params) async {
    final res = await dio.post('/api/register/step', data: params);
    return res.data as Map<String, dynamic>;
  }

  /// 注册资料上传（对齐 iOS `requestRegistermaterialsWithParams`）
  Future<Map<String, dynamic>> registerMaterials(
    Map<String, dynamic> params,
  ) async {
    final res = await dio.post('/api/register/materials', data: params);
    return res.data as Map<String, dynamic>;
  }

  /// 注册前唯一性校验（对齐 iOS `requestCheckUniqueWithEmail:…`）
  Future<Map<String, dynamic>> checkRegisterUnique({
    String email = '',
    String telAreaCode = '',
    String tel = '',
    String identityDocumentType = '',
    String identityDocumentNumber = '',
    String password = '',
    String country = '',
  }) async {
    final res = await dio.post(
      '/api/account/check-unique',
      data: {
        'email': email,
        'tel_area_code': telAreaCode,
        'tel': tel,
        'identity_document_type': identityDocumentType,
        'identity_document_number': identityDocumentNumber,
        'password': password,
        'countrycode': country,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// 未登录验证码校验（对齐 iOS `requestNotLoginValidateCode`）
  Future<Map<String, dynamic>> validateRegisterCode({
    required String code,
    required String vcodeId,
    required String areaCode,
    required String phone,
    required String mail,
    required String type,
    int codeType = 2,
  }) async {
    final res = await dio.post(
      '/api/account/validate/code',
      data: {
        'id': vcodeId,
        'code': code,
        'area_code': areaCode,
        'tel': phone,
        'email': mail,
        'type': type,
        'code_type': codeType,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// 已登录验证码校验（对齐 iOS `requestValidateCode` → violet/api/user/validate/code）。
  Future<Map<String, dynamic>> validateUserCode({
    required String code,
    required String type,
    required int codeType,
    String areaCode = '',
    String phone = '',
    String mail = '',
  }) async {
    final res = await dio.post(
      '/api/user/validate/code',
      data: {
        'code': code,
        'area_code': areaCode,
        'tel': phone,
        'email': mail,
        'type': type,
        'code_type': codeType,
      },
    );
    final json = res.data as Map<String, dynamic>;
    final c = json['code'];
    final ok = c == 0 || c == '0' || (c is num && c == 0);
    if (!ok) {
      throw Exception(
        json['message']?.toString() ?? stLocalizedTextFromZhHans('验证码错误'),
      );
    }
    return json;
  }

  /// 第三方认证（对齐 iOS `requestThirdVerifyWithParams`）
  Future<Map<String, dynamic>> thirdPartyVerify(
    Map<String, dynamic> params,
  ) async {
    final res = await dio.post('/api/oauth/third-party/verify', data: params);
    return res.data as Map<String, dynamic>;
  }

  /// 第三方登录（对齐 iOS `requestThirdLoginWithParams`）
  Future<Map<String, dynamic>> thirdPartyLogin({
    required String oauthToken,
  }) async {
    final res = await dio.post(
      '/api/account/oauth/login',
      data: {'oauth_token': oauthToken},
    );
    return res.data as Map<String, dynamic>;
  }

  /// 发送验证码到手机（泛用型，对齐 iOS: violet/api/user/send_vcode / requestSendCodeWithParams）
  Future<Map<String, dynamic>> sendVerificationCode(
    Map<String, dynamic> params,
  ) async {
    final res = await dio.post('/api/user/send_vcode', data: params);
    return res.data as Map<String, dynamic>;
  }

  /// `send_vcode` 的 `code_type`：修改登录密码（与 iOS `STCodeType` 一致；若发码失败请对照原生枚举调整数值）。
  static const int codeTypeChangeLoginPassword = 4;
  static const int codeTypeCloseAccount = 10;

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final s = value.trim().toLowerCase();
      return s == '1' || s == 'true' || s == 'yes' || s == 'y';
    }
    return false;
  }

  /// 校验登录密码是否与当前账号一致（对齐 iOS `requestCheckPasswordSameWithParams`）。
  /// 接口返回通常为 `{code:0, data:{is:true}}`。
  Future<bool> checkLoginPasswordSame({
    required String oldPlainPassword,
  }) async {
    final res = await dio.post(
      '/api/user/check_password_same',
      data: {'old_password': stHmacSha256Hex(oldPlainPassword)},
    );
    final json = res.data as Map<String, dynamic>;
    final code = json['code'] as int? ?? -1;
    if (code != 0) {
      throw Exception(json['message']?.toString() ?? '旧密码校验失败');
    }
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return _parseBool(data['is']);
    }
    return _parseBool(data);
  }

  /// 校验资金密码是否与当前账号一致（对齐 iOS `requestCheckFundsPasswordSameWithParams`）。
  /// 接口返回通常为 `{code:0, data:{is:true}}`。
  Future<bool> checkFundsPasswordSame({
    required String oldPlainPassword,
  }) async {
    final res = await dio.post(
      '/api/user/check_funds_password_same',
      data: {'old_password': stHmacSha256Hex(oldPlainPassword)},
    );
    final json = res.data as Map<String, dynamic>;
    final code = json['code'] as int? ?? -1;
    if (code != 0) {
      throw Exception(json['message']?.toString() ?? '旧资金密码校验失败');
    }
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return _parseBool(data['is']);
    }
    return _parseBool(data);
  }

  /// 修改登录密码（对齐 iOS `requestUpdatePasswordWithOldPassword:…` → violet/api/user/update_password）
  /// 已登录修改密码场景可传短信/邮箱验证码 [verificationCode]；无二次验证时传空字符串。
  Future<Map<String, dynamic>> changePassword({
    required String oldPlainPassword,
    required String newPlainPassword,
    required String confirmPlainPassword,
    String verificationCode = '',
  }) async {
    final res = await dio.post(
      '/api/user/update_password',
      data: {
        'old_password': stHmacSha256Hex(oldPlainPassword),
        'new_password': stHmacSha256Hex(newPlainPassword),
        'confirm_password': stHmacSha256Hex(confirmPlainPassword),
        'code': verificationCode,
      },
    );
    final json = res.data as Map<String, dynamic>;
    final c = json['code'];
    final ok = c == 0 || c == '0' || (c is num && c == 0);
    if (!ok) {
      throw Exception(json['message']?.toString() ?? '修改密码失败');
    }
    return json;
  }

  /// `STCodeType_FindPassword`，用于未登录验证码校验。
  static const int codeTypeForgotLoginPassword = 1;

  /// 短信 `type`：找回登录密码（iOS `STLoginSendVerCodeTypeFindPassword`）。
  static const int smsTypeForgotLoginPassword = smsVerCodeTypeFindPassword;

  /// 邮箱验证码 `type`：找回登录密码（iOS `STLoginSendVerCodeTypeFindPassword`）。
  static const int emailTypeForgotLoginPassword = emailVerCodeTypeFindPassword;

  /// 未登录找回密码验证码校验（对齐 iOS `requestNotLoginValidateCode`）。
  Future<Map<String, dynamic>> validateForgotPasswordCode({
    required String code,
    required String vcodeId,
    required String areaCode,
    required String phone,
    required String mail,
    required String type,
  }) {
    return validateRegisterCode(
      code: code,
      vcodeId: vcodeId,
      areaCode: areaCode,
      phone: phone,
      mail: mail,
      type: type,
      codeType: codeTypeForgotLoginPassword,
    );
  }

  /// 未登录：通过短信/邮箱验证码重置登录密码（对齐 iOS `requestForgetPasswordWithParams` → `violet/api/account/reset_password`）。
  Future<Map<String, dynamic>> resetLoginPasswordWithVerificationCode({
    required String verificationCode,
    required String newPlainPassword,
    required String confirmPlainPassword,
    String? tel,
    String? telAreaCode,
    String? email,
    int isGoogleJwt = 0,
  }) async {
    final e = email?.trim() ?? '';
    final t = tel?.trim().replaceAll(RegExp(r'\s'), '') ?? '';
    if (e.isEmpty && t.isEmpty) {
      throw ArgumentError('tel 与 email 至少填一项');
    }
    final body = <String, dynamic>{
      'code': verificationCode.trim(),
      'new_password': stHmacSha256Hex(newPlainPassword),
      'confirm_password': stHmacSha256Hex(confirmPlainPassword),
      'area_code': t.isNotEmpty ? (telAreaCode ?? '+86').trim() : '',
      'tel': t,
      'email': e,
      'is_google_jwt': isGoogleJwt,
    };
    final res = await dio.post('/api/account/reset_password', data: body);
    final json = res.data as Map<String, dynamic>;
    final c = json['code'];
    final ok = c == 0 || c == '0' || (c is num && c == 0);
    if (!ok) {
      throw Exception(json['message']?.toString() ?? '重置密码失败');
    }
    return json;
  }

  /// 已登录：通过短信/邮箱验证码重置登录密码（对齐 iOS `requestLoginedForgetPasswordWithParams`）。
  Future<Map<String, dynamic>> resetLoggedInPasswordWithVerificationCode({
    required String verificationCode,
    required String newPlainPassword,
    required String confirmPlainPassword,
  }) async {
    final res = await dio.post(
      '/api/user/reset_password',
      data: {
        'code': verificationCode.trim(),
        'new_password': stHmacSha256Hex(newPlainPassword),
        'confirm_password': stHmacSha256Hex(confirmPlainPassword),
      },
    );
    final json = res.data as Map<String, dynamic>;
    final c = json['code'];
    final ok = c == 0 || c == '0' || (c is num && c == 0);
    if (!ok) {
      throw Exception(json['message']?.toString() ?? '重置密码失败');
    }
    return json;
  }

  /// 绑定手机（对齐 iOS `requestBindPhoneWithCode` → violet/api/user/bind_tel）
  Future<Map<String, dynamic>> bindPhone({
    required String code,
    required String areaCode,
    required String tel,
    int isGoogleJwt = 0,
  }) async {
    final res = await dio.post(
      '/api/user/bind_tel',
      data: {
        'code': code,
        'area_code': areaCode,
        'tel': tel,
        'is_google_jwt': isGoogleJwt,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// 绑定邮箱（对齐 iOS `requestBindEmailWithEmail` → violet/api/user/bind_email）
  Future<Map<String, dynamic>> bindEmail({
    required String email,
    required String code,
  }) async {
    final res = await dio.post(
      '/api/user/bind_email',
      data: {'email': email, 'code': code},
    );
    return res.data as Map<String, dynamic>;
  }

  /// 查询账户注销预检（对齐 iOS `requestCheckCloseAccountWithCompletion`）。
  Future<Map<String, dynamic>> checkCloseAccountPrecondition() async {
    final res = await dio.get('/api/user/check/wallet_and_account_balance');
    return res.data as Map<String, dynamic>;
  }

  /// 注销账户（对齐 iOS `requestCloseAccountWithVercode`）。
  Future<Map<String, dynamic>> closeAccountWithCode({
    required String code,
  }) async {
    final res = await dio.post('/api/user/deactivate', data: {'code': code});
    return res.data as Map<String, dynamic>;
  }

  /// 国家列表（对齐 iOS: `requestCountryWithLanguage` → `countries` + `hot_countries`）
  Future<Map<String, dynamic>> getCountries(String language) async {
    final res = await dio.get(
      '/api/account/countries',
      queryParameters: {'language': language},
    );
    final root = res.data;
    if (root is! Map<String, dynamic>) return {};
    final data = root['data'];
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  /// IP 定位（对齐 iOS: `requestLocation` → `iso_code` 默认国家）
  Future<Map<String, dynamic>> getIpLocation() async {
    final res = await dio.get('/api/account/get/ip_location');
    final root = res.data;
    if (root is! Map<String, dynamic>) return {};
    final data = root['data'];
    if (data is Map<String, dynamic>) return data;
    return root;
  }

  @Deprecated('Use getCountries')
  Future<List<dynamic>> getCountryList(String language) async {
    final payload = await getCountries(language);
    return payload['countries'] as List<dynamic>? ?? [];
  }

  // ==================== 用户信息 ====================

  /// 获取用户信息（对齐 iOS: violet/api/user/info）
  Future<Map<String, dynamic>> getUserProfile() async {
    final res = await dio.get('/api/user/info');
    return res.data as Map<String, dynamic>;
  }

  /// 更新用户信息（对齐 iOS: violet/api/user/update/info）
  Future<Map<String, dynamic>> updateUserProfile(
    Map<String, dynamic> data,
  ) async {
    final res = await dio.post('/api/user/update/info', data: data);
    return res.data as Map<String, dynamic>;
  }

  /// 更新用户偏好（涨跌色 / 一键平仓 / 时区等，对齐 iOS 偏好页提交）
  Future<Map<String, dynamic>> updateUserPreferences({
    int? riseAndFallType,
    bool? oneKeyClose,
    String? timezone,
  }) async {
    final data = <String, dynamic>{};
    if (riseAndFallType != null) {
      data['rise_and_fall_type'] = RiseAndFallApi.toApiValue(riseAndFallType);
    }
    if (oneKeyClose != null) {
      data['one_key_close'] = oneKeyClose ? 1 : 0;
    }
    if (timezone != null && timezone.isNotEmpty) {
      data['timezone'] = timezone;
    }
    if (data.isEmpty) {
      return <String, dynamic>{'code': 0};
    }
    return updateUserProfile(data);
  }

  /// 编辑资料（昵称/签名）（对齐 iOS: requestUpdateUserInfo）
  Future<Map<String, dynamic>> editUserInfo({
    String? avatar,
    String? nickName,
    String? autograph,
  }) async {
    final data = <String, dynamic>{};
    if (avatar != null) data['avatar'] = avatar;
    if (nickName != null) data['nickname'] = nickName;
    if (autograph != null) {
      data['autograph'] = autograph;
      data['signature'] = autograph;
    }
    final res = await dio.post('/api/user/update/info', data: data);
    return res.data as Map<String, dynamic>;
  }

  /// 用户等级（对齐 iOS: requestGetLevel）
  Future<Map<String, dynamic>> getLevel() async {
    final res = await dio.get('/api/user/level');
    return res.data as Map<String, dynamic>;
  }

  /// 用户等级变化（对齐 iOS: requestGetLevelChangeStatus）
  Future<Map<String, dynamic>> getLevelChangeStatus() async {
    final res = await dio.get('/api/user/check/pending_adjust_user_level');
    return res.data as Map<String, dynamic>;
  }

  // ==================== 行情（MarketData）====================
  // iOS 路径前缀: violet/marketdata/...

  /// 获取产品列表（分页）（对齐 iOS: violet/marketdata/get_symbols_data）
  Future<Map<String, dynamic>> getProductListByRank({
    required int rankType,
    int offset = 0,
    int limit = kCategoryMarketSymbolsPageDefault,
    String sortOrder = 'OrderAsce',
    bool needPoints = true,
  }) async {
    final qp = <String, dynamic>{
      'platform': 'MT5',
      'offset': offset.toString(),
      'limit': limit.toString(),
      'sort_order': sortOrder,
      'need_points': STService._needPointsQuery(needPoints),
      'symbol_group': symbolGroupParam(rankType),
    };
    final res = await dio.get(
      '/marketdata/get_symbols_data',
      queryParameters: qp,
    );
    final raw = res.data;
    if (raw == null) {
      debugPrint('⚠️ getProductListByRank: response body is null');
      return <String, dynamic>{};
    }
    if (raw is! Map) {
      debugPrint(
        '⚠️ getProductListByRank: unexpected body type ${raw.runtimeType}',
      );
      return <String, dynamic>{};
    }
    return Map<String, dynamic>.from(raw);
  }

  /// 获取产品详情（对齐 iOS: violet/marketdata/get_symbol_detail）
  Future<Map<String, dynamic>> getProductDetail(String symbol) async {
    final res = await dio.get(
      '/marketdata/get_symbol_detail',
      queryParameters: {'platform': 'MT5', 'symbol': symbol},
    );
    return res.data as Map<String, dynamic>;
  }

  /// 获取热门品种（对齐 iOS: violet/marketdata/get_hot_symbol）
  Future<List<dynamic>> getHotSymbols({bool needPoints = true}) async {
    final res = await dio.get(
      '/marketdata/get_hot_symbol',
      queryParameters: {
        'platform': 'MT5',
        'need_points': STService._needPointsQuery(needPoints),
      },
    );
    final raw = res.data;
    if (raw is Map) {
      return STService._symbolsListFromResponseRoot(
        Map<String, dynamic>.from(raw),
      );
    }
    return <dynamic>[];
  }

  /// 获取自选列表（含 sparkline points）（对齐 iOS: violet/marketdata/get_symbol_watch_list）
  Future<List<dynamic>> getOptionList({bool needPoints = true}) async {
    final res = await dio.get(
      '/marketdata/get_symbol_watch_list',
      queryParameters: {
        'platform': 'MT5',
        'need_points': STService._needPointsQuery(needPoints),
      },
    );
    final raw = res.data;
    if (raw is Map) {
      return STService._symbolsListFromResponseRoot(
        Map<String, dynamic>.from(raw),
      );
    }
    return <dynamic>[];
  }

  /// 获取自选展示品种（未登录模式）（对齐 iOS: violet/marketdata/get_watch_symbol）
  Future<List<dynamic>> getOptionSymbol({bool needPoints = true}) async {
    final res = await dio.get(
      '/marketdata/get_watch_symbol',
      queryParameters: {
        'platform': 'MT5',
        'need_points': STService._needPointsQuery(needPoints),
      },
    );
    final raw = res.data;
    if (raw is Map) {
      return STService._symbolsListFromResponseRoot(
        Map<String, dynamic>.from(raw),
      );
    }
    return <dynamic>[];
  }

  /// 搜索品种（对齐 iOS: violet/marketdata/search_symbol）
  /// 响应解析与热门/自选一致：[STService._symbolsListFromResponseRoot]。
  Future<List<dynamic>> searchSymbols(
    String keyword, {
    bool needPoints = true,
  }) async {
    final res = await dio.get(
      '/marketdata/search_symbol',
      queryParameters: {
        'platform': 'MT5',
        'keyword': keyword,
        'need_points': STService._needPointsQuery(needPoints),
      },
    );
    final raw = res.data;
    if (raw is! Map) return <dynamic>[];
    return STService._symbolsListFromResponseRoot(
      Map<String, dynamic>.from(raw),
    );
  }

  /// 获取 K 线数据
  /// 对齐 iOS `STService+Market` `requestKlineDataWithSymbol:…`：主路径 `get_tick_stats`，
  /// `data.tick_stats`；为空时回退 `get_symbol_kline_data`。
  Future<List<dynamic>> getKlineData({
    required String symbol,
    required String chart,
    int endTime = 0,
    int count = 300,
  }) async {
    final qp = <String, String>{
      'platform': 'MT5',
      'symbol': symbol,
      'chart': chart,
      'end_time': endTime.toString(),
      'count': count.toString(),
    };

    Future<List<dynamic>> pull(String path) async {
      final res = await dio.get(path, queryParameters: qp);
      final map = res.data as Map<String, dynamic>;
      return _extractMarketDataList(map);
    }

    var list = await pull('/marketdata/get_tick_stats');
    if (list.isEmpty) {
      list = await pull('/marketdata/get_symbol_kline_data');
    }
    return list;
  }

  /// 获取单个行情基础数据（对齐 iOS: violet/marketdata/get_symbol_kline_data, count=0）
  Future<Map<String, dynamic>> getBasicQuote(String symbol) async {
    final res = await dio.get(
      '/marketdata/get_symbol_kline_data',
      queryParameters: {'platform': 'MT5', 'symbol': symbol, 'count': '0'},
    );
    return res.data as Map<String, dynamic>;
  }

  /// 添加自选（对齐 iOS: violet/marketdata/add_symbol_watch_list，symbol_name 为数组）
  Future<void> addToWatchlist(List<String> symbols) async {
    await dio.post(
      '/marketdata/add_symbol_watch_list',
      data: {'platform': 'MT5', 'symbol_name': symbols},
    );
  }

  /// 删除自选（对齐 iOS: violet/marketdata/delete_symbol_watch_list）
  Future<void> removeFromWatchlist(List<String> symbols) async {
    await dio.post(
      '/marketdata/delete_symbol_watch_list',
      data: {'platform': 'MT5', 'symbol_name': symbols},
    );
  }

  /// 自选排序（对齐 iOS: violet/marketdata/sort_symbol_watch_list）
  Future<void> sortWatchlist(List<String> symbols) async {
    await dio.post(
      '/marketdata/sort_symbol_watch_list',
      data: {'platform': 'MT5', 'symbol_name': symbols},
    );
  }

  /// 从 `get_symbol_group` 的 `data` 字段解出列表（与 [symbolArrayFromMarketDataMap] 类似，部分环境 `data` 为 Map）
  static List<dynamic> _symbolGroupListFromResponseData(dynamic data) {
    if (data is List<dynamic>) return data;
    if (data is! Map) return <dynamic>[];
    final m = Map<String, dynamic>.from(data);
    for (final k in const [
      'list',
      'items',
      'groups',
      'records',
      'rows',
      'symbol_groups',
    ]) {
      final v = m[k];
      if (v is List<dynamic>) return v;
    }
    return <dynamic>[];
  }

  /// 获取市场分组（对齐 iOS: violet/marketdata/get_symbol_group）
  Future<List<dynamic>> getSymbolGroups() async {
    final res = await dio.get(
      '/marketdata/get_symbol_group',
      queryParameters: {'platform': 'MT5'},
    );
    final root = res.data;
    if (root is! Map) return <dynamic>[];
    final data = Map<String, dynamic>.from(root)['data'];
    return _symbolGroupListFromResponseData(data);
  }

  /// 获取价格预警配置（对齐 iOS: violet/marketdata/price_alert/get）
  Future<Map<String, dynamic>> getAlerts(String symbol) async {
    final res = await dio.get(
      '/marketdata/price_alert/get',
      queryParameters: {'platform': 'MT5', 'symbol': symbol},
    );
    return res.data as Map<String, dynamic>;
  }

  /// 批量获取行情报价（对齐 iOS: violet/marketdata/get_symbols_data）
  Future<List<dynamic>> getMarketQuotes({List<String>? symbols}) async {
    final params = <String, dynamic>{'platform': 'MT5'};
    if (symbols != null && symbols.isNotEmpty) {
      params['symbol_group'] = symbols.join(',');
    }
    final res = await dio.get(
      '/marketdata/get_symbols_data',
      queryParameters: params,
    );
    return (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
  }

  /// 全部品种价格（对齐 iOS: violet/marketdata/transaction/get_all_forex_symbol_real_time_prece）
  Future<List<dynamic>> getAllSymbolPrices() async {
    final res = await dio.get(
      '/marketdata/transaction/get_all_forex_symbol_real_time_prece',
    );
    return _listFromResponseRoot(
      Map<String, dynamic>.from(res.data as Map),
      const ['symbols', 'list', 'items'],
    );
  }

  // ==================== 交易 ====================
  // iOS 路径前缀: violet/api/transaction/...

  /// 获取交易账户列表（对齐 iOS: violet/api/transaction/accounts）
  Future<List<dynamic>> getTradeAccounts() async {
    final res = await dio.get('/api/transaction/accounts');
    final raw = res.data;
    if (raw is! Map) return <dynamic>[];
    final map = Map<String, dynamic>.from(raw);
    final data = map['data'];
    if (data is List<dynamic>) return data;
    if (data is List) return List<dynamic>.from(data);
    if (data is Map) {
      final inner = Map<String, dynamic>.from(data);
      for (final key in ['accounts', 'list', 'items']) {
        final v = inner[key];
        if (v is List) return List<dynamic>.from(v);
      }
    }
    return <dynamic>[];
  }

  /// 获取当前交易账户（对齐 iOS: violet/api/transaction/accounts/current）
  Future<Map<String, dynamic>> getCurrentTransAccount() async {
    final res = await dio.get('/api/transaction/accounts/current');
    return res.data as Map<String, dynamic>;
  }

  /// 切换交易账户（对齐 iOS: violet/api/transaction/accounts/switch）
  Future<Map<String, dynamic>> switchTradeAccount(
    Map<String, dynamic> data,
  ) async {
    if (tradeAccountSwitchDiagnosticsEnabled()) {
      debugPrint(
        '[TradeAccountSwitch][service_request] '
        '${_tradeAccountSwitchRequestDebug(data)}',
      );
    }
    final res = await dio.post('/api/transaction/accounts/switch', data: data);
    final root = _requireBusinessSuccess(res.data, '切换账户失败');
    if (tradeAccountSwitchDiagnosticsEnabled()) {
      debugPrint(
        '[TradeAccountSwitch][service_response] '
        '${_tradeAccountSwitchResponseDebug(root)}',
      );
    }
    return root;
  }

  /// 重置交易账号（对齐 iOS: violet/api/transaction/accounts/reset）
  Future<Map<String, dynamic>> resetTradeAccount() async {
    final res = await dio.post('/api/transaction/accounts/reset');
    return res.data as Map<String, dynamic>;
  }

  /// 开仓（对齐 iOS: violet/api/transaction/orders/position）
  Future<Map<String, dynamic>> submitOrder(Map<String, dynamic> data) async {
    final res = await dio.post('/api/transaction/orders/position', data: data);
    return _tradeDataMapFromRoot(res.data as Map<String, dynamic>);
  }

  /// 挂单（对齐 iOS: violet/api/transaction/orders/pending）
  Future<Map<String, dynamic>> submitPendingOrder(
    Map<String, dynamic> data,
  ) async {
    final res = await dio.post('/api/transaction/orders/pending', data: data);
    return _tradeDataMapFromRoot(res.data as Map<String, dynamic>);
  }

  /// 平仓（对齐 iOS: violet/api/transaction/orders/positions/close）
  Future<Map<String, dynamic>> closePosition(Map<String, dynamic> data) async {
    final res = await dio.post(
      '/api/transaction/orders/positions/close',
      data: data,
    );
    return _tradeDataMapFromRoot(res.data as Map<String, dynamic>);
  }

  /// 批量平仓（对齐 iOS: violet/api/transaction/orders/positions/close/batch）
  Future<Map<String, dynamic>> batchClosePositions(
    Map<String, dynamic> data,
  ) async {
    final res = await dio.post(
      '/api/transaction/orders/positions/close/batch',
      data: data,
    );
    return _tradeDataMapFromRoot(res.data as Map<String, dynamic>);
  }

  Map<String, dynamic> _tradeDataMapFromRoot(Map<String, dynamic> root) {
    final code = root['code'];
    final codeText = code?.toString();
    if (code != null && codeText != '0' && codeText != '200162') {
      throw Exception(root['message']?.toString() ?? '交易失败');
    }
    final data = _decodedTradeData(root['data']);
    if (data is Map) return Map<String, dynamic>.from(data);
    return root;
  }

  Map<String, dynamic> _tradePollingMapFromRoot(Map<String, dynamic> root) {
    final code = root['code'];
    final codeText = code?.toString();
    if (code != null && codeText != '0' && codeText != '200162') {
      throw Exception(root['message']?.toString() ?? '交易失败');
    }
    final data = _decodedTradeData(root['data']);
    if (data is Map) {
      final envelope = Map<String, dynamic>.from(root)..remove('data');
      return <String, dynamic>{...envelope, ...Map<String, dynamic>.from(data)};
    }
    return root;
  }

  Object? _decodedTradeData(Object? data) {
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        // Some endpoints may return a plain string in data. Keep the root
        // envelope in that case so callers can still inspect code/message.
      }
    }
    return data;
  }

  /// 根据执行 id 查订单 id（对齐 iOS: violet/api/transaction/orders/status）
  Future<Map<String, dynamic>> getTradeOrderStatus(
    Map<String, dynamic> params,
  ) async {
    final res = await dio.get(
      '/api/transaction/orders/status',
      queryParameters: params,
    );
    return _tradePollingMapFromRoot(res.data as Map<String, dynamic>);
  }

  /// 查询订单成交结果（对齐 iOS: violet/api/transaction/orders/deal）
  Future<Map<String, dynamic>> getTradeOrderDeal(
    Map<String, dynamic> params,
  ) async {
    final res = await dio.get(
      '/api/transaction/orders/deal',
      queryParameters: params,
    );
    return _tradePollingMapFromRoot(res.data as Map<String, dynamic>);
  }

  /// 修改持仓（止盈止损）（对齐 iOS: violet/api/transaction/orders/position/update）
  Future<Map<String, dynamic>> editPosition(Map<String, dynamic> data) async {
    final res = await dio.post(
      '/api/transaction/orders/position/update',
      data: data,
    );
    return res.data as Map<String, dynamic>;
  }

  /// 修改挂单（对齐 iOS: violet/api/transaction/orders/pending/update）
  Future<Map<String, dynamic>> editPendingOrder(
    Map<String, dynamic> data,
  ) async {
    final res = await dio.post(
      '/api/transaction/orders/pending/update',
      data: data,
    );
    return res.data as Map<String, dynamic>;
  }

  /// 删除订单（对齐 iOS: violet/api/transaction/orders/delete）
  Future<Map<String, dynamic>> deleteOrder(Map<String, dynamic> data) async {
    final res = await dio.post('/api/transaction/orders/delete', data: data);
    return res.data as Map<String, dynamic>;
  }

  /// 获取持仓列表（对齐 iOS: violet/api/transaction/orders/position/list）
  Future<List<dynamic>> getPositions() async {
    final res = await dio.get('/api/transaction/orders/position/list');
    return _listFromResponseRoot(
      Map<String, dynamic>.from(res.data as Map),
      const ['orders', 'positions', 'list', 'items'],
    );
  }

  /// 解析挂单列表接口响应（`data` 可为 List，或 Map 内嵌 `orders` / `count`）。
  (List<dynamic>, int) _parsePendingListResponse(Map<String, dynamic> root) {
    int? totalCount;

    void takeCount(dynamic c) {
      if (c == null) return;
      if (c is num) {
        totalCount = c.toInt();
      } else {
        totalCount = int.tryParse(c.toString());
      }
    }

    final data = root['data'];
    if (data is List) {
      takeCount(root['count']);
      return (data, totalCount ?? data.length);
    }
    if (data is Map<String, dynamic>) {
      takeCount(data['count']);
      final orders = data['orders'];
      if (orders is List) {
        return (orders, totalCount ?? orders.length);
      }
    }
    takeCount(root['count']);
    final orders = root['orders'];
    if (orders is List) {
      return (orders, totalCount ?? orders.length);
    }
    return (<dynamic>[], totalCount ?? 0);
  }

  /// 挂单列表 + 总数（一次请求；对齐 iOS `pending/list` 的 offset/limit 与 count）
  Future<({List<dynamic> orders, int total})> getPendingOrdersWithTotal({
    int offset = 0,
    int limit = 100,
  }) async {
    final res = await dio.get(
      '/api/transaction/orders/pending/list',
      queryParameters: {'offset': offset, 'limit': limit},
    );
    final parsed = _parsePendingListResponse(res.data as Map<String, dynamic>);
    return (orders: parsed.$1, total: parsed.$2);
  }

  /// 获取挂单列表（对齐 iOS: `requestPendingListWithParams` offset/limit，响应含 orders/count）
  Future<List<dynamic>> getPendingOrders({
    int offset = 0,
    int limit = 100,
  }) async {
    final r = await getPendingOrdersWithTotal(offset: offset, limit: limit);
    return r.orders;
  }

  /// 挂单总数（与 [getPendingOrders] 同源响应中的 count）
  Future<int> getPendingOrdersCount({int offset = 0, int limit = 100}) async {
    final r = await getPendingOrdersWithTotal(offset: offset, limit: limit);
    return r.total;
  }

  /// 获取当日成交（对齐 iOS: violet/api/transaction/orders/deal/today）
  Future<List<dynamic>> getTodayOrders({
    String? dealType,
    int offset = 0,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'offset': offset.toString(),
      'limit': limit.toString(),
    };
    if (dealType != null) params['deal_type'] = dealType;
    final res = await dio.get(
      '/api/transaction/orders/deal/today',
      queryParameters: params,
    );
    return (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
  }

  /// 获取历史订单（对齐 iOS: violet/api/transaction/orders/history/list，POST）
  Future<List<dynamic>> getHistoryOrders({
    List<String>? symbols,
    int offset = 0,
    int limit = kCategoryMarketSymbolsPageDefault,
    int? startTime,
    int? endTime,
    String? status,
    String? direction,
    bool? isProfit,
  }) async {
    final data = <String, dynamic>{'offset': offset, 'limit': limit};
    if (symbols != null && symbols.isNotEmpty) data['symbols'] = symbols;
    if (startTime != null) data['create_time_start'] = startTime;
    if (endTime != null) data['create_time_end'] = endTime;
    if (status != null) data['status'] = int.tryParse(status) ?? 0;
    if (direction != null) data['direction'] = int.tryParse(direction) ?? 0;
    if (isProfit != null) data['is_profit'] = isProfit ? 1 : 0;
    final res = await dio.post(
      '/api/transaction/orders/history/list',
      data: data,
    );
    return _listFromResponseRoot(
      Map<String, dynamic>.from(res.data as Map),
      const ['orders', 'history', 'list', 'items'],
    );
  }

  /// 获取用户交易品种（对齐 iOS: violet/api/transaction/symbols/used）
  Future<List<dynamic>> getTradeSymbols({int type = 0}) async {
    if (type != 0) {
      final res = await dio.get(
        '/api/transaction/symbols/used',
        queryParameters: {'used_type': type},
      );
      return _listFromResponseRoot(
        Map<String, dynamic>.from(res.data as Map),
        const ['symbols', 'list', 'items'],
      );
    }
    final res = await dio.get(
      '/marketdata/search_symbol',
      queryParameters: {'platform': 'MT5', 'keyword': ''},
    );
    return _listFromResponseRoot(
      Map<String, dynamic>.from(res.data as Map),
      const ['symbols', 'list', 'items'],
    );
  }

  /// 解析单品种接口返回体：`{ code, data }` 且 `data.symbol_info` 含 bid/ask（对齐 iOS `requestSymbolInfo` + 详情页 `symbol_info`）。
  static Map<String, dynamic> unwrapSymbolOrQuoteEnvelope(
    Map<String, dynamic> root,
  ) {
    Map<String, dynamic> payload;
    final code = root['code'];
    final ok =
        code == null ||
        code == 0 ||
        code == 200 ||
        (code is num && (code == 0 || code == 200)) ||
        (code is String &&
            (code == '0' ||
                code == '200' ||
                code.toLowerCase() == 'ok' ||
                code.toLowerCase() == 'success'));
    final data = root['data'];
    if (ok && data is Map) {
      payload = Map<String, dynamic>.from(data);
    } else {
      payload = Map<String, dynamic>.from(root);
    }
    for (final key in ['symbol_info', 'symbolInfo', 'quote', 'Quote']) {
      final nested = payload[key];
      if (nested is Map) {
        payload.addAll(Map<String, dynamic>.from(nested));
      }
    }
    return payload;
  }

  /// 获取品种信息用于开仓（对齐 iOS: violet/marketdata/symbols/{symbol}）
  Future<Map<String, dynamic>> getSymbolInfo(String symbol) async {
    final res = await dio.get('/marketdata/symbols/$symbol');
    return unwrapSymbolOrQuoteEnvelope(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  /// 获取订单状态（对齐 iOS: violet/api/transaction/orders/deal）
  Future<Map<String, dynamic>> getOrderStatus(
    Map<String, dynamic> params,
  ) async {
    final res = await dio.get(
      '/api/transaction/orders/deal',
      queryParameters: params,
    );
    return res.data as Map<String, dynamic>;
  }

  /// 获取跟单信息（对齐 iOS: violet/api/copytrading/copytrading/order/{shareid}）
  Future<Map<String, dynamic>> getCopyTradingInfo(String shareId) async {
    final res = await dio.get('/api/copytrading/copytrading/order/$shareId');
    return res.data as Map<String, dynamic>;
  }

  /// 获取带单员身份信息（对齐 iOS: violet/api/copytrading/is_signal_provider）
  Future<Map<String, dynamic>> getSignalProviderInfo() async {
    final res = await dio.get('/api/copytrading/is_signal_provider');
    return res.data as Map<String, dynamic>;
  }

  /// 获取交易组详情（对齐 iOS: violet/api/transaction/transaction_group/detail）
  Future<Map<String, dynamic>> getTransactionGroupDetail() async {
    final res = await dio.get('/api/transaction/transaction_group/detail');
    return res.data as Map<String, dynamic>;
  }

  /// 获取合伙人摘要（对齐 iOS: violet/api/taskcenter/get_partner_summary）
  Future<Map<String, dynamic>> getPartnerSummary() async {
    final res = await dio.get('/api/taskcenter/get_partner_summary');
    return res.data as Map<String, dynamic>;
  }

  // ==================== 钱包 ====================
  // iOS 路径前缀: violet/api/finance/...

  /// 获取钱包资产信息（对齐 iOS: violet/api/finance/get/wallet/list）
  ///
  /// iOS `requestWalletListWithCompletion` 取 `response.data`，其中包含
  /// `Wallet`、`TransAccount`、`total_amount_usd`、`total_local_amount` 等字段。
  Future<Map<String, dynamic>> getWalletInfo() async {
    final res = await dio.get('/api/finance/get/wallet/list');
    final root = res.data;
    if (root is! Map) return <String, dynamic>{};
    final map = Map<String, dynamic>.from(root);
    final data = _decodeJsonIfNeeded(map['data']);
    if (data is Map) return Map<String, dynamic>.from(data);
    return map;
  }

  static List<dynamic> walletListFromInfo(Map<String, dynamic> info) {
    for (final key in const [
      'Wallet',
      'wallet',
      'wallets',
      'wallet_list',
      'walletList',
      'list',
      'items',
    ]) {
      final raw = _decodeJsonIfNeeded(info[key]);
      if (raw is List) return List<dynamic>.from(raw);
    }
    return const <dynamic>[];
  }

  static List<dynamic> transAccountsFromWalletInfo(Map<String, dynamic> info) {
    for (final key in const [
      'TransAccount',
      'trans_account',
      'transAccount',
      'accounts',
    ]) {
      final raw = _decodeJsonIfNeeded(info[key]);
      if (raw is List) return List<dynamic>.from(raw);
    }
    return const <dynamic>[];
  }

  /// 获取钱包列表（对齐 iOS: violet/api/finance/get/wallet/list）
  Future<List<dynamic>> getWalletList() async {
    return walletListFromInfo(await getWalletInfo());
  }

  /// 解析钱包流水返回体：支持 `wallet_trans` + `count`，并兼容 `{ data: [...], count: ... }` 两种返回形态
  (List<dynamic>, int) _parseWalletTransactionResponse(
    Map<String, dynamic> root,
  ) {
    int? parseCount(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    List<dynamic> pickList(dynamic value) {
      return value is List<dynamic> ? List<dynamic>.from(value) : <dynamic>[];
    }

    final data = root['data'];
    int? total;
    List<dynamic> items = <dynamic>[];

    if (data is List<dynamic>) {
      items = data;
      total = parseCount(root['count']);
    } else if (data is Map<String, dynamic>) {
      const candidates = [
        'wallet_trans',
        'fundflows',
        'transactions',
        'data',
        'items',
        'orders',
      ];
      for (final key in candidates) {
        final picked = pickList(data[key]);
        if (picked.isNotEmpty) {
          items = picked;
          break;
        }
      }
      if (items.isEmpty && data.values.any((e) => e is List)) {
        final v = data.values.firstWhere((e) => e is List);
        items = pickList(v);
      }
      total = parseCount(data['count']) ?? parseCount(root['count']);
    } else if (root['wallet_trans'] is List<dynamic>) {
      items = List<dynamic>.from(root['wallet_trans']);
      total = parseCount(root['count']);
    } else if (root['fundflows'] is List<dynamic>) {
      items = List<dynamic>.from(root['fundflows']);
      total = parseCount(root['count']);
    }

    return (items, total ?? items.length);
  }

  /// 获取钱包流水（对齐 iOS: violet/api/finance/get/wallet_transaction/list）
  /// iOS 侧是 offset/limit 分页；保留 page 参数兼容旧调用。
  Future<({List<dynamic> items, int total})> getWalletTransactionsWithTotal({
    int page = 1,
    int? offset,
    int limit = 20,
    String? walletId,
    int? createTimeStart,
    int? createTimeEnd,
    dynamic method,
    dynamic type,
  }) async {
    final effectiveOffset =
        offset ?? ((page <= 1 ? 0 : (page - 1)) * (limit <= 0 ? 20 : limit));
    final params = <String, dynamic>{
      'offset': effectiveOffset,
      'limit': limit <= 0 ? 20 : limit,
    };

    if (walletId != null && walletId.isNotEmpty) {
      params['wallet_id'] = walletId;
    }
    if (createTimeStart != null) {
      params['create_time_start'] = createTimeStart;
    }
    if (createTimeEnd != null) {
      params['create_time_end'] = createTimeEnd;
    }
    if (method != null && method is! bool && method.toString().isNotEmpty) {
      params['method'] = method;
    } else if (type != null && type is! bool && type.toString().isNotEmpty) {
      params['type'] = type;
    }

    final res = await dio.get(
      '/api/finance/get/wallet_transaction/list',
      queryParameters: params,
    );

    final root = res.data as Map<String, dynamic>;
    final parsed = _parseWalletTransactionResponse(root);
    return (items: parsed.$1, total: parsed.$2);
  }

  /// 获取钱包流水（对齐 iOS: violet/api/finance/get/wallet_transaction/list）
  Future<List<dynamic>> getWalletTransactions({int page = 1}) async {
    return (await getWalletTransactionsWithTotal(page: page)).items;
  }

  /// 获取交易账户流水（对齐 iOS: violet/api/transaction/accounts/fundflow）
  Future<List<dynamic>> getTransAccountFlow(Map<String, dynamic> params) async {
    final res = await dio.get(
      '/api/transaction/accounts/fundflow',
      queryParameters: params,
    );
    final parsed = _parseWalletTransactionResponse(
      Map<String, dynamic>.from(res.data as Map),
    );
    return parsed.$1;
  }

  /// 获取支付通道列表（对齐 iOS: violet/api/finance/get/pay_channel/list）
  Future<List<dynamic>> getDepositChannels() async {
    final res = await dio.get('/api/finance/get/pay_channel/list');
    final channels = WalletDepositWithdrawContract.depositChannelsFromResponse(
      res.data,
    );
    debugPrint('💰 getDepositChannels 支付渠道数量=${channels.length}');
    for (var i = 0; i < channels.length; i++) {
      final channel = channels[i];
      final presets = WalletDepositWithdrawContract.presetAmounts(channel);
      debugPrint(
        '💰 getDepositChannels[$i] '
        'id=${WalletDepositWithdrawContract.channelId(channel)} '
        'name=${channel['name'] ?? channel['pay_name'] ?? channel['title'] ?? ''} '
        'currency=${channel['currency'] ?? channel['pay_currency'] ?? ''} '
        'min=${channel['min_amount'] ?? ''} '
        'max=${channel['max_amount'] ?? ''} '
        'presetAmounts=$presets',
      );
    }
    return channels;
  }

  /// 获取出金方式与金额模板（对齐 iOS: violet/api/finance/get/withdrawal_types）
  Future<Map<String, dynamic>> getWithdrawalTypes() async {
    final res = await dio.get('/api/finance/get/withdrawal_types');
    final json = res.data as Map<String, dynamic>;
    final code = json['code'] as int? ?? -1;
    if (code != 0) {
      throw Exception(
        json['message']?.toString() ?? stLocalizedTextFromZhHans('获取出金方式失败'),
      );
    }
    final inner = json['data'];
    if (inner is Map<String, dynamic>) return inner;
    return {};
  }

  /// 发起划转请求（对齐 iOS: violet/api/finance/add/transaction）
  /// 返回 `data` 字段 Map（与 iOS completion(response.data) 一致）
  Future<Map<String, dynamic>> walletTransfer(Map<String, dynamic> data) async {
    final res = await dio.post('/api/finance/add/transaction', data: data);
    final json = res.data as Map<String, dynamic>;
    final code = json['code'] as int? ?? -1;
    if (code != 0) {
      throw Exception(json['message']?.toString() ?? '划转失败');
    }
    final inner = json['data'];
    if (inner is Map<String, dynamic>) return inner;
    return {};
  }

  /// 获取收银台支付地址（对齐 iOS `pay_url` 在响应 data 内）
  Future<Map<String, dynamic>> getPaymentAddress(
    Map<String, dynamic> data,
  ) async {
    final res = await dio.get(
      '/api/finance/get/payment_address',
      queryParameters: data,
    );
    final json = res.data as Map<String, dynamic>;
    final code = json['code'] as int? ?? -1;
    if (code != 0) {
      throw Exception(
        json['message']?.toString() ?? stLocalizedTextFromZhHans('获取支付地址失败'),
      );
    }
    final inner = json['data'];
    if (inner is Map<String, dynamic>) return inner;
    return {};
  }

  /// 提现申请（对齐 iOS: violet/api/finance/add/withdrawal + `getDraw:` 字段）
  Future<Map<String, dynamic>> withdraw(Map<String, dynamic> data) async {
    final res = await dio.post('/api/finance/add/withdrawal', data: data);
    final json = res.data as Map<String, dynamic>;
    final code = json['code'] as int? ?? -1;
    if (code != 0) {
      throw Exception(
        json['message']?.toString() ?? stLocalizedTextFromZhHans('提现失败'),
      );
    }
    final inner = json['data'];
    if (inner is Map<String, dynamic>) return inner;
    return {};
  }

  /// 查询提现手续费（对齐 iOS `getDrawFee`: 仅 `amount`；返回 `data` Map）
  Future<Map<String, dynamic>> getWithdrawFee(Map<String, dynamic> data) async {
    final res = await dio.get('/api/finance/get/fee', queryParameters: data);
    final json = res.data as Map<String, dynamic>;
    final code = json['code'] as int? ?? -1;
    if (code != 0) {
      throw Exception(
        json['message']?.toString() ?? stLocalizedTextFromZhHans('查询手续费失败'),
      );
    }
    final inner = json['data'];
    if (inner is Map<String, dynamic>) return inner;
    return {};
  }

  /// 查询充值手续费（对齐 iOS: violet/api/finance/get/pay_handing_fee）
  Future<Map<String, dynamic>> getDepositFee(Map<String, dynamic> data) async {
    final res = await dio.get(
      '/api/finance/get/pay_handing_fee',
      queryParameters: data,
    );
    final json = res.data as Map<String, dynamic>;
    final code = json['code'] as int? ?? -1;
    if (code != 0) {
      throw Exception(
        json['message']?.toString() ?? stLocalizedTextFromZhHans('查询充值手续费失败'),
      );
    }
    final inner = json['data'];
    if (inner is Map<String, dynamic>) return inner;
    return {};
  }

  /// 查询币种汇率（对齐 iOS: violet/api/finance/get/pay_currency/rate）
  Future<Map<String, dynamic>> getExchangeRate(
    Map<String, dynamic> data,
  ) async {
    final res = await dio.get(
      '/api/finance/get/pay_currency/rate',
      queryParameters: data,
    );
    final json = res.data as Map<String, dynamic>;
    final code = json['code'] as int? ?? -1;
    if (code != 0) {
      throw Exception(
        json['message']?.toString() ?? stLocalizedTextFromZhHans('查询汇率失败'),
      );
    }
    final inner = json['data'];
    if (inner is Map<String, dynamic>) return inner;
    return {};
  }

  /// 发送钱包验证码（对齐 iOS: violet/api/user/send_vcode）
  Future<Map<String, dynamic>> sendWalletVerificationCode(
    Map<String, dynamic> data,
  ) async {
    final res = await dio.post('/api/user/send_vcode', data: data);
    final json = res.data as Map<String, dynamic>;
    final code = json['code'] as int? ?? -1;
    if (code != 0) {
      throw Exception(json['message']?.toString() ?? '发送验证码失败');
    }
    final inner = json['data'];
    if (inner is Map<String, dynamic>) return inner;
    return {};
  }

  /// 获取订单类型（对齐 iOS: violet/api/finance/order_types）
  Future<Map<String, dynamic>> getOrderTypes() async {
    final res = await dio.get('/api/finance/order_types');
    return res.data as Map<String, dynamic>;
  }

  /// 设置资金密码（对齐 iOS: violet/api/user/set/funds_password）
  Future<Map<String, dynamic>> setFundPassword(
    Map<String, dynamic> data,
  ) async {
    final res = await dio.post('/api/user/set/funds_password', data: data);
    final json = res.data as Map<String, dynamic>;
    final code = json['code'] as int? ?? -1;
    if (code != 0) {
      throw Exception(json['message']?.toString() ?? '设置资金密码失败');
    }
    final inner = json['data'];
    if (inner is Map<String, dynamic>) return inner;
    return {};
  }

  /// 修改资金密码（对齐 iOS: violet/api/user/update/funds_password）
  Future<Map<String, dynamic>> editFundPassword(
    Map<String, dynamic> data,
  ) async {
    final res = await dio.post('/api/user/update/funds_password', data: data);
    final json = res.data as Map<String, dynamic>;
    final code = json['code'] as int? ?? -1;
    if (code != 0) {
      throw Exception(json['message']?.toString() ?? '修改资金密码失败');
    }
    final inner = json['data'];
    if (inner is Map<String, dynamic>) return inner;
    return {};
  }

  /// 忘记资金密码（对齐 iOS: violet/api/user/reset/funds_password）
  Future<Map<String, dynamic>> resetFundPassword(
    Map<String, dynamic> data,
  ) async {
    final res = await dio.post('/api/user/reset/funds_password', data: data);
    final json = res.data as Map<String, dynamic>;
    final code = json['code'] as int? ?? -1;
    if (code != 0) {
      throw Exception(json['message']?.toString() ?? '重置资金密码失败');
    }
    final inner = json['data'];
    if (inner is Map<String, dynamic>) return inner;
    return {};
  }

  // ==================== 认证 (KYC) ====================

  /// 获取认证状态（对齐 iOS: violet/api/user/get/verification_status）
  Future<Map<String, dynamic>> getAuthStatus() async {
    final res = await dio.get('/api/user/get/verification_status');
    return res.data as Map<String, dynamic>;
  }

  /// 获取 KYC 权限配置（对齐 iOS: requestVerificationConfig）
  Future<List<dynamic>> getVerificationConfig() async {
    final res = await dio.get('/api/user/get/verification_config');
    return _extractListFromResponse(
      res.data,
      candidateKeys: const [
        'data',
        'list',
        'items',
        'result',
        'permissions',
        'verification_config',
        'verificationConfig',
      ],
    );
  }

  /// 提交实名认证（对齐 iOS: violet/api/user/submit/identity_document）
  Future<Map<String, dynamic>> submitAuth(Map<String, dynamic> data) async {
    final res = await dio.post(
      '/api/user/submit/identity_document',
      data: data,
    );
    return _requireBusinessSuccess(res.data, '提交实名认证失败');
  }

  /// 获取实名认证状态列表（对齐 iOS: violet/api/user/get/identity_document/list）
  Future<List<dynamic>> getIdentityStatus() async {
    final res = await dio.get('/api/user/get/identity_document/list');
    final root = res.data as Map<String, dynamic>;
    final data = root['data'];
    if (data is Map && data['identity_documents'] is List) {
      return List<dynamic>.from(data['identity_documents'] as List);
    }
    if (data is List) return List<dynamic>.from(data);
    if (root['identity_documents'] is List) {
      return List<dynamic>.from(root['identity_documents'] as List);
    }
    return const [];
  }

  /// OCR 识别身份证（对齐 iOS: violet/api/user/ocr/id_document）
  Future<Map<String, dynamic>> ocrIdentityDocument(
    Map<String, dynamic> data,
  ) async {
    final res = await dio.post('/api/user/ocr/id_document', data: data);
    return res.data as Map<String, dynamic>;
  }

  /// TUS 上传证件照片（对齐 iOS `STUploadFileTool` / `STTusUploadTool`）。
  Future<String> uploadIdentityImage({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final brand = BrandConfig.jufu();
    final base = brand.apiBaseUrlForBuildMode.replaceFirst(RegExp(r'/+$'), '');
    final uploadUrl = '$base/cape/v1/upload/';
    final metadata = <String, String>{
      'filename': filename,
      'filetype': mimeType,
      'platform': 'mp',
    };
    final token = dio.currentAuthToken;
    if (token != null && token.isNotEmpty) {
      metadata['Authorization'] = token;
    }
    final uploadDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    final create = await uploadDio.post<dynamic>(
      uploadUrl,
      options: Options(
        headers: {
          'TUS-Resumable': '1.0.0',
          'Upload-Extension': 'creation',
          'Upload-Length': '${bytes.length}',
          'Upload-Metadata': _encodeTusMetadata(metadata),
        },
        responseType: ResponseType.plain,
      ),
    );
    final location = create.headers.value('location');
    if (location == null || location.isEmpty) {
      throw Exception('上传失败');
    }
    final fileUrl = Uri.parse(uploadUrl).resolve(location).toString();

    final upload = await uploadDio.post<dynamic>(
      fileUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          'TUS-Resumable': '1.0.0',
          'Content-Type': 'application/offset+octet-stream',
          'Upload-Offset': '0',
          'Content-Length': '${bytes.length}',
          'X-HTTP-Method-Override': 'PATCH',
        },
        responseType: ResponseType.plain,
      ),
    );
    final offset = int.tryParse(upload.headers.value('upload-offset') ?? '');
    if (offset != bytes.length) {
      throw Exception('上传失败');
    }
    return fileUrl;
  }

  static String _encodeTusMetadata(Map<String, String> metadata) {
    return metadata.entries
        .map((e) => '${e.key} ${base64Encode(utf8.encode(e.value))}')
        .join(', ');
  }

  /// OCR 识别银行卡（对齐 iOS: violet/api/user/ocr/bank_card）
  Future<Map<String, dynamic>> ocrBankCard(Map<String, dynamic> data) async {
    final res = await dio.post('/api/user/ocr/bank_card', data: data);
    return res.data as Map<String, dynamic>;
  }

  // ==================== 银行卡 ====================

  /// 获取银行卡列表（对齐 iOS: violet/api/user/get/bank_card/list）
  Future<List<dynamic>> getBankCards() async {
    final res = await dio.get('/api/user/get/bank_card/list');
    return _extractListFromResponse(
      res.data,
      candidateKeys: const ['bank_cards', 'data', 'list', 'items'],
      wrapSingleMap: false,
    );
  }

  /// 获取所有银行列表（对齐 iOS: violet/api/user/get/bank/list）
  Future<List<dynamic>> getBankList() async {
    final res = await dio.get('/api/user/get/bank/list');
    return _extractListFromResponse(
      res.data,
      candidateKeys: const ['banks', 'bank_list', 'data', 'list', 'items'],
      wrapSingleMap: false,
    );
  }

  /// 添加银行卡（对齐 iOS: violet/api/user/submit/bank_card）
  Future<Map<String, dynamic>> addBankCard(Map<String, dynamic> data) async {
    final res = await dio.post('/api/user/submit/bank_card', data: data);
    return _requireBusinessSuccess(res.data, '添加银行卡失败');
  }

  /// 设置默认银行卡（对齐 iOS: violet/api/user/set/default/bank_card）
  Future<Map<String, dynamic>> setDefaultBankCard(
    Map<String, dynamic> data,
  ) async {
    final res = await dio.post('/api/user/set/default/bank_card', data: data);
    return _requireBusinessSuccess(res.data, '设置默认银行卡失败');
  }

  /// 删除银行卡（对齐 iOS: violet/api/user/delete/bank_card）
  Future<void> deleteBankCard(Map<String, dynamic> data) async {
    final res = await dio.post('/api/user/delete/bank_card', data: data);
    _requireBusinessSuccess(res.data, '删除银行卡失败');
  }

  // ==================== 电子钱包 ====================

  /// 获取电子钱包列表（对齐 iOS: violet/api/user/get/e_wallet/list）
  Future<List<dynamic>> getEWalletList() async {
    final res = await dio.get('/api/user/get/e_wallet/list');
    return _extractListFromResponse(
      res.data,
      candidateKeys: const ['e_wallets', 'data', 'list', 'items'],
      wrapSingleMap: false,
    );
  }

  /// 获取币种列表（对齐 iOS: violet/api/user/get/currency/list）
  Future<List<dynamic>> getCurrencyList() async {
    final res = await dio.get('/api/user/get/currency/list');
    return (res.data as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
  }

  /// 获取加密币种（对齐 iOS: violet/api/account/cryptocurrency）
  Future<Map<String, dynamic>> getCryptoCurrency() async {
    final res = await dio.get('/api/account/cryptocurrency');
    return res.data as Map<String, dynamic>;
  }

  /// 添加电子钱包（对齐 iOS: violet/api/user/submit/e_wallet）
  Future<Map<String, dynamic>> addEWallet(Map<String, dynamic> data) async {
    final res = await dio.post('/api/user/submit/e_wallet', data: data);
    return _requireBusinessSuccess(res.data, '添加电子钱包失败');
  }

  /// 设置默认电子钱包（对齐 iOS: violet/api/user/set/default/e_wallet）
  Future<Map<String, dynamic>> setDefaultEWallet(
    Map<String, dynamic> data,
  ) async {
    final res = await dio.post('/api/user/set/default/e_wallet', data: data);
    return res.data as Map<String, dynamic>;
  }

  /// 删除电子钱包（对齐 iOS: violet/api/user/delete/e_wallet）
  Future<void> deleteEWallet(Map<String, dynamic> data) async {
    await dio.post('/api/user/delete/e_wallet', data: data);
  }

  // ==================== 活动 ====================

  /// 检查试用活动（对齐 iOS: violet/api/trial_activity/check_active）
  Future<Map<String, dynamic>> checkTrialActivity() async {
    final res = await dio.get('/api/trial_activity/check_active');
    return _dataMapFromResponseRoot(Map<String, dynamic>.from(res.data as Map));
  }

  /// 检查赠金活动（对齐 iOS: violet/api/bonus_activity/check_active）
  Future<Map<String, dynamic>> checkBonusActivity() async {
    final res = await dio.get('/api/bonus_activity/check_active');
    return _dataMapFromResponseRoot(Map<String, dynamic>.from(res.data as Map));
  }

  /// 获取赠金活动简明信息（对齐 iOS: violet/api/bonus_activity/activity_brief）
  Future<Map<String, dynamic>> getBonusBrief() async {
    final res = await dio.get('/api/bonus_activity/activity_brief');
    return _dataMapFromResponseRoot(Map<String, dynamic>.from(res.data as Map));
  }

  /// 获取赠金活动进度（对齐 iOS: violet/api/bonus_activity/progress）
  Future<Map<String, dynamic>> getBonusProgress(int activityId) async {
    final res = await dio.get(
      '/api/bonus_activity/progress',
      queryParameters: {'activity_id': activityId.toString()},
    );
    return _dataMapFromResponseRoot(Map<String, dynamic>.from(res.data as Map));
  }

  /// 获取赠金活动详情（对齐 iOS: violet/api/bonus_activity/detail）
  Future<Map<String, dynamic>> getBonusDetail(int activityId) async {
    final res = await dio.get(
      '/api/bonus_activity/detail',
      queryParameters: {'activity_id': activityId.toString()},
    );
    return _dataMapFromResponseRoot(Map<String, dynamic>.from(res.data as Map));
  }

  /// 获取交易解锁任务进度（对齐 iOS: violet/api/user_trade_unlock_activity/tasks/progress）
  Future<Map<String, dynamic>> getTradeUnlockTaskProgress() async {
    final res = await dio.get('/api/user_trade_unlock_activity/tasks/progress');
    return _dataMapFromResponseRoot(Map<String, dynamic>.from(res.data as Map));
  }

  /// 获取交易解锁品种配置（对齐 iOS: violet/api/user_trade_unlock_activity/symbol/configs）
  Future<Map<String, dynamic>> getTradeUnlockSymbolConfig() async {
    final res = await dio.get('/api/user_trade_unlock_activity/symbol/configs');
    return _dataMapFromResponseRoot(Map<String, dynamic>.from(res.data as Map));
  }

  /// 获取交易解锁结算明细（对齐 iOS: violet/api/user_trade_unlock_activity/settlement/details）
  Future<Map<String, dynamic>> getTradeUnlockSettlementDetail() async {
    final res = await dio.get(
      '/api/user_trade_unlock_activity/settlement/details',
    );
    return _dataMapFromResponseRoot(Map<String, dynamic>.from(res.data as Map));
  }

  /// 获取试用活动进度（对齐 iOS: violet/api/trial_activity/progress）
  Future<Map<String, dynamic>> getTrialBonusProgress() async {
    final res = await dio.get('/api/trial_activity/progress');
    return _dataMapFromResponseRoot(Map<String, dynamic>.from(res.data as Map));
  }

  /// 结算赠金（对齐 iOS: violet/api/bonus_activity/settle）
  Future<Map<String, dynamic>> settleBonus(int activityId) async {
    final res = await dio.post(
      '/api/bonus_activity/settle',
      data: {'activity_id': activityId},
    );
    return _dataMapFromResponseRoot(Map<String, dynamic>.from(res.data as Map));
  }

  // ==================== 新闻 ====================

  /// 获取新闻列表（对齐 iOS: violet/api/content/news/list）
  Future<List<dynamic>> getNewsList({int limit = 4}) async {
    final res = await dio.get(
      '/api/content/news/list',
      queryParameters: {'limit': limit.toString(), 'lang': dio.currentLanguage},
    );
    final root = res.data;
    if (root is! Map) return [];
    final map = Map<String, dynamic>.from(root);
    final data = map['data'];
    if (data is List<dynamic>) return data;
    if (data is Map<String, dynamic>) {
      for (final k in ['list', 'records', 'items', 'rows', 'news']) {
        final v = data[k];
        if (v is List<dynamic>) return v;
      }
    }
    return [];
  }

  /// 资讯详情（对齐 iOS: violet/api/content/news + requestNewsDetailWithParams）
  Future<Map<String, dynamic>?> getNewsDetail({required String id}) async {
    try {
      final res = await dio.get(
        '/api/content/news',
        queryParameters: {'id': id},
      );
      final json = res.data as Map<String, dynamic>;
      final code = json['code'] as int? ?? -1;
      if (code != 0) return null;
      final data = json['data'];
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (e, st) {
      debugPrint('⚠️ getNewsDetail error: $e\n$st');
      return null;
    }
  }

  /// 快讯列表（对齐 iOS: violet/api/content/flash/list + requestFlashListWithParams）
  Future<List<dynamic>> getFlashList({
    required int offset,
    required int limit,
    required String lang,
  }) async {
    final res = await dio.get(
      '/api/content/flash/list',
      queryParameters: {'offset': offset, 'limit': limit, 'lang': lang},
    );
    return (res.data as Map<String, dynamic>)['data']?['list']
            as List<dynamic>? ??
        [];
  }

  /// 财经日历列表（对齐 iOS: violet/api/content/calendar/list）
  Future<List<dynamic>> getCalendarList({
    required int offset,
    required int limit,
    required String lang,
    required int startTimeSec,
    required int endTimeSec,
    String order = 'desc',
    String orderBy = 'time',
  }) async {
    final res = await dio.get(
      '/api/content/calendar/list',
      queryParameters: {
        'offset': offset,
        'limit': limit,
        'lang': lang,
        'start_time': startTimeSec,
        'end_time': endTimeSec,
        'order': order,
        'order_by': orderBy,
      },
    );
    return (res.data as Map<String, dynamic>)['data']?['list']
            as List<dynamic>? ??
        [];
  }

  // ==================== 多语言 ====================

  /// 获取可用语言列表（对齐 iOS: violet/api/account/languages/available）。
  /// Flutter：用 `AppLanguageOption.fromAvailableLanguagesPayload` 解析 `data.languages`。
  Future<List<dynamic>> getAvailableLanguages() async {
    final res = await dio.get('/api/account/languages/available');
    final root = res.data as Map<String, dynamic>?;
    final data = root?['data'];

    if (data is List<dynamic>) return data;

    if (data is Map<String, dynamic>) {
      return data['languages'] as List<dynamic>? ??
          data['list'] as List<dynamic>? ??
          data['languageList'] as List<dynamic>? ??
          data['items'] as List<dynamic>? ??
          [];
    }

    return [];
  }

  // ==================== 价格预警 ====================

  /// 创建价格预警
  Future<Map<String, dynamic>> createAlert(Map<String, dynamic> data) async {
    final res = await dio.post('/marketdata/price_alert/create', data: data);
    return res.data as Map<String, dynamic>;
  }

  /// 删除价格预警
  Future<void> deleteAlert(Map<String, dynamic> data) async {
    await dio.post('/marketdata/price_alert/delete', data: data);
  }

  /// 服务端 KlineType → chart 参数辅助
  static String chartParam(String klineType) {
    switch (klineType) {
      case '1m':
      case 'FS':
        return '1MIN';
      case '5m':
        return '5MIN';
      case '15m':
        return '15MIN';
      case '30m':
        return '30MIN';
      case '1h':
      case '1H':
        return '1H';
      case '2h':
      case '2H':
        return '2H';
      case '4h':
      case '4H':
        return '4H';
      case '1d':
      case '1D':
        return '1D';
      case '2d':
      case '2D':
        return '2D';
      case '1w':
      case '1W':
        return '1W';
      case '1M':
      case '1mo':
      case '1MO':
        return '1MO';
      default:
        return '1MIN';
    }
  }

  // ==================== 风控报告（对齐 iOS: B.10 STService+Report） ====================

  /// 请求风控报告（对齐 iOS: requestRiskReport）
  /// 用于设备指纹和行为分析，不阻塞启动流程
  /// iOS violet/api/risk/report
  Future<Map<String, dynamic>?> requestRiskReport({
    bool isLoggedIn = false,
    String userId = '',
    bool pushReachable = false,
    bool gpsEnabled = false,
    String network = 'Unknown',
    String carrier = '',
    String location = '',
  }) async {
    try {
      final loginId = int.tryParse(userId.trim()) ?? 0;
      final payload = <String, dynamic>{
        'log_type': 'app_launch',
        'version': 'v0.0.1',
        'visitor_id': dio.currentRequestId,
        'terminal_type': dio.currentDeviceModel,
        'app_key': dio.currentRequestId,
        'app_version': dio.currentAppVersion,
        'device_model': dio.currentDeviceModel,
        'network': network,
        'operate_system': dio.currentSystemVersion,
        'login_type': isLoggedIn ? 1 : 0,
        'login_id': loginId,
        'cpu_arch': defaultTargetPlatform.name,
        'cpu_model': dio.currentDeviceModel,
        'carrier': carrier,
        'screen_resolution': '',
        'location': location,
        'login_model': '',
        'push_id': '',
        'reachable': pushReachable,
        'gps_status': gpsEnabled,
      };
      final res = await dio.post('/api/risk/report', data: payload);
      final json = res.data as Map<String, dynamic>?;
      return json;
    } catch (e) {
      debugPrint('⚠️ requestRiskReport failed: $e');
      return null;
    }
  }
}

/// K 线接口 `data` 可能是 List，也可能是 `{ list: [...] }` 等嵌套结构（对齐 iOS `tick_stats` / `list`）
List<dynamic> _extractMarketDataList(Map<String, dynamic> json) {
  final data = json['data'];
  if (data is List<dynamic>) return data;
  if (data is Map<String, dynamic>) {
    for (final key in [
      'list',
      'kline',
      'ticks',
      'items',
      'records',
      'bars',
      'tick_stats',
      'tickStats',
      'TickStats',
    ]) {
      final v = data[key];
      if (v is List<dynamic>) return v;
    }
  }
  return const [];
}

/// rankType → symbol_group（与 iOS `STMarketRankType` + `symbolGroupParamWithRankType:` 一致）
String symbolGroupParam(int rankType) {
  switch (rankType) {
    case 0:
      return '';
    case 1:
      return 'Forex';
    case 2:
      return 'Commodities';
    case 3:
      return 'Stock';
    case 4:
      return 'Crypto';
    case 5:
      return 'Index';
    case 6:
      return 'Metals';
    case 7:
      return 'USStock';
    case 8:
      return 'HKStock';
    default:
      return '';
  }
}

/// Provider
final stServiceProvider = Provider<STService>((ref) {
  final dio = ref.watch(stDioProvider);
  final service = STService(dio);
  final sessionCoordinator = STSessionInvalidationCoordinator(
    read: ref.read,
    dio: dio,
    anonymousLogin: service.anonymousLogin,
  );
  var refreshingUserInfo = false;
  dio.setAuthTokenRefreshHandler((data) async {
    final userNotifier = ref.read(userStateProvider.notifier);
    await userNotifier.applyRefreshedAuthTokenPayload(data);
    if (refreshingUserInfo ||
        !ref.read(userStateProvider).isExplicitlyLoggedIn) {
      return;
    }
    refreshingUserInfo = true;
    unawaited(
      userNotifier.refreshProfileAfterLogin(service).whenComplete(() {
        refreshingUserInfo = false;
      }),
    );
  });
  dio.setSessionInvalidationHandler(sessionCoordinator.handle);
  ref.onDispose(() {
    dio.setAuthTokenRefreshHandler(null);
    dio.setSessionInvalidationHandler(null);
  });
  return service;
});
