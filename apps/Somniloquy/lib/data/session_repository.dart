import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/models.dart';

abstract class SessionRepository {
  Future<RepositoryState> load();
  Future<String> createAudioPath(String sessionId);
  Future<void> saveSession(NightSession session);
  Future<void> deleteSession(String sessionId);
  Future<void> clearAll();
  Future<void> saveLocale(String localeCode);
  Future<void> saveOnboardingCompleted(bool completed);
  Future<void> markRecordingStarted(RecordingMarker marker);
  Future<void> clearRecordingMarker();
  Future<void> discardRecordingMarker();
  Future<void> deleteAudioAtPath(String path);
  Future<bool> audioExists(String path);
}

class FileSessionRepository implements SessionRepository {
  FileSessionRepository._(
    this._root,
    this._manifest,
    this._audioDirectory,
    this._audioDeleter,
  );

  factory FileSessionRepository.forRoot(
    Directory root, {
    Future<void> Function(String path)? audioDeleter,
  }) {
    final audio = Directory('${root.path}/audio');
    return FileSessionRepository._(
      root,
      File('${root.path}/manifest.json'),
      audio,
      audioDeleter,
    );
  }

  final Directory _root;
  final File _manifest;
  final Directory _audioDirectory;
  final Future<void> Function(String path)? _audioDeleter;
  RepositoryState? _cached;

  static Future<FileSessionRepository> create() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}/somniloquy');
    final audio = Directory('${root.path}/audio');
    await audio.create(recursive: true);
    return FileSessionRepository._(
      root,
      File('${root.path}/manifest.json'),
      audio,
      null,
    );
  }

  @override
  Future<RepositoryState> load() async {
    if (_cached != null) return _cached!;
    if (!await _manifest.exists()) {
      _cached = const RepositoryState(sessions: [], localeCode: 'zh');
      return _cached!;
    }
    final raw = jsonDecode(await _manifest.readAsString());
    if (raw is! Map<String, Object?>) {
      throw const FormatException('Invalid Somniloquy manifest root');
    }
    final sessions = (raw['sessions'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .map(NightSession.fromJson)
        .toList();
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final markerJson = raw['recordingMarker'];
    _cached = RepositoryState(
      sessions: sessions,
      localeCode: raw['localeCode'] as String? ?? 'zh',
      recordingMarker: markerJson is Map<String, Object?>
          ? RecordingMarker.fromJson(markerJson)
          : null,
      hasCompletedOnboarding: raw['hasCompletedOnboarding'] as bool? ?? false,
    );
    return _cached!;
  }

  @override
  Future<String> createAudioPath(String sessionId) async {
    await _audioDirectory.create(recursive: true);
    return '${_audioDirectory.path}/$sessionId.m4a';
  }

  @override
  Future<void> saveSession(NightSession session) async {
    final state = await load();
    final sessions = [...state.sessions];
    final index = sessions.indexWhere((item) => item.id == session.id);
    if (index == -1) {
      sessions.insert(0, session);
    } else {
      sessions[index] = session;
    }
    await _write(
      RepositoryState(
        sessions: sessions,
        localeCode: state.localeCode,
        recordingMarker: state.recordingMarker,
        hasCompletedOnboarding: state.hasCompletedOnboarding,
      ),
    );
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final state = await load();
    final session = state.sessions
        .where((item) => item.id == sessionId)
        .firstOrNull;
    if (session == null) return;
    await deleteAudioAtPath(session.audioPath);
    await _write(
      RepositoryState(
        sessions: state.sessions.where((item) => item.id != sessionId).toList(),
        localeCode: state.localeCode,
        recordingMarker: state.recordingMarker,
        hasCompletedOnboarding: state.hasCompletedOnboarding,
      ),
    );
  }

  @override
  Future<void> clearAll() async {
    final state = await load();
    if (await _audioDirectory.exists()) {
      await _audioDirectory.delete(recursive: true);
    }
    await _audioDirectory.create(recursive: true);
    await _write(
      RepositoryState(
        sessions: const [],
        localeCode: state.localeCode,
        hasCompletedOnboarding: state.hasCompletedOnboarding,
      ),
    );
  }

  @override
  Future<void> saveLocale(String localeCode) async {
    final state = await load();
    await _write(
      RepositoryState(
        sessions: state.sessions,
        localeCode: localeCode,
        recordingMarker: state.recordingMarker,
        hasCompletedOnboarding: state.hasCompletedOnboarding,
      ),
    );
  }

  @override
  Future<void> saveOnboardingCompleted(bool completed) async {
    final state = await load();
    await _write(
      RepositoryState(
        sessions: state.sessions,
        localeCode: state.localeCode,
        recordingMarker: state.recordingMarker,
        hasCompletedOnboarding: completed,
      ),
    );
  }

  @override
  Future<void> markRecordingStarted(RecordingMarker marker) async {
    final state = await load();
    await _write(
      RepositoryState(
        sessions: state.sessions,
        localeCode: state.localeCode,
        recordingMarker: marker,
        hasCompletedOnboarding: state.hasCompletedOnboarding,
      ),
    );
  }

  @override
  Future<void> clearRecordingMarker() async {
    final state = await load();
    await _write(
      RepositoryState(
        sessions: state.sessions,
        localeCode: state.localeCode,
        hasCompletedOnboarding: state.hasCompletedOnboarding,
      ),
    );
  }

  @override
  Future<void> discardRecordingMarker() async {
    final state = await load();
    final marker = state.recordingMarker;
    if (marker != null) {
      final audio = File(marker.audioPath);
      if (await audio.exists()) await audio.delete();
    }
    await clearRecordingMarker();
  }

  @override
  Future<void> deleteAudioAtPath(String path) async {
    if (_audioDeleter != null) {
      await _audioDeleter(path);
      return;
    }
    final audio = File(path);
    if (await audio.exists()) await audio.delete();
  }

  @override
  Future<bool> audioExists(String path) => File(path).exists();

  Future<void> _write(RepositoryState state) async {
    await _root.create(recursive: true);
    final payload = <String, Object?>{
      'schemaVersion': 1,
      'localeCode': state.localeCode,
      'hasCompletedOnboarding': state.hasCompletedOnboarding,
      'sessions': state.sessions.map((item) => item.toJson()).toList(),
      'recordingMarker': state.recordingMarker?.toJson(),
    };
    final temporary = File('${_manifest.path}.tmp');
    await temporary.writeAsString(jsonEncode(payload), flush: true);
    await temporary.rename(_manifest.path);
    _cached = state;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
