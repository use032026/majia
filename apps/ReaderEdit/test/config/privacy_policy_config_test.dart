import 'package:flutter_test/flutter_test.dart';
import 'package:reader_edit/config/privacy_policy_config.dart';

void main() {
  test('unpublished configuration produces no request address', () {
    const config = PrivacyPolicyConfig();
    expect(config.uriForLanguage('zh'), isNull);
    expect(config.uriForLanguage('en'), isNull);
  });

  test('locale chooses its policy without changing the configured query', () {
    const config = PrivacyPolicyConfig(
      chineseUrl: 'https://policy.example.invalid/zh/privacy.html',
      englishUrl:
          'https://policy.example.invalid/en/privacy.html?version=draft',
    );
    expect(config.uriForLanguage('zh')?.path, '/zh/privacy.html');
    expect(
      config.uriForLanguage('en')?.toString(),
      'https://policy.example.invalid/en/privacy.html?version=draft',
    );
  });

  test('shared URL is used only when the localized one is missing', () {
    const config = PrivacyPolicyConfig(
      chineseUrl: 'https://policy.example.invalid/zh.html',
      defaultUrl: 'https://policy.example.invalid/privacy.html',
    );
    expect(config.uriForLanguage('zh')?.path, '/zh.html');
    expect(config.uriForLanguage('en')?.path, '/privacy.html');
  });

  test('invalid and non-HTTPS URLs do not open a web request', () {
    for (final value in [
      'not a URL',
      'http://policy.example.invalid',
      'file:///private/policy.html',
      'https:///policy.html',
    ]) {
      expect(
        PrivacyPolicyConfig(defaultUrl: value).uriForLanguage('en'),
        isNull,
      );
    }
  });
}
