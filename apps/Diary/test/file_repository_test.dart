import 'dart:convert';
import 'dart:io';

import 'package:diary/data/diary_repository.dart';
import 'package:diary/domain/diary_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_repository.dart';

void main() {
  late Directory directory;
  late FileDiaryRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('echo_page_test_');
    repository = FileDiaryRepository(directory);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('missing files load an empty snapshot', () async {
    final result = await repository.load();

    expect(result.snapshot.entries, isEmpty);
    expect(result.recoveredFromBackup, isFalse);
  });

  test('save and load preserve local diary data', () async {
    final snapshot = DiarySnapshot(entries: <DiaryEntry>[sampleEntry()]);

    await repository.save(snapshot);
    final result = await repository.load();

    expect(result.snapshot.entries.single.id, 'entry-1');
    expect(
      await File(
        '${directory.path}/${FileDiaryRepository.pendingFileName}',
      ).exists(),
      isFalse,
    );
  });

  test('corrupt current file recovers the last readable backup', () async {
    final first = DiarySnapshot(
      entries: <DiaryEntry>[sampleEntry(id: 'first')],
    );
    final second = DiarySnapshot(
      entries: <DiaryEntry>[sampleEntry(id: 'second')],
    );
    await repository.save(first);
    await repository.save(second);
    await File(
      '${directory.path}/${FileDiaryRepository.dataFileName}',
    ).writeAsString('{not valid json');

    final result = await repository.load();

    expect(result.recoveredFromBackup, isTrue);
    expect(result.snapshot.entries.single.id, 'first');
  });

  test('semantically invalid current file recovers a valid backup', () async {
    final first = DiarySnapshot(
      entries: <DiaryEntry>[sampleEntry(id: 'valid-backup')],
    );
    final second = DiarySnapshot(
      entries: <DiaryEntry>[sampleEntry(id: 'invalid-current')],
    );
    await repository.save(first);
    await repository.save(second);
    final invalid = second.toJson();
    final entry = Map<String, Object?>.from(
      (invalid['entries']! as List<Object?>).single! as Map,
    );
    entry['futureQuestion'] = '   ';
    entry['revisitAt'] = null;
    invalid['entries'] = <Object?>[entry];
    await File(
      '${directory.path}/${FileDiaryRepository.dataFileName}',
    ).writeAsString(jsonEncode(invalid));

    final result = await repository.load();

    expect(result.recoveredFromBackup, isTrue);
    expect(result.snapshot.entries.single.id, 'valid-backup');
  });

  test(
    'first save after recovery preserves the last known-good backup',
    () async {
      final first = DiarySnapshot(
        entries: <DiaryEntry>[sampleEntry(id: 'known-good')],
      );
      final second = DiarySnapshot(
        entries: <DiaryEntry>[sampleEntry(id: 'newer')],
      );
      final third = DiarySnapshot(
        entries: <DiaryEntry>[sampleEntry(id: 'after-recovery')],
      );
      await repository.save(first);
      await repository.save(second);
      final current = File(
        '${directory.path}/${FileDiaryRepository.dataFileName}',
      );
      await current.writeAsString('corrupt current');
      expect(
        (await repository.load()).snapshot.entries.single.id,
        'known-good',
      );

      await repository.save(third);
      await current.writeAsString('corrupt again');
      final recoveredAgain = await repository.load();

      expect(recoveredAgain.recoveredFromBackup, isTrue);
      expect(recoveredAgain.snapshot.entries.single.id, 'known-good');
    },
  );

  test(
    'discard-history save removes deleted content from app backup',
    () async {
      final first = DiarySnapshot(
        entries: <DiaryEntry>[sampleEntry(id: 'private-old')],
      );
      final second = DiarySnapshot(
        entries: <DiaryEntry>[sampleEntry(id: 'private-new')],
      );
      await repository.save(first);
      await repository.save(second);

      await repository.save(const DiarySnapshot.empty(), discardHistory: true);

      final result = await repository.load();
      expect(result.snapshot.entries, isEmpty);
      final backupRepository = FileDiaryRepository(directory);
      await File(
        '${directory.path}/${FileDiaryRepository.dataFileName}',
      ).writeAsString('corrupt current');
      final backupResult = await backupRepository.load();
      expect(backupResult.recoveredFromBackup, isTrue);
      expect(backupResult.snapshot.entries, isEmpty);
    },
  );

  test(
    'failed purge backup replacement rolls current back without data loss',
    () async {
      var failNextBackupReplace = false;
      final injected = FileDiaryRepository(
        directory,
        renamer: (source, targetPath) async {
          if (failNextBackupReplace &&
              targetPath.endsWith(FileDiaryRepository.backupFileName)) {
            failNextBackupReplace = false;
            throw const FileSystemException('injected backup replace failure');
          }
          return source.rename(targetPath);
        },
      );
      final first = DiarySnapshot(
        entries: <DiaryEntry>[sampleEntry(id: 'older-readable')],
      );
      final second = DiarySnapshot(
        entries: <DiaryEntry>[sampleEntry(id: 'current-readable')],
      );
      await injected.save(first);
      await injected.save(second);
      failNextBackupReplace = true;

      await expectLater(
        injected.save(const DiarySnapshot.empty(), discardHistory: true),
        throwsA(isA<FileSystemException>()),
      );

      final currentResult = await FileDiaryRepository(directory).load();
      expect(currentResult.snapshot.entries.single.id, 'current-readable');
      await File(
        '${directory.path}/${FileDiaryRepository.dataFileName}',
      ).writeAsString('corrupt current');
      final backupResult = await FileDiaryRepository(directory).load();
      expect(backupResult.snapshot.entries.single.id, 'older-readable');
    },
  );

  test(
    'failed purge current replacement restores the previous backup',
    () async {
      var failNextCurrentReplace = false;
      final injected = FileDiaryRepository(
        directory,
        renamer: (source, targetPath) async {
          if (failNextCurrentReplace &&
              targetPath.endsWith(FileDiaryRepository.dataFileName)) {
            failNextCurrentReplace = false;
            throw const FileSystemException('injected current replace failure');
          }
          return source.rename(targetPath);
        },
      );
      final first = DiarySnapshot(
        entries: <DiaryEntry>[sampleEntry(id: 'older-readable')],
      );
      final second = DiarySnapshot(
        entries: <DiaryEntry>[sampleEntry(id: 'current-readable')],
      );
      await injected.save(first);
      await injected.save(second);
      failNextCurrentReplace = true;

      await expectLater(
        injected.save(const DiarySnapshot.empty(), discardHistory: true),
        throwsA(isA<FileSystemException>()),
      );

      expect(
        (await FileDiaryRepository(
          directory,
        ).load()).snapshot.entries.single.id,
        'current-readable',
      );
      await File(
        '${directory.path}/${FileDiaryRepository.dataFileName}',
      ).writeAsString('corrupt current');
      expect(
        (await FileDiaryRepository(
          directory,
        ).load()).snapshot.entries.single.id,
        'older-readable',
      );
    },
  );

  test(
    'unreadable current and backup lock recovery instead of clearing',
    () async {
      await directory.create(recursive: true);
      await File(
        '${directory.path}/${FileDiaryRepository.dataFileName}',
      ).writeAsString('bad');
      await File(
        '${directory.path}/${FileDiaryRepository.backupFileName}',
      ).writeAsString('also bad');

      await expectLater(repository.load(), throwsA(isA<DiaryDataException>()));
    },
  );
}
