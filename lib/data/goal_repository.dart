import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

abstract class GoalRepository {
  Future<SavingsGoal?> loadGoal();
  Future<void> saveGoal(SavingsGoal goal);
  Future<void> clearGoal();
  Future<String?> loadLocaleCode();
  Future<void> saveLocaleCode(String localeCode);
  Future<bool?> loadDarkMode();
  Future<void> saveDarkMode(bool enabled);
}

class SharedPreferencesGoalRepository implements GoalRepository {
  static const _goalKey = 'pace_jar.goal.v1';
  static const _localeKey = 'pace_jar.locale';
  static const _darkModeKey = 'pace_jar.dark_mode';

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  @override
  Future<SavingsGoal?> loadGoal() async {
    final raw = (await _preferences).getString(_goalKey);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException('Invalid local record');
    }
    final map = decoded.cast<String, Object?>();
    if (map['schemaVersion'] != 1 || map['goal'] is! Map<Object?, Object?>) {
      throw const FormatException('Unsupported local record');
    }
    return SavingsGoal.fromJson(
      (map['goal']! as Map<Object?, Object?>).cast<String, Object?>(),
    );
  }

  @override
  Future<void> saveGoal(SavingsGoal goal) async {
    final encoded = jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'goal': goal.toJson(),
    });
    final saved = await (await _preferences).setString(_goalKey, encoded);
    if (!saved) throw StateError('Local save failed');
  }

  @override
  Future<void> clearGoal() async {
    final cleared = await (await _preferences).remove(_goalKey);
    if (!cleared && (await _preferences).containsKey(_goalKey)) {
      throw StateError('Local clear failed');
    }
  }

  @override
  Future<String?> loadLocaleCode() async =>
      (await _preferences).getString(_localeKey);

  @override
  Future<void> saveLocaleCode(String localeCode) async {
    final saved = await (await _preferences).setString(_localeKey, localeCode);
    if (!saved) throw StateError('Locale save failed');
  }

  @override
  Future<bool?> loadDarkMode() async =>
      (await _preferences).getBool(_darkModeKey);

  @override
  Future<void> saveDarkMode(bool enabled) async {
    final saved = await (await _preferences).setBool(_darkModeKey, enabled);
    if (!saved) throw StateError('Theme save failed');
  }
}
