enum MomentLabel {
  pending,
  possibleSpeech,
  breathing,
  environment,
  uncertain,
  ignored,
}

MomentLabel momentLabelFromJson(Object? value) {
  return MomentLabel.values.firstWhere(
    (item) => item.name == value,
    orElse: () => MomentLabel.pending,
  );
}

class SoundMoment {
  const SoundMoment({
    required this.id,
    required this.offsetSeconds,
    required this.peakDb,
    this.label = MomentLabel.pending,
  });

  final String id;
  final int offsetSeconds;
  final double peakDb;
  final MomentLabel label;

  SoundMoment copyWith({MomentLabel? label}) => SoundMoment(
    id: id,
    offsetSeconds: offsetSeconds,
    peakDb: peakDb,
    label: label ?? this.label,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'offsetSeconds': offsetSeconds,
    'peakDb': peakDb,
    'label': label.name,
  };

  factory SoundMoment.fromJson(Map<String, Object?> json) => SoundMoment(
    id: json['id'] as String,
    offsetSeconds: (json['offsetSeconds'] as num).toInt(),
    peakDb: (json['peakDb'] as num).toDouble(),
    label: momentLabelFromJson(json['label']),
  );
}

class NightSession {
  const NightSession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.audioPath,
    required this.prompt,
    required this.contextTags,
    required this.moments,
    this.morningNote = '',
    this.isReviewed = false,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final String audioPath;
  final String prompt;
  final List<String> contextTags;
  final List<SoundMoment> moments;
  final String morningNote;
  final bool isReviewed;

  Duration get duration => endedAt.difference(startedAt);

  NightSession copyWith({
    List<SoundMoment>? moments,
    String? morningNote,
    bool? isReviewed,
  }) => NightSession(
    id: id,
    startedAt: startedAt,
    endedAt: endedAt,
    audioPath: audioPath,
    prompt: prompt,
    contextTags: contextTags,
    moments: moments ?? this.moments,
    morningNote: morningNote ?? this.morningNote,
    isReviewed: isReviewed ?? this.isReviewed,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'endedAt': endedAt.toUtc().toIso8601String(),
    'audioPath': audioPath,
    'prompt': prompt,
    'contextTags': contextTags,
    'moments': moments.map((item) => item.toJson()).toList(),
    'morningNote': morningNote,
    'isReviewed': isReviewed,
  };

  factory NightSession.fromJson(Map<String, Object?> json) => NightSession(
    id: json['id'] as String,
    startedAt: DateTime.parse(json['startedAt'] as String).toLocal(),
    endedAt: DateTime.parse(json['endedAt'] as String).toLocal(),
    audioPath: json['audioPath'] as String,
    prompt: json['prompt'] as String? ?? '',
    contextTags: (json['contextTags'] as List<Object?>? ?? const [])
        .whereType<String>()
        .toList(growable: false),
    moments: (json['moments'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .map(SoundMoment.fromJson)
        .toList(growable: false),
    morningNote: json['morningNote'] as String? ?? '',
    isReviewed: json['isReviewed'] as bool? ?? false,
  );
}

class RecordingMarker {
  const RecordingMarker({
    required this.id,
    required this.startedAt,
    required this.audioPath,
    required this.prompt,
    required this.contextTags,
  });

  final String id;
  final DateTime startedAt;
  final String audioPath;
  final String prompt;
  final List<String> contextTags;

  Map<String, Object?> toJson() => {
    'id': id,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'audioPath': audioPath,
    'prompt': prompt,
    'contextTags': contextTags,
  };

  factory RecordingMarker.fromJson(Map<String, Object?> json) =>
      RecordingMarker(
        id: json['id'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String).toLocal(),
        audioPath: json['audioPath'] as String,
        prompt: json['prompt'] as String? ?? '',
        contextTags: (json['contextTags'] as List<Object?>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
      );
}

class RepositoryState {
  const RepositoryState({
    required this.sessions,
    required this.localeCode,
    this.recordingMarker,
  });

  final List<NightSession> sessions;
  final String localeCode;
  final RecordingMarker? recordingMarker;
}

class MomentDetector {
  MomentDetector({
    this.calibrationSampleCount = 5,
    this.cooldownSeconds = 15,
    this.maxMoments = 24,
  });

  final int calibrationSampleCount;
  final int cooldownSeconds;
  final int maxMoments;
  final List<double> _calibration = [];
  final List<SoundMoment> _moments = [];
  int? _lastOffset;

  List<SoundMoment> get moments => List.unmodifiable(_moments);
  bool get isCalibrated => _calibration.length >= calibrationSampleCount;

  double get thresholdDb {
    if (_calibration.isEmpty) return -38;
    final average = _calibration.reduce((a, b) => a + b) / _calibration.length;
    return (average + 12).clamp(-38, -18).toDouble();
  }

  SoundMoment? addSample(double db, Duration elapsed) {
    if (!db.isFinite) return null;
    if (!isCalibrated) {
      _calibration.add(db.clamp(-100, 0).toDouble());
      return null;
    }
    if (_moments.length >= maxMoments || db < thresholdDb) return null;
    final offset = elapsed.inSeconds;
    if (_lastOffset != null && offset - _lastOffset! < cooldownSeconds) {
      return null;
    }
    final moment = SoundMoment(
      id: 'm_${offset}_${_moments.length}',
      offsetSeconds: offset,
      peakDb: db.clamp(-100, 0).toDouble(),
    );
    _lastOffset = offset;
    _moments.add(moment);
    return moment;
  }
}
