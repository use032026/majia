import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_edit/app/reader_edit_app.dart';
import 'package:reader_edit/app/reader_edit_store.dart';
import 'package:reader_edit/data/session_repository.dart';
import 'package:reader_edit/data/text_import_service.dart';
import 'package:reader_edit/domain/novel.dart';
import 'package:reader_edit/domain/revision_session.dart';

class _FakeTextImportService implements TextImportService {
  const _FakeTextImportService(this.file);

  final ImportedTextFile? file;

  @override
  Future<ImportedTextFile?> pickTextFile() async => file;
}

Future<ReaderEditStore> _pumpApp(
  WidgetTester tester, {
  String languageCode = 'zh',
  bool darkMode = false,
  List<RevisionSession>? sessions,
  List<Novel>? novels,
  TextImportService textImportService = const _FakeTextImportService(null),
}) async {
  final store = ReaderEditStore(
    MemorySessionRepository(
      languageCode: languageCode,
      darkMode: darkMode,
      sessions: sessions,
      novels: novels,
    ),
  );
  await store.load();
  await tester.pumpWidget(
    ReaderEditApp(store: store, textImportService: textImportService),
  );
  await tester.pumpAndSettle();
  return store;
}

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('settings sheet dismisses, reopens, and switches locale', (
    tester,
  ) async {
    await _pumpApp(tester);

    await _tapAndSettle(tester, find.byKey(const ValueKey('settings_button')));
    expect(find.text('数据与隐私'), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('数据与隐私'), findsNothing);

    await _tapAndSettle(tester, find.byKey(const ValueKey('settings_button')));
    await _tapAndSettle(tester, find.text('English'));
    expect(find.text('Settings & privacy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sample completes reader scan, revision, verification and export',
    (tester) async {
      String? copiedText;
      var clipboardShouldFail = true;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            if (clipboardShouldFail) {
              throw PlatformException(code: 'clipboard_unavailable');
            }
            copiedText =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final store = await _pumpApp(tester);

      await _tapAndSettle(tester, find.byKey(const ValueKey('sample_button')));
      expect(find.text('读者通读'), findsOneWidget);

      await _tapAndSettle(tester, find.byKey(const ValueKey('signal_clear')));
      await _tapAndSettle(
        tester,
        find.byKey(const ValueKey('scan_save_button')),
      );

      await _tapAndSettle(
        tester,
        find.byKey(const ValueKey('signal_dragging')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('scan_note_field')),
        '转折来得太晚',
      );
      await _tapAndSettle(
        tester,
        find.byKey(const ValueKey('scan_save_button')),
      );

      await _tapAndSettle(tester, find.byKey(const ValueKey('signal_clear')));
      await _tapAndSettle(
        tester,
        find.byKey(const ValueKey('scan_save_button')),
      );

      expect(find.text('修订队列'), findsOneWidget);
      expect(find.text('1 个信号 · 1 个待处理'), findsOneWidget);
      final flagged = store.sessions.single.passages[1];
      final frozenOriginal = flagged.original;
      await _tapAndSettle(
        tester,
        find.byKey(ValueKey('reassess_${flagged.id}')),
      );
      expect(find.text('读者通读'), findsOneWidget);
      expect(find.text(frozenOriginal), findsOneWidget);
      await _tapAndSettle(tester, find.byKey(const ValueKey('signal_lost')));
      await _tapAndSettle(
        tester,
        find.byKey(const ValueKey('scan_save_button')),
      );
      final reassessed = store.sessions.single.passages[1];
      expect(reassessed.id, flagged.id);
      expect(reassessed.original, frozenOriginal);
      expect(reassessed.signal.name, 'lost');
      expect(find.text('修订队列'), findsOneWidget);
      await _tapAndSettle(tester, find.text('修改'));

      await tester.enterText(
        find.byKey(const ValueKey('revision_field')),
        '她拆开信。第一句话只有七个字：“别搭明早六点的车。”',
      );
      await _tapAndSettle(
        tester,
        find.byKey(const ValueKey('resolved_checkbox')),
      );
      await _tapAndSettle(
        tester,
        find.byKey(const ValueKey('save_revision_button')),
      );

      expect(find.text('1 个信号 · 0 个待处理'), findsOneWidget);
      await _tapAndSettle(tester, find.byKey(const ValueKey('summary_button')));
      await _tapAndSettle(
        tester,
        find.byKey(const ValueKey('promise_know_check')),
      );
      await _tapAndSettle(
        tester,
        find.byKey(const ValueKey('promise_feel_check')),
      );
      await _tapAndSettle(
        tester,
        find.byKey(const ValueKey('promise_wonder_check')),
      );

      expect(store.sessions.single.isComplete, isTrue);
      await tester.drag(find.byType(ListView), const Offset(0, 1200));
      await tester.pumpAndSettle();
      expect(find.text('本轮修订完成'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -2400));
      await tester.pumpAndSettle();
      final copyLog = find.byKey(const ValueKey('copy_log_button'));
      await tester.ensureVisible(copyLog);
      await tester.tap(copyLog);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('无法写入系统剪贴板，请重试。'), findsOneWidget);
      expect(copiedText, isNull);
      clipboardShouldFail = false;
      await tester.tap(copyLog);
      await tester.pump(const Duration(milliseconds: 200));
      expect(copiedText, contains('修订记录'));
      expect(store.sessions.single.changedCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dirty new session confirms before discarding input', (
    tester,
  ) async {
    final store = await _pumpApp(tester);
    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('empty_new_session_button')),
    );
    await tester.enterText(find.byKey(const ValueKey('title_field')), '未保存');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的草稿？'), findsOneWidget);
    await _tapAndSettle(tester, find.text('取消'));
    expect(find.text('未保存'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await _tapAndSettle(tester, find.text('放弃'));
    expect(store.sessions, isEmpty);
    expect(find.text('开始一次修订'), findsOneWidget);
  });

  testWidgets('reassessing a flagged passage as clear removes it from queue', (
    tester,
  ) async {
    final original = RevisionSession(
      id: 'reassess',
      title: 'Reassess',
      knowPromise: 'Know',
      feelPromise: 'Feel',
      wonderPromise: 'Wonder',
      passages: const [
        PassageRevision(
          id: 'reassess_flagged',
          original: 'Flagged original.',
          revised: 'Flagged original.',
          signal: ReaderSignal.dragging,
        ),
        PassageRevision(
          id: 'reassess_clear',
          original: 'Clear original.',
          revised: 'Clear original.',
          signal: ReaderSignal.clear,
          isResolved: true,
        ),
      ],
      updatedAt: DateTime.utc(2026, 9, 30),
    );
    final store = await _pumpApp(tester, sessions: [original]);

    await _tapAndSettle(tester, find.byKey(const ValueKey('session_reassess')));
    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('reassess_reassess_flagged')),
    );
    expect(find.text('保存并返回队列'), findsOneWidget);
    await _tapAndSettle(tester, find.byKey(const ValueKey('signal_clear')));
    await _tapAndSettle(tester, find.byKey(const ValueKey('scan_save_button')));

    final updated = store.sessions.single;
    expect(updated.passages.first.id, original.passages.first.id);
    expect(updated.passages.first.original, original.passages.first.original);
    expect(updated.flaggedCount, 0);
    expect(updated.unresolvedCount, 0);
    expect(find.text('0 个信号 · 0 个待处理'), findsOneWidget);
    expect(find.text('通读没有发现阻塞点'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reassess_reassess_flagged')),
      findsNothing,
    );

    final reloadedStore = ReaderEditStore(store.repository);
    await reloadedStore.load();
    expect(reloadedStore.sessions.single.flaggedCount, 0);
    expect(reloadedStore.sessions.single.unresolvedCount, 0);
  });

  testWidgets(
    'compact English layout with large text has no framework exception',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await _pumpApp(tester, languageCode: 'en', darkMode: true);
      expect(find.textContaining('Write, read, and revise'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Start a revision'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Start a revision'), findsOneWidget);
    },
  );

  testWidgets('compact large-text core pages remain usable', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final session = RevisionSession(
      id: 'compact',
      title: 'Compact test',
      knowPromise: 'The point',
      feelPromise: 'Momentum',
      wonderPromise: 'What follows',
      passages: const [
        PassageRevision(
          id: 'compact_1',
          original: 'First passage.',
          revised: 'First passage.',
          signal: ReaderSignal.dragging,
          note: 'Needs pace',
        ),
        PassageRevision(
          id: 'compact_2',
          original: 'Second passage.',
          revised: 'Second passage.',
          signal: ReaderSignal.clear,
        ),
      ],
      updatedAt: DateTime.utc(2026, 9, 30),
    );
    await _pumpApp(
      tester,
      languageCode: 'en',
      darkMode: true,
      sessions: [session],
    );
    final sessionCard = find.byKey(ValueKey('session_${session.id}'));
    await tester.scrollUntilVisible(
      sessionCard,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await _tapAndSettle(tester, sessionCard);
    expect(find.text('Revision queue'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final reassess = find.byKey(
      ValueKey('reassess_${session.passages.first.id}'),
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -1600));
    await tester.pumpAndSettle();
    await _tapAndSettle(tester, reassess);
    expect(find.text('Reader scan'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    final revise = find.byKey(ValueKey('revise_${session.passages.first.id}'));
    if (revise.evaluate().isEmpty) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -1600));
      await tester.pumpAndSettle();
    }
    await _tapAndSettle(tester, revise);
    expect(find.text('Before & after'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await _tapAndSettle(tester, find.byKey(const ValueKey('summary_button')));
    expect(find.text('Review & export'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates a novel and edits a chapter from its reading view', (
    tester,
  ) async {
    final store = await _pumpApp(tester);

    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('create_novel_button')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('novel_title_field')),
      '长篇测试',
    );
    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('create_novel_submit_button')),
    );
    expect(find.text('章节'), findsOneWidget);

    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('add_chapter_button')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('chapter_title_field')),
      '第一章',
    );
    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('create_chapter_submit_button')),
    );
    expect(find.byKey(const ValueKey('chapter_edit_view')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('edit_chapter_content_field')),
      '这是可以直接编辑的正文。',
    );
    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('save_chapter_button')),
    );
    expect(find.text('这是可以直接编辑的正文。'), findsOneWidget);

    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('edit_chapter_button')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit_chapter_content_field')),
      '阅读时切换编辑后的正文。',
    );
    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('save_chapter_button')),
    );

    final novel = store.novels.single;
    expect(novel.chapters.single.content, '阅读时切换编辑后的正文。');
    expect(find.text('阅读时切换编辑后的正文。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('imports a long-form file into readable chapters', (
    tester,
  ) async {
    final store = await _pumpApp(
      tester,
      textImportService: const _FakeTextImportService(
        ImportedTextFile(
          name: '雾站.txt',
          content: '第1章 到站\n第一章正文。\n\n第2章 来信\n第二章正文。',
        ),
      ),
    );

    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('import_novel_button')),
    );
    expect(find.text('2 章 · 12 字符'), findsOneWidget);
    expect(store.novels.single.chapters, hasLength(2));

    await _tapAndSettle(
      tester,
      find.byKey(ValueKey('chapter_${store.novels.single.chapters.first.id}')),
    );
    expect(find.text('第一章正文。'), findsOneWidget);
    expect(find.byKey(const ValueKey('edit_chapter_button')), findsOneWidget);
  });
}
