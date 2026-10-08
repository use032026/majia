import 'package:flutter_test/flutter_test.dart';
import 'package:somniloquy/controllers/app_controller.dart';
import 'package:somniloquy/domain/models.dart';

import 'fakes.dart';

void main() {
  test(
    'load failure locks creation instead of falling through to empty state',
    () async {
      final repository = MemorySessionRepository()..failLoad = true;
      final recorder = FakeRecorderService();
      final controller = AppController(
        repository: repository,
        recorder: recorder,
        player: FakeClipPlayerService(),
      );

      await controller.initialize();
      expect(controller.loadFailed, isTrue);
      expect(controller.error, ControllerError.load);
      expect(
        await controller.startRecording(prompt: '', contextTags: const []),
        isFalse,
      );
      expect(recorder.started, isFalse);
      expect(repository.markCalls, 0);
      controller.dispose();
    },
  );

  test('permission denial creates no marker or session', () async {
    final repository = MemorySessionRepository();
    final recorder = FakeRecorderService()..permission = false;
    final controller = AppController(
      repository: repository,
      recorder: recorder,
      player: FakeClipPlayerService(),
    );
    await controller.initialize();

    expect(
      await controller.startRecording(
        prompt: 'remember',
        contextTags: const [],
      ),
      isFalse,
    );
    expect(controller.error, ControllerError.permission);
    expect(repository.state.recordingMarker, isNull);
    expect(repository.state.sessions, isEmpty);
    controller.dispose();
  });

  test('records, saves reviewed data, and permanently deletes it', () async {
    final repository = MemorySessionRepository();
    final recorder = FakeRecorderService();
    var now = DateTime(2026, 10, 8, 23);
    final controller = AppController(
      repository: repository,
      recorder: recorder,
      player: FakeClipPlayerService(),
      clock: () => now,
    );
    await controller.initialize();

    expect(
      await controller.startRecording(
        prompt: 'last image',
        contextTags: const ['sharedRoom'],
      ),
      isTrue,
    );
    expect(repository.state.recordingMarker, isNotNull);
    now = now.add(const Duration(minutes: 42));
    expect(await controller.stopRecording(), isTrue);
    expect(controller.reviewSession, isNotNull);

    expect(
      await controller.saveReview(
        morningNote: 'A quiet train',
        labels: const <String, MomentLabel>{},
      ),
      isTrue,
    );
    expect(controller.sessions, hasLength(1));
    expect(controller.sessions.single.isReviewed, isTrue);
    expect(controller.sessions.single.morningNote, 'A quiet train');
    expect(repository.state.recordingMarker, isNull);

    final id = controller.sessions.single.id;
    final audioPath = controller.sessions.single.audioPath;
    expect(repository.audioPaths, contains(audioPath));
    expect(await controller.deleteSession(id), isTrue);
    expect(controller.sessions, isEmpty);
    expect(repository.audioPaths, isNot(contains(audioPath)));
    controller.dispose();
  });

  test('save failure keeps review content available for retry', () async {
    final repository = MemorySessionRepository();
    final controller = AppController(
      repository: repository,
      recorder: FakeRecorderService(),
      player: FakeClipPlayerService(),
    );
    await controller.initialize();
    await controller.startRecording(prompt: '', contextTags: const []);
    repository.failSave = true;

    expect(await controller.stopRecording(), isTrue);
    expect(controller.error, ControllerError.save);
    expect(controller.reviewSession, isNotNull);
    expect(controller.sessions, isEmpty);

    repository.failSave = false;
    expect(
      await controller.saveReview(
        morningNote: 'retry succeeded',
        labels: const {},
      ),
      isTrue,
    );
    expect(controller.reviewSession, isNull);
    expect(controller.reviewedSessions.single.morningNote, 'retry succeeded');
    expect(repository.state.recordingMarker, isNull);
    controller.dispose();
  });

  test(
    'restores a pending review and requires every candidate to be labeled',
    () async {
      final draft = NightSession(
        id: 'draft',
        startedAt: DateTime(2026, 10, 8, 23),
        endedAt: DateTime(2026, 10, 9, 7),
        audioPath: '/memory/draft.m4a',
        prompt: 'remember',
        contextTags: const ['stressfulDay'],
        moments: const [SoundMoment(id: 'm1', offsetSeconds: 30, peakDb: -18)],
      );
      final repository = MemorySessionRepository(sessions: [draft]);
      final controller = AppController(
        repository: repository,
        recorder: FakeRecorderService(),
        player: FakeClipPlayerService(),
      );

      await controller.initialize();
      expect(controller.reviewSession?.id, 'draft');
      expect(controller.reviewedSessions, isEmpty);
      expect(
        await controller.saveReview(morningNote: 'unsaved', labels: const {}),
        isFalse,
      );
      expect(controller.error, ControllerError.reviewRequired);
      expect(controller.busy, isFalse);
      expect(repository.state.sessions.single.isReviewed, isFalse);

      controller.deferReview();
      expect(controller.reviewSession, isNull);
      expect(repository.state.sessions.single.morningNote, isEmpty);
      controller.resumeReview(controller.pendingReviews.single);
      expect(
        await controller.saveReview(
          morningNote: 'saved',
          labels: const {'m1': MomentLabel.uncertain},
        ),
        isTrue,
      );
      expect(controller.reviewedSessions.single.morningNote, 'saved');
      expect(
        controller.reviewedSessions.single.moments.single.label,
        MomentLabel.uncertain,
      );
      controller.dispose();
    },
  );

  test(
    'partial recorder start failure is cancelled and leaves no orphan',
    () async {
      final repository = MemorySessionRepository();
      final recorder = FakeRecorderService()..failStartAfterActivation = true;
      final controller = AppController(
        repository: repository,
        recorder: recorder,
        player: FakeClipPlayerService(),
      );
      await controller.initialize();

      expect(
        await controller.startRecording(prompt: '', contextTags: const []),
        isFalse,
      );
      expect(recorder.started, isFalse);
      expect(recorder.cancelCalls, 1);
      expect(repository.audioPaths, isEmpty);
      expect(repository.state.recordingMarker, isNull);
      expect(repository.state.sessions, isEmpty);
      controller.dispose();
    },
  );
}
