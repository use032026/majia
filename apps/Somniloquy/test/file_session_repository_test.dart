import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:somniloquy/data/session_repository.dart';
import 'package:somniloquy/domain/models.dart';

void main() {
  test(
    'persists, reloads, and deletes the manifest and managed audio',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'somniloquy_repository_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final repository = FileSessionRepository.forRoot(root);
      final audioPath = await repository.createAudioPath('night_1');
      await File(audioPath).writeAsBytes([1, 2, 3], flush: true);
      final session = NightSession(
        id: 'night_1',
        startedAt: DateTime(2026, 10, 8, 23),
        endedAt: DateTime(2026, 10, 9, 7),
        audioPath: audioPath,
        prompt: 'remember',
        contextTags: const ['travel'],
        moments: const [],
        morningNote: 'train',
        isReviewed: true,
      );

      await repository.saveSession(session);
      await repository.saveLocale('en');
      await repository.saveOnboardingCompleted(true);
      final reloaded = FileSessionRepository.forRoot(root);
      final state = await reloaded.load();
      expect(state.localeCode, 'en');
      expect(state.hasCompletedOnboarding, isTrue);
      expect(state.sessions.single.morningNote, 'train');
      expect(await reloaded.audioExists(audioPath), isTrue);

      await reloaded.deleteSession('night_1');
      final afterDelete = await FileSessionRepository.forRoot(root).load();
      expect(afterDelete.sessions, isEmpty);
      expect(afterDelete.hasCompletedOnboarding, isTrue);
      expect(await reloaded.audioExists(audioPath), isFalse);
    },
  );

  test('discarding an interrupted marker removes its partial audio', () async {
    final root = await Directory.systemTemp.createTemp('somniloquy_marker_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final repository = FileSessionRepository.forRoot(root);
    final audioPath = await repository.createAudioPath('partial');
    await File(audioPath).writeAsBytes([1], flush: true);
    await repository.markRecordingStarted(
      RecordingMarker(
        id: 'partial',
        startedAt: DateTime(2026, 10, 8, 23),
        audioPath: audioPath,
        prompt: '',
        contextTags: const [],
      ),
    );

    await repository.discardRecordingMarker();
    final state = await FileSessionRepository.forRoot(root).load();
    expect(state.recordingMarker, isNull);
    expect(await repository.audioExists(audioPath), isFalse);
  });

  test(
    'audio deletion failure retains the index so deletion can be retried',
    () async {
      final root = await Directory.systemTemp.createTemp('somniloquy_retry_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      var failDeletion = true;
      final repository = FileSessionRepository.forRoot(
        root,
        audioDeleter: (path) async {
          if (failDeletion) throw StateError('delete failed');
          final file = File(path);
          if (await file.exists()) await file.delete();
        },
      );
      final audioPath = await repository.createAudioPath('retry');
      await File(audioPath).writeAsBytes([1], flush: true);
      await repository.saveSession(
        NightSession(
          id: 'retry',
          startedAt: DateTime(2026, 10, 8, 23),
          endedAt: DateTime(2026, 10, 9, 7),
          audioPath: audioPath,
          prompt: '',
          contextTags: const [],
          moments: const [],
        ),
      );

      await expectLater(repository.deleteSession('retry'), throwsStateError);
      final afterFailure = await FileSessionRepository.forRoot(root).load();
      expect(afterFailure.sessions.single.id, 'retry');
      expect(await repository.audioExists(audioPath), isTrue);

      failDeletion = false;
      await repository.deleteSession('retry');
      final afterRetry = await FileSessionRepository.forRoot(root).load();
      expect(afterRetry.sessions, isEmpty);
      expect(await repository.audioExists(audioPath), isFalse);
    },
  );
}
