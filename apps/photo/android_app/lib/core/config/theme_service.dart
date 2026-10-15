import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/user_preference_prefs.dart';

/// 主题模式持久化服务
/// 支持：浅色、深色、跟随系统
class ThemeService {
  static const String _legacyThemeModeKey = UserPreferencePrefs.themeModeKey;

  /// 保存主题模式
  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_legacyThemeModeKey, mode.name);
    await prefs.setInt(UserPreferencePrefs.appDarkModeKey, _themeModeToAppDarkMode(mode));
  }

  /// 加载主题模式
  Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyMode = prefs.getString(_legacyThemeModeKey);
    final darkMode = prefs.getInt(UserPreferencePrefs.appDarkModeKey);

    final mapped = _appDarkModeToThemeMode(darkMode);
    if (mapped != null) {
      return mapped;
    }

    if (legacyMode != null) {
      return ThemeMode.values.firstWhere(
        (m) => m.name == legacyMode,
        orElse: () => ThemeMode.system,
      );
    }

    return ThemeMode.system;
  }

  ThemeMode? _appDarkModeToThemeMode(int? value) {
    switch (value) {
      case 0:
        return ThemeMode.system;
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      default:
        return null;
    }
  }

  int _themeModeToAppDarkMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 1;
      case ThemeMode.dark:
        return 2;
      case ThemeMode.system:
        return 0;
    }
  }

}

/// ThemeMode Provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final ThemeService _service = ThemeService();

  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final mode = await _service.loadThemeMode();
    state = mode;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _service.saveThemeMode(mode);
  }
}
