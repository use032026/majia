import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:plotproof_lab/data/lesson_catalog.dart';
import 'package:plotproof_lab/data/lesson_catalog_repository.dart';
import 'package:plotproof_lab/data/progress_repository.dart';
import 'package:plotproof_lab/domain/models.dart';
import 'package:plotproof_lab/state/app_controller.dart';

void main() {
  test('first launch uses Chinese only for a Chinese system locale', () async {
    final chineseController = AppController(MemoryProgressRepository());
    await chineseController.initialize(
      systemLocale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
        countryCode: 'TW',
      ),
    );

    final japaneseController = AppController(MemoryProgressRepository());
    await japaneseController.initialize(systemLocale: const Locale('ja', 'JP'));

    expect(chineseController.locale.languageCode, 'zh');
    expect(japaneseController.locale.languageCode, 'en');
  });

  test('stored language preference overrides the system locale', () async {
    final chinesePreferenceController = AppController(
      MemoryProgressRepository(languageCode: 'zh'),
    );
    await chinesePreferenceController.initialize(
      systemLocale: const Locale('ja', 'JP'),
    );

    final englishPreferenceController = AppController(
      MemoryProgressRepository(languageCode: 'en'),
    );
    await englishPreferenceController.initialize(
      systemLocale: const Locale('zh', 'CN'),
    );

    expect(chinesePreferenceController.locale.languageCode, 'zh');
    expect(englishPreferenceController.locale.languageCode, 'en');
  });

  test('failed save does not commit a completed attempt in memory', () async {
    final repository = MemoryProgressRepository()..failWrites = true;
    final controller = AppController(repository);
    await controller.initialize(systemLocale: const Locale('zh'));

    final didSave = await controller.completeLesson(
      lessons.first,
      Verdict.misleading,
    );

    expect(didSave, isFalse);
    expect(controller.attempts, isEmpty);
    expect(controller.errorMessage, isNotNull);
  });

  test(
    'latest result owns review membership and a correct retry closes it',
    () async {
      final controller = AppController(MemoryProgressRepository());
      await controller.initialize(systemLocale: const Locale('en'));
      final lesson = lessons.first;

      await controller.completeLesson(lesson, Verdict.fair);
      expect(controller.reviewLessonIds, contains(lesson.id));

      await controller.completeLesson(lesson, lesson.correctVerdict);
      expect(controller.reviewLessonIds, isNot(contains(lesson.id)));
      expect(controller.completedLessonIds, contains(lesson.id));
    },
  );

  test('cached public-data lessons join the bundled catalog', () async {
    final remoteLesson = Lesson(
      id: 'remote-test-axis-2026-w39',
      revision: '2026-W39',
      kind: LessonKind.axis,
      mode: ExperimentMode.axisBaseline,
      title: const LocalizedText(zh: '远程题', en: 'Remote lab'),
      subtitle: const LocalizedText(zh: '坐标轴', en: 'Axes'),
      claim: const LocalizedText(zh: 'B 远高于 A', en: 'B is far above A'),
      prompt: const LocalizedText(zh: '公平吗？', en: 'Is it fair?'),
      correctVerdict: Verdict.misleading,
      explanation: const LocalizedText(
        zh: '这是一段长度足够的测试解析，用于验证远程题进入控制器。',
        en: 'This sufficiently long explanation verifies controller loading.',
      ),
      checklist: const [
        LocalizedText(zh: '检查坐标轴', en: 'Check the axis'),
        LocalizedText(zh: '检查实际数值', en: 'Check the values'),
      ],
      misconception: const LocalizedText(
        zh: '只看柱高',
        en: 'Read bar height alone',
      ),
      values: const [80, 82],
      initialParameter: 75,
      fairParameter: 0,
      minParameter: 0,
      maxParameter: 79,
      axisMaximum: 100,
      source: const LessonSource(
        name: 'Test source',
        url: 'https://example.com/data',
        license: 'CC BY 4.0',
        attribution: 'Test source',
      ),
    );
    final snapshot = LessonCatalogSnapshot(
      revision: '2026-W39',
      generatedAt: DateTime.utc(2026, 9, 24),
      lessons: [remoteLesson],
    );
    final controller = AppController(
      MemoryProgressRepository(),
      lessonCatalogRepository: _FakeLessonCatalogRepository(snapshot),
    );

    await controller.initialize(systemLocale: const Locale('zh'));
    await controller.completeLesson(remoteLesson, Verdict.misleading);

    expect(controller.activeLessons, hasLength(lessons.length + 1));
    expect(controller.catalogRevision, '2026-W39');
    expect(controller.attempts.single.lessonRevision, '2026-W39');
    expect(controller.attempts.single.misconceptionText?.zh, '只看柱高');
  });
}

class _FakeLessonCatalogRepository implements LessonCatalogRepository {
  _FakeLessonCatalogRepository(this.snapshot);

  final LessonCatalogSnapshot snapshot;

  @override
  Future<LessonCatalogSnapshot?> loadCached() async => snapshot;

  @override
  Future<LessonCatalogSnapshot?> refresh({bool force = false}) async => null;
}
