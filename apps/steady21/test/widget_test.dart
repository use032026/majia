import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady21/controller.dart';
import 'package:steady21/domain.dart';
import 'package:steady21/main.dart';
import 'package:steady21/repository.dart';

AppController _controller({AppSnapshot snapshot = const AppSnapshot()}) {
  return AppController(
    MemoryRepository(snapshot),
    now: () => DateTime(2026, 9, 22, 12),
    idFactory: () => 'widget-experiment',
  );
}

Future<void> _pump(WidgetTester tester, AppController controller) async {
  await tester.pumpWidget(SteadyApp(controller: controller));
  await tester.pumpAndSettle();
}

Future<void> _createExperiment(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('createExperimentButton')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('titleField')), '晚饭后读书');
  await tester.enterText(find.byKey(const Key('cueField')), '收好餐具后');
  await tester.enterText(find.byKey(const Key('fullActionField')), '读十页');
  await tester.enterText(find.byKey(const Key('minimumActionField')), '读一页');
  await tester.tap(find.byKey(const Key('saveExperimentButton')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('create route cancels, reopens, and saves a real experiment', (
    tester,
  ) async {
    final controller = _controller();
    await _pump(tester, controller);
    expect(find.text('从一个微小实验开始'), findsOneWidget);

    await tester.tap(find.byKey(const Key('createExperimentButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('titleField')), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(controller.snapshot.experiments, isEmpty);

    await _createExperiment(tester);
    expect(find.text('晚饭后读书'), findsOneWidget);
    expect(controller.snapshot.active?.minimumAction, '读一页');
    expect(tester.takeException(), isNull);
  });

  testWidgets('check-in sheet dismisses, reopens, and commits only on save', (
    tester,
  ) async {
    final controller = _controller();
    await _pump(tester, controller);
    await _createExperiment(tester);

    await tester.tap(find.byKey(const Key('checkInFullButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('checkInSheet')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('entryNoteField')), '状态很好');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(controller.snapshot.active?.entries, isEmpty);

    await tester.ensureVisible(find.byKey(const Key('checkInMinimumButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('checkInMinimumButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('entryNoteField')), '先做一点');
    await tester.tap(find.byKey(const Key('saveEntryButton')));
    await tester.pumpAndSettle();
    expect(controller.snapshot.active?.entries.single.kind, EntryKind.minimum);
    expect(find.text('最低完成'), findsOneWidget);

    await tester.tap(find.byKey(const Key('editTodayButton')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'English switch survives rebuild and keeps core content reachable',
    (tester) async {
      final controller = _controller();
      await _pump(tester, controller);
      await tester.tap(find.byKey(const Key('settingsTab')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Privacy & local data'), findsOneWidget);
      expect(controller.snapshot.localeCode, 'en');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('destructive dialog cancels and reopens without mutation', (
    tester,
  ) async {
    final controller = _controller();
    await _pump(tester, controller);
    await _createExperiment(tester);
    await tester.tap(find.byKey(const Key('settingsTab')));
    await tester.pumpAndSettle();
    final settingsScrollable = find
        .descendant(
          of: find.byKey(const Key('settingsScroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(settingsScrollable, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deleteAllButton')));
    await tester.pumpAndSettle();
    expect(find.text('删除全部本地数据？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(controller.snapshot.active, isNotNull);

    await tester.tap(find.byKey(const Key('deleteAllButton')));
    await tester.pumpAndSettle();
    expect(find.text('删除全部本地数据？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(controller.snapshot.active, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('milestone review sheet cancels, reopens, and saves once', (
    tester,
  ) async {
    final entries = List.generate(
      7,
      (index) => DailyEntry(
        date: '2026-09-${(index + 16).toString().padLeft(2, '0')}',
        kind: EntryKind.full,
      ),
    );
    final experiment = Experiment(
      id: 'milestone',
      title: 'Read nightly',
      cue: 'After dinner',
      fullAction: 'Read ten pages',
      minimumAction: 'Read one page',
      targetDays: 21,
      startedAt: DateTime(2026, 9, 16),
      entries: entries,
    );
    final controller = _controller(
      snapshot: AppSnapshot(experiments: [experiment]),
    );
    await _pump(tester, controller);
    await tester.tap(find.byKey(const Key('journeyTab')));
    await tester.pumpAndSettle();
    final reviewButton = find.text('复盘第 7 个练习日');
    final journeyScrollable = find
        .descendant(
          of: find.byKey(const Key('journeyScroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(journeyScrollable, const Offset(0, -280));
    await tester.pumpAndSettle();
    await tester.tap(reviewButton);
    await tester.pumpAndSettle();
    expect(find.text('下一阶段，你决定怎样做？'), findsWidgets);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(controller.snapshot.active?.reviews, isEmpty);

    await tester.tap(reviewButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(controller.snapshot.active?.reviews, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text and long bilingual content remain scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final experiment = Experiment(
      id: 'long',
      title:
          'A deliberately long experiment title that must wrap without hiding the decision',
      cue:
          'After finishing a long and unpredictable sequence of evening household tasks',
      fullAction: 'Read and annotate ten pages of a difficult technical book',
      minimumAction: 'Open the book and read one paragraph',
      targetDays: 21,
      startedAt: DateTime(2026, 9, 1),
    );
    final controller = _controller(
      snapshot: AppSnapshot(localeCode: 'en', experiments: [experiment]),
    );
    await tester.pumpWidget(SteadyApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('checkInFullButton')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('checkInFullButton')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('archived experiment keeps its complete report readable', (
    tester,
  ) async {
    const archivedTitle = '晚饭后完成一段安静而专注的阅读练习并记录真正有效的触发方式与温和恢复策略';
    final archived = Experiment(
      id: 'archive-report',
      title: archivedTitle,
      cue: '收好餐具后',
      fullAction: '读十页',
      minimumAction: '读一页',
      targetDays: 21,
      startedAt: DateTime(2026, 9, 20),
      archivedAt: DateTime(2026, 9, 20),
      entries: const [
        DailyEntry(date: '2026-09-20', kind: EntryKind.full, note: '很顺利'),
      ],
      reviews: [
        MilestoneReview(
          milestone: 7,
          decision: ReviewDecision.keep,
          recordedAt: DateTime(2026, 9, 22),
          note: '继续保持',
        ),
      ],
    );
    final active = Experiment(
      id: 'active',
      title: '散步',
      cue: '午饭后',
      fullAction: '走二十分钟',
      minimumAction: '走到楼下',
      targetDays: 21,
      startedAt: DateTime(2026, 9, 22),
    );
    final controller = _controller(
      snapshot: AppSnapshot(experiments: [archived, active]),
    );
    await _pump(tester, controller);
    await tester.tap(find.byKey(const Key('journeyTab')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('archivedTile-archive-report')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(
      find.byKey(const Key('archivedTile-archive-report')),
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('archivedTile-archive-report')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('archivedReport-archive-report')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('archivedFullTitle-archive-report')),
      findsOneWidget,
    );
    expect(find.text(archivedTitle), findsNWidgets(2));
    expect(find.text('收好餐具后'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('很顺利'), findsOneWidget);
    expect(find.textContaining('继续保持'), findsOneWidget);
    expect(find.text('恢复为当前实验'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
