import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_cost/core/domain/core_models.dart';
import 'package:trip_cost/features/settings/presentation/privacy_policy_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('privacyPolicyUriFor', () {
    test('uses an explicitly selected app language', () {
      expect(
        privacyPolicyUriFor(
          languageMode: AppLanguageMode.simplifiedChinese,
          systemLocale: const Locale('en', 'US'),
        ).toString(),
        'https://tripcost.fit/privacy.html?lang=zh',
      );
      expect(
        privacyPolicyUriFor(
          languageMode: AppLanguageMode.english,
          systemLocale: const Locale('zh', 'CN'),
        ).toString(),
        'https://tripcost.fit/privacy.html?lang=en',
      );
    });

    test('follows the system when there is no explicit language', () {
      expect(
        privacyPolicyUriFor(
          languageMode: AppLanguageMode.system,
          systemLocale: const Locale('zh', 'TW'),
        ).queryParameters['lang'],
        'zh',
      );
      expect(
        privacyPolicyUriFor(
          languageMode: null,
          systemLocale: const Locale('fr', 'FR'),
        ).queryParameters['lang'],
        'en',
      );
    });
  });
}
