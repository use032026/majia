import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plotproof_lab/app.dart';
import 'package:plotproof_lab/data/progress_repository.dart';
import 'package:plotproof_lab/state/app_controller.dart';

void main() {
  testWidgets('first launch completes onboarding and does not show it again', (
    tester,
  ) async {
    final repository = MemoryProgressRepository();
    final controller = AppController(repository);
    await controller.initialize(systemLocale: const Locale('zh'));

    await tester.pumpWidget(PlotProofApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('别让图表替结论说话'), findsOneWidget);
    expect(find.text('把“看起来”变成“有证据”'), findsNothing);

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('亲手改变一个变量'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('离线学习，记录只属于你'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-start')));
    await tester.pumpAndSettle();

    expect(controller.hasCompletedOnboarding, isTrue);
    expect(find.text('把“看起来”变成“有证据”'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-pages')), findsNothing);

    final restoredController = AppController(repository);
    await restoredController.initialize(systemLocale: const Locale('zh'));
    await tester.pumpWidget(PlotProofApp(controller: restoredController));
    await tester.pumpAndSettle();

    expect(restoredController.hasCompletedOnboarding, isTrue);
    expect(find.byKey(const Key('onboarding-pages')), findsNothing);
  });

  testWidgets('failed onboarding save keeps the first-run flow visible', (
    tester,
  ) async {
    final repository = MemoryProgressRepository()..failWrites = true;
    final controller = AppController(repository);
    await controller.initialize(systemLocale: const Locale('en'));

    await tester.pumpWidget(PlotProofApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();

    expect(controller.hasCompletedOnboarding, isFalse);
    expect(find.byKey(const Key('onboarding-pages')), findsOneWidget);
    expect(find.text('Could not save progress. Try again.'), findsOneWidget);
  });

  testWidgets('onboarding remains usable with large accessibility text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = AppController(MemoryProgressRepository());
    await controller.initialize(systemLocale: const Locale('zh'));

    await tester.pumpWidget(PlotProofApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding-next')), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
