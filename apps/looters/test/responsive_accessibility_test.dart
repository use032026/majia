import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_jar/app.dart';
import 'package:pace_jar/domain/models.dart';
import 'package:pace_jar/state/app_controller.dart';

import 'test_support.dart';

void main() {
  testWidgets('compact phone at 2x text keeps core action reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final repository = FakeGoalRepository()
      ..goal = sampleGoal(name: 'Long bilingual goal 名称用于大字小屏检查');
    final controller = AppController(
      repository: repository,
      now: () => DateTime(2026, 9, 29),
    );
    await controller.initialize();
    await tester.pumpWidget(PaceJarApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('record-week')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('record-week')));
    await tester.tap(find.byKey(const Key('record-week')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('save-event')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide layout exposes navigation rail and dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = FakeGoalRepository()..goal = sampleGoal();
    final controller = AppController(
      repository: repository,
      now: () => DateTime(2026, 9, 29),
    );
    await controller.initialize();
    await tester.pumpWidget(PaceJarApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    await tester.tap(find.byTooltip('深色模式'));
    await tester.pumpAndSettle();
    expect(controller.darkMode, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timeline cards remain readable at 2x on a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final repository = FakeGoalRepository()
      ..goal = sampleGoal(
        events: <SavingsEvent>[
          SavingsEvent(
            id: 'responsive-event',
            type: SavingsEventType.deposit,
            amountCents: 25000,
            occurredAt: DateTime(2026, 9, 29),
            note: 'A longer note that still needs to wrap cleanly.',
          ),
        ],
      );
    final controller = AppController(
      repository: repository,
      now: () => DateTime(2026, 9, 29),
    );
    await controller.initialize();
    await tester.pumpWidget(PaceJarApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.history_outlined));
    await tester.pumpAndSettle();
    final timelineScroll = find.descendant(
      of: find.byKey(const PageStorageKey<String>('goal-timeline-goal-1')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('timeline-event-responsive-event')),
      180,
      scrollable: timelineScroll,
    );
    expect(
      find.byKey(const Key('timeline-event-responsive-event')),
      findsOneWidget,
    );
    expect(find.textContaining('记录后进度'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('timeline-plan-plan-1')),
      180,
      scrollable: timelineScroll,
    );
    await tester.pumpAndSettle();

    expect(find.text('当前周额'), findsOneWidget);
    expect(find.text('目标日期'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grouped settings remain usable at 2x on a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final repository = FakeGoalRepository()..goal = sampleGoal();
    final controller = AppController(
      repository: repository,
      now: () => DateTime(2026, 9, 29),
    );
    await controller.initialize();
    await tester.pumpWidget(PaceJarApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('privacy-policy')), findsOneWidget);

    final settingsScroll = find.byKey(
      const PageStorageKey<String>('settings-scroll'),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('delete-all')),
      180,
      scrollable: find.descendant(
        of: settingsScroll,
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('delete-all')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
