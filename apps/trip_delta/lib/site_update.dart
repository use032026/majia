import 'dart:convert';
import 'dart:io';

class SiteUpdate {
  const SiteUpdate({
    required this.side,
    required this.hasUpdate,
    required this.forceUpdate,
    this.latestVersion,
    this.downloadUrl,
    this.updateNotes,
  });

  final String side;
  final bool hasUpdate;
  final bool forceUpdate;
  final String? latestVersion;
  final Uri? downloadUrl;
  final String? updateNotes;

  factory SiteUpdate.fromJson(Object? json) {
    if (json case {
      'side': final String side,
      'hasUpdate': final bool hasUpdate,
      'forceUpdate': final bool forceUpdate,
      'latestVersion': final String? latestVersion,
      'downloadUrl': final String? downloadUrl,
      'updateNotes': final String? updateNotes,
    }) {
      final url = downloadUrl == null ? null : Uri.tryParse(downloadUrl);
      final validVersion =
          latestVersion == null || _isNumericVersion(latestVersion);
      final validUrl =
          url == null ||
          (url.scheme == 'https' &&
              url.host.isNotEmpty &&
              url.userInfo.isEmpty);
      if ((side == 'A' || side == 'B') &&
          validVersion &&
          validUrl &&
          (hasUpdate
              ? latestVersion != null && url != null
              : !forceUpdate && downloadUrl == null && updateNotes == null)) {
        return SiteUpdate(
          side: side,
          hasUpdate: hasUpdate,
          forceUpdate: forceUpdate,
          latestVersion: latestVersion,
          downloadUrl: url,
          updateNotes: updateNotes,
        );
      }
    }
    throw const FormatException('Invalid site update response');
  }
}

final _versionPattern = RegExp(r'^[0-9]+(?:\.[0-9]+){0,3}$');
final _installedVersionPattern = RegExp(
  r'^v?([0-9]+(?:\.[0-9]+){0,3})(?:[-+][0-9A-Za-z.+-]+)?$',
);

bool _isNumericVersion(String version) =>
    _versionPattern.hasMatch(version) &&
    version
        .split('.')
        .every((part) => (int.tryParse(part) ?? 2147483648) <= 2147483647);

Future<SiteUpdate> checkSiteUpdate(
  String installedVersion, {
  Uri? endpoint,
}) async {
  final version = _installedVersionPattern
      .firstMatch(installedVersion)
      ?.group(1);
  if (version == null || !_isNumericVersion(version)) {
    throw const FormatException('Invalid installed app version');
  }

  const timeout = Duration(seconds: 6);
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    return await _requestUpdate(
      client,
      endpoint ?? Uri.https('gotripdelta.com', '/_zt/check-update'),
      version,
    ).timeout(timeout);
  } finally {
    client.close(force: true);
  }
}

Future<SiteUpdate> _requestUpdate(
  HttpClient client,
  Uri endpoint,
  String version,
) async {
  final request = await client.postUrl(endpoint);
  request.followRedirects = false;
  request.headers.contentType = ContentType.json;
  request.headers.set(HttpHeaders.acceptHeader, 'application/json');
  request.write(jsonEncode({'version': version}));
  final response = await request.close();
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException('Update check returned HTTP ${response.statusCode}');
  }
  final bytes = <int>[];
  await for (final chunk in response) {
    if (bytes.length + chunk.length > 64 * 1024) {
      throw const FormatException('Site update response is too large');
    }
    bytes.addAll(chunk);
  }
  return SiteUpdate.fromJson(jsonDecode(utf8.decode(bytes)));
}
