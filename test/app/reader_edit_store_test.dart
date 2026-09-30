import 'package:flutter_test/flutter_test.dart';
import 'package:reader_edit/app/reader_edit_store.dart';
import 'package:reader_edit/data/session_repository.dart';
import 'package:reader_edit/domain/revision_session.dart';

void main() {
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
