import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

Uri privacyPolicyUri({required bool useChinese}) => Uri.https(
  'www.almanac1.com',
  '/privacy.html',
  <String, String>{'lang': useChinese ? 'zh' : 'en'},
);

Future<bool> openPrivacyPolicy({required bool useChinese}) async {
  try {
    return await launchUrl(
      privacyPolicyUri(useChinese: useChinese),
      mode: LaunchMode.inAppBrowserView,
    );
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
