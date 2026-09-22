enum EntryKind { full, minimum, skipped }

enum Obstacle { none, time, energy, forgot, environment, tooLarge, other }

enum RecoveryPlan { none, makeSmaller, changeTime, changeCue, keepPlan }

enum ReviewDecision { keep, makeSmaller, changeTime, changeCue, finish }

String localDateKey(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

DateTime dateFromKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) throw const FormatException('Invalid date key');
  final date = DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
  if (localDateKey(date) != key) {
    throw const FormatException('Invalid date key');
  }
  return date;
}

int civilDayNumber(String key) {
  final date = dateFromKey(key);
  return DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(1970)).inDays;
}

T _enumValue<T extends Enum>(List<T> values, Object? raw, String field) {
  if (raw is! String) throw FormatException('Invalid $field');
  return values.firstWhere(
    (value) => value.name == raw,
    orElse: () => throw FormatException('Invalid $field'),
  );
}

class DailyEntry {
  const DailyEntry({
    required this.date,
    required this.kind,
    this.obstacle = Obstacle.none,
    this.recoveryPlan = RecoveryPlan.none,
    this.note = '',
  });

  final String date;
  final EntryKind kind;
  final Obstacle obstacle;
  final RecoveryPlan recoveryPlan;
  final String note;

  bool get isPractice => kind != EntryKind.skipped;

  Map<String, Object?> toJson() => {
    'date': date,
    'kind': kind.name,
    'obstacle': obstacle.name,
    'recoveryPlan': recoveryPlan.name,
    'note': note,
  };

  factory DailyEntry.fromJson(Map<String, Object?> json) {
    final date = json['date'];
    if (date is! String) throw const FormatException('Invalid entry date');
    dateFromKey(date);
    return DailyEntry(
      date: date,
      kind: _enumValue(EntryKind.values, json['kind'], 'entry kind'),
      obstacle: _enumValue(
        Obstacle.values,
        json['obstacle'] ?? 'none',
        'obstacle',
      ),
      recoveryPlan: _enumValue(
        RecoveryPlan.values,
        json['recoveryPlan'] ?? 'none',
        'recovery plan',
      ),
      note: json['note'] is String ? json['note']! as String : '',
    );
  }
}

class MilestoneReview {
  const MilestoneReview({
    required this.milestone,
    required this.decision,
    required this.recordedAt,
    this.note = '',
  });

  final int milestone;
  final ReviewDecision decision;
  final DateTime recordedAt;
  final String note;

  Map<String, Object?> toJson() => {
    'milestone': milestone,
    'decision': decision.name,
    'recordedAt': recordedAt.toIso8601String(),
    'note': note,
  };

  factory MilestoneReview.fromJson(Map<String, Object?> json) {
    final milestone = json['milestone'];
    final recordedAt = json['recordedAt'];
    if (milestone is! int || !const [7, 14, 21].contains(milestone)) {
      throw const FormatException('Invalid milestone');
    }
    if (recordedAt is! String) {
      throw const FormatException('Invalid review timestamp');
    }
    return MilestoneReview(
      milestone: milestone,
      decision: _enumValue(
        ReviewDecision.values,
        json['decision'],
        'review decision',
      ),
      recordedAt: DateTime.parse(recordedAt),
      note: json['note'] is String ? json['note']! as String : '',
    );
  }
}

class Experiment {
  const Experiment({
    required this.id,
    required this.title,
    required this.cue,
    required this.fullAction,
    required this.minimumAction,
    required this.targetDays,
    required this.startedAt,
    this.archivedAt,
    this.entries = const [],
    this.reviews = const [],
  });

  final String id;
  final String title;
  final String cue;
  final String fullAction;
  final String minimumAction;
  final int targetDays;
  final DateTime startedAt;
  final DateTime? archivedAt;
  final List<DailyEntry> entries;
  final List<MilestoneReview> reviews;

  bool get isArchived => archivedAt != null;

  DailyEntry? entryFor(DateTime date) {
    final key = localDateKey(date);
    for (final entry in entries) {
      if (entry.date == key) return entry;
    }
    return null;
  }

  bool needsRecoveryBefore(DateTime date) {
    final key = localDateKey(date);
    final earlier =
        entries.where((entry) => entry.date.compareTo(key) < 0).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    if (earlier.isEmpty) return false;
    final latest = earlier.last;
    if (latest.kind == EntryKind.skipped) return true;
    return (civilDayNumber(key) - civilDayNumber(latest.date)).abs() > 1;
  }

