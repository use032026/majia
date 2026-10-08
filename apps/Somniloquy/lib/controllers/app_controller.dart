import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/session_repository.dart';
import '../domain/models.dart';
import '../services/audio_services.dart';

enum ControllerError {
  load,
  permission,
  recording,
  stop,
  save,
  delete,
  playback,
  reviewRequired,
}

class AppController extends ChangeNotifier {
  AppController({
    required SessionRepository repository,
    required RecorderService recorder,
    required ClipPlayerService player,
    DateTime Function()? clock,
  }) : _repository = repository,
       _recorder = recorder,
       _player = player,
       _clock = clock ?? DateTime.now;

  final SessionRepository _repository;
  final RecorderService _recorder;
  final ClipPlayerService _player;
  final DateTime Function() _clock;
  static const maxRecordingDuration = Duration(hours: 12);

  List<NightSession> _sessions = [];
  String _localeCode = 'zh';
  bool _hasCompletedOnboarding = false;
  bool _loading = true;
  bool _busy = false;
  bool _loadFailed = false;
  ControllerError? _error;
  RecordingMarker? _interruptedMarker;
  RecordingMarker? _activeMarker;
  MomentDetector? _detector;
  NightSession? _reviewSession;
  Timer? _ticker;
  Timer? _playbackResetTimer;
  Duration _elapsed = Duration.zero;
  double? _currentDb;
  bool _sampling = false;
  String? _playingMomentId;
  String? _playingSessionId;

  List<NightSession> get sessions => List.unmodifiable(_sessions);
  List<NightSession> get reviewedSessions =>
      List.unmodifiable(_sessions.where((item) => item.isReviewed));
  List<NightSession> get pendingReviews =>
      List.unmodifiable(_sessions.where((item) => !item.isReviewed));
  String get localeCode => _localeCode;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get loading => _loading;
  bool get busy => _busy;
  bool get loadFailed => _loadFailed;
  ControllerError? get error => _error;
  RecordingMarker? get interruptedMarker => _interruptedMarker;
  bool get isRecording => _activeMarker != null;
  bool get isCalibrated => _detector?.isCalibrated ?? false;
  int get candidateCount => _detector?.moments.length ?? 0;
  Duration get elapsed => _elapsed;
  double? get currentDb => _currentDb;
  NightSession? get reviewSession => _reviewSession;
  String? get playingMomentId => _playingMomentId;
  String? get playingSessionId => _playingSessionId;

