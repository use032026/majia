import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user_state.dart';
import '../network/market_websocket.dart';
import '../network/st_service.dart';
import '../providers/event_bus.dart';
import 'apple_credential_launch_guard.dart';

/// Active logout aligned with iOS `STLoginManager.logoutSuccess`.
///
/// iOS clears the logged-in user locally, starts anonymous login immediately,
/// deletes the Apple user id from Keychain, and posts logout notification after
/// the anonymous request callback. It does not call `violet/api/user/logout`
/// from the settings page.
Future<void> performIosAlignedLogout(WidgetRef ref) async {
  final service = ref.read(stServiceProvider);
  final userNotifier = ref.read(userStateProvider.notifier);
  final marketWebSocket = ref.read(marketWebSocketProvider);

  await userNotifier.logout();
  service.dio.setAuthToken(null);
  await clearAppleSignInUserIdLikeIos();

  unawaited(
    _restoreAnonymousSessionAfterLogout(
      service: service,
      userNotifier: userNotifier,
      marketWebSocket: marketWebSocket,
    ),
  );
}

Future<void> clearAppleSignInUserIdLikeIos() async {
  try {
    const storage = FlutterSecureStorage();
    await storage.delete(key: kAppleSignInUserIdSecureKey);
  } catch (e) {
    debugPrint('Apple credential logout cleanup skipped: $e');
  }
}

Future<void> _restoreAnonymousSessionAfterLogout({
  required STService service,
  required UserStateNotifier userNotifier,
  required MarketWebSocket marketWebSocket,
}) async {
  try {
    final response = await service.anonymousLogin();
    final code = response['code'];
    final rawData = response['data'];
    if ((code == null || code == 0) && rawData is Map) {
      final data = Map<String, dynamic>.from(rawData);
      final token = UserState.pickString(data, ['token']) ?? '';
      if (token.isNotEmpty) {
        service.dio.setAuthToken(token);
      }
      await userNotifier.establishAnonymousSession(data);
    }
  } catch (e) {
    debugPrint('Anonymous login after active logout failed: $e');
  } finally {
    try {
      marketWebSocket.sendLogout();
      marketWebSocket.reConnect();
    } catch (_) {}
    EventBus().emit(EventBus.logout);
  }
}
