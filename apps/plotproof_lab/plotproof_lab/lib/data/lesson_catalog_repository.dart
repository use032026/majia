import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import 'lesson_catalog.dart';

class LessonCatalogSnapshot {
  const LessonCatalogSnapshot({
    required this.revision,
    required this.generatedAt,
    required this.lessons,
  });

  final String revision;
  final DateTime generatedAt;
  final List<Lesson> lessons;
}

abstract interface class LessonCatalogRepository {
  Future<LessonCatalogSnapshot?> loadCached();
  Future<LessonCatalogSnapshot?> refresh({bool force = false});
}

class SharedPreferencesLessonCatalogRepository
    implements LessonCatalogRepository {
  SharedPreferencesLessonCatalogRepository({
    required SharedPreferences preferences,
    required http.Client client,
    required Uri endpoint,
    this.refreshInterval = const Duration(days: 7),
    this.maximumRemoteLessons = maximumRemoteLessonCount,
    DateTime Function()? now,
  }) : _preferences = preferences,
       _client = client,
       _endpoint = endpoint,
       _now = now ?? DateTime.now {
    if (endpoint.scheme != 'https' || endpoint.host.isEmpty) {
      throw ArgumentError.value(endpoint, 'endpoint', 'Must use HTTPS.');
    }
    if (maximumRemoteLessons < 1 ||
        maximumRemoteLessons > maximumRemoteLessonCount) {
      throw RangeError.range(
        maximumRemoteLessons,
        1,
        maximumRemoteLessonCount,
        'maximumRemoteLessons',
      );
    }
  }

  static const _catalogKey = 'remote_lesson_catalog_v1';
  static const _lastRefreshAttemptKey = 'remote_lesson_refresh_attempt_v1';
  static const _maximumResponseBytes = 1024 * 1024;
  static const _maximumDownloadedLessons = 8;

  final SharedPreferences _preferences;
  final http.Client _client;
  final Uri _endpoint;
  final Duration refreshInterval;
  final int maximumRemoteLessons;
  final DateTime Function() _now;

  @override
  Future<LessonCatalogSnapshot?> loadCached() async {
    final source = _preferences.getString(_catalogKey);
    if (source == null || source.isEmpty) return null;
    try {
      return decodeLessonCatalog(
        source,
        maximumLessons: maximumRemoteLessons,
        requireMatchingRevision: false,
      );
    } on FormatException {
      await _preferences.remove(_catalogKey);
      return null;
    }
  }

  @override
  Future<LessonCatalogSnapshot?> refresh({bool force = false}) async {
    final now = _now().toUtc();
    final lastAttemptMilliseconds = _preferences.getInt(_lastRefreshAttemptKey);
    if (!force && lastAttemptMilliseconds != null) {
      final lastAttempt = DateTime.fromMillisecondsSinceEpoch(
        lastAttemptMilliseconds,
        isUtc: true,
      );
      if (now.difference(lastAttempt) < refreshInterval) return null;
    }

    await _preferences.setInt(
      _lastRefreshAttemptKey,
      now.millisecondsSinceEpoch,
    );
    final response = await _client
        .get(_endpoint, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('Lesson update returned HTTP ${response.statusCode}.');
    }
    if (response.bodyBytes.length > _maximumResponseBytes) {
      throw const FormatException('Lesson update exceeds the size limit.');
    }
    final source = utf8.decode(response.bodyBytes);
    final incoming = decodeLessonCatalog(
      source,
      maximumLessons: _maximumDownloadedLessons,
    );
    final snapshot = _mergeCatalogs(await loadCached(), incoming);
    final didSave = await _preferences.setString(
      _catalogKey,
      encodeLessonCatalog(snapshot),
    );
    if (!didSave) {
      throw StateError('Could not cache the lesson update.');
    }
    return snapshot;
  }

  LessonCatalogSnapshot _mergeCatalogs(
    LessonCatalogSnapshot? cached,
    LessonCatalogSnapshot incoming,
  ) {
    final merged = <Lesson>[...?cached?.lessons];
    final indexById = <String, int>{
      for (var index = 0; index < merged.length; index++)
        merged[index].id: index,
    };

    for (final lesson in incoming.lessons) {
      final existingIndex = indexById[lesson.id];
      if (existingIndex == null) {
        indexById[lesson.id] = merged.length;
        merged.add(lesson);
      } else {
        merged[existingIndex] = lesson;
      }
    }

    final overflow = merged.length - maximumRemoteLessons;
    final retained = overflow > 0 ? merged.sublist(overflow) : merged;
    return LessonCatalogSnapshot(
      revision: incoming.revision,
      generatedAt: incoming.generatedAt,
      lessons: List<Lesson>.unmodifiable(retained),
    );
  }
}

