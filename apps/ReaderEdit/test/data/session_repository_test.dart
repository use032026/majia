import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_edit/data/session_repository.dart';
import 'package:reader_edit/domain/novel.dart';
import 'package:reader_edit/domain/revision_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

RevisionSession _session(String id, String title) => RevisionSession(
  id: id,
  title: title,
  knowPromise: 'know',
  feelPromise: 'feel',
  wonderPromise: 'wonder',
  passages: [PassageRevision(id: '${id}_p', original: 'One.', revised: 'One.')],
  updatedAt: DateTime.utc(2026, 9, 30),
);

String _envelope(List<RevisionSession> sessions) => jsonEncode({
  'schemaVersion': 1,
  'sessions': sessions.map((session) => session.toJson()).toList(),
});

Novel _novel(String id, String title) => Novel(
  id: id,
  title: title,
  description: '',
  chapters: const [],
  createdAt: DateTime.utc(2026, 9, 30),
  updatedAt: DateTime.utc(2026, 9, 30),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late JsonFileSessionRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('reader_edit_test_');
    repository = JsonFileSessionRepository(
      directory: directory,
      preferences: await SharedPreferences.getInstance(),
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('fresh install loads empty and accepts the first write', () async {
    final result = await repository.loadSessions();

    expect(result.sessions, isEmpty);
    await repository.saveSessions([_session('first', 'First')]);
    expect((await repository.loadSessions()).sessions.single.id, 'first');
  });

  test('migrates schema v1 and round-trips novels in schema v2', () async {
    await File(
      '${directory.path}/reader_edit_sessions_v1.json',
    ).writeAsString(_envelope([_session('legacy', 'Legacy')]));

    final legacy = await repository.loadSessions();
    expect(legacy.sessions.single.id, 'legacy');
    expect(legacy.novels, isEmpty);

    await repository.saveSessions(
      legacy.sessions,
      novels: [_novel('novel', 'Novel')],
    );
    final migrated = await repository.loadSessions();
    expect(migrated.sessions.single.id, 'legacy');
    expect(migrated.novels.single.title, 'Novel');
  });

  test(
    'recovers the prior valid snapshot when primary JSON is invalid',
    () async {
      await repository.saveSessions([_session('one', 'First')]);
      await repository.saveSessions([_session('two', 'Second')]);
      await File(
        '${directory.path}/reader_edit_sessions_v1.json',
      ).writeAsString('{broken', flush: true);

      final result = await repository.loadSessions();
      expect(result.recoveredFromBackup, isTrue);
      expect(result.sessions.single.title, 'First');
    },
  );

  test('does not overwrite a valid backup after recovery', () async {
    await repository.saveSessions([_session('one', 'First')]);
    await repository.saveSessions([_session('two', 'Second')]);
    final primary = File('${directory.path}/reader_edit_sessions_v1.json');
    await primary.writeAsString('{broken', flush: true);

    expect((await repository.loadSessions()).sessions.single.id, 'one');
    await repository.saveSessions([_session('three', 'Third')]);
    await primary.writeAsString('{broken again', flush: true);

    final relaunched = JsonFileSessionRepository(
      directory: directory,
      preferences: await SharedPreferences.getInstance(),
    );
    final recovered = await relaunched.loadSessions();
    expect(recovered.sessions.single.id, 'one');
  });

  test(
    'uses a fully flushed pending snapshot when both snapshots are invalid',
    () async {
      await File(
        '${directory.path}/reader_edit_sessions_v1.json',
      ).writeAsString('{broken', flush: true);
      await File(
        '${directory.path}/reader_edit_sessions_backup_v1.json',
      ).writeAsString('{also broken', flush: true);
      await File(
        '${directory.path}/reader_edit_sessions_pending_v1.json',
      ).writeAsString(_envelope([_session('pending', 'Pending')]), flush: true);

      final result = await repository.loadSessions();
      expect(result.recoveredFromBackup, isTrue);
      expect(result.sessions.single.id, 'pending');
    },
  );

  test(
    'single-session deletion cannot be resurrected from recovery files',
    () async {
      await repository.saveSessions([
        _session('keep', 'Keep'),
        _session('delete', 'Delete'),
      ]);
      await repository.saveSessions([
        _session('keep', 'Keep'),
      ], retainPrevious: false);

      final primary = File('${directory.path}/reader_edit_sessions_v1.json');
      await primary.writeAsString('{broken', flush: true);
      final recovered = await repository.loadSessions();
      expect(recovered.sessions.map((session) => session.id), ['keep']);

      for (final file in directory.listSync().whereType<File>()) {
        expect(await file.readAsString(), isNot(contains('delete')));
      }
    },
  );

  test(
    'clear-all recovery snapshot stays empty after primary corruption',
    () async {
      await repository.saveSessions([_session('delete', 'Delete')]);
      await repository.saveSessions(const [], retainPrevious: false);
      await File(
        '${directory.path}/reader_edit_sessions_v1.json',
      ).writeAsString('{broken', flush: true);

      final recovered = await repository.loadSessions();
      expect(recovered.sessions, isEmpty);
    },
  );
}
