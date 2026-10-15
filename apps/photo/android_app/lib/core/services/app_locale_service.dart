import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/st_service.dart';
import '../constants/ios_language_catalog.dart';
import 'user_preference_prefs.dart';

/// 应用界面语言（持久化 `app_language`，对齐 iOS 切换语言后更新 `X-Language`）
final appLocaleProvider = StateNotifierProvider<AppLocaleNotifier, Locale>((
  ref,
) {
  return AppLocaleNotifier(ref);
});

class AppLocaleNotifier extends StateNotifier<Locale> {
  AppLocaleNotifier(this._ref)
    : super(
        localeFromLanguageCode(
          UserPreferencePrefs.defaultAppLanguageForPlatformLocale(
            ui.PlatformDispatcher.instance.locale,
          ),
        ),
      ) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final code = await UserPreferencePrefs.readAppLanguage();
    final canon = IosLanguageCatalog.canonicalize(code.trim());
    state = localeFromLanguageCode(canon);
    _applyToDio(canon);
  }

  /// `/user/info`、登录合并等写入 `app_language` 后刷新（对齐 iOS 拉用户信息后同步界面语言）。
  Future<void> reloadFromPrefs() => _load();

  Future<void> setLanguageCode(String code, {String? name}) async {
    final canon = IosLanguageCatalog.canonicalize(code.trim());
    await UserPreferencePrefs.saveAppLanguage(canon);
    if (name != null && name.isNotEmpty) {
      await UserPreferencePrefs.saveAppLanguageName(name);
    }
    state = localeFromLanguageCode(canon);
    _applyToDio(canon);
  }

  void _applyToDio(String code) {
    try {
      _ref.read(stServiceProvider).dio.setLanguage(code);
    } catch (_) {}
  }
}