LessonCatalogSnapshot decodeLessonCatalog(
  String source, {
  int maximumLessons =
      SharedPreferencesLessonCatalogRepository._maximumDownloadedLessons,
  bool requireMatchingRevision = true,
}) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Lesson catalog must be an object.');
  }
  if (decoded['schemaVersion'] != 1) {
    throw const FormatException('Unsupported lesson catalog schema.');
  }
  final revision = decoded['revision'];
  final generatedAtSource = decoded['generatedAt'];
  final checksum = decoded['contentSha256'];
  final lessonPayloads = decoded['lessons'];
  if (revision is! String ||
      revision.trim().isEmpty ||
      generatedAtSource is! String ||
      checksum is! String ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(checksum) ||
      lessonPayloads is! List<Object?> ||
      lessonPayloads.isEmpty ||
      lessonPayloads.length > maximumLessons) {
    throw const FormatException('Invalid lesson catalog metadata.');
  }
  final generatedAt = DateTime.tryParse(generatedAtSource)?.toUtc();
  if (generatedAt == null) {
    throw const FormatException('Invalid lesson catalog timestamp.');
  }
  final canonicalPayload = jsonEncode(_canonicalize(lessonPayloads));
  final actualChecksum = sha256
      .convert(utf8.encode(canonicalPayload))
      .toString();
  if (actualChecksum != checksum) {
    throw const FormatException('Lesson catalog checksum mismatch.');
  }

  final seedIds = lessons.map((lesson) => lesson.id).toSet();
  final remoteIds = <String>{};
  final remoteLessons = lessonPayloads
      .map((payload) {
        if (payload is! Map<String, Object?>) {
          throw const FormatException('Lesson entry must be an object.');
        }
        final lesson = _decodeLesson(payload);
        if (requireMatchingRevision && lesson.revision != revision) {
          throw FormatException(
            'Lesson revision does not match catalog: ${lesson.id}.',
          );
        }
        _validateRemoteLesson(lesson);
        if (seedIds.contains(lesson.id) || !remoteIds.add(lesson.id)) {
          throw FormatException('Duplicate lesson id: ${lesson.id}.');
        }
        return lesson;
      })
      .toList(growable: false);

  return LessonCatalogSnapshot(
    revision: revision,
    generatedAt: generatedAt,
    lessons: List<Lesson>.unmodifiable(remoteLessons),
  );
}

String encodeLessonCatalog(LessonCatalogSnapshot snapshot) {
  if (snapshot.revision.trim().isEmpty ||
      snapshot.lessons.isEmpty ||
      snapshot.lessons.length > maximumRemoteLessonCount) {
    throw const FormatException('Invalid lesson catalog snapshot.');
  }
  final lessonPayloads = snapshot.lessons
      .map((lesson) => lesson.toJson())
      .toList(growable: false);
  final canonicalPayload = jsonEncode(_canonicalize(lessonPayloads));
  return jsonEncode(<String, Object?>{
    'schemaVersion': 1,
    'revision': snapshot.revision,
    'generatedAt': snapshot.generatedAt.toUtc().toIso8601String(),
    'contentSha256': sha256.convert(utf8.encode(canonicalPayload)).toString(),
    'lessons': lessonPayloads,
  });
}

