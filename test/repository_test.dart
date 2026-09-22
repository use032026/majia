import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:steady21/domain.dart';
import 'package:steady21/repository.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('steady21_test_');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('repository persists and restores a snapshot', () async {
    final repository = JsonFileRepository(
      directoryProvider: () async => directory,
    );
    final snapshot = AppSnapshot(
      localeCode: 'en',
      experiments: [
        Experiment(
          id: 'e1',
          title: 'Stretch',
          cue: 'After waking',
          fullAction: 'Stretch 10 minutes',
          minimumAction: 'Stretch once',
          targetDays: 21,
          startedAt: DateTime(2026, 9, 22),
          entries: const [
            DailyEntry(date: '2026-09-22', kind: EntryKind.minimum),
          ],
        ),
      ],
    );
    await repository.save(snapshot);
    final restored = await repository.load();
    expect(restored.localeCode, 'en');
    expect(restored.active?.entries.single.kind, EntryKind.minimum);
    expect(await File('${directory.path}/steady21.json.tmp').exists(), isFalse);
  });

  test('malformed JSON fails without overwriting the source', () async {
    final file = File('${directory.path}/steady21.json');
    await file.writeAsString('{bad json');
    final repository = JsonFileRepository(
      directoryProvider: () async => directory,
    );
    await expectLater(repository.load(), throwsFormatException);
    expect(await file.readAsString(), '{bad json');
  });

  test('missing file uses the supported system-language default', () async {
    final repository = JsonFileRepository(
      directoryProvider: () async => directory,
      defaultLocaleCode: 'en',
    );
    final snapshot = await repository.load();
    expect(snapshot.experiments, isEmpty);
    expect(snapshot.localeCode, 'en');
  });
}
