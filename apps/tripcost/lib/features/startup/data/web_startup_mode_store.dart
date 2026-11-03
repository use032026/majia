import 'package:shared_preferences/shared_preferences.dart';

abstract interface class WebStartupModeStore {
  Future<bool> isEnabled();

  Future<void> setEnabled(bool enabled);
}

final class SharedPreferencesWebStartupModeStore
    implements WebStartupModeStore {
  SharedPreferencesWebStartupModeStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences;

  static const _enabledKey = 'startup.polymer_web_enabled.v1';

  SharedPreferencesAsync? _preferences;

  @override
  Future<bool> isEnabled() async {
    final preferences = _preferences ??= SharedPreferencesAsync();
    return await preferences.getBool(_enabledKey) ?? false;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final preferences = _preferences ??= SharedPreferencesAsync();
    await preferences.setBool(_enabledKey, enabled);
  }
}
