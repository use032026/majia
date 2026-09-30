import 'package:flutter/foundation.dart';

import '../data/session_repository.dart';
import '../domain/novel.dart';
import '../domain/revision_session.dart';

class ReaderEditStore extends ChangeNotifier {
  ReaderEditStore(this.repository);

  final SessionRepository repository;

  List<RevisionSession> _sessions = const [];
  List<Novel> _novels = const [];
  String _languageCode = 'zh';
  bool _darkMode = false;
  bool _isReady = false;
  bool _isBusy = false;
  bool _loadFailed = false;
  bool _recoveredFromBackup = false;
  Object? _lastError;

  List<RevisionSession> get sessions => List.unmodifiable(_sessions);
  List<Novel> get novels => List.unmodifiable(_novels);
  String get languageCode => _languageCode;
  bool get darkMode => _darkMode;
  bool get isReady => _isReady;
  bool get isBusy => _isBusy;
  bool get loadFailed => _loadFailed;
  bool get recoveredFromBackup => _recoveredFromBackup;
  Object? get lastError => _lastError;

  Future<void> load() async {
    _isReady = false;
    _lastError = null;
    _loadFailed = false;
    notifyListeners();
    try {
      final result = await repository.loadSessions();
      _sessions = List<RevisionSession>.from(result.sessions)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _novels = List<Novel>.from(result.novels)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _recoveredFromBackup = result.recoveredFromBackup;
      _languageCode = await repository.loadLanguageCode() ?? 'zh';
      _darkMode = await repository.loadDarkMode();
    } on Object catch (error) {
      _lastError = error;
      _loadFailed = true;
    } finally {
      _isReady = true;
      notifyListeners();
    }
  }

  RevisionSession sessionById(String id) {
    return _sessions.firstWhere((session) => session.id == id);
  }

  Novel novelById(String id) {
    return _novels.firstWhere((novel) => novel.id == id);
  }

  NovelChapter chapterById(String novelId, String chapterId) {
    return novelById(
      novelId,
    ).chapters.firstWhere((chapter) => chapter.id == chapterId);
  }

  Future<Novel> createNovel({
    required String title,
    String description = '',
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const FormatException('A novel title is required.');
    }
    final now = DateTime.now();
    final novel = Novel(
      id: 'novel_${now.microsecondsSinceEpoch}',
      title: normalizedTitle,
      description: description.trim(),
      chapters: const [],
      createdAt: now,
      updatedAt: now,
    );
    await _commit(_sessions, nextNovels: [novel, ..._novels]);
    return novel;
  }

