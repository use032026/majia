import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/novel.dart';
import '../domain/revision_session.dart';

class RepositoryLoadResult {
  const RepositoryLoadResult({
    required this.sessions,
    required this.novels,
    required this.recoveredFromBackup,
  });

  final List<RevisionSession> sessions;
  final List<Novel> novels;
  final bool recoveredFromBackup;
}

abstract class SessionRepository {
  Future<RepositoryLoadResult> loadSessions();
  Future<void> saveSessions(
    List<RevisionSession> sessions, {
    List<Novel> novels = const [],
    bool retainPrevious = true,
  });
  Future<String?> loadLanguageCode();
  Future<void> saveLanguageCode(String code);
  Future<bool> loadDarkMode();
  Future<void> saveDarkMode(bool enabled);
}

class JsonFileSessionRepository implements SessionRepository {
  JsonFileSessionRepository({
    required this.directory,
    required this.preferences,
  });

  static const _languageKey = 'reader_edit_language_v1';
  static const _darkModeKey = 'reader_edit_dark_mode_v1';

  final Directory directory;
  final SharedPreferences preferences;

  File get _primary => File('${directory.path}/reader_edit_sessions_v1.json');
  File get _backup =>
      File('${directory.path}/reader_edit_sessions_backup_v1.json');
  File get _temporary =>
      File('${directory.path}/reader_edit_sessions_pending_v1.json');
  File get _backupPending =>
      File('${directory.path}/reader_edit_sessions_backup_pending_v1.json');

  bool _primaryNeedsRepair = false;

  @override
  Future<RepositoryLoadResult> loadSessions() async {
    final primaryExists = await _primary.exists();
    final backupExists = await _backup.exists();
    final pendingExists = await _temporary.exists();
    if (!primaryExists && !backupExists && !pendingExists) {
      return const RepositoryLoadResult(
        sessions: [],
        novels: [],
        recoveredFromBackup: false,
      );
    }

    Object? lastError;
    for (final candidate in [
      (_primary, false),
      (_backup, true),
      (_temporary, true),
    ]) {
      if (!await candidate.$1.exists()) continue;
      try {
        final snapshot = _decodeWorkspaceEnvelope(
          await candidate.$1.readAsString(),
        );
        _primaryNeedsRepair = candidate.$2;
        return RepositoryLoadResult(
          sessions: snapshot.sessions,
          novels: snapshot.novels,
          recoveredFromBackup: candidate.$2,
        );
      } on Object catch (error) {
        lastError = error;
      }
    }

    throw FormatException('No valid local revision snapshot: $lastError');
  }

  @override
  Future<void> saveSessions(
    List<RevisionSession> sessions, {
    List<Novel> novels = const [],
    bool retainPrevious = true,
  }) async {
    await directory.create(recursive: true);
    final payload = _encodeWorkspaceEnvelope(sessions, novels);
    await _temporary.writeAsString(payload, flush: true);

    if (!retainPrevious) {
      await _backupPending.writeAsString(payload, flush: true);
      await _replaceWithPending(_backupPending, _backup);
    } else if (!_primaryNeedsRepair && await _primary.exists()) {
      try {
        _decodeWorkspaceEnvelope(await _primary.readAsString());
        await _primary.copy(_backupPending.path);
        await _replaceWithPending(_backupPending, _backup);
      } on FormatException {
        _primaryNeedsRepair = true;
      }
    }

    await _replaceWithPending(_temporary, _primary);
    _primaryNeedsRepair = false;
  }

  Future<void> _replaceWithPending(File pending, File destination) async {
    // iOS and Android use POSIX rename semantics: a flushed file replaces the
    // destination atomically. If the rename fails, keep the pending snapshot
    // intact so the loader can still recover it; never fall back to truncating
    // the destination in place.
    await pending.rename(destination.path);
  }

  @override
  Future<String?> loadLanguageCode() async =>
      preferences.getString(_languageKey);

  @override
  Future<void> saveLanguageCode(String code) async {
    final saved = await preferences.setString(_languageKey, code);
    if (!saved) throw StateError('Unable to save language.');
  }

  @override
  Future<bool> loadDarkMode() async =>
      preferences.getBool(_darkModeKey) ?? false;

  @override
  Future<void> saveDarkMode(bool enabled) async {
    final saved = await preferences.setBool(_darkModeKey, enabled);
    if (!saved) throw StateError('Unable to save appearance.');
  }
}

class MemorySessionRepository implements SessionRepository {
  MemorySessionRepository({
    List<RevisionSession>? sessions,
    List<Novel>? novels,
    this.languageCode,
    this.darkMode = false,
  }) : sessions = List<RevisionSession>.from(sessions ?? const []),
       novels = List<Novel>.from(novels ?? const []);

  List<RevisionSession> sessions;
  List<Novel> novels;
  String? languageCode;
  bool darkMode;
  bool failNextSave = false;
  bool? lastRetainPrevious;

  @override
  Future<RepositoryLoadResult> loadSessions() async => RepositoryLoadResult(
    sessions: List<RevisionSession>.from(sessions),
    novels: List<Novel>.from(novels),
    recoveredFromBackup: false,
  );

  @override
  Future<void> saveSessions(
    List<RevisionSession> sessions, {
    List<Novel> novels = const [],
    bool retainPrevious = true,
  }) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('Simulated save failure.');
    }
    lastRetainPrevious = retainPrevious;
    this.sessions = List<RevisionSession>.from(sessions);
    this.novels = List<Novel>.from(novels);
  }

  @override
  Future<String?> loadLanguageCode() async => languageCode;

  @override
  Future<void> saveLanguageCode(String code) async {
    languageCode = code;
  }

  @override
  Future<bool> loadDarkMode() async => darkMode;

  @override
  Future<void> saveDarkMode(bool enabled) async {
    darkMode = enabled;
  }
}

String _encodeWorkspaceEnvelope(
  List<RevisionSession> sessions,
  List<Novel> novels,
) => jsonEncode({
  'schemaVersion': 2,
  'sessions': sessions.map((session) => session.toJson()).toList(),
  'novels': novels.map((novel) => novel.toJson()).toList(),
});

_WorkspaceSnapshot _decodeWorkspaceEnvelope(String source) {
  try {
    final root = jsonDecode(source) as Map<String, Object?>;
    final schemaVersion = root['schemaVersion'];
    if (schemaVersion != 1 && schemaVersion != 2) {
      throw const FormatException('Unsupported local data version.');
    }
    final rawSessions = root['sessions'] as List<Object?>? ?? const [];
    final rawNovels = schemaVersion == 2
        ? root['novels'] as List<Object?>? ?? const []
        : const <Object?>[];
    return _WorkspaceSnapshot(
      sessions: rawSessions
          .map(
            (value) => RevisionSession.fromJson(value! as Map<String, Object?>),
          )
          .toList(growable: false),
      novels: rawNovels
          .map((value) => Novel.fromJson(value! as Map<String, Object?>))
          .toList(growable: false),
    );
  } on FormatException {
    rethrow;
  } on Object catch (error) {
    throw FormatException('Invalid local revision data: $error');
  }
}

class _WorkspaceSnapshot {
  const _WorkspaceSnapshot({required this.sessions, required this.novels});

  final List<RevisionSession> sessions;
  final List<Novel> novels;
}
