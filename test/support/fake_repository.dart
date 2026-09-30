import 'dart:async';

import 'package:diary/data/diary_repository.dart';
import 'package:diary/domain/diary_entry.dart';

class FakeDiaryRepository implements DiaryRepository {
  FakeDiaryRepository({
    DiarySnapshot initial = const DiarySnapshot.empty(),
    this.failLoad = false,
    this.failSave = false,
    this.recoveredFromBackup = false,
  }) : stored = initial;

  DiarySnapshot stored;
  bool failLoad;
  bool failSave;
  bool recoveredFromBackup;
  Completer<void>? saveGate;
  int saveCount = 0;
  bool lastDiscardHistory = false;

  @override
  Future<DiaryLoadResult> load() async {
    if (failLoad) throw const DiaryDataException('load failed');
    return DiaryLoadResult(
      snapshot: stored,
      recoveredFromBackup: recoveredFromBackup,
    );
  }

  @override
  Future<void> save(
    DiarySnapshot snapshot, {
    bool discardHistory = false,
  }) async {
    saveCount += 1;
    lastDiscardHistory = discardHistory;
    final gate = saveGate;
    if (gate != null) await gate.future;
    if (failSave) throw const DiaryDataException('save failed');
    stored = snapshot;
  }
}

DiaryEntry sampleEntry({
  String id = 'entry-1',
  DateTime? now,
  String title = 'A small turning point',
  String body = 'I finally asked the question I had been avoiding.',
  String question = 'Will the answer still feel difficult next week?',
  DateTime? revisitAt,
  List<DiaryEcho> echoes = const <DiaryEcho>[],
  DateTime? closedAt,
  DateTime? deletedAt,
}) {
  final created = now ?? DateTime(2026, 9, 30, 9);
  return DiaryEntry(
    id: id,
    createdAt: created,
    updatedAt: created,
    title: title,
    body: body,
    mood: EntryMood.uncertain,
    futureQuestion: question,
    revisitAt: closedAt == null
        ? revisitAt ?? created.add(const Duration(days: 7))
        : null,
    echoes: echoes,
    closedAt: closedAt,
    deletedAt: deletedAt,
  );
}
