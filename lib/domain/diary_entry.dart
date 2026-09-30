enum EntryMood { calm, bright, heavy, uncertain, energized }

enum EchoShift { same, clearer, changed, resolved }

class DiaryEcho {
  const DiaryEcho({
    required this.id,
    required this.createdAt,
    required this.body,
    required this.shift,
  });

  final String id;
  final DateTime createdAt;
  final String body;
  final EchoShift shift;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'body': body,
    'shift': shift.name,
  };

  factory DiaryEcho.fromJson(Map<String, Object?> json) {
    final echo = DiaryEcho(
      id: json['id']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String).toLocal(),
      body: json['body']! as String,
      shift: EchoShift.values.byName(json['shift']! as String),
    );
    if (echo.id.trim().isEmpty || echo.body.trim().isEmpty) {
      throw const FormatException('Diary echoes require an id and body.');
    }
    return echo;
  }
}

class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.title,
    required this.body,
    required this.mood,
    required this.futureQuestion,
    required this.revisitAt,
    required this.echoes,
    required this.closedAt,
    required this.deletedAt,
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String title;
  final String body;
  final EntryMood mood;
  final String futureQuestion;
  final DateTime? revisitAt;
  final List<DiaryEcho> echoes;
  final DateTime? closedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
  bool get isClosed => closedAt != null;
  bool get hasOpenThread =>
      !isDeleted && !isClosed && futureQuestion.isNotEmpty;

  bool isDue(DateTime now) {
    final date = revisitAt;
    return hasOpenThread && date != null && !date.isAfter(now);
  }

  bool matches(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    return <String>[
      title,
      body,
      futureQuestion,
      ...echoes.map((echo) => echo.body),
    ].any((value) => value.toLowerCase().contains(query));
  }

  DiaryEntry copyWith({
    DateTime? updatedAt,
    String? title,
    String? body,
    EntryMood? mood,
    String? futureQuestion,
    DateTime? revisitAt,
    bool clearRevisitAt = false,
    List<DiaryEcho>? echoes,
    DateTime? closedAt,
    bool clearClosedAt = false,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return DiaryEntry(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      title: title ?? this.title,
      body: body ?? this.body,
      mood: mood ?? this.mood,
      futureQuestion: futureQuestion ?? this.futureQuestion,
      revisitAt: clearRevisitAt ? null : (revisitAt ?? this.revisitAt),
      echoes: echoes ?? this.echoes,
      closedAt: clearClosedAt ? null : (closedAt ?? this.closedAt),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'title': title,
    'body': body,
    'mood': mood.name,
    'futureQuestion': futureQuestion,
    'revisitAt': revisitAt?.toUtc().toIso8601String(),
    'echoes': echoes.map((echo) => echo.toJson()).toList(),
    'closedAt': closedAt?.toUtc().toIso8601String(),
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };

  factory DiaryEntry.fromJson(Map<String, Object?> json) {
    final rawEchoes = json['echoes']! as List<Object?>;
    final entry = DiaryEntry(
      id: json['id']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt']! as String).toLocal(),
      title: json['title']! as String,
      body: json['body']! as String,
      mood: EntryMood.values.byName(json['mood']! as String),
      futureQuestion: json['futureQuestion']! as String,
      revisitAt: _dateOrNull(json['revisitAt']),
      echoes: rawEchoes
          .map(
            (value) =>
                DiaryEcho.fromJson(Map<String, Object?>.from(value! as Map)),
          )
          .toList(growable: false),
      closedAt: _dateOrNull(json['closedAt']),
      deletedAt: _dateOrNull(json['deletedAt']),
    );
    entry._validateLoadedState();
    return entry;
  }

  void _validateLoadedState() {
    if (id.trim().isEmpty || body.trim().isEmpty) {
      throw const FormatException('Diary entries require an id and body.');
    }
    if (futureQuestion != futureQuestion.trim()) {
      throw const FormatException(
        'A diary question cannot contain surrounding-only whitespace.',
      );
    }
    if (updatedAt.isBefore(createdAt)) {
      throw const FormatException('Diary updatedAt precedes createdAt.');
    }
    final echoIds = <String>{};
    for (final echo in echoes) {
      if (!echoIds.add(echo.id)) {
        throw const FormatException('Duplicate echo id in diary entry.');
      }
    }
    if (futureQuestion.trim().isEmpty) {
      if (revisitAt != null) {
        throw const FormatException(
          'A plain diary page cannot have a revisit date.',
        );
      }
      return;
    }
    if (closedAt == null && revisitAt == null) {
      throw const FormatException(
        'An open reflection thread requires a revisit date.',
      );
    }
    if (closedAt != null && revisitAt != null) {
      throw const FormatException(
        'A closed reflection thread cannot keep a revisit date.',
      );
    }
  }

  static DateTime? _dateOrNull(Object? value) {
    if (value == null) return null;
    return DateTime.parse(value as String).toLocal();
  }
}

class DiarySnapshot {
  const DiarySnapshot({
    required this.entries,
    this.localeCode = 'system',
    this.themeMode = 'system',
  });

  const DiarySnapshot.empty()
    : entries = const <DiaryEntry>[],
      localeCode = 'system',
      themeMode = 'system';

  final List<DiaryEntry> entries;
  final String localeCode;
  final String themeMode;

  DiarySnapshot copyWith({
    List<DiaryEntry>? entries,
    String? localeCode,
    String? themeMode,
  }) {
    return DiarySnapshot(
      entries: entries ?? this.entries,
      localeCode: localeCode ?? this.localeCode,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 1,
    'localeCode': localeCode,
    'themeMode': themeMode,
    'entries': entries.map((entry) => entry.toJson()).toList(),
  };

  factory DiarySnapshot.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported diary schema version.');
    }
    final rawEntries = json['entries']! as List<Object?>;
    final localeCode = (json['localeCode'] as String?) ?? 'system';
    final themeMode = (json['themeMode'] as String?) ?? 'system';
    if (!const <String>{'system', 'zh', 'en'}.contains(localeCode)) {
      throw const FormatException('Unsupported diary locale.');
    }
    if (!const <String>{'system', 'light', 'dark'}.contains(themeMode)) {
      throw const FormatException('Unsupported diary theme mode.');
    }
    final entries = rawEntries
        .map(
          (value) =>
              DiaryEntry.fromJson(Map<String, Object?>.from(value! as Map)),
        )
        .toList(growable: false);
    if (entries.map((entry) => entry.id).toSet().length != entries.length) {
      throw const FormatException('Duplicate diary entry id.');
    }
    return DiarySnapshot(
      localeCode: localeCode,
      themeMode: themeMode,
      entries: entries,
    );
  }
}
