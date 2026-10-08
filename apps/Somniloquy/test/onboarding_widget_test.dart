import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:somniloquy/app.dart';
import 'package:somniloquy/controllers/app_controller.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first launch completes onboarding and later launch skips it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MemorySessionRepository(onboardingCompleted: false);
    final controller = AppController(
      repository: repository,
      recorder: FakeRecorderService(),
      player: FakeClipPlayerService(),
    );
    await controller.initialize();

    await tester.pumpWidget(SomniloquyApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('只记录，不替你判断'), findsOneWidget);
    expect(find.byKey(const Key('onboarding_skip')), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    expect(find.text('醒来后，听你想听的'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    expect(find.text('隐私，从开始录音前说清楚'), findsOneWidget);
    expect(find.byKey(const Key('onboarding_start')), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_start')));
    await tester.pumpAndSettle();
    expect(controller.hasCompletedOnboarding, isTrue);
    expect(repository.state.hasCompletedOnboarding, isTrue);
    expect(find.byKey(const Key('prepare_button')), findsOneWidget);
    controller.dispose();

    final restored = AppController(
      repository: repository,
      recorder: FakeRecorderService(),
      player: FakeClipPlayerService(),
    );
    await restored.initialize();
    await tester.pumpWidget(SomniloquyApp(controller: restored));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onboarding_pages')), findsNothing);
    expect(find.byKey(const Key('prepare_button')), findsOneWidget);
    restored.dispose();
  });

  testWidgets(
    'failed skip stays on onboarding and large text does not overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repository = MemorySessionRepository(
        localeCode: 'en',
        onboardingCompleted: false,
      );
      final controller = AppController(
        repository: repository,
        recorder: FakeRecorderService(),
        player: FakeClipPlayerService(),
      );
      await controller.initialize();
      repository.failSave = true;

      await tester.pumpWidget(SomniloquyApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('Record without guessing'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('onboarding_skip')));
      await tester.pumpAndSettle();
      expect(controller.hasCompletedOnboarding, isFalse);
      expect(find.byKey(const Key('onboarding_pages')), findsOneWidget);
      expect(
        find.text(
          'The onboarding choice could not be saved. Please try again.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      controller.dispose();
    },
  );
}
