import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:trip_cost/core/domain/core_models.dart';
import 'package:url_launcher/url_launcher.dart';

const _privacyPolicyHost = 'tripcost.fit';
const _privacyPolicyPath = '/privacy.html';

Uri privacyPolicyUriFor({
  required AppLanguageMode? languageMode,
  required Locale systemLocale,
}) {
  final systemLanguage = systemLocale.languageCode.toLowerCase() == 'zh'
      ? 'zh'
      : 'en';
  final language = switch (languageMode) {
    AppLanguageMode.simplifiedChinese => 'zh',
    AppLanguageMode.english => 'en',
    AppLanguageMode.system || null => systemLanguage,
  };
  return Uri.https(_privacyPolicyHost, _privacyPolicyPath, <String, String>{
    'lang': language,
  });
}

Future<void> openPrivacyPolicy(Uri uri) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    final opened = await const MethodChannel('trip_cost/privacy_policy')
        .invokeMethod<bool>('openPrivacyPolicy', {
          'url': uri.toString(),
          'chinese': uri.queryParameters['lang'] == 'zh',
        });
    if (opened != true) {
      throw PlatformException(code: 'privacy_policy_unavailable');
    }
    return;
  }
  await launchUrl(
    uri,
    mode: LaunchMode.inAppBrowserView,
    browserConfiguration: const BrowserConfiguration(showTitle: true),
  );
}
