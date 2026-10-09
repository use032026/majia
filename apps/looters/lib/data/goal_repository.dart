import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

abstract class GoalRepository {
  Future<GoalLibrary> loadLibrary();
  Future<void> saveLibrary(GoalLibrary library);
  Future<void> clearLibrary();
  Future<String?> loadLocaleCode();
  Future<void> saveLocaleCode(String localeCode);
  Future<bool?> loadDarkMode();
  Future<void> saveDarkMode(bool enabled);
}

class SharedPreferencesGoalRepository implements GoalRepository {
  static const _libraryKey = 'pace_jar.library.v2';
  static const _legacyGoalKey = 'pace_jar.goal.v1';
  static const _localeKey = 'pace_jar.locale';
  static const _darkModeKey = 'pace_jar.dark_mode';

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  @override
  Future<GoalLibrary> loadLibrary() async {
    final preferences = await _preferences;
    final raw = preferences.getString(_libraryKey);
    if (raw != null) return _decodeLibrary(raw);

    final legacyRaw = preferences.getString(_legacyGoalKey);
    if (legacyRaw == null) return GoalLibrary();
    final decoded = jsonDecode(legacyRaw);
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException('Invalid local record');
    }
    final map = decoded.cast<String, Object?>();
    if (map['schemaVersion'] != 1 || map['goal'] is! Map<Object?, Object?>) {
      throw const FormatException('Unsupported local record');
    }
    return GoalLibrary(
      activeGoal: SavingsGoal.fromJson(
        (map['goal']! as Map<Object?, Object?>).cast<String, Object?>(),
      ),
    );
  }

  GoalLibrary _decodeLibrary(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException('Invalid local record');
    }
    final map = decoded.cast<String, Object?>();
    if (map['schemaVersion'] != 2 || map['library'] is! Map<Object?, Object?>) {
      throw const FormatException('Unsupported local record');
    }
    return GoalLibrary.fromJson(
      (map['library']! as Map<Object?, Object?>).cast<String, Object?>(),
    );
  }

  @override
  Future<void> saveLibrary(GoalLibrary library) async {
    final encoded = jsonEncode(<String, Object?>{
      'schemaVersion': 2,
      'library': library.toJson(),
    });
    final preferences = await _preferences;
    final saved = await preferences.setString(_libraryKey, encoded);
    if (!saved) throw StateError('Local save failed');
    try {
      await preferences.remove(_legacyGoalKey);
    } catch (_) {
      // The v2 record is authoritative and is always read before the legacy key.
    }
  }

  @override
  Future<void> clearLibrary() async {
    final preferences = await _preferences;
    await preferences.remove(_libraryKey);
    await preferences.remove(_legacyGoalKey);
    if (preferences.containsKey(_libraryKey) ||
        preferences.containsKey(_legacyGoalKey)) {
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
