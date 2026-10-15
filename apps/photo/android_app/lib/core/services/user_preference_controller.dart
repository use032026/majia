import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/card_tool.dart';
import '../config/theme_service.dart';
import '../localization/st_localizations.dart';
import '../models/user_state.dart';
import '../providers/available_languages_provider.dart';
import '../providers/event_bus.dart';
import 'app_locale_service.dart';
import 'user_preference_prefs.dart';

/// 偏好设置写入：本地持久化 + 状态刷新（对齐 iOS `STPreferenceSetViewController`）
final userPreferenceControllerProvider = Provider<UserPreferenceController>((
  ref,
) {
  return UserPreferenceController(ref);
});

class UserPreferenceController {
  UserPreferenceController(this._ref);

  final Ref _ref;

  UserStateNotifier get _user => _ref.read(userStateProvider.notifier);
  UserState get _state => _ref.read(userStateProvider);

  Future<void> setThemeMode(ThemeMode mode) async {
    await _ref.read(themeModeProvider.notifier).setThemeMode(mode);
  }

  Future<void> setRiseAndFallType(int type) async {
    final oldType = _state.riseAndFallType;
    if (oldType == type) return;
    await UserPreferencePrefs.saveRiseAndFallType(type, userId: _state.userId);
    _user.updateRiseAndFallType(type);
    CardTool.setRiseAndFallType(type);
    EventBus().emit(EventBus.riseColorChanged);
  }

  Future<void> setOneKeyClose(bool value) async {
    await UserPreferencePrefs.saveOneKeyClose(value, userId: _state.userId);
    _user.updateOneKeyClose(value);
  }

  Future<void> setTimezone(String tz) async {
    await UserPreferencePrefs.saveTimezone(tz, userId: _state.userId);
    _user.updateSelectedTimeZone(tz);
  }

  Future<void> setLanguageCode(String code, {String? name}) async {
    _ref.read(iosLanguageBundleProvider).clearCache();
    await _ref
        .read(appLocaleProvider.notifier)
        .setLanguageCode(code, name: name);
    await _ref.read(availableLanguagesProvider.notifier).refreshFromNetwork();
    final canon = languageCodeFromLocale(_ref.read(appLocaleProvider));
    final rows = _ref.read(availableLanguagesProvider);
    String? refreshedName;
    for (final item in rows) {
      if (item.code == canon && item.label.trim().isNotEmpty) {
        refreshedName = item.label.trim();
        break;
      }
    }
    if (refreshedName != null) {
      await UserPreferencePrefs.saveAppLanguageName(refreshedName);
    }
  }
}
