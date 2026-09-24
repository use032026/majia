import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plotproof_lab/data/lesson_catalog.dart';
import 'package:plotproof_lab/data/progress_repository.dart';
import 'package:plotproof_lab/domain/models.dart';
import 'package:plotproof_lab/state/app_controller.dart';
import 'package:plotproof_lab/ui/app_theme.dart';
import 'package:plotproof_lab/ui/lesson_screen.dart';

void main() {
  for (final lesson in lessons) {
    testWidgets('${lesson.id} reveals initial and fair evidence snapshots', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = AppController(MemoryProgressRepository());
      await controller.initialize(systemLocale: const Locale('zh'));
      await tester.pumpWidget(_lessonApp(controller, lesson));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(Key('verdict-${lesson.correctVerdict.name}')),
      );
      await tester.pump();
      await _explore(tester, lesson);
      await tester.ensureVisible(find.byKey(const Key('reveal-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reveal-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('comparison-initial')), findsOneWidget);
      expect(find.byKey(const Key('comparison-fair')), findsOneWidget);
      if (lesson.correctVerdict == Verdict.fair) {
        expect(find.text('另一种公平表达'), findsOneWidget);
        expect(find.textContaining('等价语境'), findsOneWidget);
      } else {
        expect(find.text('补全后的表达'), findsOneWidget);
        expect(find.textContaining('只补全了本关'), findsOneWidget);
      }
      if (lesson.id == 'axis-baseline') {
        expect(find.text('范围 95–100 u · 放大 20.0×'), findsOneWidget);
        expect(find.text('范围 0–100 u · 放大 1.0×'), findsOneWidget);
      }
      if (lesson.id == 'axis-context') {
        expect(find.text('范围 70–82 u · 放大 6.8×'), findsOneWidget);
        expect(find.text('范围 0–82 u · 放大 1.0×'), findsOneWidget);
      }
      expect(controller.attempts, hasLength(1));
      expect(controller.attempts.single.isCorrect, isTrue);
    });
  }

  testWidgets('save failure still reveals teaching result and can retry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MemoryProgressRepository()..failWrites = true;
    final controller = AppController(repository);
    await controller.initialize(systemLocale: const Locale('zh'));
    final lesson = lessons.first;
    await tester.pumpWidget(_lessonApp(controller, lesson));

    await tester.tap(find.byKey(const Key('verdict-misleading')));
    await tester.pump();
    await _explore(tester, lesson);
    await tester.ensureVisible(find.byKey(const Key('reveal-button')));
    await tester.tap(find.byKey(const Key('reveal-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('comparison-fair')), findsOneWidget);
    expect(find.byKey(const Key('unsaved-result')), findsOneWidget);
    expect(controller.attempts, isEmpty);

    repository.failWrites = false;
    await tester.ensureVisible(find.byKey(const Key('retry-save')));
    await tester.tap(find.byKey(const Key('retry-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unsaved-result')), findsNothing);
    expect(controller.attempts, hasLength(1));
  });

  testWidgets('secondary pages add the current bottom safe-area inset', (
    tester,
  ) async {
    final controller = AppController(MemoryProgressRepository());
    await controller.initialize(systemLocale: const Locale('zh'));

    await tester.pumpWidget(_lessonApp(controller, lessons.first));
    await tester.pumpAndSettle();

    var scrollView = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('secondary-page-scroll-view')),
    );
    expect(scrollView.padding, const EdgeInsets.fromLTRB(20, 6, 20, 36));

    await tester.pumpWidget(
      _lessonApp(controller, lessons.first, bottomViewPadding: 34),
    );
    await tester.pumpAndSettle();

    scrollView = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('secondary-page-scroll-view')),
    );
    expect(scrollView.padding, const EdgeInsets.fromLTRB(20, 6, 20, 70));
  });
}

Widget _lessonApp(
  AppController controller,
  Lesson lesson, {
  double bottomViewPadding = 0,
}) {
  return MaterialApp(
    locale: const Locale('zh'),
    supportedLocales: const [Locale('zh'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: AppTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(viewPadding: EdgeInsets.only(bottom: bottomViewPadding)),
      child: child!,
    ),
    home: LessonScreen(controller: controller, lesson: lesson),
  );
}

Future<void> _explore(WidgetTester tester, Lesson lesson) async {
  switch (lesson.kind) {
    case LessonKind.axis:
      await tester.ensureVisible(find.byKey(const Key('axis-slider')));
      await tester.drag(
        find.byKey(const Key('axis-slider')),
        const Offset(-100, 0),
      );
    case LessonKind.correlation:
      await tester.ensureVisible(find.byKey(const Key('outlier-switch')));
      await tester.tap(find.byKey(const Key('outlier-switch')));
    case LessonKind.sample:
      await tester.ensureVisible(find.byKey(const Key('sample-slider')));
      await tester.drag(
        find.byKey(const Key('sample-slider')),
        const Offset(-100, 0),
      );
    case LessonKind.risk:
      final label = lesson.id == 'risk-frequency' ? '每百人' : '绝对';
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
  }
  await tester.pumpAndSettle();
}
