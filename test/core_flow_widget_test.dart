import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_jar/app.dart';
import 'package:pace_jar/domain/models.dart';
import 'package:pace_jar/state/app_controller.dart';

import 'test_support.dart';

void main() {
  final now = DateTime(2026, 9, 29, 10);

  testWidgets('creates a goal through the complete empty-state flow', (
    tester,
  ) async {
    final repository = FakeGoalRepository();
    final controller = AppController(repository: repository, now: () => now);
    await controller.initialize();
    await tester.pumpWidget(PaceJarApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create-goal')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('goal-name')), 'Laptop buffer');
    await tester.enterText(find.byKey(const Key('target-amount')), '1000');
    await tester.enterText(find.byKey(const Key('starting-amount')), '100');
    await tester.enterText(find.byKey(const Key('weekly-amount')), '100');
    await tester.ensureVisible(find.byKey(const Key('submit-goal')));
    await tester.tap(find.byKey(const Key('submit-goal')));
    await tester.pumpAndSettle();

    expect(controller.goal?.name, 'Laptop buffer');
    expect(find.byKey(const Key('record-week')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('language switch keeps unsubmitted form input', (tester) async {
    final repository = FakeGoalRepository();
    final controller = AppController(repository: repository, now: () => now);
    await controller.initialize();
    await tester.pumpWidget(PaceJarApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create-goal')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('goal-name')),
      'Long mixed 目标 name',
    );
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(
      find.byKey(const Key('goal-name')),
    );
    expect(field.controller!.text, 'Long mixed 目标 name');
    expect(find.text('Create a focus goal'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('event sheet cancel and reopen do not mutate or retain input', (
    tester,
  ) async {
    final repository = FakeGoalRepository()..goal = sampleGoal();
    final controller = AppController(repository: repository, now: () => now);
    await controller.initialize();
    await tester.pumpWidget(PaceJarApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('record-week')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('event-amount')), '25');
    await tester.enterText(find.byKey(const Key('event-note')), 'Lower income');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('取消').last);
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    expect(controller.goal!.events, isEmpty);

    await tester.ensureVisible(find.byKey(const Key('record-week')));
    await tester.tap(find.byKey(const Key('record-week')));
    await tester.pumpAndSettle();
    final amount = tester.widget<TextFormField>(
      find.byKey(const Key('event-amount')),
    );
    expect(amount.controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recovery action appends a plan and returns to pace', (
    tester,
  ) async {
    final repository = FakeGoalRepository()..goal = sampleGoal();
    final controller = AppController(repository: repository, now: () => now);
    await controller.initialize();
    await tester.pumpWidget(PaceJarApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('open-recovery')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('open-recovery')));
    await tester.tap(find.byKey(const Key('open-recovery')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('apply-plan')));
    await tester.tap(find.byKey(const Key('apply-plan')));
    await tester.pumpAndSettle();

    expect(controller.goal!.plans, hasLength(2));
    expect(find.byKey(const Key('record-week')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('load failure blocks creation and retry restores old goal', (
    tester,
  ) async {
    final repository = FakeGoalRepository()
      ..goal = sampleGoal()
      ..failLoad = true;
    final controller = AppController(repository: repository, now: () => now);
    await controller.initialize();
    await tester.pumpWidget(PaceJarApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('retry-load')), findsOneWidget);
    expect(find.byKey(const Key('create-goal')), findsNothing);
    repository.failLoad = false;
    await tester.tap(find.byKey(const Key('retry-load')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('record-week')), findsOneWidget);
    expect(controller.goal!.name, 'Laptop buffer');
    expect(repository.saveCalls, 0);
  });

  testWidgets('expired recovery disables keep-date and saves a viable plan', (
    tester,
  ) async {
    final repository = FakeGoalRepository()
      ..goal = sampleGoal(targetDate: DateTime(2026, 9, 1));
    final controller = AppController(repository: repository, now: () => now);
    await controller.initialize();
    await tester.pumpWidget(PaceJarApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('open-recovery')));
    await tester.tap(find.byKey(const Key('open-recovery')));
    await tester.pumpAndSettle();
    final disabled = tester.widget<InkWell>(
      find.byKey(const Key('strategy-keepDate')),
    );
    expect(disabled.onTap, isNull);
    expect(find.textContaining('原日期已过'), findsOneWidget);

    await tester.tap(find.byKey(const Key('apply-plan')));
    await tester.pumpAndSettle();
    expect(controller.goal!.plans, hasLength(2));
    expect(controller.goal!.currentPlan.targetDate.isAfter(now), isTrue);
  });

  testWidgets('barrier dismisses event sheet and reopen starts clean', (
    tester,
  ) async {
    final repository = FakeGoalRepository()..goal = sampleGoal();
    final controller = AppController(repository: repository, now: () => now);
    await controller.initialize();
    await tester.pumpWidget(PaceJarApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('record-week')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('event-amount')), '25');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(controller.goal!.events, isEmpty);

    await tester.tap(find.byKey(const Key('record-week')));
    await tester.pumpAndSettle();
    final field = tester.widget<TextFormField>(
      find.byKey(const Key('event-amount')),
    );
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('completed goal replacement opens a clean create flow', (
    tester,
  ) async {
    final repository = FakeGoalRepository()
      ..goal = sampleGoal(
        targetCents: 20000,
        events: <SavingsEvent>[
          SavingsEvent(
            id: 'complete',
            type: SavingsEventType.deposit,
            amountCents: 10000,
            occurredAt: now,
          ),
        ],
      );
    final controller = AppController(repository: repository, now: () => now);
    await controller.initialize();
    await tester.pumpWidget(PaceJarApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.textContaining('完成日期: 2026年9月29日'), findsOneWidget);
    repository.failClear = true;
    await tester.ensureVisible(find.byKey(const Key('start-new')));
    await tester.tap(find.byKey(const Key('start-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-replace')));
    await tester.pumpAndSettle();

    expect(controller.goal, isNotNull);
    expect(find.textContaining('未能保存'), findsOneWidget);

    repository.failClear = false;
    await tester.ensureVisible(find.byKey(const Key('start-new')));
    await tester.tap(find.byKey(const Key('start-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-replace')));
    await tester.pumpAndSettle();

    expect(controller.goal, isNull);
    expect(find.byKey(const Key('submit-goal')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
