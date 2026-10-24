import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const _privacyPolicyChannel = MethodChannel('com.almanac.lite/privacy_policy');

Uri privacyPolicyUri({required bool useChinese}) => Uri.https(
  'www.almanac1.com',
  '/privacy.html',
  <String, String>{'lang': useChinese ? 'zh' : 'en'},
);

Future<bool> openPrivacyPolicy({required bool useChinese}) async {
  try {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return await _privacyPolicyChannel
              .invokeMethod<bool>('openPrivacyPolicy', {
                'url': privacyPolicyUri(useChinese: useChinese).toString(),
                'chinese': useChinese,
              }) ??
          false;
    }
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
