import 'package:shared_preferences/shared_preferences.dart';

abstract class StateStore {
  Future<String?> read();
  Future<bool> write(String value);
  Future<bool> clear();
}

class PreferencesStateStore implements StateStore {
  PreferencesStateStore(this._preferences);

  static const String _key = 'almanac_state_v1';
  final SharedPreferences _preferences;

  @override
  Future<String?> read() async => _preferences.getString(_key);

  @override
  Future<bool> write(String value) => _preferences.setString(_key, value);

  @override
  Future<bool> clear() => _preferences.remove(_key);
}
