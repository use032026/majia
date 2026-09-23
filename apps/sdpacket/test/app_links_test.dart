import 'package:flutter_test/flutter_test.dart';
import 'package:moving_box/config/app_links.dart';

void main() {
  test('privacy policy URL follows the selected app language', () {
    expect(
      AppLinks.privacyPolicyUrlFor('zh'),
      'https://kifxpro.com/privacy.html?lang=zh',
    );
    expect(
      AppLinks.privacyPolicyUrlFor('en'),
      'https://kifxpro.com/index.html?lang=en',
    );
  });

  test('public support email is configured', () {
    expect(AppLinks.supportEmail, '15211857631@163.com');
  });
}
