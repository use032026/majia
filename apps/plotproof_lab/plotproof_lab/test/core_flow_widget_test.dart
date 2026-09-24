import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plotproof_lab/app.dart';
import 'package:plotproof_lab/data/lesson_catalog.dart';
import 'package:plotproof_lab/data/progress_repository.dart';
import 'package:plotproof_lab/state/app_controller.dart';

void main() {
  testWidgets(
    'judgment, experiment, explanation, and review queue form a loop',
    (tester) async {
      final controller = AppController(
        MemoryProgressRepository(onboardingCompleted: true),
      );
      await controller.initialize(systemLocale: const Locale('zh'));
      await tester.pumpWidget(PlotProofApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('把“看起来”变成“有证据”'), findsOneWidget);
      await tester.tap(find.text('开始').first);
      await tester.pumpAndSettle();

      final reveal = tester.widget<FilledButton>(
        find.byKey(const Key('reveal-button')),
      );
      expect(reveal.onPressed, isNull);

      await tester.tap(find.byKey(const Key('verdict-fair')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('axis-slider')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('axis-slider')),
        const Offset(-120, 0),
      );
      await tester.pump();

      final enabledReveal = tester.widget<FilledButton>(
        find.byKey(const Key('reveal-button')),
      );
      expect(enabledReveal.onPressed, isNotNull);
      await tester.ensureVisible(find.byKey(const Key('reveal-button')));
      await tester.tap(find.byKey(const Key('reveal-button')));
      await tester.pumpAndSettle();

      expect(find.text('这里值得再看一眼'), findsOneWidget);
      expect(controller.attempts, hasLength(1));
      expect(controller.reviewLessonIds, contains('axis-baseline'));
    },
  );

  testWidgets('language selection updates all core navigation labels', (
    tester,
  ) async {
    final controller = AppController(
      MemoryProgressRepository(onboardingCompleted: true),
    );
    await controller.initialize(systemLocale: const Locale('zh'));
    await tester.pumpWidget(PlotProofApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(controller.locale.languageCode, 'en');
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Privacy and limits'), findsOneWidget);
  });

  testWidgets('completed catalog has no continue or start action', (
    tester,
  ) async {
    final controller = AppController(
      MemoryProgressRepository(onboardingCompleted: true),
    );
    await controller.initialize(systemLocale: const Locale('zh'));
    for (final lesson in lessons) {
      await controller.completeLesson(lesson, lesson.correctVerdict);
    }

    await tester.pumpWidget(PlotProofApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('all-lessons-complete-card')), findsOneWidget);
    expect(find.text('全部实验已完成'), findsOneWidget);
    expect(find.text('继续实验'), findsNothing);
    expect(find.byKey(const Key('start-next-lesson')), findsNothing);
    expect(find.text('开始'), findsNothing);
  });
}
