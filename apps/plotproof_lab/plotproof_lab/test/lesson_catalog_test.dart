import 'package:flutter_test/flutter_test.dart';
import 'package:plotproof_lab/data/lesson_catalog.dart';
import 'package:plotproof_lab/domain/models.dart';

void main() {
  test('catalog contains two complete bilingual labs per module', () {
    expect(lessons.map((lesson) => lesson.id).toSet(), hasLength(8));
    expect(lessons, hasLength(bundledLessonCount));
    expect(bundledLessonCount + maximumRemoteLessonCount, maximumLessonCount);
    expect(maximumLessonCount, 56);
    for (final kind in LessonKind.values) {
      expect(lessons.where((lesson) => lesson.kind == kind), hasLength(2));
    }
    for (final lesson in lessons) {
      expect(lesson.title.zh, isNotEmpty);
      expect(lesson.title.en, isNotEmpty);
      expect(lesson.explanation.zh.length, greaterThan(20));
      expect(lesson.explanation.en.length, greaterThan(20));
      expect(lesson.checklist, hasLength(greaterThanOrEqualTo(2)));
      expect(switch (lesson.kind) {
        LessonKind.axis => {
          ExperimentMode.axisBaseline,
          ExperimentMode.axisPrecision,
        }.contains(lesson.mode),
        LessonKind.correlation => {
          ExperimentMode.correlationOutlier,
          ExperimentMode.correlationCausation,
        }.contains(lesson.mode),
        LessonKind.sample => {
          ExperimentMode.sampleComposition,
          ExperimentMode.sampleStrata,
        }.contains(lesson.mode),
        LessonKind.risk => {
          ExperimentMode.riskRelative,
          ExperimentMode.riskFrequency,
        }.contains(lesson.mode),
      }, isTrue);
    }
  });
}
