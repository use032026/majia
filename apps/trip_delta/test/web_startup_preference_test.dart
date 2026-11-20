import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_delta/web_startup_preference.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('trip_web_preference_');
  });
  tearDown(() async => directory.delete(recursive: true));

  test(
    'absent preference defaults off and enabling survives a new instance',
    () async {
      final preference = FileWebStartupPreference(directory: directory);
      expect(await preference.readEnabled(), isFalse);
      await preference.saveEnabled();
      expect(
        await FileWebStartupPreference(directory: directory).readEnabled(),
        isTrue,
      );
      expect(directory.listSync().map((entry) => entry.path.split('/').last), [
        FileWebStartupPreference.fileName,
      ]);
    },
  );

  test('strict schema corruption and nonboolean values fail closed', () async {
    final preference = FileWebStartupPreference(directory: directory);
    final file = File('${directory.path}/${FileWebStartupPreference.fileName}');
    for (final invalid in [
      '{broken',
      'true',
      'null',
      '{}',
      '{"schemaVersion":1,"enabled":"true"}',
      '{"schemaVersion":1.0,"enabled":true}',
      '{"schemaVersion":2,"enabled":true}',
      '{"schemaVersion":1,"enabled":true,"extra":1}',
      '{"schemaVersion":1,"enabled":false}',
    ]) {
      await file.writeAsString(invalid);
      expect(await preference.readEnabled(), isFalse, reason: invalid);
    }
  });

  test('read errors default off and save errors do not claim opt-in', () async {
    final blocked = File('${directory.path}/not_a_directory');
    await blocked.writeAsString('keep this file');
    final preference = FileWebStartupPreference(
      directory: Directory(blocked.path),
    );
    expect(await preference.readEnabled(), isFalse);
    await expectLater(
      preference.saveEnabled(),
      throwsA(isA<FileSystemException>()),
    );
    expect(await blocked.readAsString(), 'keep this file');
  });

  test('atomic replacement preserves separate trip and backup data', () async {
    final trip = File('${directory.path}/trip_delta_v1.json');
    await trip.writeAsString('existing trip bytes');
    final preference = FileWebStartupPreference(directory: directory);
    await preference.saveEnabled();
    await preference.saveEnabled();
    expect(await preference.readEnabled(), isTrue);
    expect(await trip.readAsString(), 'existing trip bytes');
    expect(
      directory.listSync().where((entry) => entry.path.contains('.pending.')),
      isEmpty,
    );
  });
}
