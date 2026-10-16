/// Online policy addresses supplied when packaging the app. Empty by default
/// until the policy is published; no placeholder website is contacted.
class PrivacyPolicyConfig {
  const PrivacyPolicyConfig({
    this.chineseUrl = const String.fromEnvironment('READEREDIT_PRIVACY_URL_ZH'),
    this.englishUrl = const String.fromEnvironment('READEREDIT_PRIVACY_URL_EN'),
    this.defaultUrl = const String.fromEnvironment('READEREDIT_PRIVACY_URL'),
  });

  final String chineseUrl;
  final String englishUrl;
  final String defaultUrl;

  Uri? uriForLanguage(String code) {
    final localized = (code == 'zh' ? chineseUrl : englishUrl).trim();
    final value = localized.isEmpty ? defaultUrl.trim() : localized;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return uri;
  }
}
