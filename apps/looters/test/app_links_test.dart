import 'package:flutter_test/flutter_test.dart';
import 'package:pace_jar/config/app_links.dart';

void main() {
  test('privacy URL requires a complete HTTPS link', () {
    expect(AppLinks.privacyPolicyUriFor('zh', configuredUrl: ''), isNull);
    expect(
      AppLinks.privacyPolicyUriFor(
        'zh',
        configuredUrl: 'http://example.com/privacy',
      ),
      isNull,
    );
  });

  test('privacy URL preserves query values and adds the app language', () {
    final uri = AppLinks.privacyPolicyUriFor(
      'en',
      configuredUrl: 'https://example.com/privacy.html?source=app',
    );

    expect(uri, isNotNull);
    expect(uri!.queryParameters['source'], 'app');
    expect(uri.queryParameters['lang'], 'en');
  });
}
