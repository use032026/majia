import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/market_websocket.dart';
import '../../core/network/st_service.dart';
import '../../core/models/user_state.dart';
import '../../core/providers/country_manager_provider.dart';
import '../../core/services/app_locale_service.dart';
import '../../core/providers/app_events.dart';
import '../../core/providers/event_bus.dart';
import '../../core/providers/tab_shell_navigation.dart';
import '../../core/router/router_guard.dart';
import '../../shared/widgets/st_localized_prompt.dart';
import '../mine/mine_pending_route.dart';
import 'auth_api_helpers.dart';

/// 登录接口 `data.user_status` 枚举（对齐 iOS `STLoginApiUserStatus`）
enum _LoginApiUserStatus {
  normal(0),
  disabled(1),
  closed(2),
  blacklist(3),
  pending(4),
  rejected(5);

  final int value;
  const _LoginApiUserStatus(this.value);

  static _LoginApiUserStatus from(dynamic raw) {
    final v = raw is num ? raw.toInt() : (int.tryParse(raw.toString()) ?? 0);
    return _LoginApiUserStatus.values.firstWhere(
      (e) => e.value == v,
      orElse: () => _LoginApiUserStatus.normal,
    );
  }

  String? get blockedMessageKey {
    switch (this) {
      case _LoginApiUserStatus.normal:
        return null;
      case _LoginApiUserStatus.pending:
        return 'flutter_prompt_account_pending';
      case _LoginApiUserStatus.disabled:
      case _LoginApiUserStatus.closed:
      case _LoginApiUserStatus.blacklist:
      case _LoginApiUserStatus.rejected:
        return 'flutter_prompt_account_disabled';
    }
  }
}

String loginSuccessFallbackLocationForTab(String? tabCode) {
  final code = tabCode?.trim();
  if (code == null || code.isEmpty) return '/';
  return '/?tab=${Uri.encodeQueryComponent(code)}';
}

/// iOS 登录控制器只用本次登录接口 `response.data.need_update_password`
/// 决定是否进入强制重设登录密码；后续 `/api/user/info` 刷新不应抢占登录返回路由。
bool loginSuccessRequiresForcePasswordReset(Map<String, dynamic> loginData) {
  return UserState.parseApiBool(loginData['need_update_password']);
}

/// 登录成功后的全局副作用（对齐 iOS `loginPreSuccess` / token / WebSocket / 通知）
Future<void> commitLoginSuccess({
  required WidgetRef ref,
  required BuildContext context,
  required Map<String, dynamic> loginResult,
  bool retryFailedRouter = true,
  int? successPopCount,
}) async {
  AuthApiHelpers.ensureOk(loginResult);
  final data = AuthApiHelpers.unwrapLoginPayload(loginResult);

  // 1. 检查 user_status（对齐 iOS `allowLoginAfterCheckingUserStatusInResponse:`）
  final userStatus = _LoginApiUserStatus.from(data['user_status']);
  final blockedMsgKey = userStatus.blockedMessageKey;
  if (blockedMsgKey != null) {
    final blockedMsg = stLocalizedText(context, blockedMsgKey);
    if (context.mounted) {
      showStLocalizedToastByKey(context, blockedMsgKey);
    }
    throw Exception(blockedMsg);
  }

  // iOS 登录页成功后直接按当前返回链路收尾，不会在异步资料刷新期间再消费旧的
  // `STRouterManagerFailedRouter`。这里先清掉历史失败路由，避免 `CTTimerHelper`
  // 在 `userState.login()` 之后抢先把旧的 `/mine/account_security` 重放出来。
  if (!retryFailedRouter) {
    await RouterGuard.clearFailedRouter();
    await MinePendingRoute.clear();
  }

  final token = UserState.pickString(data, ['token']) ?? '';
  if (token.isNotEmpty) {
    ref.read(stServiceProvider).dio.setAuthToken(token);
  }
  final requiresForcePasswordReset = loginSuccessRequiresForcePasswordReset(
    data,
  );

  final service = ref.read(stServiceProvider);
  await ref.read(userStateProvider.notifier).login(data);
  await ref.read(userStateProvider.notifier).refreshProfileAfterLogin(service);
  await ref.read(userStateProvider.notifier).bootstrapLoggedInSession(service);
  try {
    final profile = await service.getUserProfile();
    final d = profile['data'];
    if (d is Map<String, dynamic>) {
      await syncCountryManagerFromProfile(
        ref.read(countryManagerProvider.notifier),
        userId: ref.read(userStateProvider).userId,
        countryKey: UserState.pickString(d, ['country']),
      );
    }
  } catch (_) {}
  await ref.read(appLocaleProvider.notifier).reloadFromPrefs();

  try {
    ref.read(marketWebSocketProvider).reConnect();
  } catch (_) {}

  ref.read(loginSuccessProvider.notifier).increment();
  EventBus().emit(EventBus.loginSuccess);

  if (!context.mounted) return;

  // 2. 登录成功提示（对齐 iOS `[STMBProgressHUD showMessage:@"login_success"]`）
  showStLocalizedToast(context, '登录成功');

  // 3. 普通登录成功后重试挂起路由（对齐 iOS `STRouterManager`）。
  // 注册成功页的“登录入金”走 `STRegisterResultViewController.popToDeposit`：
  // 先回根页面，再提交登录态；不能让历史失败路由抢占落点。
  if (retryFailedRouter) {
    final didRetryFailedRouter = await ref
        .read(routerRetryProvider)
        .retryFailedRouter(context);
    if (didRetryFailedRouter) return;
  }

  if (!context.mounted) return;
  if (requiresForcePasswordReset) {
    showStLocalizedToast(context, '请先修改登录密码');
    context.go('/mine/change_login_password');
  } else {
    final pending = retryFailedRouter ? await MinePendingRoute.consume() : null;
    if (!context.mounted) return;
    if (pending != null && pending.isNotEmpty) {
      context.go(pending);
      return;
    }
    if (_popAfterLoginSuccess(context, successPopCount)) {
      return;
    }
    context.go(
      loginSuccessFallbackLocationForTab(
        ref.read(currentTabShellTabCodeProvider),
      ),
    );
  }
}

bool _popAfterLoginSuccess(BuildContext context, int? successPopCount) {
  final count = successPopCount;
  if (count == null || count <= 0) return false;

  final router = GoRouter.of(context);
  var didPop = false;
  for (var i = 0; i < count; i += 1) {
    if (!router.canPop()) break;
    router.pop();
    didPop = true;
  }
  return didPop;
}
