import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plotproof_lab/data/lesson_catalog.dart';
import 'package:plotproof_lab/data/lesson_catalog_repository.dart';
import 'package:plotproof_lab/domain/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late String trackedPack;

  setUpAll(() async {
    trackedPack = await File('content/lesson_pack.json').readAsString();
  });

  test('tracked public-data pack passes checksum and lesson validation', () {
    final snapshot = decodeLessonCatalog(trackedPack);

    expect(snapshot.lessons, hasLength(4));
    expect(snapshot.lessons.every((lesson) => lesson.isRemote), isTrue);
    expect(
      snapshot.lessons.map((lesson) => lesson.id).toSet()
        ..retainAll(lessons.map((lesson) => lesson.id).toSet()),
      isEmpty,
    );
  });

  test('content changes are rejected when checksum is stale', () {
    final payload = jsonDecode(trackedPack) as Map<String, Object?>;
    final lessonPayloads = payload['lessons']! as List<Object?>;
    final firstLesson = lessonPayloads.first! as Map<String, Object?>;
    final title = firstLesson['title']! as Map<String, Object?>;
    title['en'] = 'Tampered title';

    expect(
      () => decodeLessonCatalog(jsonEncode(payload)),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'repository caches valid refreshes and respects refresh interval',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount += 1;
        return http.Response(
          trackedPack,
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final repository = SharedPreferencesLessonCatalogRepository(
        preferences: preferences,
        client: client,
        endpoint: Uri.parse('https://example.com/lesson_pack.json'),
        now: () => DateTime.utc(2026, 9, 24),
      );

      final refreshed = await repository.refresh();
      final skipped = await repository.refresh();
      final cached = await repository.loadCached();

      expect(refreshed?.lessons, hasLength(4));
      expect(skipped, isNull);
      expect(cached?.revision, refreshed?.revision);
      expect(requestCount, 1);
    },
  );

  test('invalid refresh never replaces an existing valid cache', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final goodRepository = SharedPreferencesLessonCatalogRepository(
      preferences: preferences,
      client: MockClient(
        (request) async => http.Response.bytes(utf8.encode(trackedPack), 200),
      ),
      endpoint: Uri.parse('https://example.com/lesson_pack.json'),
      now: () => DateTime.utc(2026, 9, 24),
    );
    await goodRepository.refresh(force: true);

    final badRepository = SharedPreferencesLessonCatalogRepository(
      preferences: preferences,
      client: MockClient((request) async => http.Response('{"bad":true}', 200)),
      endpoint: Uri.parse('https://example.com/lesson_pack.json'),
      now: () => DateTime.utc(2026, 10, 1),
    );

    await expectLater(
      badRepository.refresh(force: true),
      throwsA(isA<FormatException>()),
    );
    expect((await badRepository.loadCached())?.lessons, hasLength(4));
  });

  test('new lessons evict the same number of oldest cached lessons', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final firstPack = _buildPack(
      trackedPack,
      revision: '2026-W39',
      ids: const [
        'remote-fifo-01',
        'remote-fifo-02',
        'remote-fifo-03',
        'remote-fifo-04',
      ],
    );
    final secondPack = _buildPack(
      trackedPack,
      revision: '2026-W40',
      ids: const ['remote-fifo-05', 'remote-fifo-06'],
    );
    var requestCount = 0;
    final repository = SharedPreferencesLessonCatalogRepository(
      preferences: preferences,
      client: MockClient((request) async {
        final body = requestCount++ == 0 ? firstPack : secondPack;
        return http.Response.bytes(utf8.encode(body), 200);
      }),
      endpoint: Uri.parse('https://example.com/lesson_pack.json'),
      maximumRemoteLessons: 4,
    );

    await repository.refresh(force: true);
    final refreshed = await repository.refresh(force: true);
    final cached = await repository.loadCached();

    const retainedIds = [
      'remote-fifo-03',
      'remote-fifo-04',
      'remote-fifo-05',
      'remote-fifo-06',
    ];
    expect(refreshed?.lessons.map((lesson) => lesson.id), retainedIds);
    expect(cached?.lessons.map((lesson) => lesson.id), retainedIds);
    expect(cached?.lessons.map((lesson) => lesson.revision), [
      '2026-W39',
      '2026-W39',
      '2026-W40',
      '2026-W40',
    ]);
  });

  test('an existing lesson ID updates without moving or evicting it', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final firstPack = _buildPack(
      trackedPack,
      revision: '2026-W39',
      ids: const [
        'remote-fifo-01',
        'remote-fifo-02',
        'remote-fifo-03',
        'remote-fifo-04',
      ],
    );
    final updatePack = _buildPack(
      trackedPack,
      revision: '2026-W40',
      ids: const ['remote-fifo-02'],
    );
    var requestCount = 0;
    final repository = SharedPreferencesLessonCatalogRepository(
      preferences: preferences,
      client: MockClient((request) async {
        final body = requestCount++ == 0 ? firstPack : updatePack;
        return http.Response.bytes(utf8.encode(body), 200);
      }),
      endpoint: Uri.parse('https://example.com/lesson_pack.json'),
      maximumRemoteLessons: 4,
    );

    await repository.refresh(force: true);
    final refreshed = await repository.refresh(force: true);

    expect(refreshed?.lessons.map((lesson) => lesson.id), const [
      'remote-fifo-01',
      'remote-fifo-02',
      'remote-fifo-03',
      'remote-fifo-04',
    ]);
    expect(refreshed?.lessons[1].revision, '2026-W40');
  });
}

String _buildPack(
  String trackedPack, {
  required String revision,
  required List<String> ids,
}) {
  final template = decodeLessonCatalog(trackedPack).lessons.first;
  final generatedLessons = ids
      .map((id) {
        final payload = Map<String, Object?>.from(template.toJson());
        payload['id'] = id;
        payload['revision'] = revision;
        return Lesson.fromJson(payload);
      })
      .toList(growable: false);
  return encodeLessonCatalog(
    LessonCatalogSnapshot(
      revision: revision,
      generatedAt: DateTime.utc(2026, 9, 24),
      lessons: generatedLessons,
    ),
  );
}
