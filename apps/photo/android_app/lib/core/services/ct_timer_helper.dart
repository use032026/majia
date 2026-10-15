import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../router/router_guard.dart';

/// CTTimerHelper — 2秒轮询定时器
/// 对齐 iOS CTTimerHelper，用于：
///   1. 安装归因路由延迟跳转（CMSInstallRouterMap）
///   2. 失败路由重试（STRouterManagerFailedRouter）
///
/// iOS：权限失败路由仅在 **已登录** 后写入 `cachedWakeUpData` 并由壳层打开；不会在未登录时丢弃 NSUserDefaults。
/// Flutter：`getAndClearFailedRouter` **仅当 `isLoggedIn()==true`** 时调用。
class CTTimerHelper {
  Timer? _timer;
  bool _isRunning = false;
  GoRouter? _router;
  bool Function()? _isLoggedIn;

  static const String _installRouterKey = 'CMSInstallRouterMap';

  /// [isLoggedIn] 每 tick 调用一次，须与业务登录态一致（如 `userStateProvider.isLogin`）。
  void start(GoRouter router, {required bool Function() isLoggedIn}) {
    if (_isRunning) return;
    _isRunning = true;
    _router = router;
    _isLoggedIn = isLoggedIn;

    debugPrint('⏱ CTTimerHelper started (2s interval)');

    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      _onTick();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _router = null;
    _isLoggedIn = null;
    debugPrint('⏱ CTTimerHelper stopped');
  }

  bool get isRunning => _isRunning;

  Future<void> _onTick() async {
    try {
      if (_router != null) {
        final prefs = await SharedPreferences.getInstance();
        final routerMap = prefs.getString(_installRouterKey);

        if (routerMap != null && routerMap.isNotEmpty) {
          debugPrint('⏱ CTTimerHelper: Found install router, navigating...');
          await prefs.remove(_installRouterKey);
          _navigateToRouter(routerMap);
          return;
        }
      }

      if (_router != null && (_isLoggedIn?.call() ?? false)) {
        final failed = await RouterGuard.getAndClearFailedRouter();
        if (failed != null) {
          debugPrint('⏱ CTTimerHelper: Retrying failed router: ${failed.key}');
          final path = failed.key;
          final params = failed.value;

          if (params.isNotEmpty) {
            _router!.go('$path?${Uri(queryParameters: params).query}');
          } else {
            _router!.go(path);
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('⏱ CTTimerHelper tick error: $e');
    }
  }

  void _navigateToRouter(String routerStr) {
    try {
      final uri = Uri.parse(routerStr);
      final path = uri.path;
      final params = uri.queryParameters;

      if (path == '/' || path.startsWith('/tabbar')) {
        final tab = params['tab'] ?? params['tabCode'] ?? 'home';
        _router!.go('/?tab=$tab');
      } else {
        String fullPath = path;
        if (params.isNotEmpty) {
          fullPath += '?${Uri(queryParameters: params).query}';
        }
        _router!.go(fullPath);
      }
    } catch (e) {
      debugPrint('⏱ CTTimerHelper navigate error: $e');
    }
  }
}

final ctTimerHelperProvider = Provider<CTTimerHelper>((ref) {
  return CTTimerHelper();
});
