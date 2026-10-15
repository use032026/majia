import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'st_router.dart';

/// 路由权限守卫
/// 对齐 iOS STRouterManager 权限检查逻辑 + PageRouter.permissionCheck
class RouterGuard {
  static const String _failedRouterKey = 'STRouterManagerFailedRouter';
  static const String _failedParamsKey = 'STRouterManagerFailedParams';
  static const Set<String> _loginRequiredPagePaths = {
    '/action/documentary',
    '/mine/account',
    '/mine/account_security',
    '/mine/accountsafe',
    '/mine/accountmanager',
    '/mine/asset',
    '/mine/auth',
    '/mine/bank',
    '/mine/bankcard',
    '/mine/bankcard/add',
    '/mine/bankcard/add_voucher',
    '/mine/draw',
    '/mine/deposit',
    '/mine/editinfo',
    '/mine/ewallet',
    '/mine/personalinfo',
    '/mine/transfer',
    '/mine/wallet',
    '/trade/accountprofile',
    '/trade/orderdetail',
  };

  /// iOS PageRouter.json 中配置了 `permission` 的页面。
  /// 补充：保留 Flutter 路由层的兼容别名（如 /mine/account_security、/mine/bankcard）。
  static String pageRouterPermissionForPath(String path) {
    return _loginRequiredPagePaths.contains(path.toLowerCase()) ? 'login' : '';
  }

  /// 检查路由权限（用于 GoRouter redirect 层）
  /// 返回 null 表示有权限，否则返回重定向路径
  static Future<String?> checkPermission(
    String path,
    Map<String, String> params,
  ) async {
    final permission =
        params['permission'] ?? pageRouterPermissionForPath(path);
    if (permission.isEmpty) return null;

    final permissions = permission
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (permissions.isEmpty) return null;

    final isLoggedIn = await _isLoggedIn();

    if (permissions.contains('login') && !isLoggedIn) {
      await saveFailedRouter(path, params);
      return '/login';
    }
    if (permissions.contains('register') && !isLoggedIn) {
      await saveFailedRouter(path, params);
      return '/register';
    }
    return null;
  }

  /// 获取页面路由判定使用的登录态（兼容 `userStateProvider` 与 SharedPreferences）。
  ///
  /// - 当上层状态已是登录态时，直接放行；
  /// - 否则回退到本地持久化 `is_logged_in`，避免状态同步时序导致的误判。
  static Future<bool> shouldAllowByLogin({required bool isLoginState}) async {
    if (isLoginState) return true;
    return await _isLoggedIn();
  }

  /// 保存失败路由（登录成功后重试）— 对外公开，供 STRouter 使用
  static Future<void> saveFailedRouter(
    String path,
    Map<String, String> params,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final isOnce = params['isOnce'] == '1';

    if (!isOnce) {
      await prefs.setString(_failedRouterKey, path);
      await prefs.setString(
        _failedParamsKey,
        Uri(queryParameters: params).query,
      );
    }
  }

  /// 获取挂起的失败路由（不移除）
  static Future<MapEntry<String, Map<String, String>>?>
  getFailedRouter() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_failedRouterKey);
    final paramsStr = prefs.getString(_failedParamsKey);

    if (path == null) return null;

    final params = <String, String>{};
    if (paramsStr != null && paramsStr.isNotEmpty) {
      final uri = Uri(query: paramsStr);
      params.addAll(uri.queryParameters);
    }
    return MapEntry(path, params);
  }

  /// 获取并清除失败路由
  static Future<MapEntry<String, Map<String, String>>?>
  getAndClearFailedRouter() async {
    final entry = await getFailedRouter();
    if (entry != null) {
      await clearFailedRouter();
    }
    return entry;
  }

  /// 清除失败路由
  static Future<void> clearFailedRouter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_failedRouterKey);
    await prefs.remove(_failedParamsKey);
  }

  /// 检查是否已登录（从 UserStateProvider 读取）
  static Future<bool> _isLoggedIn() async {
    // 默认 true；实际在 checkPermission 调用处通过 ref 传入更准确。
    // 这里作为 fallback，依赖 SharedPreferences 中持久化标记。
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }

  /// 供外部在登录成功后调用，清除标记并持久化
  static Future<void> markLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', value);
  }
}

/// 路由重试服务（使用 STRouter 而非 Navigator.pushNamed）
final routerRetryProvider = Provider<RouterRetryService>((ref) {
  return RouterRetryService(ref);
});

class RouterRetryService {
  final Ref _ref;
  RouterRetryService(this._ref);

  /// 登录成功后重试挂起的路由。
  ///
  /// 返回 true 表示已恢复到原目标页面，调用方不应再执行默认落点跳转。
  Future<bool> retryFailedRouter(BuildContext context) async {
    final failed = await RouterGuard.getAndClearFailedRouter();
    if (failed == null) return false;
    if (!context.mounted) return false;

    final path = failed.key;
    final params = failed.value.map((k, v) => MapEntry(k, v as dynamic));
    final router = _ref.read(stRouterProvider);
    await router.openPage(context, path, params: params);
    return true;
  }
}
