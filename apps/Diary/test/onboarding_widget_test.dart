import 'package:diary/app.dart';
import 'package:diary/domain/diary_entry.dart';
import 'package:diary/state/diary_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_repository.dart';

Future<DiaryController> pumpOnboarding(
  WidgetTester tester, {
  FakeDiaryRepository? repository,
  String localeCode = 'en',
}) async {
  final target =
      repository ??
      FakeDiaryRepository(
        initial: DiarySnapshot(
          localeCode: localeCode,
          entries: const <DiaryEntry>[],
        ),
      );
  final controller = DiaryController(target);
  await controller.initialize();
  await tester.pumpWidget(EchoPageApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('first launch completes onboarding and remembers it', (
    tester,
  ) async {
    final repository = FakeDiaryRepository(
      initial: const DiarySnapshot(localeCode: 'en', entries: <DiaryEntry>[]),
    );
    final controller = await pumpOnboarding(tester, repository: repository);

    expect(find.byKey(const ValueKey<String>('onboarding_pages')), findsOne);
    expect(find.text('Capture this moment'), findsOne);

    await tester.tap(find.byKey(const ValueKey<String>('onboarding_next')));
    await tester.pumpAndSettle();
    expect(find.text('Leave a question for later'), findsOne);

    await tester.tap(find.byKey(const ValueKey<String>('onboarding_next')));
    await tester.pumpAndSettle();
    expect(find.text('Notice what changed'), findsOne);

    await tester.tap(find.byKey(const ValueKey<String>('onboarding_start')));
    await tester.pumpAndSettle();

    expect(controller.snapshot.hasCompletedOnboarding, isTrue);
    expect(repository.stored.hasCompletedOnboarding, isTrue);
    expect(
      find.byKey(const ValueKey<String>('onboarding_pages')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey<String>('new_entry')), findsOne);

    final restoredController = DiaryController(repository);
    await restoredController.initialize();
    await tester.pumpWidget(EchoPageApp(controller: restoredController));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('onboarding_pages')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey<String>('new_entry')), findsOne);
  });

  testWidgets('skip persists completion from any onboarding page', (
    tester,
  ) async {
    final repository = FakeDiaryRepository(
      initial: const DiarySnapshot(localeCode: 'zh', entries: <DiaryEntry>[]),
    );
    await pumpOnboarding(tester, repository: repository);

    expect(find.text('写下此刻'), findsOne);
    await tester.tap(find.byKey(const ValueKey<String>('onboarding_skip')));
    await tester.pumpAndSettle();

    expect(repository.stored.hasCompletedOnboarding, isTrue);
    expect(find.byKey(const ValueKey<String>('new_entry')), findsOne);
  });

  testWidgets('failed completion keeps onboarding visible', (tester) async {
    final repository = FakeDiaryRepository(
      initial: const DiarySnapshot(localeCode: 'en', entries: <DiaryEntry>[]),
      failSave: true,
    );
    final controller = await pumpOnboarding(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey<String>('onboarding_skip')));
    await tester.pumpAndSettle();

    expect(controller.snapshot.hasCompletedOnboarding, isFalse);
    expect(find.byKey(const ValueKey<String>('onboarding_pages')), findsOne);
    expect(find.text('Not saved; existing data was unchanged.'), findsOne);
  });

  testWidgets('onboarding remains usable on a small screen with large text', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(
      () => tester.platformDispatcher.clearTextScaleFactorTestValue(),
    );
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 3.2;

    await pumpOnboarding(tester, localeCode: 'zh');

    expect(find.byKey(const ValueKey<String>('onboarding_next')), findsOne);
    expect(tester.takeException(), isNull);
  });
}
