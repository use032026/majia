import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_edit/app/reader_edit_app.dart';
import 'package:reader_edit/app/reader_edit_store.dart';
import 'package:reader_edit/data/session_repository.dart';
import 'package:reader_edit/data/text_import_service.dart';
import 'package:reader_edit/domain/novel.dart';
import 'package:reader_edit/domain/revision_session.dart';
import 'package:reader_edit/ui/changes_page.dart';
import 'package:reader_edit/ui/chapter_reader_page.dart';
import 'package:reader_edit/ui/create_chapter_page.dart';
import 'package:reader_edit/ui/create_novel_page.dart';
import 'package:reader_edit/ui/create_session_page.dart';
import 'package:reader_edit/ui/home_page.dart';
import 'package:reader_edit/ui/novel_detail_page.dart';
import 'package:reader_edit/ui/revision_editor_page.dart';
import 'package:reader_edit/ui/revision_queue_page.dart';
import 'package:reader_edit/ui/scan_page.dart';
import 'package:reader_edit/ui/summary_page.dart';

const _importService = FileSelectorTextImportService();

Future<ReaderEditStore> _pumpWorkspace(
  WidgetTester tester,
  double bottom,
) async {
  tester.view.physicalSize = const Size(390, 700);
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = FakeViewPadding(bottom: bottom);
  tester.view.padding = FakeViewPadding(bottom: bottom);
  addTearDown(tester.view.reset);
  final now = DateTime.utc(2026, 10, 16);
  final text = List.filled(18, '车站外下着雨，远处的广播传来熟悉的声音。').join('\n');
  final store = ReaderEditStore(
    MemorySessionRepository(
      onboardingCompleted: true,
      novels: [
        Novel(
          id: 'novel',
          title: '测试小说',
          description: '',
          chapters: List.generate(
            8,
            (i) => NovelChapter(
              id: 'c$i',
              title: '第 $i 章',
              content: text,
              createdAt: now,
              updatedAt: now,
            ),
          ),
          createdAt: now,
          updatedAt: now,
        ),
      ],
      sessions: List.generate(
        8,
        (i) => RevisionSession(
          id: 's$i',
          title: '修订 $i',
          knowPromise: '知道',
          feelPromise: '感受',
          wonderPromise: '好奇',
          passages: [
            PassageRevision(
              id: 'p',
              original: text,
              revised: '$text\n新的结尾。',
              signal: ReaderSignal.dragging,
              note: List.filled(12, '这段的转折需要更清楚。').join('\n'),
            ),
          ],
          updatedAt: now,
        ),
      ),
    ),
  );
  await store.load();
  await tester.pumpWidget(ReaderEditApp(store: store));
  await tester.pumpAndSettle();
  return store;
}

Future<void> _open(WidgetTester tester, Widget page) async {
  Navigator.of(
    tester.element(find.byType(HomePage)),
  ).push<void>(MaterialPageRoute(builder: (_) => page));
  await tester.pumpAndSettle();
}

Future<void> _scrollToEnd(WidgetTester tester, Finder list) async {
  final scrollable = find
      .descendant(of: list, matching: find.byType(Scrollable))
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  for (var i = 0; i < 3; i++) {
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
  }
}

