import 'package:flutter/foundation.dart';

import '../data/diary_repository.dart';
import '../domain/diary_entry.dart';

typedef Clock = DateTime Function();

class DiaryController extends ChangeNotifier {
  DiaryController(this._repository, {Clock? clock})
    : _clock = clock ?? DateTime.now;

  final DiaryRepository _repository;
  final Clock _clock;

  DiarySnapshot _snapshot = const DiarySnapshot.empty();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _storageLocked = false;
  bool _recoveredFromBackup = false;
  String? _error;

  DiarySnapshot get snapshot => _snapshot;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get storageLocked => _storageLocked;
  bool get recoveredFromBackup => _recoveredFromBackup;
  String? get error => _error;

  List<DiaryEntry> get activeEntries {
    final values = _snapshot.entries
        .where((entry) => !entry.isDeleted)
        .toList();
    values.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return values;
  }

  List<DiaryEntry> get trashEntries {
    final values = _snapshot.entries.where((entry) => entry.isDeleted).toList();
    values.sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return values;
  }

  List<DiaryEntry> openThreads({DateTime? now}) {
    final current = now ?? _clock();
    final values = activeEntries.where((entry) => entry.hasOpenThread).toList();
    values.sort((a, b) {
      final aDate = a.revisitAt ?? current.add(const Duration(days: 36500));
      final bDate = b.revisitAt ?? current.add(const Duration(days: 36500));
      return aDate.compareTo(bDate);
    });
    return values;
  }

  List<DiaryEntry> dueEntries({DateTime? now}) {
    final current = now ?? _clock();
    return openThreads(
      now: current,
    ).where((entry) => entry.isDue(current)).toList(growable: false);
  }

  DiaryEntry? entryById(String id) {
    for (final entry in _snapshot.entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _repository.load();
      _snapshot = result.snapshot;
      _recoveredFromBackup = result.recoveredFromBackup;
      _storageLocked = false;
    } catch (error) {
      _storageLocked = true;
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void dismissRecoveryNotice() {
    _recoveredFromBackup = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<DiaryEntry?> createEntry({
    required String title,
    required String body,
    required EntryMood mood,
    required String futureQuestion,
    DateTime? revisitAt,
  }) async {
    if (body.trim().isEmpty) return null;
    final now = _clock();
    final trimmedQuestion = futureQuestion.trim();
    if (trimmedQuestion.isNotEmpty && revisitAt == null) return null;
    final entry = DiaryEntry(
      id: 'entry_${now.microsecondsSinceEpoch.toRadixString(36)}',
      createdAt: now,
      updatedAt: now,
      title: title.trim(),
      body: body.trim(),
      mood: mood,
      futureQuestion: trimmedQuestion,
      revisitAt: trimmedQuestion.isEmpty ? null : revisitAt,
      echoes: const <DiaryEcho>[],
      closedAt: trimmedQuestion.isEmpty ? now : null,
      deletedAt: null,
    );
    final candidate = _snapshot.copyWith(
      entries: <DiaryEntry>[..._snapshot.entries, entry],
    );
    return await _commit(candidate) ? entry : null;
  }

  Future<bool> updateEntry({
    required String id,
    required String title,
    required String body,
    required EntryMood mood,
    required String futureQuestion,
    DateTime? revisitAt,
  }) async {
    if (body.trim().isEmpty) return false;
    final current = entryById(id);
    if (current == null || current.isDeleted) return false;
    final question = futureQuestion.trim();
    final shouldOpen = question.isNotEmpty && revisitAt != null;
    final updated = current.copyWith(
      updatedAt: _clock(),
      title: title.trim(),
      body: body.trim(),
      mood: mood,
      futureQuestion: question,
      revisitAt: revisitAt,
      clearRevisitAt: question.isEmpty || (current.isClosed && !shouldOpen),
      closedAt: question.isEmpty ? _clock() : null,
      clearClosedAt: shouldOpen,
    );
    return _replace(updated);
  }

  Future<bool> addEcho({
    required String entryId,
    required String body,
    required EchoShift shift,
    required bool closeThread,
    DateTime? nextRevisitAt,
  }) async {
    if (body.trim().isEmpty) return false;
    if (!closeThread && nextRevisitAt == null) return false;
    final current = entryById(entryId);
    if (current == null || current.isDeleted || !current.hasOpenThread) {
      return false;
    }
    final now = _clock();
    final echo = DiaryEcho(
      id: 'echo_${now.microsecondsSinceEpoch.toRadixString(36)}',
      createdAt: now,
      body: body.trim(),
      shift: shift,
    );
    final updated = current.copyWith(
      updatedAt: now,
      echoes: <DiaryEcho>[...current.echoes, echo],
      closedAt: closeThread ? now : null,
      clearClosedAt: !closeThread,
      revisitAt: closeThread ? null : nextRevisitAt,
      clearRevisitAt: closeThread,
    );
    return _replace(updated);
  }

  Future<bool> moveToTrash(String id) async {
    final current = entryById(id);
    if (current == null || current.isDeleted) return false;
    return _replace(current.copyWith(updatedAt: _clock(), deletedAt: _clock()));
  }

  Future<bool> restore(String id) async {
    final current = entryById(id);
    if (current == null || !current.isDeleted) return false;
    return _replace(
      current.copyWith(updatedAt: _clock(), clearDeletedAt: true),
    );
  }

  Future<bool> deleteForever(String id) async {
    final current = entryById(id);
    if (current == null || !current.isDeleted) return false;
    final entries = _snapshot.entries.where((entry) => entry.id != id).toList();
    return _commit(_snapshot.copyWith(entries: entries), discardHistory: true);
  }

  Future<bool> emptyTrash() async {
    final entries = _snapshot.entries
        .where((entry) => !entry.isDeleted)
        .toList();
    return _commit(_snapshot.copyWith(entries: entries), discardHistory: true);
  }

  Future<bool> clearAll() async {
    return _commit(
      _snapshot.copyWith(entries: const <DiaryEntry>[]),
      discardHistory: true,
    );
  }

  Future<bool> setLocale(String code) {
    return _commit(_snapshot.copyWith(localeCode: code));
  }

  Future<bool> setTheme(String mode) {
    return _commit(_snapshot.copyWith(themeMode: mode));
  }

  Future<bool> _replace(DiaryEntry replacement) {
    final entries = _snapshot.entries
        .map((entry) => entry.id == replacement.id ? replacement : entry)
        .toList(growable: false);
    return _commit(_snapshot.copyWith(entries: entries));
  }

  Future<bool> _commit(
    DiarySnapshot candidate, {
    bool discardHistory = false,
  }) async {
    if (_isSaving || _storageLocked) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.save(candidate, discardHistory: discardHistory);
      _snapshot = candidate;
      return true;
    } catch (error) {
      _error = error.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