  Experiment copyWith({
    String? title,
    String? cue,
    String? fullAction,
    String? minimumAction,
    int? targetDays,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    List<DailyEntry>? entries,
    List<MilestoneReview>? reviews,
  }) {
    return Experiment(
      id: id,
      title: title ?? this.title,
      cue: cue ?? this.cue,
      fullAction: fullAction ?? this.fullAction,
      minimumAction: minimumAction ?? this.minimumAction,
      targetDays: targetDays ?? this.targetDays,
      startedAt: startedAt,
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
      entries: entries ?? this.entries,
      reviews: reviews ?? this.reviews,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'cue': cue,
    'fullAction': fullAction,
    'minimumAction': minimumAction,
    'targetDays': targetDays,
    'startedAt': startedAt.toIso8601String(),
    'archivedAt': archivedAt?.toIso8601String(),
    'entries': entries.map((entry) => entry.toJson()).toList(),
    'reviews': reviews.map((review) => review.toJson()).toList(),
  };

  factory Experiment.fromJson(Map<String, Object?> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Invalid $key');
      }
      return value;
    }

    final targetDays = json['targetDays'];
    final startedAt = json['startedAt'];
    final archivedAt = json['archivedAt'];
    final rawEntries = json['entries'];
    final rawReviews = json['reviews'];
    if (targetDays is! int || targetDays < 1 || targetDays > 365) {
      throw const FormatException('Invalid target days');
    }
    if (startedAt is! String ||
        (archivedAt != null && archivedAt is! String) ||
        rawEntries is! List ||
        rawReviews is! List) {
      throw const FormatException('Invalid experiment payload');
    }
    final entries = rawEntries.map((raw) {
      if (raw is! Map) throw const FormatException('Invalid entry');
      return DailyEntry.fromJson(Map<String, Object?>.from(raw));
    }).toList();
    if (entries.map((entry) => entry.date).toSet().length != entries.length) {
      throw const FormatException('Duplicate entry date');
    }
    final reviews = rawReviews.map((raw) {
      if (raw is! Map) throw const FormatException('Invalid review');
      return MilestoneReview.fromJson(Map<String, Object?>.from(raw));
    }).toList();
    if (reviews.map((review) => review.milestone).toSet().length !=
        reviews.length) {
      throw const FormatException('Duplicate milestone review');
    }
    return Experiment(
      id: requiredString('id'),
      title: requiredString('title'),
      cue: requiredString('cue'),
      fullAction: requiredString('fullAction'),
      minimumAction: requiredString('minimumAction'),
      targetDays: targetDays,
      startedAt: DateTime.parse(startedAt),
      archivedAt: archivedAt == null
          ? null
          : DateTime.parse(archivedAt as String),
      entries: List.unmodifiable(entries),
      reviews: List.unmodifiable(reviews),
    );
  }
}

class AppSnapshot {
  const AppSnapshot({
    this.schemaVersion = 1,
    this.localeCode = 'zh',
    this.experiments = const [],
  });

  final int schemaVersion;
  final String localeCode;
  final List<Experiment> experiments;

  Experiment? get active {
    for (final experiment in experiments.reversed) {
      if (!experiment.isArchived) return experiment;
    }
    return null;
  }

  List<Experiment> get archived => experiments
      .where((experiment) => experiment.isArchived)
      .toList()
      .reversed
      .toList();

  AppSnapshot copyWith({String? localeCode, List<Experiment>? experiments}) {
    return AppSnapshot(
      schemaVersion: schemaVersion,
      localeCode: localeCode ?? this.localeCode,
      experiments: experiments ?? this.experiments,
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'localeCode': localeCode,
    'experiments': experiments.map((item) => item.toJson()).toList(),
  };

  factory AppSnapshot.fromJson(Map<String, Object?> json) {
    final schema = json['schemaVersion'];
    final locale = json['localeCode'];
    final rawExperiments = json['experiments'];
    if (schema is! int ||
        schema != 1 ||
        (locale != 'zh' && locale != 'en') ||
        rawExperiments is! List) {
      throw const FormatException('Unsupported snapshot');
    }
    final experiments = rawExperiments.map((raw) {
      if (raw is! Map) throw const FormatException('Invalid experiment');
      return Experiment.fromJson(Map<String, Object?>.from(raw));
    }).toList();
    if (experiments.where((item) => !item.isArchived).length > 1) {
      throw const FormatException('Multiple active experiments');
    }
    return AppSnapshot(
      schemaVersion: schema,
      localeCode: locale as String,
      experiments: List.unmodifiable(experiments),
    );
  }
}

class ProgressTier {
  const ProgressTier(this.minimum, this.maximum, this.zh, this.en);

