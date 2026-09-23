import 'package:flutter/services.dart';
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

  test('opens the policy in the native STMini web container', () async {
    const channel = MethodChannel('stmini_flutter/methods');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final uri = Uri.parse('https://tripcost.fit/privacy.html?lang=en');

    await openPrivacyPolicy(uri, title: 'Privacy policy');

    expect(calls, hasLength(1));
    expect(calls.single.method, 'openWeb');
    expect(calls.single.arguments, <String, Object>{
      'url': 'https://tripcost.fit/privacy.html?lang=en',
      'title': 'Privacy policy',
      'showNavigationBar': true,
    });
  });
}
