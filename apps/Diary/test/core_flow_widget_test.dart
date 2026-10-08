import 'dart:async';

import 'package:diary/app.dart';
import 'package:diary/domain/diary_entry.dart';
import 'package:diary/state/diary_controller.dart';
import 'package:diary/ui/entry_widgets.dart';
import 'package:diary/ui/trash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_repository.dart';

Future<DiaryController> pumpDiary(
  WidgetTester tester, {
  DiarySnapshot initial = const DiarySnapshot(
    entries: <DiaryEntry>[],
    localeCode: 'en',
  ),
}) async {
  final repository = FakeDiaryRepository(initial: initial);
  final controller = DiaryController(repository);
  await controller.initialize();
  await tester.pumpWidget(EchoPageApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('bottom spacing adapts to the safe area and keyboard', (
    tester,
  ) async {
    const contentKey = ValueKey<String>('safe_area_content');
    double? spacing;

    Future<void> pumpInsets(MediaQueryData data) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: data,
            child: Builder(
              builder: (context) {
                spacing = bottomSafeSpacing(context);
                return const Scaffold(
                  resizeToAvoidBottomInset: false,
                  body: BottomSafeArea(child: SizedBox.expand(key: contentKey)),
                );
              },
            ),
          ),
        ),
      );
    }

    await pumpInsets(
      const MediaQueryData(
        padding: EdgeInsets.only(bottom: 34),
        viewPadding: EdgeInsets.only(bottom: 34),
      ),
    );
    final safeAreaBottom = tester.getBottomRight(find.byKey(contentKey)).dy;
    final viewBottom =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(spacing, 54);
    expect(safeAreaBottom, viewBottom - 34);

    await pumpInsets(
      const MediaQueryData(
        viewPadding: EdgeInsets.only(bottom: 34),
        viewInsets: EdgeInsets.only(bottom: 300),
      ),
    );
    expect(spacing, 320);
    expect(tester.getBottomRight(find.byKey(contentKey)).dy, safeAreaBottom);
  });

  testWidgets('all standalone pages share the bottom safe area policy', (
    tester,
  ) async {
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetViewInsets);
    final physicalBottomInset = 34 * tester.view.devicePixelRatio;
    tester.view.padding = FakeViewPadding(bottom: physicalBottomInset);
    tester.view.viewPadding = FakeViewPadding(bottom: physicalBottomInset);
    final active = sampleEntry();
    final deleted = sampleEntry(
      id: 'deleted-entry',
      deletedAt: DateTime(2026, 10, 8),
    );
    await pumpDiary(
      tester,
      initial: DiarySnapshot(
        entries: <DiaryEntry>[active, deleted],
        localeCode: 'en',
      ),
    );

    expect(
      tester
          .widget<NavigationBar>(find.byType(NavigationBar))
          .maintainBottomViewPadding,
      isTrue,
    );

    await tester.tap(find.text(active.title));
    await tester.pumpAndSettle();
    final detailList = tester.widget<ListView>(
      find.byKey(const ValueKey<String>('entry_detail_scroll')),
    );
    expect((detailList.padding! as EdgeInsets).bottom, 70);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    final settingsList = tester.widget<ListView>(find.byType(ListView));
    expect((settingsList.padding! as EdgeInsets).bottom, 70);
    await tester.dragUntilVisible(
      find.text('Recently Deleted'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    final trashTile = find.ancestor(
      of: find.text('Recently Deleted'),
      matching: find.byType(ListTile),
    );
    expect(trashTile, findsOneWidget);
    await tester.tap(trashTile);
    await tester.pumpAndSettle();
    expect(find.byType(TrashPage), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
    final trashList = tester.widget<ListView>(find.byType(ListView));
    expect((trashList.padding! as EdgeInsets).bottom, 70);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('new_entry')));
    await tester.pumpAndSettle();
    final editorList = tester.widget<ListView>(
      find.byKey(const ValueKey<String>('entry_editor_scroll')),
    );
    expect((editorList.padding! as EdgeInsets).bottom, 24);

    final bottomSave = find.byKey(const ValueKey<String>('save_entry_bottom'));
    final logicalViewBottom =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(tester.getSize(bottomSave).height, greaterThanOrEqualTo(48));
    expect(
      tester.getBottomRight(bottomSave).dy,
      lessThanOrEqualTo(logicalViewBottom - 46),
    );

    tester.view.viewInsets = FakeViewPadding(
      bottom: 300 * tester.view.devicePixelRatio,
    );
    await tester.pumpAndSettle();
    expect(bottomSave, findsNothing);

    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(bottomSave, findsOneWidget);
  });

  testWidgets('selected choice chips use color without checkmarks', (
    tester,
  ) async {
    await pumpDiary(tester);
    await tester.tap(find.byKey(const ValueKey<String>('new_entry')));
    await tester.pumpAndSettle();

    final rawChoiceChips = tester.widgetList<RawChip>(
      find.descendant(
        of: find.byType(ChoiceChip),
        matching: find.byType(RawChip),
      ),
    );
    expect(rawChoiceChips, hasLength(EntryMood.values.length));
    expect(rawChoiceChips.where((chip) => chip.selected), hasLength(1));
    expect(rawChoiceChips.every((chip) => chip.showCheckmark == false), isTrue);
  });

  testWidgets('revisit time uses a bottom sheet with longer options', (
    tester,
  ) async {
    await pumpDiary(tester);
    await tester.tap(find.byKey(const ValueKey<String>('new_entry')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey<String>('entry_editor_scroll')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('question_field')),
      'What will matter later?',
    );
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey<String>('entry_editor_scroll')),
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('revisit_dropdown')));
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    for (final label in <String>[
      'In 3 days',
      'In 7 days',
      'In 2 weeks',
      'In 30 days',
      'In 3 months',
      'In 6 months',
      'In 1 year',
    ]) {
      expect(find.descendant(of: sheet, matching: find.text(label)), findsOne);
    }

    final selectedSurface = tester.widget<Material>(
      find.byKey(const ValueKey<String>('revisit_option_surface_7')),
    );
    expect(
      selectedSurface.color,
      Theme.of(tester.element(sheet)).colorScheme.primaryContainer,
    );
    expect(
      find.descendant(of: sheet, matching: find.byIcon(Icons.check_rounded)),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey<String>('revisit_option_365')));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('In 1 year'), findsOneWidget);
  });

  testWidgets(
    'user creates a thread, dismisses and reopens echo, then closes it',
    (tester) async {
      final controller = await pumpDiary(tester);
      expect(find.text('Your first thread starts here'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('new_entry')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('title_field')),
        'A quiet turning point',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('body_field')),
        'I chose to wait before answering.',
      );
      await tester.drag(
        find.byKey(const ValueKey<String>('entry_editor_scroll')),
        const Offset(0, -420),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('question_field')),
        'Will waiting change what I notice?',
      );
      await tester.pump();
      await tester.drag(
        find.byKey(const ValueKey<String>('entry_editor_scroll')),
        const Offset(0, -520),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('revisit_dropdown')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey<String>('save_entry')));
      await tester.pumpAndSettle();

      expect(controller.activeEntries, hasLength(1));
      expect(find.text('A quiet turning point'), findsOneWidget);

      await tester.tap(find.text('A quiet turning point'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('add_echo')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('add_echo')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('echo_body_field')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('cancel_echo')));
      await tester.pumpAndSettle();
      expect(controller.activeEntries.single.echoes, isEmpty);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('add_echo')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('add_echo')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 110));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('echo_body_field')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey<String>('add_echo')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('echo_body_field')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey<String>('add_echo')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('echo_body_field')),
        'The pause made the next step easier to see.',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('save_echo')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('save_echo')));
      await tester.pumpAndSettle();

      expect(controller.activeEntries.single.echoes, hasLength(1));
      expect(controller.activeEntries.single.isClosed, isTrue);
      expect(
        find.text('The pause made the next step easier to see.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('canceling entry editor makes no data change', (tester) async {
    final controller = await pumpDiary(tester);

    await tester.tap(find.byKey(const ValueKey<String>('new_entry')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('body_field')),
      'A draft that should be discarded.',
    );
    await tester.tap(find.byKey(const ValueKey<String>('cancel_editor')));
    await tester.pumpAndSettle();

    expect(controller.activeEntries, isEmpty);
    expect(find.text('A draft that should be discarded.'), findsNothing);
  });

  testWidgets('failed echo save keeps the sheet and typed draft for retry', (
    tester,
  ) async {
    final entry = sampleEntry();
    final repository = FakeDiaryRepository(
      initial: DiarySnapshot(localeCode: 'en', entries: <DiaryEntry>[entry]),
    );
    final controller = DiaryController(repository);
    await controller.initialize();
    await tester.pumpWidget(EchoPageApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text(entry.title));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey<String>('add_echo')));
    await tester.tap(find.byKey(const ValueKey<String>('add_echo')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('echo_body_field')),
      'Keep this draft when storage fails.',
    );
    repository.failSave = true;
    await tester.tap(find.byKey(const ValueKey<String>('save_echo')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('echo_body_field')),
      findsOneWidget,
    );
    expect(find.text('Keep this draft when storage fails.'), findsOneWidget);
    expect(controller.entryById(entry.id)!.echoes, isEmpty);

    repository.failSave = false;
    await tester.tap(find.byKey(const ValueKey<String>('save_echo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('echo_body_field')), findsNothing);
    expect(controller.entryById(entry.id)!.echoes, hasLength(1));
  });

  testWidgets('pending echo save blocks back, barrier, and drag dismissal', (
    tester,
  ) async {
    final entry = sampleEntry();
    final repository = FakeDiaryRepository(
      initial: DiarySnapshot(localeCode: 'en', entries: <DiaryEntry>[entry]),
    );
    final controller = DiaryController(repository);
    await controller.initialize();
    await tester.pumpWidget(EchoPageApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text(entry.title));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey<String>('add_echo')));
    await tester.tap(find.byKey(const ValueKey<String>('add_echo')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('echo_body_field')),
      'Persist this exactly once.',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    repository.saveGate = Completer<void>();
    await tester.tap(find.byKey(const ValueKey<String>('save_echo')));
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('echo_body_field')),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(10, 100));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('echo_body_field')),
      findsOneWidget,
    );
    await tester.drag(find.byType(BottomSheet), const Offset(0, 500));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('echo_body_field')),
      findsOneWidget,
    );
    expect(controller.entryById(entry.id)!.echoes, isEmpty);

    repository.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('echo_body_field')), findsNothing);
    expect(controller.entryById(entry.id)!.echoes, hasLength(1));
  });

  testWidgets('editing a due thread preserves its exact revisit date', (
    tester,
  ) async {
    final dueDate = DateTime.now().subtract(const Duration(days: 2));
    final entry = sampleEntry(revisitAt: dueDate);
    final controller = await pumpDiary(
      tester,
      initial: DiarySnapshot(localeCode: 'en', entries: <DiaryEntry>[entry]),
    );

    await tester.tap(find.text(entry.title).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('title_field')),
      'Edited without rescheduling',
    );
    await tester.drag(
      find.byKey(const ValueKey<String>('entry_editor_scroll')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('save_entry')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('save_entry')));
    await tester.pumpAndSettle();

    expect(controller.entryById(entry.id)!.revisitAt, dueDate);
    expect(controller.entryById(entry.id)!.isDue(DateTime.now()), isTrue);
  });

  testWidgets('archive search finds text from a later echo', (tester) async {
    final echo = DiaryEcho(
      id: 'echo-1',
      createdAt: DateTime(2026, 10, 7),
      body: 'A copper-colored answer appeared.',
      shift: EchoShift.changed,
    );
    await pumpDiary(
      tester,
      initial: DiarySnapshot(
        localeCode: 'en',
        entries: <DiaryEntry>[
          sampleEntry(echoes: <DiaryEcho>[echo], closedAt: echo.createdAt),
        ],
      ),
    );

    await tester.tap(find.byIcon(Icons.auto_stories_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('search_field')),
      'copper-colored',
    );
    await tester.pump();

    expect(find.text('A small turning point'), findsOneWidget);
    expect(find.text('No matching threads found.'), findsNothing);
  });

  testWidgets('restore failure is visible and keeps the item in trash', (
    tester,
  ) async {
    final deleted = sampleEntry(deletedAt: DateTime(2026, 10, 1));
    final repository = FakeDiaryRepository(
      initial: DiarySnapshot(localeCode: 'en', entries: <DiaryEntry>[deleted]),
    );
    final controller = DiaryController(repository);
    await controller.initialize();
    await tester.pumpWidget(EchoPageApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.auto_stories_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recently Deleted · 1'));
    await tester.pumpAndSettle();
    repository.failSave = true;

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect(
      find.text('Not saved; existing data was unchanged.'),
      findsOneWidget,
    );
    expect(controller.trashEntries, hasLength(1));
  });

  testWidgets('clipboard platform failure is reported without success', (
    tester,
  ) async {
    final entry = sampleEntry();
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'clipboard-unavailable');
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await pumpDiary(
      tester,
      initial: DiarySnapshot(localeCode: 'en', entries: <DiaryEntry>[entry]),
    );
    await tester.tap(find.text(entry.title));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy full record'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not write to the system clipboard. Nothing was copied.'),
      findsOneWidget,
    );
    expect(find.text('Copied to the system clipboard'), findsNothing);
  });

  testWidgets(
    'Chinese locale and compact large-text home stay exception-free',
    (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());
      addTearDown(
        () => tester.platformDispatcher.clearTextScaleFactorTestValue(),
      );
      tester.view.physicalSize = const Size(640, 1136);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 3.2;
      final longEntry = sampleEntry(
        title: '这是一个用于验证小屏幕和大字体的很长标题',
        body: List<String>.filled(20, '这段文字会换行但不应遮住主要操作。').join(),
        question: '等一周以后，最重要的变化会是什么？',
      );

      await pumpDiary(
        tester,
        initial: DiarySnapshot(
          localeCode: 'zh',
          entries: <DiaryEntry>[longEntry],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('回声页'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('new_entry')), findsOneWidget);
      expect(tester.takeException(), isNull);

      final titleFinder = find.text(longEntry.title);
      final homeList = find
          .ancestor(of: titleFinder, matching: find.byType(ListView))
          .first;
      await tester.dragUntilVisible(
        titleFinder,
        homeList,
        const Offset(0, -240),
      );
      await tester.pumpAndSettle();
      await tester.drag(homeList, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.drag(homeList, const Offset(0, -220));
      await tester.pumpAndSettle();
      await tester.tap(titleFinder);
      await tester.pumpAndSettle();
      expect(find.text('当时写下'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('body_field')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      expect(find.text('数据与隐私'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unreadable storage presents a retry lock screen', (
    tester,
  ) async {
    final repository = FakeDiaryRepository(failLoad: true);
    final controller = DiaryController(repository);
    await controller.initialize();
    await tester.pumpWidget(EchoPageApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Local diary data is unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('new_entry')), findsNothing);
  });
}
