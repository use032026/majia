import 'package:somniloquy/data/session_repository.dart';
import 'package:somniloquy/domain/models.dart';
import 'package:somniloquy/services/audio_services.dart';

class MemorySessionRepository implements SessionRepository {
  MemorySessionRepository({
    List<NightSession> sessions = const [],
    String localeCode = 'zh',
    RecordingMarker? marker,
  }) : state = RepositoryState(
         sessions: [...sessions],
         localeCode: localeCode,
         recordingMarker: marker,
       ) {
    audioPaths.addAll(sessions.map((item) => item.audioPath));
    if (marker != null) audioPaths.add(marker.audioPath);
  }

  RepositoryState state;
  final Set<String> audioPaths = {};
  bool failLoad = false;
  bool failSave = false;
  bool failDelete = false;
  int markCalls = 0;

  @override
  Future<RepositoryState> load() async {
    if (failLoad) throw StateError('load failed');
    return state;
  }

  @override
  Future<String> createAudioPath(String sessionId) async {
    final path = '/memory/$sessionId.m4a';
    audioPaths.add(path);
    return path;
  }

  @override
  Future<void> saveSession(NightSession session) async {
    if (failSave) throw StateError('save failed');
    final sessions = [...state.sessions];
    final index = sessions.indexWhere((item) => item.id == session.id);
    if (index < 0) {
      sessions.add(session);
    } else {
      sessions[index] = session;
    }
    state = RepositoryState(
      sessions: sessions,
      localeCode: state.localeCode,
      recordingMarker: state.recordingMarker,
    );
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    if (failDelete) throw StateError('delete failed');
    final matching = state.sessions.where((item) => item.id == sessionId);
    if (matching.isNotEmpty) audioPaths.remove(matching.first.audioPath);
    state = RepositoryState(
      sessions: state.sessions.where((item) => item.id != sessionId).toList(),
      localeCode: state.localeCode,
      recordingMarker: state.recordingMarker,
    );
  }

  @override
  Future<void> clearAll() async {
    if (failDelete) throw StateError('delete failed');
    audioPaths.clear();
    state = RepositoryState(sessions: const [], localeCode: state.localeCode);
  }

  @override
  Future<void> saveLocale(String localeCode) async {
    if (failSave) throw StateError('save failed');
    state = RepositoryState(
      sessions: state.sessions,
      localeCode: localeCode,
      recordingMarker: state.recordingMarker,
    );
  }

  @override
  Future<void> markRecordingStarted(RecordingMarker marker) async {
    if (failSave) throw StateError('mark failed');
    markCalls += 1;
    state = RepositoryState(
      sessions: state.sessions,
      localeCode: state.localeCode,
      recordingMarker: marker,
    );
  }

  @override
  Future<void> clearRecordingMarker() async {
    if (failSave) throw StateError('clear failed');
    state = RepositoryState(
      sessions: state.sessions,
      localeCode: state.localeCode,
    );
  }

  @override
  Future<void> discardRecordingMarker() async {
    if (failDelete) throw StateError('discard failed');
    final marker = state.recordingMarker;
    if (marker != null) audioPaths.remove(marker.audioPath);
    await clearRecordingMarker();
  }

  @override
  Future<void> deleteAudioAtPath(String path) async {
    audioPaths.remove(path);
  }

  @override
  Future<bool> audioExists(String path) async => audioPaths.contains(path);
}

class FakeRecorderService implements RecorderService {
  bool permission = true;
  bool started = false;
  String? path;
  double amplitude = -20;
  bool failStop = false;
  bool failStartAfterActivation = false;
  int cancelCalls = 0;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<void> start(String path) async {
    this.path = path;
    started = true;
    if (failStartAfterActivation) throw StateError('partial start failure');
  }

  @override
  Future<double?> readAmplitude() async => amplitude;

  @override
  Future<String?> stop() async {
    if (failStop) throw StateError('stop failed');
    started = false;
    return path;
  }

  @override
  Future<void> cancel() async {
    started = false;
    cancelCalls += 1;
  }

  @override
  Future<void> dispose() async {}
}

class FakeClipPlayerService implements ClipPlayerService {
  String? path;
  Duration? position;

  @override
  Future<void> play(String path, Duration position) async {
    this.path = path;
    this.position = position;
  }

  @override
  Future<void> stop() async {
    path = null;
  }

  @override
  Future<void> dispose() async {}
}
