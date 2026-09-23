import 'package:flutter/widgets.dart';
import 'package:stmini_flutter/stmini_flutter.dart';
import 'package:trip_cost/core/domain/core_models.dart';

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

Future<void> openPrivacyPolicy(Uri uri, {required String title}) {
  return StminiFlutter.openWeb(uri.toString(), title: title);
}
