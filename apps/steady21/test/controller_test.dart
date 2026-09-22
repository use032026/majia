import 'package:flutter_test/flutter_test.dart';
import 'package:steady21/controller.dart';
import 'package:steady21/domain.dart';
import 'package:steady21/repository.dart';

void main() {
  final today = DateTime(2026, 9, 22, 12);

  AppController makeController(MemoryRepository repository) =>
      AppController(repository, now: () => today, idFactory: () => 'e1');

  Future<AppController> populated() async {
    final controller = makeController(MemoryRepository());
    await controller.load();
    await controller.createExperiment(
      title: 'Read',
      cue: 'After dinner',
      fullAction: 'Read 10 pages',
      minimumAction: 'Read 1 page',
      targetDays: 21,
    );
    return controller;
  }

  test('save-before-commit preserves prior state after a failure', () async {
    final repository = MemoryRepository();
    final controller = makeController(repository);
    await controller.load();
    repository.saveFailure = StateError('disk full');
    final ok = await controller.createExperiment(
      title: 'Read',
      cue: 'After dinner',
      fullAction: 'Read 10 pages',
      minimumAction: 'Read 1 page',
      targetDays: 21,
    );
    expect(ok, isFalse);
    expect(controller.snapshot.experiments, isEmpty);
    expect(controller.actionError, isA<StateError>());
  });

  test('skipping requires an obstacle and recovery plan', () async {
    final controller = await populated();
    await expectLater(
      controller.saveEntry(experimentId: 'e1', kind: EntryKind.skipped),
      throwsA(
        isA<DomainValidationException>().having(
          (error) => error.code,
          'code',
          'obstacle_required',
        ),
      ),
    );
    final ok = await controller.saveEntry(
      experimentId: 'e1',
      kind: EntryKind.skipped,
      obstacle: Obstacle.energy,
      recoveryPlan: RecoveryPlan.makeSmaller,
    );
    expect(ok, isTrue);
    expect(controller.snapshot.active?.entries.single.kind, EntryKind.skipped);
  });

  test('today can be corrected and undone without duplicate dates', () async {
    final controller = await populated();
    await controller.saveEntry(experimentId: 'e1', kind: EntryKind.full);
    await controller.saveEntry(experimentId: 'e1', kind: EntryKind.minimum);
    expect(controller.snapshot.active?.entries, hasLength(1));
    expect(controller.snapshot.active?.entries.single.kind, EntryKind.minimum);
    await controller.undoToday('e1');
    expect(controller.snapshot.active?.entries, isEmpty);
  });

  test(
    'correcting a pause clears a no-longer-applicable recovery plan',
    () async {
      final controller = await populated();
      await controller.saveEntry(
        experimentId: 'e1',
        kind: EntryKind.skipped,
        obstacle: Obstacle.energy,
        recoveryPlan: RecoveryPlan.makeSmaller,
      );
      await controller.saveEntry(
        experimentId: 'e1',
        kind: EntryKind.full,
        recoveryPlan: RecoveryPlan.makeSmaller,
      );
      final corrected = controller.snapshot.active!.entries.single;
      expect(corrected.kind, EntryKind.full);
      expect(corrected.obstacle, Obstacle.none);
      expect(corrected.recoveryPlan, RecoveryPlan.none);
      expect(
        ExperimentStats(controller.snapshot.active!, today).recoveryCount,
        0,
      );
    },
  );

  test('only one experiment may be active and archive preserves it', () async {
    final controller = await populated();
    await expectLater(
      controller.createExperiment(
        title: 'Walk',
        cue: 'At lunch',
        fullAction: 'Walk 20 minutes',
        minimumAction: 'Walk downstairs',
        targetDays: 7,
      ),
      throwsA(isA<DomainValidationException>()),
    );
    await controller.archive('e1');
    expect(controller.snapshot.active, isNull);
    expect(controller.snapshot.archived.single.title, 'Read');
    await controller.restore('e1');
    expect(controller.snapshot.active?.title, 'Read');
    await controller.archive('e1');
    await controller.deleteExperiment('e1');
    expect(controller.snapshot.experiments, isEmpty);
  });

  test(
    'delete all removes records but preserves explicit language choice',
    () async {
      final controller = await populated();
      await controller.setLocale('en');
      await controller.deleteAll();
      expect(controller.snapshot.experiments, isEmpty);
      expect(controller.snapshot.localeCode, 'en');
    },
  );

  test(
    'correcting progress removes reviews for milestones no longer reached',
    () async {
      final reviewed = Experiment(
        id: 'reviewed',
        title: 'Read',
        cue: 'After dinner',
        fullAction: 'Read 10 pages',
        minimumAction: 'Read 1 page',
        targetDays: 21,
        startedAt: DateTime(2026, 9, 16),
        entries: List.generate(
          7,
          (index) => DailyEntry(
            date: '2026-09-${(index + 16).toString().padLeft(2, '0')}',
            kind: EntryKind.full,
          ),
        ),
        reviews: [
          MilestoneReview(
            milestone: 7,
            decision: ReviewDecision.keep,
            recordedAt: today,
          ),
        ],
      );
      final controller = makeController(
        MemoryRepository(AppSnapshot(experiments: [reviewed])),
      );
      await controller.load();

      await controller.undoToday('reviewed');

      expect(controller.snapshot.active?.entries, hasLength(6));
      expect(controller.snapshot.active?.reviews, isEmpty);
      expect(
        ExperimentStats(controller.snapshot.active!, today).dueMilestones,
        isEmpty,
      );
    },
  );
}
