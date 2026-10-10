enum PromptSide { suitable, avoid }

enum ReflectionOutcome { practiced, reframed, released }

enum AppLocaleMode { system, zhHans, en }

enum AppThemeMode { system, light, dark }

class PromptItem {
  const PromptItem({
    required this.id,
    required this.side,
    required this.domain,
    required this.zh,
    required this.en,
  });

  final String id;
  final PromptSide side;
  final String domain;
  final String zh;
  final String en;

  String text({required bool useChinese}) => useChinese ? zh : en;
}

class DailyLeaf {
  const DailyLeaf({
    required this.dateKey,
    required this.createdAt,
    required this.generatorVersion,
    required this.seedFingerprint,
    required this.suitablePromptIds,
    required this.avoidPromptIds,
    required this.verseZh,
    required this.verseEn,
    this.selectedSuitableId,
    this.selectedAvoidId,
    this.intention,
    this.outcome,
    this.sealedAt,
    this.reflectedAt,
  });

  final String dateKey;
  final DateTime createdAt;
  final int generatorVersion;
  final String seedFingerprint;
  final List<String> suitablePromptIds;
  final List<String> avoidPromptIds;
  final List<String> verseZh;
  final List<String> verseEn;
  final String? selectedSuitableId;
  final String? selectedAvoidId;
  final String? intention;
  final ReflectionOutcome? outcome;
  final DateTime? sealedAt;
  final DateTime? reflectedAt;

  bool get isSealed =>
      selectedSuitableId != null && selectedAvoidId != null && sealedAt != null;

  DailyLeaf copyWith({
    String? selectedSuitableId,
    String? selectedAvoidId,
    String? intention,
    ReflectionOutcome? outcome,
    DateTime? sealedAt,
    DateTime? reflectedAt,
  }) {
    return DailyLeaf(
      dateKey: dateKey,
      createdAt: createdAt,
      generatorVersion: generatorVersion,
      seedFingerprint: seedFingerprint,
      suitablePromptIds: suitablePromptIds,
      avoidPromptIds: avoidPromptIds,
      verseZh: verseZh,
      verseEn: verseEn,
      selectedSuitableId: selectedSuitableId ?? this.selectedSuitableId,
      selectedAvoidId: selectedAvoidId ?? this.selectedAvoidId,
      intention: intention ?? this.intention,
      outcome: outcome ?? this.outcome,
      sealedAt: sealedAt ?? this.sealedAt,
      reflectedAt: reflectedAt ?? this.reflectedAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'dateKey': dateKey,
    'createdAt': createdAt.toIso8601String(),
    'generatorVersion': generatorVersion,
    'seedFingerprint': seedFingerprint,
    'suitablePromptIds': suitablePromptIds,
    'avoidPromptIds': avoidPromptIds,
    'verseZh': verseZh,
    'verseEn': verseEn,
    'selectedSuitableId': selectedSuitableId,
    'selectedAvoidId': selectedAvoidId,
    'intention': intention,
    'outcome': outcome?.name,
    'sealedAt': sealedAt?.toIso8601String(),
    'reflectedAt': reflectedAt?.toIso8601String(),
  };

  factory DailyLeaf.fromJson(Map<String, Object?> json) {
    List<String> stringList(String key) {
      final value = json[key];
      if (value is! List) {
        throw FormatException('$key must be a list');
      }
      return value
          .map((item) {
            if (item is! String) {
              throw FormatException('$key contains a non-string value');
            }
            return item;
          })
          .toList(growable: false);
    }

    DateTime? optionalDate(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String) throw FormatException('$key must be a string');
      return DateTime.parse(value);
    }

    final outcomeName = json['outcome'];
    return DailyLeaf(
      dateKey: json['dateKey']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
      generatorVersion: json['generatorVersion']! as int,
      seedFingerprint: json['seedFingerprint']! as String,
      suitablePromptIds: stringList('suitablePromptIds'),
      avoidPromptIds: stringList('avoidPromptIds'),
      verseZh: stringList('verseZh'),
      verseEn: stringList('verseEn'),
      selectedSuitableId: json['selectedSuitableId'] as String?,
      selectedAvoidId: json['selectedAvoidId'] as String?,
      intention: json['intention'] as String?,
      outcome: outcomeName is String
          ? ReflectionOutcome.values.byName(outcomeName)
          : null,
      sealedAt: optionalDate('sealedAt'),
      reflectedAt: optionalDate('reflectedAt'),
    );
  }
}

class AlmanacData {
  const AlmanacData({
    required this.schemaVersion,
    required this.installationSeed,
    required this.onboardingSeen,
    required this.localeMode,
    required this.themeMode,
    required this.leaves,
  });

  factory AlmanacData.initial(String installationSeed) => AlmanacData(
    schemaVersion: 1,
    installationSeed: installationSeed,
    onboardingSeen: false,
    localeMode: AppLocaleMode.system,
    themeMode: AppThemeMode.system,
    leaves: const <String, DailyLeaf>{},
  );

  final int schemaVersion;
  final String installationSeed;
  final bool onboardingSeen;
  final AppLocaleMode localeMode;
  final AppThemeMode themeMode;
  final Map<String, DailyLeaf> leaves;

  AlmanacData copyWith({
    bool? onboardingSeen,
    AppLocaleMode? localeMode,
    AppThemeMode? themeMode,
    Map<String, DailyLeaf>? leaves,
  }) => AlmanacData(
    schemaVersion: schemaVersion,
    installationSeed: installationSeed,
    onboardingSeen: onboardingSeen ?? this.onboardingSeen,
    localeMode: localeMode ?? this.localeMode,
    themeMode: themeMode ?? this.themeMode,
    leaves: leaves ?? this.leaves,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'installationSeed': installationSeed,
    'onboardingSeen': onboardingSeen,
    'localeMode': localeMode.name,
    'themeMode': themeMode.name,
    'leaves': leaves.map(
      (key, value) => MapEntry<String, Object?>(key, value.toJson()),
    ),
  };

  factory AlmanacData.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported local data version');
    }
    final rawLeaves = json['leaves'];
    if (rawLeaves is! Map) {
      throw const FormatException('leaves must be a map');
    }
    final seed = json['installationSeed'];
    if (seed is! String || seed.isEmpty) {
      throw const FormatException('installationSeed is missing');
    }
    return AlmanacData(
      schemaVersion: 1,
      installationSeed: seed,
      onboardingSeen: json['onboardingSeen'] == true,
      localeMode: AppLocaleMode.values.byName(
        (json['localeMode'] as String?) ?? AppLocaleMode.system.name,
      ),
      themeMode: AppThemeMode.values.byName(
        (json['themeMode'] as String?) ?? AppThemeMode.system.name,
      ),
      leaves: rawLeaves.map<String, DailyLeaf>((key, value) {
        if (key is! String || value is! Map) {
          throw const FormatException('Invalid leaf entry');
        }
        return MapEntry(
          key,
          DailyLeaf.fromJson(Map<String, Object?>.from(value)),
        );
      }),
    );
  }
}
