import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_edit/l10n/app_strings.dart';
import 'package:reader_edit/app/reader_edit_store.dart';
import 'package:reader_edit/data/session_repository.dart';
import 'package:reader_edit/domain/revision_session.dart';

void main() {
  test(
    'legacy sample follows locale with its signals and notes intact',
    () async {
      const chinese = AppStrings(Locale('zh'));
      final repository = MemorySessionRepository(languageCode: 'zh');
      final store = ReaderEditStore(repository);
      await store.load();
      final sample = await store.createSession(
        title: chinese.sampleTitle,
        draft: chinese.sampleDraft,
        knowPromise: chinese.sampleKnow,
        feelPromise: chinese.sampleFeel,
        wonderPromise: chinese.sampleWonder,
      );
      await store.recordSignal(
        sessionId: sample.id,
        passageId: sample.passages.first.id,
        signal: ReaderSignal.dragging,
        note: '保留我的备注',
      );
      await store.setLanguageCode('en');
      final english = store.sessionById(sample.id);
      expect(english.title, 'The Letter at Fog Station');
      expect(store.sessions.single.title, english.title);
      expect(
        english.passages.first.original,
        startsWith('After the last train left, Mara'),
      );
      expect(
        english.passages.every((p) => countCjkCharacters(p.original) == 0),
        isTrue,
      );
      expect(english.passages.first.signal, ReaderSignal.dragging);
      expect(english.passages.first.note, '保留我的备注');
      expect(english.knowPromise, 'Someone at the station knows Mara’s plans');
      expect(english.changedCount, 0);
      expect(
        repository.sessions.single.passages.first.original,
        sample.passages.first.original,
      );
      final reloaded = ReaderEditStore(repository);
      await reloaded.load();
      expect(reloaded.sessions.single.title, 'The Letter at Fog Station');
      await reloaded.setLanguageCode('zh');
      expect(reloaded.sessions.single.title, '雾站来信');
      expect(reloaded.sessions.single.passages.first.note, '保留我的备注');
    },
  );

  test(
    'switching locale preserves rewritten sample text and ordinary drafts',
    () async {
      const chinese = AppStrings(Locale('zh'));
      final store = ReaderEditStore(
        MemorySessionRepository(languageCode: 'zh'),
      );
      await store.load();
      final sample = await store.createSession(
        title: chinese.sampleTitle,
        draft: chinese.sampleDraft,
        knowPromise: chinese.sampleKnow,
        feelPromise: chinese.sampleFeel,
        wonderPromise: chinese.sampleWonder,
      );
      await store.saveRevision(
        sessionId: sample.id,
        passageId: sample.passages.first.id,
        revised: '这是我自己改写的段落。',
        isResolved: false,
      );
      final custom = await store.createSession(
        title: '雾站来信',
        draft: '我的正文。\n\n第二段。',
        knowPromise: 'A',
        feelPromise: 'B',
        wonderPromise: 'C',
      );
      await store.setLanguageCode('en');
      expect(
        store.sessionById(sample.id).passages.first.revised,
        '这是我自己改写的段落。',
      );
      expect(
        store.sessionById(sample.id).passages.first.original,
        sample.passages.first.original,
      );
      expect(store.sessionById(custom.id).title, '雾站来信');
      expect(store.sessionById(custom.id).passages.first.original, '我的正文。');
    },
  );

  test(
    'commits the reader-signal to revision workflow and persists it',
    () async {
      final repository = MemorySessionRepository();
      final store = ReaderEditStore(repository);
      await store.load();

      final session = await store.createSession(
        title: 'Test',
        draft: 'First.\n\nSecond.',
        knowPromise: 'A',
        feelPromise: 'B',
        wonderPromise: 'C',
      );
      await store.recordSignal(
        sessionId: session.id,
        passageId: session.passages.first.id,
        signal: ReaderSignal.dragging,
        note: 'Too slow',
      );
      await store.recordSignal(
        sessionId: session.id,
        passageId: session.passages.last.id,
        signal: ReaderSignal.clear,
        note: '',
      );
      await store.saveRevision(
        sessionId: session.id,
        passageId: session.passages.first.id,
        revised: 'First, quickly.',
        isResolved: true,
      );
      await store.setPromiseChecks(
        sessionId: session.id,
        knowChecked: true,
        feelChecked: true,
        wonderChecked: true,
      );

      expect(store.sessionById(session.id).isComplete, isTrue);
      expect(repository.sessions.single.isComplete, isTrue);
    },
  );

  test('does not mutate visible state when persistence fails', () async {
    final repository = MemorySessionRepository();
    final store = ReaderEditStore(repository);
    await store.load();
    repository.failNextSave = true;

    await expectLater(
      store.createSession(
        title: 'Test',
        draft: 'First.\n\nSecond.',
        knowPromise: 'A',
        feelPromise: 'B',
        wonderPromise: 'C',
      ),
      throwsStateError,
    );

    expect(store.sessions, isEmpty);
    expect(repository.sessions, isEmpty);
  });

  test('deletion uses a non-retaining persistence commit', () async {
    final repository = MemorySessionRepository();
    final store = ReaderEditStore(repository);
    await store.load();
    final session = await store.createSession(
      title: 'Private',
      draft: 'First.\n\nSecond.',
      knowPromise: 'A',
      feelPromise: 'B',
      wonderPromise: 'C',
    );

    await store.deleteSession(session.id);

    expect(store.sessions, isEmpty);
    expect(repository.lastRetainPrevious, isFalse);
  });

  test('creates, imports, and edits local novels without an account', () async {
    final repository = MemorySessionRepository();
    final store = ReaderEditStore(repository);
    await store.load();

    final novel = await store.createNovel(
      title: 'Local story',
      description: 'Offline first',
    );
    final chapter = await store.addChapter(
      novelId: novel.id,
      title: 'Chapter one',
      content: 'Original text.',
    );
    await store.updateChapter(
      novelId: novel.id,
      chapterId: chapter.id,
      title: 'Chapter one',
      content: 'Edited while reading.',
    );
    await store.importChapters(
      novelId: novel.id,
      fileName: 'more.md',
      content: '# Chapter two\nImported text.',
    );

    expect(store.novelById(novel.id).chapters, hasLength(2));
    expect(
      store.chapterById(novel.id, chapter.id).content,
      'Edited while reading.',
    );
    expect(repository.novels.single.chapters.last.title, 'Chapter two');
  });

  test('failed chapter save leaves the visible chapter unchanged', () async {
    final repository = MemorySessionRepository();
    final store = ReaderEditStore(repository);
    await store.load();
    final novel = await store.createNovel(title: 'Story');
    final chapter = await store.addChapter(
      novelId: novel.id,
      title: 'One',
      content: 'Original',
    );
    repository.failNextSave = true;

    await expectLater(
      store.updateChapter(
        novelId: novel.id,
        chapterId: chapter.id,
        title: 'One',
        content: 'Should not commit',
      ),
      throwsStateError,
    );

    expect(store.chapterById(novel.id, chapter.id).content, 'Original');
  });
}