  Future<void> initialize() async {
    _loading = true;
    _loadFailed = false;
    _error = null;
    notifyListeners();
    try {
      final state = await _repository.load();
      _sessions = [...state.sessions]
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      _localeCode = state.localeCode == 'en' ? 'en' : 'zh';
      _hasCompletedOnboarding = state.hasCompletedOnboarding;
      final drafts = _sessions.where((item) => !item.isReviewed);
      _reviewSession = drafts.isEmpty ? null : drafts.first;
      final marker = state.recordingMarker;
      if (marker != null && _sessions.any((item) => item.id == marker.id)) {
        await _repository.clearRecordingMarker();
      } else {
        _interruptedMarker = marker;
      }
    } catch (_) {
      _loadFailed = true;
      _error = ControllerError.load;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> startRecording({
    required String prompt,
    required List<String> contextTags,
  }) async {
    if (_busy || _loadFailed || isRecording) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    String? path;
    try {
      if (!await _recorder.hasPermission()) {
        _error = ControllerError.permission;
        return false;
      }
      final startedAt = _clock();
      final id = 'night_${startedAt.toUtc().microsecondsSinceEpoch}';
      path = await _repository.createAudioPath(id);
      await _recorder.start(path);
      final marker = RecordingMarker(
        id: id,
        startedAt: startedAt,
        audioPath: path,
        prompt: prompt.trim(),
        contextTags: List.unmodifiable(contextTags),
      );
      try {
        await _repository.markRecordingStarted(marker);
      } catch (_) {
        await _recorder.cancel();
        rethrow;
      }
      _activeMarker = marker;
      _detector = MomentDetector();
      _elapsed = Duration.zero;
      _currentDb = null;
      _startTicker();
      return true;
    } catch (_) {
      if (path != null) {
        try {
          await _recorder.cancel();
        } catch (_) {}
        try {
          await _repository.deleteAudioAtPath(path);
        } catch (_) {}
      }
      _error = ControllerError.recording;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final marker = _activeMarker;
      if (marker == null) return;
      _elapsed = _clock().difference(marker.startedAt);
      if (_elapsed.isNegative) _elapsed = Duration.zero;
      if (_elapsed >= maxRecordingDuration && !_busy) {
        unawaited(stopRecording());
        return;
      }
      if (_elapsed.inSeconds.isEven) unawaited(_sampleAmplitude());
      notifyListeners();
    });
  }

  Future<void> _sampleAmplitude() async {
    if (_sampling || _activeMarker == null) return;
    _sampling = true;
    try {
      final db = await _recorder.readAmplitude();
      if (db != null && _activeMarker != null) {
        _currentDb = db;
        _detector?.addSample(db, _elapsed);
        notifyListeners();
      }
    } catch (_) {
      _error = ControllerError.recording;
      notifyListeners();
    } finally {
      _sampling = false;
    }
  }

  Future<bool> stopRecording() async {
    final marker = _activeMarker;
    if (_busy || marker == null) return false;
    _busy = true;
    _error = null;
    _ticker?.cancel();
    notifyListeners();
    try {
      final stoppedPath = await _recorder.stop();
      final session = NightSession(
        id: marker.id,
        startedAt: marker.startedAt,
        endedAt: _clock(),
        audioPath: stoppedPath ?? marker.audioPath,
        prompt: marker.prompt,
        contextTags: marker.contextTags,
        moments: _detector?.moments ?? const [],
      );
      _activeMarker = null;
      _detector = null;
      _reviewSession = session;
      try {
        await _repository.saveSession(session);
        await _repository.clearRecordingMarker();
        _upsertSession(session);
      } catch (_) {
        _error = ControllerError.save;
      }
      return true;
    } catch (_) {
      _error = ControllerError.stop;
      _startTicker();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> saveReview({
    required String morningNote,
    required Map<String, MomentLabel> labels,
  }) async {
    final current = _reviewSession;
    if (_busy || current == null) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    final updatedMoments = current.moments
        .map(
          (moment) => moment.copyWith(label: labels[moment.id] ?? moment.label),
        )
        .toList(growable: false);
    if (updatedMoments.any((moment) => moment.label == MomentLabel.pending)) {
      _error = ControllerError.reviewRequired;
      _busy = false;
      notifyListeners();
      return false;
    }
    final updated = current.copyWith(
      morningNote: morningNote.trim(),
      moments: updatedMoments,
      isReviewed: true,
    );
    try {
      await _repository.saveSession(updated);
      await _repository.clearRecordingMarker();
      _upsertSession(updated);
      _reviewSession = null;
      await stopPlayback();
      return true;
    } catch (_) {
      _reviewSession = updated;
      _error = ControllerError.save;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void deferReview() {
    if (_busy || _reviewSession == null) return;
    _reviewSession = null;
    _error = null;
    unawaited(stopPlayback());
    notifyListeners();
  }

  void resumeReview(NightSession session) {
    if (_busy || session.isReviewed) return;
    _reviewSession = session;
    _error = null;
    notifyListeners();
  }

  Future<bool> deleteReviewDraft() async {
    final draft = _reviewSession;
    if (draft == null) return false;
    final deleted = await deleteSession(draft.id);
    if (deleted) {
      _reviewSession = null;
      notifyListeners();
    }
    return deleted;
  }

  void _upsertSession(NightSession session) {
    _sessions.removeWhere((item) => item.id == session.id);
    _sessions.insert(0, session);
    _sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  Future<bool> deleteSession(String id) async {
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.deleteSession(id);
      _sessions.removeWhere((item) => item.id == id);
      await stopPlayback();
      return true;
    } catch (_) {
      _error = ControllerError.delete;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> clearAll() async {
    if (_busy || isRecording) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.clearAll();
      _sessions = [];
      _interruptedMarker = null;
      _reviewSession = null;
      await stopPlayback();
      return true;
    } catch (_) {
      _error = ControllerError.delete;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> discardInterruptedRecording() async {
    if (_busy || _interruptedMarker == null) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.discardRecordingMarker();
      _interruptedMarker = null;
      return true;
    } catch (_) {
      _error = ControllerError.delete;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> setLocale(String code) async {
    final normalized = code == 'en' ? 'en' : 'zh';
    if (normalized == _localeCode) return;
    _localeCode = normalized;
    notifyListeners();
    try {
      await _repository.saveLocale(normalized);
    } catch (_) {
      _error = ControllerError.save;
      notifyListeners();
    }
  }

  Future<bool> completeOnboarding() async {
    if (_hasCompletedOnboarding) return true;
    _error = null;
    try {
      await _repository.saveOnboardingCompleted(true);
      _hasCompletedOnboarding = true;
      notifyListeners();
      return true;
    } catch (_) {
      _error = ControllerError.save;
      notifyListeners();
      return false;
    }
  }

  Future<void> playMoment(NightSession session, SoundMoment moment) async {
    if (_playingMomentId == moment.id) {
      await stopPlayback();
      return;
    }
    _error = null;
    try {
      if (!await _repository.audioExists(session.audioPath)) {
        _error = ControllerError.playback;
        notifyListeners();
        return;
      }
      _playbackResetTimer?.cancel();
      _playingSessionId = null;
      _playingMomentId = moment.id;
      notifyListeners();
      final start = Duration(
        seconds: (moment.offsetSeconds - 5).clamp(0, 1 << 30),
      );
      const clipDuration = Duration(seconds: 12);
      await _player.play(session.audioPath, start, maxDuration: clipDuration);
      _playbackResetTimer = Timer(const Duration(seconds: 12), () {
        unawaited(stopPlayback());
      });
    } catch (_) {
      _playingMomentId = null;
      _playingSessionId = null;
      _error = ControllerError.playback;
      notifyListeners();
    }
  }

  Future<void> playSession(NightSession session) async {
    if (_playingSessionId == session.id) {
      await stopPlayback();
      return;
    }
    _error = null;
    try {
      if (!await _repository.audioExists(session.audioPath)) {
        _error = ControllerError.playback;
        notifyListeners();
        return;
      }
      _playbackResetTimer?.cancel();
      _playingMomentId = null;
      _playingSessionId = session.id;
      notifyListeners();
      await _player.play(session.audioPath, Duration.zero);
      final duration = session.duration > Duration.zero
          ? session.duration
          : const Duration(seconds: 1);
      _playbackResetTimer = Timer(duration, () {
        unawaited(stopPlayback());
      });
    } catch (_) {
      _playingMomentId = null;
      _playingSessionId = null;
      _error = ControllerError.playback;
      notifyListeners();
    }
  }

  Future<void> stopPlayback() async {
    _playbackResetTimer?.cancel();
    _playingMomentId = null;
    _playingSessionId = null;
    await _player.stop();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _playbackResetTimer?.cancel();
    unawaited(_recorder.dispose());
    unawaited(_player.dispose());
    super.dispose();
  }
}