  final int minimum;
  final int? maximum;
  final String zh;
  final String en;

  bool contains(int days) =>
      days >= minimum && (maximum == null || days <= maximum!);
}

const progressTiers = [
  ProgressTier(0, 0, '起念时刻', 'Spark'),
  ProgressTier(1, 6, '小试牛刀', 'First Steps'),
  ProgressTier(7, 14, '渐入佳境', 'Finding Rhythm'),
  ProgressTier(15, 20, '稳步推进', 'Building Momentum'),
  ProgressTier(21, 21, '廿一新章', 'Twenty-One Turn'),
  ProgressTier(22, 30, '稳步成章', 'Steady Chapter'),
  ProgressTier(31, null, '长期同行', 'Long Haul'),
];

ProgressTier tierForDays(int days) =>
    progressTiers.firstWhere((tier) => tier.contains(days));

class ExperimentStats {
  ExperimentStats(this.experiment, this.today) {
    final sorted = [...experiment.entries]
      ..sort((a, b) => a.date.compareTo(b.date));
    fullDays = sorted.where((entry) => entry.kind == EntryKind.full).length;
    minimumDays = sorted
        .where((entry) => entry.kind == EntryKind.minimum)
        .length;
    skippedDays = sorted
        .where((entry) => entry.kind == EntryKind.skipped)
        .length;
    practiceDays = fullDays + minimumDays;
    recoveryCount = sorted
        .where(
          (entry) =>
              entry.isPractice && entry.recoveryPlan != RecoveryPlan.none,
        )
        .length;
    currentStreak = _currentStreak(sorted, today);
    bestStreak = _bestStreak(sorted);
    commonObstacle = _commonObstacle(sorted);
  }

  final Experiment experiment;
  final DateTime today;
  late final int fullDays;
  late final int minimumDays;
  late final int skippedDays;
  late final int practiceDays;
  late final int recoveryCount;
  late final int currentStreak;
  late final int bestStreak;
  late final Obstacle? commonObstacle;

  ProgressTier get tier => tierForDays(practiceDays);
  bool get targetReached => practiceDays >= experiment.targetDays;
  double get targetProgress =>
      (practiceDays / experiment.targetDays).clamp(0, 1).toDouble();
  int get elapsedDays =>
      (civilDayNumber(localDateKey(today)) -
              civilDayNumber(localDateKey(experiment.startedAt)))
          .clamp(0, 100000) +
      1;
  double get calendarPracticeRate =>
      elapsedDays == 0 ? 0 : practiceDays / elapsedDays;
  List<int> get dueMilestones => const [7, 14, 21]
      .where(
        (milestone) =>
            practiceDays >= milestone &&
            !experiment.reviews.any((review) => review.milestone == milestone),
      )
      .toList();

  static int _currentStreak(List<DailyEntry> entries, DateTime today) {
    final todayKey = localDateKey(today);
    final todayEntry = entries
        .where((entry) => entry.date == todayKey)
        .firstOrNull;
    if (todayEntry?.kind == EntryKind.skipped) return 0;
    final practice = entries
        .where((entry) => entry.isPractice)
        .map((entry) => civilDayNumber(entry.date))
        .toSet();
    final todayNumber = civilDayNumber(todayKey);
    var cursor = practice.contains(todayNumber) ? todayNumber : todayNumber - 1;
    if (!practice.contains(cursor)) return 0;
    var count = 0;
    while (practice.contains(cursor)) {
      count += 1;
      cursor -= 1;
    }
    return count;
  }

  static int _bestStreak(List<DailyEntry> entries) {
    final dates =
        entries
            .where((entry) => entry.isPractice)
            .map((entry) => civilDayNumber(entry.date))
            .toList()
          ..sort();
    var best = 0;
    var current = 0;
    int? previous;
    for (final date in dates) {
      current = previous != null && date - previous == 1 ? current + 1 : 1;
      if (current > best) best = current;
      previous = date;
    }
    return best;
  }

  static Obstacle? _commonObstacle(List<DailyEntry> entries) {
    final counts = <Obstacle, int>{};
    for (final entry in entries) {
      if (entry.obstacle != Obstacle.none) {
        counts.update(entry.obstacle, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
