import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refqo/domain.dart';
import 'package:refqo/storage.dart';

void main() {
  test('interrupted export cleanup removes only owned backup files', () async {
    final dir = await Directory.systemTemp.createTemp('refqo-cache-');
    try {
      final owned = File('${dir.path}/refqo-backup-123.json');
      final other = File('${dir.path}/personal.json');
      await owned.writeAsString('private library');
      await other.writeAsString('keep');
      await cleanTemporaryBackups(dir);
      expect(await owned.exists(), false);
      expect(await other.readAsString(), 'keep');
    } finally {
      await dir.delete(recursive: true);
    }
  });

  late Directory directory;
  late FileRepository repository;
  final initial = AppData(
    supplies: const [Supply(id: 'a', name: 'Refill', stock: 1)],
  );
  final next = receiveSupply(initial, 'a', 2, DateTime.utc(2026, 10, 21));
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('refqo_repository_test_');
    repository = FileRepository(directory);
  });
  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'first load is empty; save reloads and retains the prior snapshot',
    () async {
      expect((await repository.load()).supplies, isEmpty);
      await repository.save(initial);
      expect(
        encodeAppData(await FileRepository(directory).load()),
        encodeAppData(initial),
      );
      await repository.save(next);
      expect(
        encodeAppData(await FileRepository(directory).load()),
        encodeAppData(next),
      );
      expect(
        encodeAppData(await repository.loadPrevious()),
        encodeAppData(initial),
      );
      expect(await File('${directory.path}/refqo.next.json').exists(), isFalse);
    },
  );
  test('invalid save does not change primary or previous', () async {
    await repository.save(initial);
    await repository.save(next);
    final before = await File(repository.primaryPath).readAsString();
    final previous = await File(repository.previousPath).readAsString();
    await expectLater(
      repository.save(initial.copyWith(language: 'bad')),
      throwsStateError,
    );
    expect(await File(repository.primaryPath).readAsString(), before);
    expect(await File(repository.previousPath).readAsString(), previous);
  });
  test(
    'failure before atomic rename leaves primary readable and caller state unchanged',
    () async {
      await repository.save(initial);
      await Directory(repository.previousPath).create();
      await expectLater(
        repository.save(next),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        encodeAppData(await FileRepository(directory).load()),
        encodeAppData(initial),
      );
      expect(initial.supplies.single.stock, 1);
    },
  );
  test(
    'corrupt primary never silently falls back; normal save locks until explicit restore',
    () async {
      await repository.save(initial);
      await repository.save(next);
      await File(repository.primaryPath).writeAsString('{broken', flush: true);
      final reopened = FileRepository(directory);
      await expectLater(reopened.load(), throwsStateError);
      await expectLater(reopened.save(next), throwsStateError);
      expect(
        encodeAppData(await reopened.loadPrevious()),
        encodeAppData(initial),
      );
      await reopened.restore(await reopened.loadPrevious());
      expect(encodeAppData(await reopened.load()), encodeAppData(initial));
      expect(await File(reopened.rejectedPath).readAsString(), '{broken');
      expect(
        encodeAppData(await reopened.loadPrevious()),
        encodeAppData(initial),
      );
      await reopened.save(next);
      expect((await reopened.load()).supplies.single.stock, 3);
    },
  );
  test(
    'missing primary with previous or interrupted initial write requires recovery',
    () async {
      await repository.save(initial);
      await repository.save(next);
      await File(repository.primaryPath).delete();
      await expectLater(FileRepository(directory).load(), throwsStateError);
      await File(repository.previousPath).delete();
      await File(
        '${directory.path}/refqo.next.json',
      ).writeAsString(encodeAppData(initial));
      await expectLater(FileRepository(directory).load(), throwsStateError);
    },
  );
  test(
    'restore preserves current valid snapshot and malformed import changes nothing',
    () async {
      await repository.save(initial);
      await repository.restore(next);
      expect(
        encodeAppData(await repository.loadPrevious()),
        encodeAppData(initial),
      );
      expect(() => decodeAppData('[]'), throwsStateError);
      expect(encodeAppData(await repository.load()), encodeAppData(next));
    },
  );
  test(
    'file size and invalid UTF-8 are rejected before JSON loading',
    () async {
      await File(repository.primaryPath).writeAsBytes([0xff, 0xfe]);
      await expectLater(repository.load(), throwsStateError);
      await File(
        repository.primaryPath,
      ).writeAsBytes(List.filled(maxBackupBytes + 1, 32));
      await expectLater(FileRepository(directory).load(), throwsStateError);
    },
  );
  test(
    'erase clears all managed recovery snapshots and permits clean relaunch',
    () async {
      await repository.save(initial);
      await repository.save(next);
      await File(repository.rejectedPath).writeAsString('old private data');
      await repository.erase(AppData(onboarded: true, language: 'zh'));
      final data = await FileRepository(directory).load();
      expect(data.supplies, isEmpty);
      expect(data.slots, isEmpty);
      expect(data.events, isEmpty);
      expect(data.onboarded, isTrue);
      expect(await File(repository.previousPath).exists(), isFalse);
      expect(await File(repository.rejectedPath).exists(), isFalse);
      await expectLater(repository.erase(initial), throwsStateError);
    },
  );
  test(
    'injected persistence failure leaves MemoryRepository unchanged and retry works',
    () async {
      final memory = MemoryRepository(initial)..failNextSave = true;
      await expectLater(memory.save(next), throwsA(isA<FileSystemException>()));
      expect(identical(await memory.load(), initial), isTrue);
      await memory.save(next);
      expect((await memory.load()).supplies.single.stock, 3);
    },
  );
}
