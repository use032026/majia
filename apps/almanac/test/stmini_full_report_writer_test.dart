import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'platform/stmini_full_report_writer.dart';

void main() {
  const nonce = '0123456789abcdef0123456789abcdef';
  late Directory directory;

  setUp(() async {
    // Host-side unit test isolation, not a guessed mobile report location.
    directory = await Directory.systemTemp.createTemp('stmini-report-writer-');
  });
  tearDown(() async => directory.delete(recursive: true));

  test(
    'actual probe, exact reader ack and complete JSON share one writer',
    () async {
      final writer = FullRuntimeReportWriter(directory.path, nonce);
      await writer.prepare();
      final probe = await writer.writeProbe();
      expect(
        jsonDecode(await File('${directory.path}/$probe').readAsString()),
        {'runNonce': nonce, 'probe': true, 'passed': true},
      );
      expect(await File('${directory.path}/$probe.writing').exists(), isFalse);
      await expectLater(writer.writeResult({'passed': true}), throwsStateError);

      var permitted = false;
      final acknowledged = writer.waitForReaderAcknowledgement().then((_) {
        permitted = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(permitted, isFalse);
      await File(
        '${directory.path}/${writer.acknowledgementName}',
      ).writeAsString(nonce, flush: true);
      await acknowledged;
      expect(permitted, isTrue);
      final result = <String, Object?>{
        'passed': true,
        'reports': [
          {
            'miniId': 'synthetic',
            'checks': {'complete': true},
          },
        ],
      };
      final name = await writer.writeResult(result);
      final bytes = await File('${directory.path}/$name').readAsString();
      expect(jsonDecode(bytes), {...result, 'runNonce': nonce});
      expect(await File('${directory.path}/$name.writing').exists(), isFalse);
      await expectLater(
        writer.writeResult({'passed': false}),
        throwsStateError,
      );
      expect(await File('${directory.path}/$name').readAsString(), bytes);
      await expectLater(
        FullRuntimeReportWriter(directory.path, nonce).prepare(),
        throwsStateError,
      );
    },
  );

  test('pre-existing partial is rejected and preserved', () async {
    final writer = FullRuntimeReportWriter(directory.path, nonce);
    final partial = File('${directory.path}/${writer.probeName}.writing');
    await partial.writeAsString('existing-partial', flush: true);
    await expectLater(writer.prepare(), throwsStateError);
    expect(await partial.readAsString(), 'existing-partial');
  });

  test('a newline or wrong nonce does not authorize verification', () async {
    final writer = FullRuntimeReportWriter(directory.path, nonce);
    await writer.prepare();
    await writer.writeProbe();
    await File(
      '${directory.path}/${writer.acknowledgementName}',
    ).writeAsString('$nonce\n', flush: true);
    await expectLater(writer.waitForReaderAcknowledgement(), throwsStateError);
    await expectLater(writer.writeResult({'passed': true}), throwsStateError);
  });
}
