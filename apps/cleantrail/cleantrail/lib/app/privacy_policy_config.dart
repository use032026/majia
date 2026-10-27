const privacyPolicyUrl = String.fromEnvironment(
  'PRIVACY_POLICY_URL',
  defaultValue: '',
);

Uri? privacyPolicyUri({
  String url = privacyPolicyUrl,
  required bool useChinese,
}) {
  final value = url.trim();
  if (value.isEmpty || RegExp(r'\s').hasMatch(value)) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri.replace(
    queryParameters: {
      ...uri.queryParametersAll,
      'lang': useChinese ? 'zh' : 'en',
    },
  );
}