  Future<Novel> importNovel({
    required String fileName,
    required String content,
  }) async {
    final plan = planNovelImport(fileName: fileName, content: content);
    final now = DateTime.now();
    final novelId = 'novel_${now.microsecondsSinceEpoch}';
    final novel = Novel(
      id: novelId,
      title: plan.title,
      description: '',
      chapters: [
        for (var index = 0; index < plan.chapters.length; index++)
          NovelChapter(
            id: '${novelId}_chapter_$index',
            title: plan.chapters[index].title,
            content: plan.chapters[index].content,
            createdAt: now,
            updatedAt: now,
          ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    await _commit(_sessions, nextNovels: [novel, ..._novels]);
    return novel;
  }

  Future<List<NovelChapter>> importChapters({
    required String novelId,
    required String fileName,
    required String content,
  }) async {
    final plan = planNovelImport(fileName: fileName, content: content);
    final novel = novelById(novelId);
    final now = DateTime.now();
    final imported = <NovelChapter>[
      for (var index = 0; index < plan.chapters.length; index++)
        NovelChapter(
          id: '${novelId}_chapter_${now.microsecondsSinceEpoch}_$index',
          title:
              plan.chapters.length == 1 &&
                  plan.chapters[index].title == '正文 / Main text'
              ? plan.title
              : plan.chapters[index].title,
          content: plan.chapters[index].content,
          createdAt: now,
          updatedAt: now,
        ),
    ];
    await _replaceNovel(
      novel.copyWith(
        chapters: [...novel.chapters, ...imported],
        updatedAt: now,
      ),
    );
    return imported;
  }

  Future<NovelChapter> addChapter({
    required String novelId,
    required String title,
    String content = '',
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const FormatException('A chapter title is required.');
    }
    if (content.length > NovelChapter.maxContentCharacters) {
      throw const FormatException('The chapter is too large.');
    }
    final novel = novelById(novelId);
    final now = DateTime.now();
    final chapter = NovelChapter(
      id: '${novelId}_chapter_${now.microsecondsSinceEpoch}',
      title: normalizedTitle,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    await _replaceNovel(
      novel.copyWith(chapters: [...novel.chapters, chapter], updatedAt: now),
    );
    return chapter;
  }

  Future<void> updateChapter({
    required String novelId,
    required String chapterId,
    required String title,
    required String content,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const FormatException('A chapter title is required.');
    }
    if (content.length > NovelChapter.maxContentCharacters) {
      throw const FormatException('The chapter is too large.');
    }
    final novel = novelById(novelId);
    final now = DateTime.now();
    final nextChapters = novel.chapters
        .map(
          (chapter) => chapter.id == chapterId
              ? chapter.copyWith(
                  title: normalizedTitle,
                  content: content,
                  updatedAt: now,
                )
              : chapter,
        )
        .toList(growable: false);
    if (!nextChapters.any((chapter) => chapter.id == chapterId)) {
      throw StateError('Chapter not found.');
    }
    await _replaceNovel(novel.copyWith(chapters: nextChapters, updatedAt: now));
  }

  Future<void> deleteChapter(String novelId, String chapterId) async {
    final novel = novelById(novelId);
    await _replaceNovel(
      novel.copyWith(
        chapters: novel.chapters
            .where((chapter) => chapter.id != chapterId)
            .toList(growable: false),
        updatedAt: DateTime.now(),
      ),
      retainPrevious: false,
    );
  }

  Future<void> deleteNovel(String novelId) async {
    await _commit(
      _sessions,
      nextNovels: _novels
          .where((novel) => novel.id != novelId)
          .toList(growable: false),
      retainPrevious: false,
    );
  }

  Future<RevisionSession> createSession({
    required String title,
    required String draft,
    required String knowPromise,
    required String feelPromise,
    required String wonderPromise,
  }) async {
    final now = DateTime.now();
    final id = 'session_${now.microsecondsSinceEpoch}';
    final paragraphs = splitDraft(draft);
    final session = RevisionSession(
      id: id,
      title: title.trim(),
      knowPromise: knowPromise.trim(),
      feelPromise: feelPromise.trim(),
      wonderPromise: wonderPromise.trim(),
      updatedAt: now,
      passages: [
        for (var index = 0; index < paragraphs.length; index++)
          PassageRevision(
            id: '${id}_passage_$index',
            original: paragraphs[index],
            revised: paragraphs[index],
          ),
      ],
    );
    await _commit([session, ..._sessions]);
    return session;
  }

  Future<void> recordSignal({
    required String sessionId,
    required String passageId,
    required ReaderSignal signal,
    required String note,
  }) async {
    final session = sessionById(sessionId);
    final updatedPassages = session.passages
        .map((passage) {
          if (passage.id != passageId) {
            return passage;
          }
          return passage.copyWith(
            signal: signal,
            note: note.trim(),
            isResolved: signal == ReaderSignal.clear,
          );
        })
        .toList(growable: false);
    await _replace(
      session.copyWith(passages: updatedPassages, updatedAt: DateTime.now()),
    );
  }

  Future<void> saveRevision({
    required String sessionId,
    required String passageId,
    required String revised,
    required bool isResolved,
  }) async {
    final session = sessionById(sessionId);
    final updatedPassages = session.passages
        .map((passage) {
          if (passage.id != passageId) {
            return passage;
          }
          return passage.copyWith(
            revised: revised.trim(),
            isResolved: isResolved,
          );
        })
        .toList(growable: false);
    await _replace(
      session.copyWith(passages: updatedPassages, updatedAt: DateTime.now()),
    );
  }

  Future<void> reopenRevision({
    required String sessionId,
    required String passageId,
  }) async {
    final session = sessionById(sessionId);
    final updatedPassages = session.passages
        .map((passage) {
          return passage.id == passageId
              ? passage.copyWith(isResolved: false)
              : passage;
        })
        .toList(growable: false);
    await _replace(
      session.copyWith(passages: updatedPassages, updatedAt: DateTime.now()),
    );
  }

  Future<void> setPromiseChecks({
    required String sessionId,
    bool? knowChecked,
    bool? feelChecked,
    bool? wonderChecked,
  }) async {
    final session = sessionById(sessionId);
    await _replace(
      session.copyWith(
        knowChecked: knowChecked,
        feelChecked: feelChecked,
        wonderChecked: wonderChecked,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteSession(String sessionId) async {
    await _commit(
      _sessions.where((session) => session.id != sessionId).toList(),
      retainPrevious: false,
    );
  }

  Future<void> clearAll() async {
    await _commit(const [], nextNovels: const [], retainPrevious: false);
  }

  Future<void> setLanguageCode(String value) async {
    if (value == _languageCode) {
      return;
    }
    _setBusy(true);
    try {
      await repository.saveLanguageCode(value);
      _languageCode = value;
      _lastError = null;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> setDarkMode(bool value) async {
    if (value == _darkMode) {
      return;
    }
    _setBusy(true);
    try {
      await repository.saveDarkMode(value);
      _darkMode = value;
      _lastError = null;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  void dismissRecoveryNotice() {
    _recoveredFromBackup = false;
    notifyListeners();
  }

  void dismissError() {
    _lastError = null;
    notifyListeners();
  }

  Future<void> _replace(RevisionSession updated) async {
    final next =
        _sessions
            .map((session) => session.id == updated.id ? updated : session)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _commit(next);
  }

  Future<void> _replaceNovel(
    Novel updated, {
    bool retainPrevious = true,
  }) async {
    final next =
        _novels
            .map((novel) => novel.id == updated.id ? updated : novel)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _commit(_sessions, nextNovels: next, retainPrevious: retainPrevious);
  }

  Future<void> _commit(
    List<RevisionSession> next, {
    List<Novel>? nextNovels,
    bool retainPrevious = true,
  }) async {
    if (_isBusy) {
      throw StateError('Another local save is still in progress.');
    }
    _setBusy(true);
    try {
      final novelsToSave = nextNovels ?? _novels;
      await repository.saveSessions(
        next,
        novels: novelsToSave,
        retainPrevious: retainPrevious,
      );
      _sessions = List.unmodifiable(next);
      _novels = List.unmodifiable(novelsToSave);
      _lastError = null;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }
}