Lesson _decodeLesson(Map<String, Object?> payload) {
  try {
    return Lesson.fromJson(payload);
  } on ArgumentError catch (error) {
    throw FormatException('Invalid lesson enum value: $error');
  }
}

Object? _canonicalize(Object? value) {
  if (value is List<Object?>) {
    return value.map(_canonicalize).toList(growable: false);
  }
  if (value is Map<String, Object?>) {
    final result = SplayTreeMap<String, Object?>();
    for (final entry in value.entries) {
      result[entry.key] = _canonicalize(entry.value);
    }
    return result;
  }
  return value;
}

void _validateRemoteLesson(Lesson lesson) {
  if (!RegExp(r'^remote-[a-z0-9-]{6,100}$').hasMatch(lesson.id) ||
      lesson.revision.trim().isEmpty ||
      lesson.title.zh.length > 100 ||
      lesson.title.en.length > 160 ||
      lesson.claim.zh.length > 240 ||
      lesson.claim.en.length > 320 ||
      lesson.prompt.zh.length > 240 ||
      lesson.prompt.en.length > 320 ||
      lesson.explanation.zh.length < 20 ||
      lesson.explanation.en.length < 20 ||
      lesson.checklist.length < 2 ||
      lesson.checklist.length > 4 ||
      lesson.values.any((value) => !value.isFinite) ||
      !lesson.initialParameter.isFinite ||
      !lesson.fairParameter.isFinite ||
      !lesson.minParameter.isFinite ||
      !lesson.maxParameter.isFinite ||
      lesson.minParameter > lesson.initialParameter ||
      lesson.initialParameter > lesson.maxParameter ||
      lesson.minParameter > lesson.fairParameter ||
      lesson.fairParameter > lesson.maxParameter) {
    throw FormatException('Invalid remote lesson: ${lesson.id}.');
  }

  final source = lesson.source;
  final sourceUri = source == null ? null : Uri.tryParse(source.url);
  if (source == null ||
      sourceUri == null ||
      sourceUri.scheme != 'https' ||
      sourceUri.host.isEmpty) {
    throw FormatException('Remote lesson lacks an HTTPS source: ${lesson.id}.');
  }

  final supportedRemoteMode = switch (lesson.kind) {
    LessonKind.axis =>
      lesson.mode == ExperimentMode.axisBaseline ||
          lesson.mode == ExperimentMode.axisPrecision,
    LessonKind.correlation => lesson.mode == ExperimentMode.correlationOutlier,
    LessonKind.sample || LessonKind.risk => false,
  };
  if (!supportedRemoteMode) {
    throw FormatException('Unsupported remote lesson mode: ${lesson.id}.');
  }

  switch (lesson.kind) {
    case LessonKind.axis:
      final maximum = lesson.axisMaximum;
      if (lesson.values.length != 2 ||
          maximum == null ||
          !maximum.isFinite ||
          lesson.values[0] < 0 ||
          lesson.values[0] >= lesson.values[1] ||
          lesson.values[1] > maximum ||
          lesson.maxParameter >= lesson.values[0] ||
          lesson.maxParameter - lesson.minParameter < 1) {
        throw FormatException('Invalid axis lesson: ${lesson.id}.');
      }
      break;
    case LessonKind.correlation:
      if (lesson.values.length < 6 || lesson.values.length.isOdd) {
        throw FormatException('Invalid correlation lesson: ${lesson.id}.');
      }
      break;
    case LessonKind.sample:
      if (lesson.values.length != 2 ||
          lesson.values.any((value) => value < 0 || value > 1)) {
        throw FormatException('Invalid sample lesson: ${lesson.id}.');
      }
      break;
    case LessonKind.risk:
      if (lesson.values.length != 2 ||
          lesson.values[0] <= 0 ||
          lesson.values[1] < 0) {
        throw FormatException('Invalid risk lesson: ${lesson.id}.');
      }
      break;
  }
}
