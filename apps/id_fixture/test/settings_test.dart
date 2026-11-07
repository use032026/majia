import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:id_fixture/services/app_settings.dart';

class FailingStore extends MemoryPreferenceStore {
  bool fail = false;
  @override
  Future<void> setString(String key, String value) async {
    if (fail) throw StateError('storage unavailable');
    return super.setString(key, value);
  }
}

class OnboardingWriteFailingStore extends MemoryPreferenceStore {
  @override
  Future<void> setBool(String key, bool value) async {
    throw StateError('storage unavailable');
  }
}

void main() {
  test('system preferences stay unset until an explicit selection', () async {
    final store = MemoryPreferenceStore();
    final settings = await AppSettings.load(store: store);
    expect(settings.locale, isNull);
    expect(settings.themeMode, ThemeMode.system);
    expect(store.values, isEmpty);
    expect(resolveAppLocale(const Locale('zh', 'TW')).languageCode, 'zh');
    expect(resolveAppLocale(const Locale('en', 'GB')), const Locale('en'));
    expect(resolveAppLocale(const Locale('vi')), const Locale('en'));
    expect(resolveAppLocale(null), const Locale('en'));
  });
  test('explicit overrides survive reload and system removes keys', () async {
    final store = MemoryPreferenceStore();
    final settings = await AppSettings.load(store: store);
    await settings.setLanguage('en');
    await settings.setThemeMode(ThemeMode.dark);
    final restored = await AppSettings.load(store: store);
    expect(restored.locale, const Locale('en'));
    expect(restored.themeMode, ThemeMode.dark);
    await restored.setLanguage(null);
    await restored.setThemeMode(ThemeMode.system);
    expect(store.values.containsKey(AppSettings.languageKey), isFalse);
    expect(store.values.containsKey(AppSettings.themeKey), isFalse);
  });
  test('onboarding completion persists independently of preferences', () async {
    final store = MemoryPreferenceStore();
    final settings = await AppSettings.load(store: store);
    expect(settings.onboardingComplete, isFalse);
    await settings.completeOnboarding();
    final restored = await AppSettings.load(store: store);
    expect(restored.onboardingComplete, isTrue);
    expect(restored.locale, isNull);
    expect(restored.themeMode, ThemeMode.system);
  });
  test('failed persistence preserves the previous choice', () async {
    final store = FailingStore();
    final settings = await AppSettings.load(store: store);
    await settings.setLanguage('en');
    store.fail = true;
    await expectLater(settings.setLanguage('zh'), throwsStateError);
    expect(settings.languageCode, 'en');
    expect(settings.storageWarning, isTrue);
  });
  test(
    'failed onboarding storage permits a truthful session-only exit',
    () async {
      final store = OnboardingWriteFailingStore();
      final settings = await AppSettings.load(store: store);
      await settings.completeOnboarding();
      expect(settings.onboardingComplete, isTrue);
      expect(settings.storageWarning, isTrue);
      expect(store.values.containsKey(AppSettings.onboardingKey), isFalse);
      final nextLaunch = await AppSettings.load(store: store);
      expect(nextLaunch.onboardingComplete, isFalse);
    },
  );
}
