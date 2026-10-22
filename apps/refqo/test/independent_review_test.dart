import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refqo/main.dart';
import 'package:refqo/domain.dart';
import 'package:refqo/storage.dart';

void main() {
  testWidgets('review: following system updates custom app strings live', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final repo = MemoryRepository(AppData(onboarded: true));
    await tester.pumpWidget(RefqoApp(repository: repo));
    await tester.pumpAndSettle();
    expect(find.text('Purchase plan'), findsOneWidget);
    tester.platformDispatcher.localeTestValue = const Locale('zh', 'CN');
    await tester.pumpAndSettle();
    expect(find.text('补货计划'), findsOneWidget);
  });
  testWidgets('review: compact supply inventory at double text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repo = MemoryRepository(
      AppData(
        onboarded: true,
        supplies: [
          Supply(
            id: 'a',
            name:
                'Carbon refill for the kitchen purifier and air cleaning system',
            code: 'MODEL-CARBON-1234567890-LONG-SIZE-REFILL',
            stock: 99999,
          ),
        ],
      ),
    );
    await tester.pumpWidget(RefqoApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supplies'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'review: local previous recovery is reachable cancelable and preserves corrupt source',
    (tester) async {
      late Directory directory;
      late FileRepository repository;
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp(
          'refqo_independent_review_',
        );
        repository = FileRepository(directory);
        final initial = AppData(
          onboarded: true,
          supplies: [Supply(id: 'a', name: 'Refill', stock: 1)],
        );
        await repository.save(initial);
        await repository.save(receiveSupply(initial, 'a', 2, DateTime.now()));
        await File(
          repository.primaryPath,
        ).writeAsString('{broken', flush: true);
      });
      addTearDown(() async {
        await directory.delete(recursive: true);
      });
      await tester.pumpWidget(RefqoApp(repository: repository));
      await waitFor(tester, find.text('Your library needs attention'));
      expect(find.text('Your library needs attention'), findsOneWidget);
      await tester.tap(find.text('Preview local recovery copy'));
      await waitFor(tester, find.text('Restore local recovery copy?'));
      expect(find.text('Restore local recovery copy?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Your library needs attention'), findsOneWidget);
      await tester.tap(find.text('Preview local recovery copy'));
      await waitFor(tester, find.text('Restore local recovery copy?'));
      await tester.tap(find.text('Confirm'));
      await waitFor(tester, find.text('Purchase plan'));
      expect(find.text('Purchase plan'), findsOneWidget);
      await tester.runAsync(() async {
        expect((await repository.load()).supplies.single.stock, 1);
        expect(await File(repository.rejectedPath).readAsString(), '{broken');
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('review: system locale update reaches open editor', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final repo = MemoryRepository(AppData(onboarded: true));
    await tester.pumpWidget(RefqoApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add a supply'));
    await tester.tap(find.text('Add a supply'));
    await tester.pumpAndSettle();
    expect(find.text('Add supply'), findsOneWidget);
    tester.platformDispatcher.localeTestValue = const Locale('zh', 'CN');
    await tester.pumpAndSettle();
    expect(find.text('添加耗材'), findsOneWidget);
  });
}

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 200; i++) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(
    finder,
    findsOneWidget,
    reason: 'Expected IO-backed UI did not appear',
  );
}
