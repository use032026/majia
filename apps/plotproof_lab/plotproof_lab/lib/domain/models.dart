import 'dart:ui';

class LocalizedText {
  const LocalizedText({required this.zh, required this.en});

  final String zh;
  final String en;

  String resolve(Locale locale) => locale.languageCode == 'zh' ? zh : en;

  Map<String, Object?> toJson() => <String, Object?>{'zh': zh, 'en': en};

  factory LocalizedText.fromJson(Map<String, Object?> json) {
    final zh = json['zh'];
    final en = json['en'];
    if (zh is! String ||
        zh.trim().isEmpty ||
        en is! String ||
        en.trim().isEmpty) {
      throw const FormatException('Localized text requires zh and en values.');
    }
    return LocalizedText(zh: zh.trim(), en: en.trim());
  }
}

enum LessonKind { axis, correlation, sample, risk }

enum ExperimentMode {
  axisBaseline,
  axisPrecision,
  correlationOutlier,
  correlationCausation,
  sampleComposition,
  sampleStrata,
  riskRelative,
  riskFrequency,
}

enum Verdict { misleading, fair, needsContext }

class LessonSource {
  const LessonSource({
    required this.name,
    required this.url,
    required this.license,
    required this.attribution,
  });

  final String name;
  final String url;
  final String license;
  final String attribution;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'url': url,
    'license': license,
    'attribution': attribution,
  };

  factory LessonSource.fromJson(Map<String, Object?> json) {
    final name = json['name'];
    final url = json['url'];
    final license = json['license'];
    final attribution = json['attribution'];
    if (name is! String ||
        name.trim().isEmpty ||
        url is! String ||
        url.trim().isEmpty ||
        license is! String ||
        license.trim().isEmpty ||
        attribution is! String ||
        attribution.trim().isEmpty) {
      throw const FormatException('Invalid lesson source.');
    }
    return LessonSource(
      name: name.trim(),
      url: url.trim(),
      license: license.trim(),
      attribution: attribution.trim(),
    );
  }
}

class Lesson {
  const Lesson({
    required this.id,
    required this.kind,
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.claim,
    required this.prompt,
    required this.correctVerdict,
    required this.explanation,
    required this.checklist,
    required this.misconception,
    required this.values,
    required this.initialParameter,
    required this.fairParameter,
    required this.minParameter,
    required this.maxParameter,
    this.revision = 'bundled-v1',
    this.axisMaximum,
    this.source,
  });

  final String id;
  final LessonKind kind;
  final ExperimentMode mode;
  final LocalizedText title;
  final LocalizedText subtitle;
  final LocalizedText claim;
  final LocalizedText prompt;
  final Verdict correctVerdict;
  final LocalizedText explanation;
  final List<LocalizedText> checklist;
  final LocalizedText misconception;
  final List<double> values;
  final double initialParameter;
  final double fairParameter;
  final double minParameter;
  final double maxParameter;
  final String revision;
  final double? axisMaximum;
  final LessonSource? source;

