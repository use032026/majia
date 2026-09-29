import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_jar/app.dart';
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
}
