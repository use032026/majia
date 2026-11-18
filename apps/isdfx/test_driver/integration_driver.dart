import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final path =
        Platform.environment['ID_FIXTURE_INTEGRATION_REPORT'] ??
        'artifacts/android-integration-response.json';
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data ?? <String, dynamic>{}),
      flush: true,
    );
  },
);
