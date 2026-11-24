import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_delta/site_update.dart';

void main() {
  const update = {
    'side': 'B',
    'hasUpdate': true,
    'forceUpdate': true,
    'latestVersion': '1.10.2',
    'downloadUrl': 'https://example.test/app',
    'updateNotes': 'Launch improvements',
  };

  test(
    'posts the installed numeric version and reads all response fields',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final request = server.first.then((request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/_zt/check-update');
        expect(request.headers.contentType?.mimeType, 'application/json');
        final body = await utf8.decoder.bind(request).join();
        expect(jsonDecode(body), {'version': '1.9.0'});
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(update));
        await request.response.close();
      });
      final result = await checkSiteUpdate(
        'v1.9.0-beta+4',
        endpoint: Uri.http('127.0.0.1:${server.port}', '/_zt/check-update'),
      );
      await request;
      expect(result.side, 'B');
      expect(result.hasUpdate, isTrue);
      expect(result.forceUpdate, isTrue);
      expect(result.latestVersion, '1.10.2');
      expect(result.downloadUrl, Uri.https('example.test', '/app'));
      expect(result.updateNotes, 'Launch improvements');
    },
  );

  test('reads a response with only a side configured', () {
    final result = SiteUpdate.fromJson({
      'side': 'A',
      'hasUpdate': false,
      'forceUpdate': false,
      'latestVersion': null,
      'downloadUrl': null,
      'updateNotes': null,
    });
    expect(result.side, 'A');
    expect(result.hasUpdate, isFalse);
    expect(result.downloadUrl, isNull);
  });

  test('rejects invalid versions and update links', () async {
    await expectLater(checkSiteUpdate('2147483648.1'), throwsFormatException);
    expect(
      () => SiteUpdate.fromJson({
        ...update,
        'downloadUrl': 'http://example.test/app',
      }),
      throwsFormatException,
    );
  });

  test('a disabled endpoint reports a failure', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final request = server.first.then((request) async {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });
    await expectLater(
      checkSiteUpdate(
        '1.0.0',
        endpoint: Uri.http('127.0.0.1:${server.port}', '/_zt/check-update'),
      ),
      throwsA(isA<HttpException>()),
    );
    await request;
  });
}
