class AppLinks {
  const AppLinks._();

  static const String privacyPolicyZhUrl =
      'https://kifxpro.com/privacy.html?lang=zh';
  static const String privacyPolicyEnUrl =
      'https://kifxpro.com/index.html?lang=en';
  static const String supportEmail = '15211857631@163.com';

  static String privacyPolicyUrlFor(String languageCode) =>
      languageCode.toLowerCase().startsWith('zh')
      ? privacyPolicyZhUrl
      : privacyPolicyEnUrl;
}
