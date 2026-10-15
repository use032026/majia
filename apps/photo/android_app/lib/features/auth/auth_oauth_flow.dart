import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/models/user_state.dart';
import '../../core/network/st_service.dart';
import '../../core/services/apple_credential_launch_guard.dart';
import '../../core/services/startup_device_registrar.dart';
import '../../core/services/user_preference_prefs.dart';
import 'auth_api_helpers.dart';
import 'auth_login_commit.dart';
import 'register_config.dart';

Future<String> readIosRegisterInviteCode() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('STUserTempInviteCode') ??
      prefs.getString('STUserInviteCode') ??
      '';
}

Future<void> handleAppleOAuthFlow({
  required WidgetRef ref,
  required BuildContext context,
  required String countryKey,
  required RegisterUiState uiState,
  String vcodeSessionId = '',
  bool retryFailedRouter = false,
  int? loginSuccessPopCount,
}) async {
  final credential = await _requestAppleCredentialLikeIos();
  if (credential == null) return;

  final idToken = credential.identityToken ?? '';
  if (idToken.isEmpty) {
    debugPrint('无法获取identity token');
    return;
  }

  final userId = credential.userIdentifier ?? '';
  if (userId.isNotEmpty) {
    try {
      await const FlutterSecureStorage().write(
        key: kAppleSignInUserIdSecureKey,
        value: userId,
      );
    } catch (e) {
      debugPrint('Apple credential save skipped: $e');
    }
  }

  if (!context.mounted) return;
  await handleThirdPartyOAuthFlow(
    ref: ref,
    context: context,
    idToken: idToken,
    code: credential.authorizationCode,
    loginType: 3,
    countryKey: countryKey,
    uiState: uiState,
    vcodeSessionId: vcodeSessionId,
    retryFailedRouter: retryFailedRouter,
    loginSuccessPopCount: loginSuccessPopCount,
  );
}

Future<AuthorizationCredentialAppleID?> _requestAppleCredentialLikeIos() async {
  try {
    return await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
  } on SignInWithAppleException catch (e) {
    debugPrint('apple 登录失败------$e');
    return null;
  } catch (e) {
    debugPrint('apple 登录失败------$e');
    return null;
  }
}

Future<void> handleThirdPartyOAuthFlow({
  required WidgetRef ref,
  required BuildContext context,
  required String idToken,
  required String code,
  required int loginType,
  required String countryKey,
  required RegisterUiState uiState,
  String vcodeSessionId = '',
  bool retryFailedRouter = false,
  int? loginSuccessPopCount,
}) async {
  final service = ref.read(stServiceProvider);
  final verifyRaw = await service.thirdPartyVerify({
    'id_token': idToken,
    'platform': 'mobile',
    'login_type': loginType,
    'app_id': 1,
    'code': code,
  });
  AuthApiHelpers.ensureOk(verifyRaw);
  final data = AuthApiHelpers.unwrapLoginPayload(verifyRaw);
  final oauthToken = '${data['oauth_token'] ?? ''}';
  final userExist = data['user_exist'] == true || data['user_exist'] == 1;
  if (userExist) {
    final loginRaw = await service.thirdPartyLogin(oauthToken: oauthToken);
    AuthApiHelpers.ensureOk(loginRaw);
    if (!context.mounted) return;
    await commitLoginSuccess(
      ref: ref,
      context: context,
      loginResult: loginRaw,
      retryFailedRouter: retryFailedRouter,
      successPopCount: loginSuccessPopCount,
    );
    return;
  }

  final language = await UserPreferencePrefs.readAppLanguage();
  if (!context.mounted) return;
  await startThirdPartyRegisterFromOAuth(
    ref: ref,
    context: context,
    service: service,
    oauthToken: oauthToken,
    countryKey: countryKey,
    language: language,
    vcodeSessionId: vcodeSessionId,
    uiState: uiState,
  );
}

Future<void> startThirdPartyRegisterFromOAuth({
  required WidgetRef ref,
  required BuildContext context,
  required STService service,
  required String oauthToken,
  required String countryKey,
  required String language,
  required RegisterUiState uiState,
  String vcodeSessionId = '',
}) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = await service.registerStart({
    'oauth_token': oauthToken,
    'country': countryKey,
    'language': language,
    'tel_area_code': '',
    'tel': '',
    'email': '',
    'password': '',
    'verify_code': '',
    'invite_code': await readIosRegisterInviteCode(),
    if (vcodeSessionId.isNotEmpty) 'vcode_session_id': vcodeSessionId,
    'is_google_jwt': 0,
  });
  AuthApiHelpers.ensureOk(raw);
  await prefs.remove('STUserInviteCode');
  await prefs.remove('STUserTempInviteCode');
  final data = AuthApiHelpers.unwrapLoginPayload(raw);
  final result = '${data['result'] ?? ''}';
  final nextStep = '${data['next_step'] ?? ''}';
  final token = '${data['register_token'] ?? ''}';

  if (!context.mounted) return;

  final outcome = parseRegisterOutcome(result);
  if (outcome == RegisterOutcome.inProgress && nextStep == 'IDENTITY') {
    context.push(
      '/register/identity',
      extra: {
        'fields': uiState.identityFieldsForThird(),
        'registerToken': token,
        'loginMode': 0,
        'registeredAccount': '',
      },
    );
    return;
  }

  if (outcome == RegisterOutcome.success) {
    final loginToken = UserState.pickString(data, ['token']) ?? '';
    if (loginToken.isNotEmpty) {
      service.dio.setAuthToken(loginToken);
    }
    final currentRaw = await service.getCurrentTransAccount();
    AuthApiHelpers.ensureOk(currentRaw);
    final currentData = AuthApiHelpers.unwrapLoginPayload(currentRaw);
    ref.read(userStateProvider.notifier).updateTransactionAccounts(currentData);
    await ref.read(startupDeviceRegistrarProvider).registerIfPossible(service);
    if (!context.mounted) return;
  }

  if (outcome == RegisterOutcome.success ||
      outcome == RegisterOutcome.rejected ||
      outcome == RegisterOutcome.pending) {
    context.push(
      '/register/result',
      extra: {
        'outcome': outcome!.index,
        'loginMode': 0,
        'userInfo': data,
        'registeredAccount': '',
      },
    );
  }
}
