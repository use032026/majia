import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_edit/app/reader_edit_app.dart';
import 'package:reader_edit/app/reader_edit_store.dart';
import 'package:reader_edit/data/session_repository.dart';
import 'package:reader_edit/domain/novel.dart';

Future<ReaderEditStore> _open(
  WidgetTester tester,
  MemorySessionRepository repository,
) async {
  final store = ReaderEditStore(repository);
  await store.load();
  await tester.pumpWidget(ReaderEditApp(key: UniqueKey(), store: store));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets(
    'first run completes three steps and stays completed on relaunch',
    (tester) async {
      final repository = MemorySessionRepository(languageCode: 'en');
      await _open(tester, repository);
      expect(find.text('Your story, in your hands'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Read with fresh eyes'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Revise with a clear purpose'), findsOneWidget);
      await tester.tap(find.text('Open my workspace'));
      await tester.pumpAndSettle();
      expect(find.text('My novels'), findsOneWidget);
      await _open(tester, repository);
      expect(find.text('My novels'), findsOneWidget);
      expect(find.text('Your story, in your hands'), findsNothing);
    },
  );

  testWidgets('skip is persisted and the tour can be replayed from settings', (
    tester,
  ) async {
    final repository = MemorySessionRepository(languageCode: 'zh');
    await _open(tester, repository);
    await tester.tap(find.text('跳过'));
    await tester.pumpAndSettle();
    await _open(tester, repository);
    expect(find.text('我的小说'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('使用引导'));
    await tester.pumpAndSettle();
    expect(find.text('把故事留在自己手中'), findsOneWidget);
    await tester.tap(find.text('跳过'));
    await tester.pumpAndSettle();
    expect(find.text('界面语言'), findsOneWidget);
  });

  testWidgets('failed completion keeps onboarding visible and can be retried', (
    tester,
  ) async {
    final repository = MemorySessionRepository(languageCode: 'en');
    await _open(tester, repository);
    repository.failNextSave = true;
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Your story, in your hands'), findsOneWidget);
    expect(find.text('My novels'), findsNothing);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('My novels'), findsOneWidget);
  });

  testWidgets(
    'existing workspace bypasses onboarding even after later clearing data',
    (tester) async {
      final now = DateTime.utc(2026, 10, 16);
      final repository = MemorySessionRepository(
        languageCode: 'en',
        novels: [
          Novel(
            id: 'existing',
            title: 'My manuscript',
            description: '',
            chapters: const [],
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
      final store = await _open(tester, repository);
      expect(find.text('My manuscript'), findsOneWidget);
      await store.clearAll();
      await _open(tester, repository);
      expect(find.text('My novels'), findsOneWidget);
      expect(find.text('Your story, in your hands'), findsNothing);
    },
  );

  testWidgets(
    'compact large-text tour can change language and reach its final action',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await _open(tester, MemorySessionRepository(languageCode: 'zh'));
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('Your story, in your hands'), findsOneWidget);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      final finish = find.text('Open my workspace');
      expect(tester.getRect(finish).bottom, lessThanOrEqualTo(534));
      await tester.tap(finish);
      await tester.pumpAndSettle();
      expect(find.text('My novels'), findsOneWidget);
    },
  );
}