void main() {
  final pages = <String, Widget Function(ReaderEditStore)>{
    'home': (s) => HomePage(store: s, importService: _importService),
    'new novel': (s) => CreateNovelPage(store: s),
    'new chapter': (s) => CreateChapterPage(store: s, novelId: 'novel'),
    'new revision': (s) => CreateSessionPage(store: s),
    'novel': (s) => NovelDetailPage(
      store: s,
      novelId: 'novel',
      importService: _importService,
    ),
    'reading': (s) =>
        ChapterReaderPage(store: s, novelId: 'novel', chapterId: 'c0'),
    'editing': (s) => ChapterReaderPage(
      store: s,
      novelId: 'novel',
      chapterId: 'c0',
      initiallyEditing: true,
    ),
    'scan': (s) => ScanPage(store: s, sessionId: 's0'),
    'revision editor': (s) =>
        RevisionEditorPage(store: s, sessionId: 's0', passageId: 'p'),
    'summary': (s) => SummaryPage(store: s, sessionId: 's0'),
    'changes': (s) => ChangesPage(session: s.sessionById('s0')),
  };
  final lastKeys = <String, String>{
    'home': 'session_s7',
    'new novel': 'create_novel_submit_button',
    'new chapter': 'create_chapter_submit_button',
    'new revision': 'create_submit_button',
    'novel': 'chapter_c7',
    'reading': 'chapter_revision_button',
    'scan': 'scan_save_button',
    'revision editor': 'save_revision_button',
    'summary': 'copy_log_button',
  };
  for (final bottom in [0.0, 34.0]) {
    for (final entry in pages.entries) {
      testWidgets(
        '${entry.key} fills the viewport and protects its end with $bottom bottom inset',
        (tester) async {
          final store = await _pumpWorkspace(tester, bottom);
          await _open(tester, entry.value(store));
          final list = find.byType(ListView).last;
          expect(tester.getRect(list).bottom, closeTo(700, 0.1));
          await _scrollToEnd(tester, list);
          final lastKey = lastKeys[entry.key];
          if (lastKey != null) {
            expect(
              tester.getRect(find.byKey(ValueKey(lastKey))).bottom,
              lessThanOrEqualTo(700 - bottom - 12),
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'queue reserves its button bar once without a large trailing gap',
    (tester) async {
      final store = await _pumpWorkspace(tester, 34);
      await _open(tester, RevisionQueuePage(store: store, sessionId: 's0'));
      final list = find.byType(ListView).last;
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      final bar = find.byWidget(scaffold.bottomNavigationBar!);
      expect(tester.getRect(bar).bottom, 700);
      expect(
        tester.getRect(list).bottom,
        closeTo(tester.getRect(bar).top, 0.1),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('summary_button'))).bottom,
        lessThanOrEqualTo(654),
      );
      await _scrollToEnd(tester, list);
      final card = find.descendant(of: list, matching: find.byType(Card)).last;
      final gap = tester.getRect(list).bottom - tester.getRect(card).bottom;
      expect(gap, inInclusiveRange(24, 40));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keyboard shrinks the scan viewport once and leaves save reachable',
    (tester) async {
      final store = await _pumpWorkspace(tester, 34);
      await _open(tester, ScanPage(store: store, sessionId: 's0'));
      await _scrollToEnd(tester, find.byType(ListView).last);
      await tester.showKeyboard(find.byKey(const ValueKey('scan_note_field')));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      tester.view.padding = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      final list = find.byType(ListView).last;
      expect(tester.getRect(list).bottom, 400);
      await _scrollToEnd(tester, list);
      expect(
        tester.getRect(find.byKey(const ValueKey('scan_save_button'))).bottom,
        closeTo(376, 0.1),
      );
      tester.view.viewInsets = FakeViewPadding.zero;
      tester.view.padding = const FakeViewPadding(bottom: 34);
      await tester.pumpAndSettle();
      await _scrollToEnd(tester, list);
      expect(
        tester.getRect(find.byKey(const ValueKey('scan_save_button'))).bottom,
        closeTo(654, 0.1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rotation updates the reading inset and protects landscape cutouts',
    (tester) async {
      final store = await _pumpWorkspace(tester, 34);
      await _open(
        tester,
        ChapterReaderPage(store: store, novelId: 'novel', chapterId: 'c0'),
      );
      tester.view.physicalSize = const Size(780, 390);
      tester.view.viewPadding = const FakeViewPadding(
        left: 44,
        right: 44,
        bottom: 21,
      );
      tester.view.padding = const FakeViewPadding(
        left: 44,
        right: 44,
        bottom: 21,
      );
      await tester.pumpAndSettle();
      final list = find.byType(ListView).last;
      expect(tester.getRect(list), Rect.fromLTRB(44, 56, 736, 390));
      await _scrollToEnd(tester, list);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('chapter_revision_button')))
            .bottom,
        closeTo(357, 0.1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings scrolls its final action above the home indicator', (
    tester,
  ) async {
    await _pumpWorkspace(tester, 34);
    await tester.tap(find.byKey(const ValueKey('settings_button')));
    await tester.pumpAndSettle();
    final scroll = find.byType(SingleChildScrollView).last;
    expect(tester.getRect(scroll).bottom, 700);
    await _scrollToEnd(tester, scroll);
    final erase = find.widgetWithText(CupertinoButton, '清空全部本地数据');
    expect(tester.getRect(erase).bottom, lessThanOrEqualTo(654));
    expect(tester.takeException(), isNull);
  });
}
