abstract final class AppLinks {
  static const String _privacyPolicyUrl = String.fromEnvironment(
    'PACEJAR_PRIVACY_POLICY_URL',
  );

  static Uri? privacyPolicyUriFor(
    String languageCode, {
    String? configuredUrl,
  }) {
    final rawUrl = (configuredUrl ?? _privacyPolicyUrl).trim();
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;

    return uri.replace(
      queryParameters: <String, String>{
        ...uri.queryParameters,
        'lang': languageCode == 'zh' ? 'zh' : 'en',
      },
    );
  }
}