  bool get isRemote => source != null;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'revision': revision,
    'kind': kind.name,
    'mode': mode.name,
    'title': title.toJson(),
    'subtitle': subtitle.toJson(),
    'claim': claim.toJson(),
    'prompt': prompt.toJson(),
    'correctVerdict': correctVerdict.name,
    'explanation': explanation.toJson(),
    'checklist': checklist.map((item) => item.toJson()).toList(growable: false),
    'misconception': misconception.toJson(),
    'values': values,
    'parameters': <String, Object?>{
      'initial': initialParameter,
      'fair': fairParameter,
      'min': minParameter,
      'max': maxParameter,
      if (axisMaximum != null) 'axisMaximum': axisMaximum,
    },
    if (source != null) 'source': source!.toJson(),
  };

  factory Lesson.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final revision = json['revision'];
    final kindName = json['kind'];
    final modeName = json['mode'];
    final verdictName = json['correctVerdict'];
    final checklistJson = json['checklist'];
    final valuesJson = json['values'];
    final parameters = json['parameters'];
    if (id is! String ||
        revision is! String ||
        kindName is! String ||
        modeName is! String ||
        verdictName is! String ||
        checklistJson is! List<Object?> ||
        valuesJson is! List<Object?> ||
        parameters is! Map<String, Object?>) {
      throw const FormatException('Invalid lesson payload.');
    }
    return Lesson(
      id: id,
      revision: revision,
      kind: LessonKind.values.byName(kindName),
      mode: ExperimentMode.values.byName(modeName),
      title: LocalizedText.fromJson(_object(json['title'], 'title')),
      subtitle: LocalizedText.fromJson(_object(json['subtitle'], 'subtitle')),
      claim: LocalizedText.fromJson(_object(json['claim'], 'claim')),
      prompt: LocalizedText.fromJson(_object(json['prompt'], 'prompt')),
      correctVerdict: Verdict.values.byName(verdictName),
      explanation: LocalizedText.fromJson(
        _object(json['explanation'], 'explanation'),
      ),
      checklist: checklistJson
          .map(
            (item) => LocalizedText.fromJson(_object(item, 'checklist item')),
          )
          .toList(growable: false),
      misconception: LocalizedText.fromJson(
        _object(json['misconception'], 'misconception'),
      ),
      values: valuesJson
          .map((item) => _number(item, 'lesson value'))
          .toList(growable: false),
      initialParameter: _number(parameters['initial'], 'initial parameter'),
      fairParameter: _number(parameters['fair'], 'fair parameter'),
      minParameter: _number(parameters['min'], 'minimum parameter'),
      maxParameter: _number(parameters['max'], 'maximum parameter'),
      axisMaximum: parameters['axisMaximum'] == null
          ? null
          : _number(parameters['axisMaximum'], 'axis maximum'),
      source: json['source'] == null
          ? null
          : LessonSource.fromJson(_object(json['source'], 'source')),
    );
  }
}

class Attempt {
  const Attempt({
    required this.lessonId,
    required this.verdict,
    required this.isCorrect,
    required this.completedAt,
    required this.misconception,
    this.lessonRevision,
    this.misconceptionText,
  });

  final String lessonId;
  final Verdict verdict;
  final bool isCorrect;
  final DateTime completedAt;
  final String misconception;
  final String? lessonRevision;
  final LocalizedText? misconceptionText;

  Map<String, Object?> toJson() => <String, Object?>{
    'lessonId': lessonId,
    'verdict': verdict.name,
    'isCorrect': isCorrect,
    'completedAt': completedAt.toUtc().toIso8601String(),
    'misconception': misconception,
    if (lessonRevision != null) 'lessonRevision': lessonRevision,
    if (misconceptionText != null)
      'misconceptionText': misconceptionText!.toJson(),
  };

  factory Attempt.fromJson(Map<String, Object?> json) {
    final verdictName = json['verdict'];
    final completedAt = json['completedAt'];
    if (json['lessonId'] is! String ||
        verdictName is! String ||
        json['isCorrect'] is! bool ||
        completedAt is! String ||
        json['misconception'] is! String) {
      throw const FormatException('Invalid attempt payload');
    }
    return Attempt(
      lessonId: json['lessonId']! as String,
      verdict: Verdict.values.byName(verdictName),
      isCorrect: json['isCorrect']! as bool,
      completedAt: DateTime.parse(completedAt),
      misconception: json['misconception']! as String,
      lessonRevision: json['lessonRevision'] is String
          ? json['lessonRevision']! as String
          : null,
      misconceptionText: json['misconceptionText'] == null
          ? null
          : LocalizedText.fromJson(
              _object(json['misconceptionText'], 'misconception text'),
            ),
    );
  }
}

Map<String, Object?> _object(Object? value, String field) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$field must be an object.');
  }
  return value;
}

double _number(Object? value, String field) {
  if (value is! num) throw FormatException('$field must be numeric.');
  return value.toDouble();
}
