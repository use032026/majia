import 'package:flutter_test/flutter_test.dart';
import 'package:pace_jar/domain/models.dart';
import 'package:pace_jar/domain/pace_calculator.dart';
import 'package:pace_jar/state/app_controller.dart';

import 'test_support.dart';

void main() {
  final now = DateTime(2026, 9, 29, 10);

  test('failed create does not commit unsaved goal', () async {
    final repository = FakeGoalRepository()..failSave = true;
    final controller = AppController(repository: repository, now: () => now);
    await controller.initialize();
    final saved = await controller.createGoal(
      CreateGoalInput(
        name: 'Trip',
        currency: r'$',
        targetCents: 100000,
        startingCents: 0,
        weeklyCents: 10000,
        targetDate: DateTime(2026, 12, 1),
      ),
    );
    expect(saved, isFalse);
    expect(controller.goal, isNull);
    expect(controller.errorCode, 'saveFailed');
  });

  test('failed event save preserves prior state', () async {
    final repository = FakeGoalRepository()..goal = sampleGoal();
    final controller = AppController(repository: repository, now: () => now);
    await controller.initialize();
    repository.failSave = true;
    final saved = await controller.recordEvent(
      type: SavingsEventType.deposit,
      amountCents: 5000,
    );
    expect(saved, isFalse);
    expect(controller.goal!.events, isEmpty);
  });

  test('withdrawal cannot make the local record negative', () async {
    final repository = FakeGoalRepository()..goal = sampleGoal();
    final controller = AppController(repository: repository, now: () => now);
    await controller.initialize();
    final saved = await controller.recordEvent(
      type: SavingsEventType.withdrawal,
      amountCents: 10001,
    );
    expect(saved, isFalse);
    expect(repository.saveCalls, 0);
    expect(controller.errorCode, 'withdrawalTooLarge');
  });

  test('applying recovery appends version with actual baseline', () async {
    final repository = FakeGoalRepository()..goal = sampleGoal();
    final controller = AppController(repository: repository, now: () => now);
    await controller.initialize();
    await controller.recordEvent(
      type: SavingsEventType.deposit,
      amountCents: 2500,
    );
    final applied = await controller.applyPlan(RecoveryStrategy.keepWeekly);
    expect(applied, isTrue);
    expect(controller.goal!.plans, hasLength(2));
    expect(controller.goal!.plans.last.baselineCents, 12500);
    expect(controller.goal!.plans.first.reason, PlanReason.initial);
  });

  test('corrupt local record is not silently overwritten', () async {
    final repository = FakeGoalRepository()..corrupt = true;
    final controller = AppController(repository: repository, now: () => now);
    await controller.initialize();
    expect(controller.corruptRecord, isTrue);
    expect(controller.goal, isNull);
    expect(repository.saveCalls, 0);
  });

  test(
    'ordinary load failure blocks writes until retry restores data',
    () async {
      final repository = FakeGoalRepository()
        ..goal = sampleGoal()
        ..failLoad = true;
      final controller = AppController(repository: repository, now: () => now);

      await controller.initialize();
      expect(controller.loadFailure, isTrue);
      expect(controller.goal, isNull);

      final created = await controller.createGoal(
        CreateGoalInput(
          name: 'Must not overwrite',
          currency: r'$',
          targetCents: 200000,
          startingCents: 0,
          weeklyCents: 10000,
          targetDate: DateTime(2027, 1, 1),
        ),
      );
      expect(created, isFalse);
      expect(repository.saveCalls, 0);

      repository.failLoad = false;
      await controller.initialize();
      expect(controller.loadFailure, isFalse);
      expect(controller.goal!.name, 'Laptop buffer');
    },
  );

  test('clipboard failure has readable state and preserves the goal', () async {
    final repository = FakeGoalRepository()..goal = sampleGoal();
    final controller = AppController(
      repository: repository,
      now: () => now,
      clipboardWriter: (_) async => throw StateError('clipboard denied'),
    );
    await controller.initialize();

    expect(await controller.copySummary(), isFalse);
    expect(controller.errorCode, 'copyFailed');
    expect(controller.goal, same(repository.goal));
    expect(repository.saveCalls, 0);
  });

  test('expired keep-date recovery never appends an invalid plan', () async {
    final repository = FakeGoalRepository()
      ..goal = sampleGoal(targetDate: DateTime(2026, 9, 1));
    final controller = AppController(repository: repository, now: () => now);
    await controller.initialize();

    expect(await controller.applyPlan(RecoveryStrategy.keepDate), isFalse);
    expect(controller.goal!.plans, hasLength(1));
    expect(repository.saveCalls, 0);
  });

  test('completed goal is archived before a new goal is created', () async {
    final completed = sampleGoal(
      targetCents: 20000,
      events: <SavingsEvent>[
        SavingsEvent(
          id: 'finish',
          type: SavingsEventType.deposit,
          amountCents: 10000,
          occurredAt: now,
        ),
      ],
    );
    final repository = FakeGoalRepository()..goal = completed;
    final controller = AppController(repository: repository, now: () => now);
    await controller.initialize();

    expect(await controller.archiveCompletedGoal(), isTrue);
    expect(controller.goal, isNull);
    expect(controller.completedGoals, hasLength(1));
    expect(controller.completedGoals.single.id, completed.id);

    expect(
      await controller.createGoal(
        CreateGoalInput(
          name: 'Next goal',
          currency: r'$',
          targetCents: 50000,
          startingCents: 0,
          weeklyCents: 5000,
          targetDate: DateTime(2027, 1, 1),
        ),
      ),
      isTrue,
    );
    expect(controller.goal!.name, 'Next goal');
    expect(controller.completedGoals.single.id, completed.id);
  });

  test('failed archive preserves the completed active goal', () async {
    final completed = sampleGoal(
      targetCents: 20000,
      events: <SavingsEvent>[
        SavingsEvent(
          id: 'finish',
          type: SavingsEventType.deposit,
          amountCents: 10000,
          occurredAt: now,
        ),
      ],
    );
    final repository = FakeGoalRepository()
      ..goal = completed
      ..failSave = true;
    final controller = AppController(repository: repository, now: () => now);
    await controller.initialize();

    expect(await controller.archiveCompletedGoal(), isFalse);
    expect(controller.goal, same(completed));
    expect(controller.completedGoals, isEmpty);
    expect(controller.errorCode, 'saveFailed');
  });

  test(
    'deleting one completed goal preserves active and other goals',
    () async {
      final first = sampleGoal(
        id: 'completed-1',
        targetCents: 20000,
        events: <SavingsEvent>[
          SavingsEvent(
            id: 'finish-1',
            type: SavingsEventType.deposit,
            amountCents: 10000,
            occurredAt: now,
          ),
        ],
      );
      final second = sampleGoal(
        id: 'completed-2',
        targetCents: 20000,
        events: <SavingsEvent>[
          SavingsEvent(
            id: 'finish-2',
            type: SavingsEventType.deposit,
            amountCents: 10000,
            occurredAt: now,
          ),
        ],
      );
      final repository = FakeGoalRepository()
        ..goal = sampleGoal(id: 'active')
        ..completedGoals = <SavingsGoal>[first, second];
      final controller = AppController(repository: repository, now: () => now);
      await controller.initialize();

      expect(await controller.deleteCompletedGoal(first.id), isTrue);
      expect(controller.goal!.id, 'active');
      expect(controller.completedGoals.map((goal) => goal.id), <String>[
        second.id,
      ]);
      expect(repository.completedGoals.map((goal) => goal.id), <String>[
        second.id,
      ]);
    },
  );

  test('failed completed-goal deletion preserves every goal', () async {
    final completed = sampleGoal(
      id: 'completed',
      targetCents: 20000,
      events: <SavingsEvent>[
        SavingsEvent(
          id: 'finish',
          type: SavingsEventType.deposit,
          amountCents: 10000,
          occurredAt: now,
        ),
      ],
    );
    final active = sampleGoal(id: 'active');
    final repository = FakeGoalRepository()
      ..goal = active
      ..completedGoals = <SavingsGoal>[completed]
      ..failSave = true;
    final controller = AppController(repository: repository, now: () => now);
    await controller.initialize();

    expect(await controller.deleteCompletedGoal(completed.id), isFalse);
    expect(controller.goal, same(active));
    expect(controller.completedGoals.single, same(completed));
    expect(repository.completedGoals.single, same(completed));
    expect(controller.errorCode, 'saveFailed');
  });

  test('delete all removes the active goal and completed history', () async {
    final completed = sampleGoal(
      id: 'completed',
      targetCents: 20000,
      events: <SavingsEvent>[
        SavingsEvent(
          id: 'finish',
          type: SavingsEventType.deposit,
          amountCents: 10000,
          occurredAt: now,
        ),
      ],
    );
    final repository = FakeGoalRepository()
      ..goal = sampleGoal(id: 'active')
      ..completedGoals = <SavingsGoal>[completed];
    final controller = AppController(repository: repository, now: () => now);
    await controller.initialize();

    expect(await controller.deleteAllData(), isTrue);
    expect(controller.goal, isNull);
    expect(controller.completedGoals, isEmpty);
    expect(repository.goal, isNull);
    expect(repository.completedGoals, isEmpty);
  });
}
