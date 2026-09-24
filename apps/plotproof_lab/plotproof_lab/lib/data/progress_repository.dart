import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

abstract interface class ProgressRepository {
  Future<List<Attempt>> loadAttempts();
  Future<void> saveAttempts(List<Attempt> attempts);
  Future<String?> loadLanguageCode();
  Future<void> saveLanguageCode(String languageCode);
  Future<bool> loadOnboardingCompleted();
  Future<void> saveOnboardingCompleted(bool completed);
  Future<void> clearAttempts();
}

class SharedPreferencesProgressRepository implements ProgressRepository {
  SharedPreferencesProgressRepository(this._preferences);

  static const _attemptsKey = 'learning_attempts_v1';
  static const _languageKey = 'language_code_v1';
  static const _onboardingCompletedKey = 'onboarding_completed_v1';

  final SharedPreferences _preferences;

  @override
  Future<List<Attempt>> loadAttempts() async {
    final source = _preferences.getString(_attemptsKey);
    if (source == null || source.isEmpty) {
      return const <Attempt>[];
    }
    final decoded = jsonDecode(source);
    if (decoded is! List<Object?>) {
      throw const FormatException('Attempt store is not a list.');
    }
    return decoded
        .map((item) {
          if (item is! Map<String, Object?>) {
            throw const FormatException('Attempt entry is not an object.');
          }
          return Attempt.fromJson(item);
        })
        .toList(growable: false);
  }

  @override
  Future<void> saveAttempts(List<Attempt> attempts) async {
    final value = jsonEncode(
      attempts.map((attempt) => attempt.toJson()).toList(growable: false),
    );
    final didSave = await _preferences.setString(_attemptsKey, value);
    if (!didSave) {
      throw StateError('Could not save learning progress.');
    }
  }

  @override
  Future<String?> loadLanguageCode() async =>
      _preferences.getString(_languageKey);

  @override
  Future<bool> loadOnboardingCompleted() async =>
      _preferences.getBool(_onboardingCompletedKey) ?? false;

  @override
  Future<void> saveLanguageCode(String languageCode) async {
    final didSave = await _preferences.setString(_languageKey, languageCode);
    if (!didSave) {
      throw StateError('Could not save language preference.');
    }
  }

  @override
  Future<void> saveOnboardingCompleted(bool completed) async {
    final didSave = await _preferences.setBool(
      _onboardingCompletedKey,
      completed,
    );
    if (!didSave) {
      throw StateError('Could not save onboarding status.');
    }
  }

  @override
  Future<void> clearAttempts() async {
    final didRemove = await _preferences.remove(_attemptsKey);
    if (!didRemove && _preferences.containsKey(_attemptsKey)) {
      throw StateError('Could not clear learning progress.');
    }
  }
}

class MemoryProgressRepository implements ProgressRepository {
  MemoryProgressRepository({
    List<Attempt>? attempts,
    String? languageCode,
    bool onboardingCompleted = false,
  }) : _attempts = List<Attempt>.of(attempts ?? const <Attempt>[]),
       _languageCode = languageCode,
       _onboardingCompleted = onboardingCompleted;

  List<Attempt> _attempts;
  String? _languageCode;
  bool _onboardingCompleted;
  bool failWrites = false;

  @override
  Future<void> clearAttempts() async {
    if (failWrites) throw StateError('Test write failure');
    _attempts = <Attempt>[];
  }

  @override
  Future<List<Attempt>> loadAttempts() async => List<Attempt>.of(_attempts);

  @override
  Future<String?> loadLanguageCode() async => _languageCode;

  @override
  Future<bool> loadOnboardingCompleted() async => _onboardingCompleted;

  @override
  Future<void> saveAttempts(List<Attempt> attempts) async {
    if (failWrites) throw StateError('Test write failure');
    _attempts = List<Attempt>.of(attempts);
  }

  @override
  Future<void> saveLanguageCode(String languageCode) async {
    if (failWrites) throw StateError('Test write failure');
    _languageCode = languageCode;
  }

  @override
  Future<void> saveOnboardingCompleted(bool completed) async {
    if (failWrites) throw StateError('Test write failure');
    _onboardingCompleted = completed;
  }
}
