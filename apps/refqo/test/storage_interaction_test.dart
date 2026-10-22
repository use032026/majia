import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:refqo/domain.dart';
import 'package:refqo/storage.dart';

void main() {
  test(
    'directory resolution fails visibly and a later load can retry',
    () async {
      final dir = await Directory.systemTemp.createTemp('refqo-lazy-');
      var calls = 0;
      final repo = FileRepository.lazy(() async {
        calls++;
        if (calls == 1) {
          throw const FileSystemException('support path unavailable');
        }
        return dir;
      });
      try {
        await expectLater(repo.load(), throwsA(isA<FileSystemException>()));
        final loaded = await repo.load();
        expect(loaded.supplies, isEmpty);
        await repo.save(AppData(onboarded: true));
        expect((await FileRepository(dir).load()).onboarded, true);
        expect(calls, 2);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'cleanup failure reports committed erasure, attempts all copies and permits retry',
    () async {
      final dir = await Directory.systemTemp.createTemp('refqo-erase-');
      var fail = true;
      final attempted = <String>[];
      final repo = FileRepository(
        dir,
        deleteManagedFile: (file) async {
          attempted.add(file.path);
          if (fail && file.path.endsWith('previous.json')) {
            throw const FileSystemException('locked');
          }
          await file.delete();
        },
      );
      try {
        await repo.save(
          AppData(
            supplies: const [Supply(id: 'a', name: '中文耗材')],
          ),
        );
        await repo.save(
          AppData(
            supplies: const [Supply(id: 'b', name: '另一种耗材')],
          ),
        );
        await expectLater(
          repo.erase(AppData(onboarded: true)),
          throwsA(isA<EraseCleanupException>()),
        );
        expect((await FileRepository(dir).load()).supplies, isEmpty);
        expect(await File(repo.previousPath).exists(), true);
        expect(await File(repo.rejectedPath).exists(), false);
        expect(attempted.length, greaterThanOrEqualTo(2));
        fail = false;
        await repo.erase(AppData(onboarded: true));
        expect(await File(repo.previousPath).exists(), false);
        expect((await FileRepository(dir).load()).supplies, isEmpty);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
}
