import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/user_state.dart';
import '../network/st_service.dart';

/// 写入后可由冷启动 `checkAppleCredentialOnColdStart` 校验（对齐 iOS Keychain 中的 Apple user id）。
/// Apple 登录接入成功后：写入一次即可。
const String kAppleSignInUserIdSecureKey = 'st_apple_sign_in_user_id';

/// 对齐 iOS `AppleAuthManager.checkCredentialState`：
/// 若本地存有 Apple user id 且凭据非 authorized，则登出并清理 token。
Future<void> checkAppleCredentialOnColdStart(Ref ref) async {
  if (kIsWeb) return;
  if (!Platform.isIOS && !Platform.isMacOS) return;

  try {
    const storage = FlutterSecureStorage();
    final userId = await storage.read(key: kAppleSignInUserIdSecureKey);
    if (userId == null || userId.isEmpty) return;

    final credentialState = await SignInAppleWrapper.getCredentialState(userId);
    if (credentialState == CredentialState.authorized) return;

    await ref.read(userStateProvider.notifier).logout();
    ref.read(stServiceProvider).dio.setAuthToken(null);
    await storage.delete(key: kAppleSignInUserIdSecureKey);
    debugPrint('Apple credential not authorized; session cleared');
  } catch (e) {
    debugPrint('Apple credential check skipped: $e');
  }
}

/// 隔离插件静态调用，便于测试替换。
class SignInAppleWrapper {
  static Future<CredentialState> getCredentialState(String userIdentifier) {
    return SignInWithApple.getCredentialState(userIdentifier);
  }
}
