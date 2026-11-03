import 'package:flutter/widgets.dart';
import 'package:trip_cost/core/domain/core_models.dart';
import 'package:trip_cost/core/platform/app_web_launcher.dart';

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

Future<void> openPrivacyPolicy(Uri uri) => appWebLauncher.open(
  uri,
  title: uri.queryParameters['lang'] == 'zh' ? '隐私政策' : 'Privacy policy',
  showNavigationBar: false,
);
