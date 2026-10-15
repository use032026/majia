import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/ios_common_alert_dialog.dart';
import '../../shared/widgets/st_toast.dart';
import '../localization/st_localizations.dart';
import '../models/user_state.dart';
import '../network/st_dio.dart';
import '../router/app_router.dart';
import 'app_locale_service.dart';
import 'user_preference_prefs.dart';

typedef STAnonymousLoginRequest = Future<Map<String, dynamic>> Function();
typedef STSessionCanHandle = bool Function();
typedef STSessionGoRoot = void Function();
typedef STProviderRead = T Function<T>(ProviderListenable<T> provider);
typedef STOtherLoginDialogPresenter =
    Future<void> Function({
      required String title,
      required String message,
      required String confirmText,
    });
typedef STSessionTextLoader = Future<Map<String, String>> Function();

class STSessionInvalidationCoordinator {
  STSessionInvalidationCoordinator({
    required STProviderRead read,
    required STDio dio,
    required STAnonymousLoginRequest anonymousLogin,
    STSessionCanHandle? canHandle,
    STSessionGoRoot? goRoot,
    STOtherLoginDialogPresenter? showOtherLoginDialog,
    STSessionTextLoader? loadText,
  }) : _read = read,
       _dio = dio,
       _anonymousLogin = anonymousLogin,
       _canHandle = canHandle ?? _defaultCanHandle,
       _goRoot = goRoot ?? _defaultGoRoot,
       _showOtherLoginDialog =
           showOtherLoginDialog ?? _defaultShowOtherLoginDialog,
       _loadText = loadText ?? (() => _defaultLoadText(read));

  final STProviderRead _read;
  final STDio _dio;
  final STAnonymousLoginRequest _anonymousLogin;
  final STSessionCanHandle _canHandle;
  final STSessionGoRoot _goRoot;
  final STOtherLoginDialogPresenter _showOtherLoginDialog;
  final STSessionTextLoader _loadText;
  bool _handling = false;

  Future<void> handle(STSessionInvalidationReason reason) async {
    if (_handling || !_canHandle()) return;
    final user = _read(userStateProvider);
    if (!user.isExplicitlyLoggedIn) return;

    _handling = true;
    try {
      await _logoutToAnonymous();
      if (reason == STSessionInvalidationReason.loggedInOnAnotherDevice) {
        final text = await _loadText();
        await _showOtherLoginDialog(
          title: text['prompt'] ?? '提示',
          message:
              text['logged_in_on_another_device'] ?? '您的账户已在其他设备登录，本机已被强制下线。',
          confirmText: text['certain'] ?? '确定',
        );
      }
      _goRoot();
    } finally {
      _handling = false;
    }
  }

  Future<void> _logoutToAnonymous() async {
    await _read(userStateProvider.notifier).logout();
    _dio.setAuthToken(null);
    try {
      final response = await _anonymousLogin();
      final code = response['code'];
      final data = response['data'];
      if ((code == null || code == 0) && data is Map<String, dynamic>) {
        final token = data['token'] as String?;
        if (token != null && token.isNotEmpty) {
          _dio.setAuthToken(token);
        }
        await _read(userStateProvider.notifier).establishAnonymousSession(data);
      }
    } catch (e) {
      debugPrint('⚠️ Anonymous login after session invalidation failed: $e');
    }
  }

  static bool _defaultCanHandle() {
    return STToast.navigatorKey.currentState != null &&
        STToast.navigatorKey.currentContext != null;
  }

  static void _defaultGoRoot() {
    AppRouter.router.go('/');
  }

  static Future<void> _defaultShowOtherLoginDialog({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final context = STToast.navigatorKey.currentContext;
    if (context == null) return;
    await showIosCommonAlertDialog(
      context: context,
      title: title,
      message: message,
      confirmText: confirmText,
      showCancel: false,
      barrierDismissible: false,
    );
  }

  static Future<Map<String, String>> _defaultLoadText(
    STProviderRead read,
  ) async {
    final languageCode = languageCodeFromLocale(read(appLocaleProvider));
    final localizations = STLocalizations(
      bundle: read(iosLanguageBundleProvider),
      languageCode: languageCode,
    );
    return localizations.textMap(const {
      'prompt': '提示',
      'logged_in_on_another_device': '您的账户已在其他设备登录，本机已被强制下线。',
      'certain': '确定',
    });
  }
}
