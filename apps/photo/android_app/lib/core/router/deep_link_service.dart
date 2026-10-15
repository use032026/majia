import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Deep Link 服务
/// 对齐 iOS CTTimerHelper + CMSInstallRouterMap + STRouterManagerFailedRouter
///
/// ⚠️ 所有导航使用 GoRouter，不再使用 Navigator.pushNamed（H15 fix）
class DeepLinkService {
  /// 保存安装归因路由（供外部调用，如推送/Universal Link）
  static Future<void> saveInstallRouter(String router) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_installRouterKey, router);
  }

  /// 处理 Universal Link（使用 GoRouter）
  static Future<void> handleUniversalLink(
    BuildContext context,
    Uri uri,
  ) async {
    if (!context.mounted) return;
    // 延迟执行，确保 App 已启动完成
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!context.mounted) return;
    _navigate(context, uri.path, uri.queryParameters);
  }

  /// 处理 Google Sign-In 回调
  static Future<void> handleGoogleSignInCallback(
    BuildContext context,
    Uri uri,
  ) async {
    // TODO: 处理 Google Sign-In URL 回调
    debugPrint('Google Sign-In callback: $uri');
  }

  // ==================== 内部辅助 ====================

  static const String _installRouterKey = 'CMSInstallRouterMap';

  /// 使用 GoRouter 执行导航（对齐 iOS: STRouterManagerOpenRouter）
  static void _navigate(BuildContext context, String path, Map<String, String> params) {
    if (!context.mounted) return;
    // Tab 路由使用 go（替换当前路由栈）
    if (path == '/' || path.startsWith('/tabbar')) {
      final tab = params['tab'] ?? params['tabCode'] ?? 'home';
      context.go('/?tab=$tab');
    } else {
      // 普通路由使用 push（保留返回栈）
      final queryString = Uri(queryParameters: params).query;
      context.push(queryString.isNotEmpty ? '$path?$queryString' : path);
    }
  }
}

/// 安装归因路由处理（由 CTTimerHelper 轮询调用，使用 GoRouter 实例直接跳转）
/// 对齐 iOS: CMSInstallRouterMap → 2s 延迟跳转
/// 不再使用 DeepLinkService.handleInstallRouter（已被 CTTimerHelper 内联实现替代）

/// Deep Link Provider
final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return DeepLinkService();
});
