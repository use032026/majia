import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class PreferenceStore {
  Future<String?> getString(String key);
  Future<bool?> getBool(String key);
  Future<void> setString(String key, String value);
  Future<void> setBool(String key, bool value);
  Future<void> remove(String key);
}

class NativePreferenceStore implements PreferenceStore {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  @override
  Future<String?> getString(String key) => _preferences.getString(key);
  @override
  Future<bool?> getBool(String key) => _preferences.getBool(key);
  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);
  @override
  Future<void> setBool(String key, bool value) =>
      _preferences.setBool(key, value);
  @override
  Future<void> remove(String key) => _preferences.remove(key);
}

class MemoryPreferenceStore implements PreferenceStore {
  final Map<String, Object> values = {};
  @override
  Future<String?> getString(String key) async => values[key] as String?;
  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;
  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> setBool(String key, bool value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

Locale resolveAppLocale(Locale? device) => device?.languageCode == 'zh'
    ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans')
    : const Locale('en');

class AppSettings extends ChangeNotifier {
  AppSettings._(this._store);
  static const languageKey = 'id_fixture.language';
  static const themeKey = 'id_fixture.theme';
  static const onboardingKey = 'id_fixture.onboarding_complete.v1';
  final PreferenceStore _store;
  String? _language;
  ThemeMode _theme = ThemeMode.system;
  bool _onboardingComplete = false;
  bool _storageWarning = false;

  static Future<AppSettings> load({PreferenceStore? store}) async {
    final settings = AppSettings._(store ?? NativePreferenceStore());
    try {
      final language = await settings._store.getString(languageKey);
      settings._language = ['zh', 'en'].contains(language) ? language : null;
      final theme = await settings._store.getString(themeKey);
      settings._theme = switch (theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      settings._onboardingComplete =
          await settings._store.getBool(onboardingKey) ?? false;
    } catch (_) {
      settings._storageWarning = true;
    }
    return settings;
  }

  bool get onboardingComplete => _onboardingComplete;
  bool get storageWarning => _storageWarning;
  String? get languageCode => _language;
  Locale? get locale =>
      _language == null ? null : resolveAppLocale(Locale(_language!));
  ThemeMode get themeMode => _theme;

  Future<void> _save(Future<void> Function() action) async {
    try {
      await action();
      _storageWarning = false;
    } catch (_) {
      _storageWarning = true;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setLanguage(String? code) async {
    if (code != null && code != 'zh' && code != 'en') {
      throw ArgumentError.value(code, 'code');
    }
    await _save(
      () => code == null
          ? _store.remove(languageKey)
          : _store.setString(languageKey, code),
    );
    _language = code;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _save(
      () => mode == ThemeMode.system
          ? _store.remove(themeKey)
          : _store.setString(themeKey, mode.name),
    );
    _theme = mode;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    try {
      await _save(() => _store.setBool(onboardingKey, true));
    } catch (_) {
      // Preference storage is nonessential: permit a session-only skip and
      // retain storageWarning so a failed write never traps the user here.
    }
    _onboardingComplete = true;
    notifyListeners();
  }
}
