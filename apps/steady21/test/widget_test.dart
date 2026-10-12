import 'package:flutter/cupertino.dart';
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

    final todayScrollable = find
        .descendant(
          of: find.byKey(const Key('todayScroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('checkInFullButton')),
      180,
      scrollable: todayScrollable,
    );
    await tester.drag(todayScrollable, const Offset(0, -120));
    await tester.pumpAndSettle();
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

  testWidgets('iOS choice sheet changes a pause reason without saving', (
    tester,
  ) async {
    final controller = _controller();
    await _pump(tester, controller);
    await _createExperiment(tester);

    final todayScrollable = find
        .descendant(
          of: find.byKey(const Key('todayScroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('checkInSkippedButton')),
      180,
      scrollable: todayScrollable,
    );
    await tester.drag(todayScrollable, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('checkInSkippedButton')));
    await tester.pumpAndSettle();
    expect(
      find.byType(CupertinoSlidingSegmentedControl<EntryKind>),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('obstacleField')));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    await tester.tap(find.text('时间不合适'));
    await tester.pumpAndSettle();
    expect(find.text('时间不合适'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(controller.snapshot.active?.entries, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('experiment action sheet keeps delete behind confirmation', (
    tester,
  ) async {
    final controller = _controller();
    await _pump(tester, controller);
    await _createExperiment(tester);
    await tester.tap(find.byKey(const Key('journeyTab')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('experimentActionsButton')));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(controller.snapshot.active, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'English switch survives rebuild and keeps core content reachable',
    (tester) async {
      final controller = _controller();
      await _pump(tester, controller);
      await tester.tap(find.byKey(const Key('settingsTab')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CupertinoSlidingSegmentedControl<String>>(
              find.byType(CupertinoSlidingSegmentedControl<String>),
            )
            .groupValue,
        'zh',
      );
      expect(find.byType(SegmentedButton<String>), findsNothing);
      expect(find.byKey(const Key('privacyPolicyLink')), findsOneWidget);
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Privacy & local data'), findsOneWidget);
      expect(controller.snapshot.localeCode, 'en');
      expect(
        tester
            .widget<CupertinoSlidingSegmentedControl<String>>(
              find.byType(CupertinoSlidingSegmentedControl<String>),
            )
            .groupValue,
        'en',
      );
      await tester.tap(find.byKey(const Key('aboutDaysLink')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Twenty-one days is a starting'),
        findsOneWidget,
      );
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
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
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
    await tester.scrollUntilVisible(
      reviewButton,
      180,
      scrollable: journeyScrollable,
    );
    await tester.drag(journeyScrollable, const Offset(0, -120));
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

  testWidgets('journey overview opens global practice and stage pages', (
    tester,
  ) async {
    final archived = Experiment(
      id: 'old',
      title: '旧实验',
      cue: '早晨',
      fullAction: '散步',
      minimumAction: '出门',
      targetDays: 21,
      startedAt: DateTime(2026, 9, 16),
      archivedAt: DateTime(2026, 9, 21),
      entries: [
        for (var day = 16; day <= 21; day++)
          DailyEntry(date: '2026-09-$day', kind: EntryKind.full),
      ],
    );
    final active = Experiment(
      id: 'new',
      title: '新实验',
      cue: '晚上',
      fullAction: '阅读',
      minimumAction: '一页',
      targetDays: 21,
      startedAt: DateTime(2026, 9, 21),
      entries: const [
        DailyEntry(date: '2026-09-21', kind: EntryKind.minimum),
        DailyEntry(date: '2026-09-22', kind: EntryKind.minimum),
      ],
    );
    final controller = _controller(
      snapshot: AppSnapshot(experiments: [archived, active]),
    );
    await _pump(tester, controller);
    await tester.tap(find.byKey(const Key('journeyTab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('journeyPracticeLink')), findsOneWidget);
    expect(find.byKey(const Key('journeyStageLink')), findsOneWidget);
    expect(find.text('7 天'), findsOneWidget);
    expect(find.text('渐入佳境'), findsOneWidget);

    await tester.tap(find.byKey(const Key('journeyPracticeLink')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('journeyPracticePage')), findsOneWidget);
    expect(find.text('7 天'), findsOneWidget);
    expect(find.text('标准行动记录'), findsOneWidget);
    expect(find.text('旧实验'), findsOneWidget);
    expect(find.text('新实验'), findsOneWidget);

    await tester.tap(find.byKey(const Key('journeyDetailBackButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('journeyStageLink')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('journeyStagePage')), findsOneWidget);
    expect(find.text('渐入佳境'), findsWidgets);
    expect(find.textContaining('累计练习 7 天'), findsOneWidget);
    expect(find.byKey(const Key('stageBadge-0')), findsOneWidget);
    expect(find.byKey(const Key('stageBadge-31')), findsOneWidget);
    expect(find.byKey(const Key('shareTier-0')), findsNothing);
    expect(find.text('第 0 天'), findsNothing);
    expect(find.text('尚未达成'), findsNothing);

    await tester.tap(find.byKey(const Key('stageBadge-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('badgeDetailDialog')), findsOneWidget);
    expect(find.text('2026年9月16日'), findsOneWidget);
    expect(find.byKey(const Key('shareBadgeInDialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('closeBadgeDialog')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('stageBadge-7')));
    await tester.tap(find.byKey(const Key('stageBadge-7')));
    await tester.pumpAndSettle();
    expect(find.text('2026年9月22日'), findsOneWidget);
    await tester.tap(find.byKey(const Key('closeBadgeDialog')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('stageBadge-15')));
    await tester.tap(find.byKey(const Key('stageBadge-15')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('badgeNotEarned')), findsOneWidget);
    expect(find.byKey(const Key('badgeAchievementDate')), findsNothing);
    expect(find.byKey(const Key('shareBadgeInDialog')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'observation dates open the matching day without previewing notes',
    (tester) async {
      final experiment = Experiment(
        id: 'observations',
        title: '晚饭后阅读',
        cue: '晚饭后',
        fullAction: '读十页',
        minimumAction: '读一页',
        targetDays: 21,
        startedAt: DateTime(2026, 9, 21),
        entries: const [
          DailyEntry(date: '2026-09-21', kind: EntryKind.full, note: '安静地读完了'),
          DailyEntry(
            date: '2026-09-22',
            kind: EntryKind.skipped,
            obstacle: Obstacle.time,
            recoveryPlan: RecoveryPlan.changeTime,
            note: '晚上临时有事',
          ),
        ],
      );
      final controller = _controller(
        snapshot: AppSnapshot(experiments: [experiment]),
      );
      await _pump(tester, controller);
      await tester.tap(find.byKey(const Key('journeyTab')));
      await tester.pumpAndSettle();

      final journeyScroll = find
          .descendant(
            of: find.byKey(const Key('journeyScroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const Key('observationLink-observations')),
        160,
        scrollable: journeyScroll,
      );
      await tester.pumpAndSettle();
      expect(find.text('练习节奏'), findsOneWidget);
      expect(find.text('晚上临时有事'), findsNothing);
      await tester.tap(find.byKey(const Key('observationLink-observations')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('observationListPage')), findsOneWidget);
      expect(
        find.byKey(const Key('observationDate-2026-09-22')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('observationDate-2026-09-21')),
        findsOneWidget,
      );
      expect(find.text('晚上临时有事'), findsNothing);
      expect(find.text('安静地读完了'), findsNothing);

      await tester.tap(find.byKey(const Key('observationDate-2026-09-22')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('observationDetailPage')), findsOneWidget);
      expect(find.text('2026年9月22日'), findsOneWidget);
      expect(find.text('晚上临时有事'), findsOneWidget);
      expect(find.text('时间不合适'), findsOneWidget);
      expect(find.text('换一个时间'), findsOneWidget);

      await tester.tap(find.byKey(const Key('observationDetailBackButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('observationDate-2026-09-21')));
      await tester.pumpAndSettle();
      expect(find.text('安静地读完了'), findsOneWidget);
      expect(find.text('读十页'), findsOneWidget);
      expect(find.text('晚上临时有事'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('English streak tiles remain equal height when labels wrap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final experiment = Experiment(
      id: 'english-stats',
      title: 'Read every night',
      cue: 'After dinner',
      fullAction: 'Read ten pages',
      minimumAction: 'Read one page',
      targetDays: 21,
      startedAt: DateTime(2026, 9, 22),
    );
    final controller = _controller(
      snapshot: AppSnapshot(localeCode: 'en', experiments: [experiment]),
    );
    await _pump(tester, controller);
    await tester.tap(find.byKey(const Key('journeyTab')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('currentStreakTile')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final current = tester.getSize(find.byKey(const Key('currentStreakTile')));
    final best = tester.getSize(find.byKey(const Key('bestStreakTile')));
    expect(current.height, best.height);
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
    await tester.tap(find.byKey(const Key('journeyTab')));
    await tester.pumpAndSettle();
    final journeyScrollable = find
        .descendant(
          of: find.byKey(const Key('journeyScroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('journeyStageLink')),
      120,
      scrollable: journeyScrollable,
    );
    await tester.drag(journeyScrollable, const Offset(0, -160));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('journeyStageLink')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('stageBadge-0')));
    await tester.tap(find.byKey(const Key('stageBadge-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('badgeAchievementDate')), findsOneWidget);
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
    final anotherArchived = Experiment(
      id: 'archive-short',
      title: '晨间散步',
      cue: '起床后',
      fullAction: '走一圈',
      minimumAction: '下楼',
      targetDays: 21,
      startedAt: DateTime(2026, 9, 18),
      archivedAt: DateTime(2026, 9, 19),
    );
    final controller = _controller(
      snapshot: AppSnapshot(experiments: [anotherArchived, archived, active]),
    );
    await _pump(tester, controller);
    await tester.tap(find.byKey(const Key('journeyTab')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('archivedExperimentLink-archive-report')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(
      find.byKey(const Key('archivedExperimentLink-archive-report')),
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('archivedExperimentLink-archive-short')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('archivedReport-archive-report')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const Key('archivedExperimentLink-archive-report')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('archivedExperimentPage-archive-report')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('archivedReport-archive-report')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('archivedFullTitle-archive-report')),
      findsOneWidget,
    );
    expect(find.text(archivedTitle), findsOneWidget);
    expect(find.text('晨间散步'), findsNothing);
    expect(find.text('收好餐具后'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('很顺利'), findsNothing);
    final detailScroll = find
        .descendant(
          of: find.byKey(const Key('archivedExperimentPage-archive-report')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.textContaining('继续保持'),
      180,
      scrollable: detailScroll,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('继续保持'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('observationLink-archive-report')),
      180,
      scrollable: detailScroll,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('observationLink-archive-report')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('observationListPage')), findsOneWidget);
    await tester.tap(find.byKey(const Key('observationDate-2026-09-20')));
    await tester.pumpAndSettle();
    expect(find.text('很顺利'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('archived detail keeps actions and returns after restore', (
    tester,
  ) async {
    final archived = Experiment(
      id: 'restorable',
      title: '旧实验',
      cue: '早晨',
      fullAction: '散步',
      minimumAction: '下楼',
      targetDays: 21,
      startedAt: DateTime(2026, 9, 20),
      archivedAt: DateTime(2026, 9, 21),
    );
    final controller = _controller(
      snapshot: AppSnapshot(experiments: [archived]),
    );
    await _pump(tester, controller);
    await tester.tap(find.byKey(const Key('journeyTab')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('archivedExperimentLink-restorable')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('archivedExperimentLink-restorable')),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('deleteArchivedButton')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('deleteArchivedButton')));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(controller.snapshot.archived, hasLength(1));

    await tester.tap(find.byKey(const Key('restoreArchivedButton')));
    await tester.pumpAndSettle();
    expect(controller.snapshot.active?.id, 'restorable');
    expect(
      find.byKey(const Key('archivedExperimentPage-restorable')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('archivedExperimentLink-restorable')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
