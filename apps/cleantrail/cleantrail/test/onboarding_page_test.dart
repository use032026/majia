import 'package:cleantrail/data/onboarding_store.dart';
import 'package:cleantrail/data/project_store.dart';
import 'package:cleantrail/domain/quality_engine.dart';
import 'package:cleantrail/main.dart';
import 'package:cleantrail/state/workbench_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_csv_gateway.dart';

void main() {
  testWidgets('first launch walks through all pages and remembers completion', (
    tester,
  ) async {
    final store = MemoryOnboardingStore();

    await tester.pumpWidget(
      CleanTrailApp(
        controller: _controller(),
        initialLocale: const Locale('en'),
        onboardingStore: store,
        showOnboarding: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding-screen')), findsOneWidget);
    expect(find.text('Confirm before inspection'), findsOneWidget);
    expect(store.completed, isFalse);

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Approve every repair'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Your data stays with you'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-start')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onboarding-screen')), findsNothing);
    expect(find.text('A calm checkpoint before analysis'), findsOneWidget);
    expect(store.completed, isTrue);
  });

  testWidgets('Chinese onboarding can be skipped and remains Chinese', (
    tester,
  ) async {
    final store = MemoryOnboardingStore();

    await tester.pumpWidget(
      CleanTrailApp(
        controller: _controller(),
        initialLocale: const Locale('zh'),
        onboardingStore: store,
        showOnboarding: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('开始检查前，先确认识别结果'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();

    expect(find.text('在分析之前，先做一次冷静检查'), findsOneWidget);
    expect(store.completed, isTrue);
  });

  testWidgets('completed onboarding opens the workbench directly', (
    tester,
  ) async {
    final store = MemoryOnboardingStore(completed: true);
    final completed = await loadOnboardingCompleted(store);

    await tester.pumpWidget(
      CleanTrailApp(
        controller: _controller(),
        initialLocale: const Locale('en'),
        onboardingStore: store,
        showOnboarding: !completed,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding-screen')), findsNothing);
    expect(find.text('A calm checkpoint before analysis'), findsOneWidget);
  });

  testWidgets('onboarding remains usable on a small screen with large text', (
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

    await tester.pumpWidget(
      CleanTrailApp(
        controller: _controller(),
        initialLocale: const Locale('en'),
        showOnboarding: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding-next')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

WorkbenchController _controller() => WorkbenchController(
  engine: const QualityEngine(),
  store: MemoryProjectStore(),
  gateway: FakeCsvGateway(),
);
