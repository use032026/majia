import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/st_service.dart';

typedef DeviceTokenProvider = Future<String?> Function();

/// 启动期设备推送 token 注册。
///
/// iOS 在 Firebase Messaging 回调拿到 FCM token 后调用
/// `violet/api/user/register_device`。Flutter 侧不强绑定具体推送 SDK，
/// 由 [tokenProvider] 注入实际 token 来源；未接入 SDK 时默认跳过。
class StartupDeviceRegistrar {
  const StartupDeviceRegistrar({this.tokenProvider});

  final DeviceTokenProvider? tokenProvider;

  Future<void> registerIfPossible(STService service) async {
    final provider = tokenProvider;
    if (provider == null) return;

    try {
      final rawToken = await provider();
      final token = rawToken?.trim() ?? '';
      if (token.isEmpty) return;
      await service.registerDeviceToken(token);
    } catch (e) {
      debugPrint('⚠️ register device token failed: $e');
    }
  }
}

final startupDeviceRegistrarProvider = Provider<StartupDeviceRegistrar>((ref) {
  return const StartupDeviceRegistrar();
});
