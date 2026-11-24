import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_report/app_controller.dart';
import 'package:photo_report/models.dart';
import 'package:photo_report/ui/app_theme.dart';
import 'package:photo_report/ui/project_detail_screen.dart';
import 'package:photo_report/ui/issue_form_screen.dart';

void main() {
  Widget app({
    required PhotoReportController controller,
    required ProjectRecord project,
    bool formalFlow = false,
  }) {
    AppLocalizations.activeLocale = const Locale('zh', 'CN');
    return MaterialApp(
      locale: const Locale('zh', 'CN'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildAppTheme(),
      home: ProjectDetailScreen(
        controller: controller,
        initialProject: project,
        formalFlow: formalFlow,
      ),
    );
  }

  testWidgets('formal empty detail keeps one add action and hides list tools', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _DetailController(const []);
    addTearDown(controller.dispose);
    final project = _project(formalFlowStep: 2);

    await tester.pumpWidget(
      app(controller: controller, project: project, formalFlow: true),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('formal-flow-banner')), findsOneWidget);
    expect(find.text('还没有现场记录'), findsOneWidget);
    expect(find.byKey(const Key('detail-empty-add-record')), findsOneWidget);
    expect(find.text('添加第一条记录'), findsOneWidget);
    expect(find.byKey(const Key('detail-add-record')), findsNothing);
    expect(find.byKey(const Key('detail-share-section')), findsNothing);
    expect(find.byKey(const Key('detail-filter-toggle')), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('single-record detail prioritizes record and secondary sharing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final project = _project();
    final controller = _DetailController([_issue(project.id)]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(app(controller: controller, project: project));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detail-quick-mode')), findsOneWidget);
    expect(find.byKey(const Key('detail-add-record')), findsOneWidget);
    expect(find.text('A-001'), findsOneWidget);
    expect(find.text('需要处理这个位置'), findsOneWidget);
    expect(find.byKey(const Key('detail-share-section')), findsOneWidget);
    expect(find.byKey(const Key('detail-generate-pdf')), findsOneWidget);
    expect(find.byKey(const Key('detail-filter-toggle')), findsNothing);
    expect(find.byKey(const Key('detail-filters-panel')), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('issue actions stay pinned to the card right edge', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final project = _project();
    final controller = _DetailController([
      _issue(project.id, severity: IssueSeverity.high),
    ]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(app(controller: controller, project: project));
    await tester.pumpAndSettle();

    final card = find.ancestor(
      of: find.text('A-001'),
      matching: find.byType(Card),
    );
    final actions = find.byKey(const Key('issue-actions-issue-1'));
    final badge = find.text('高优先级');
    expect(card, findsOneWidget);
    expect(actions, findsOneWidget);
    expect(badge, findsOneWidget);

    final cardRect = tester.getRect(card);
    final actionsRect = tester.getRect(actions);
    final badgeRect = tester.getRect(badge);
    expect(cardRect.right - actionsRect.right, closeTo(13, 0.1));
    expect(actionsRect.left, greaterThan(badgeRect.right));
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtered long lists keep the matching order while scrolling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final project = _project();
    final controller = _DetailController(
      List.generate(
        40,
        (index) => _issue(
          project.id,
          sequence: index + 1,
          category: index.isEven ? '漏水检查' : '地面检查',
        ),
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller: controller, project: project));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-filter-toggle')));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '漏水');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SliverList>(find.byType(SliverList))
          .delegate
          .estimatedChildCount,
      39,
    );
    final scrollable = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('A-039'),
      500,
      scrollable: scrollable,
    );
    expect(find.text('A-039'), findsOneWidget);
    expect(find.text('地面检查'), findsNothing);
    expect(find.text('A-040'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtered records refresh after returning from editing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final project = _project();
    final controller = _DetailController([
      _issue(project.id, category: '漏水检查'),
      _issue(project.id, sequence: 2, category: '地面检查'),
    ]);
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller: controller, project: project));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-filter-toggle')));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '漏水');
    await tester.pumpAndSettle();
    expect(find.text('A-001'), findsOneWidget);
    expect(find.text('A-002'), findsNothing);
    await tester.ensureVisible(find.text('A-001'));
    await tester.tap(find.text('A-001'));
    await tester.pumpAndSettle();
    expect(find.byType(IssueFormScreen), findsOneWidget);
    controller.issueRecords = [
      _issue(project.id, category: '已修复'),
      _issue(project.id, sequence: 2, category: '漏水检查'),
    ];
    Navigator.of(
      tester.element(find.byType(IssueFormScreen)),
    ).pop(IssueFormResult.saved);
    await tester.pumpAndSettle();
    expect(controller.loadCount, 2);
    expect(find.text('A-001'), findsNothing);
    expect(find.text('A-002'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '不存在');
    await tester.pumpAndSettle();
    expect(find.text('当前筛选下没有记录'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('A-001'), findsOneWidget);
    expect(find.text('A-002'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'search matches each field and preserves Unicode, trimming and clearing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(402, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final project = _project();
      final controller = _DetailController([
        _issue(
          project.id,
          room: 'HallΩ',
          location: 'Étage😀',
          category: '漏水检查',
          description: '面板Δ说明',
          assignee: 'Agentß',
        ),
        _issue(project.id, sequence: 2, category: '其他记录'),
      ]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller: controller, project: project));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('detail-filter-toggle')));
      await tester.pumpAndSettle();
      for (final query in [
        'a-001',
        'hallω',
        '  éTAGE😀  ',
        '漏水',
        '面板δ',
        'aGENTß',
      ]) {
        await tester.enterText(find.byType(TextField), query);
        await tester.pumpAndSettle();
        expect(find.text('A-001'), findsOneWidget, reason: query);
        expect(find.text('A-002'), findsNothing, reason: query);
      }
      await tester.enterText(find.byType(TextField), '完全不匹配');
      await tester.pumpAndSettle();
      expect(find.text('当前筛选下没有记录'), findsOneWidget);
      for (final query in ['   ', '']) {
        await tester.enterText(find.byType(TextField), query);
        await tester.pumpAndSettle();
        expect(find.text('A-001'), findsOneWidget);
        expect(find.text('A-002'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search intersects status and room filters without resetting them',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(402, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final project = _project();
      final controller = _DetailController([
        _issue(
          project.id,
          room: 'North',
          status: IssueStatus.pending,
          assignee: 'Alex',
        ),
        _issue(
          project.id,
          sequence: 2,
          room: 'North',
          status: IssueStatus.completed,
          assignee: 'Alex',
        ),
        _issue(
          project.id,
          sequence: 3,
          room: 'South',
          status: IssueStatus.pending,
          assignee: 'Alex',
        ),
      ]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller: controller, project: project));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('detail-filter-toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), ' ALEX ');
      await tester.pumpAndSettle();
      final pending = find.widgetWithText(ChoiceChip, '待处理');
      await tester.ensureVisible(pending);
      await tester.tap(pending);
      await tester.pumpAndSettle();
      final north = find.widgetWithText(FilterChip, 'North');
      await tester.ensureVisible(north);
      await tester.tap(north);
      await tester.pumpAndSettle();
      expect(find.text('A-001'), findsOneWidget);
      expect(find.text('A-002'), findsNothing);
      expect(find.text('A-003'), findsNothing);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pumpAndSettle();
      expect(find.text('当前筛选下没有记录'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.text('A-001'), findsOneWidget);
      expect(find.text('A-002'), findsNothing);
      expect(find.text('A-003'), findsNothing);
      expect(tester.widget<ChoiceChip>(pending).selected, isTrue);
      expect(tester.widget<FilterChip>(north).selected, isTrue);
      final allStates = find.widgetWithText(ChoiceChip, '全部状态');
      await tester.ensureVisible(allStates);
      await tester.tap(allStates);
      await tester.pumpAndSettle();
      final allRooms = find.widgetWithText(FilterChip, '全部区域');
      await tester.ensureVisible(allRooms);
      await tester.tap(allRooms);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SliverList>(find.byType(SliverList))
            .delegate
            .estimatedChildCount,
        5,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('multiple records expose filters only after explicit request', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final project = _project();
    final controller = _DetailController([
      _issue(project.id),
      _issue(project.id, sequence: 2),
    ]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(app(controller: controller, project: project));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detail-filter-toggle')), findsOneWidget);
    expect(find.byKey(const Key('detail-filters-panel')), findsNothing);
    await tester.tap(find.byKey(const Key('detail-filter-toggle')));
    await tester.pump();
    expect(find.byKey(const Key('detail-filters-panel')), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _DetailController extends PhotoReportController {
  _DetailController(this.issueRecords);

  List<IssueRecord> issueRecords;
  int loadCount = 0;

  @override
  Future<List<IssueRecord>> loadIssues(String projectId) async {
    loadCount++;
    return issueRecords;
  }
}

ProjectRecord _project({int formalFlowStep = 0}) {
  final now = DateTime(2026, 8, 28, 10, 31);
  return ProjectRecord(
    id: 'project-1',
    name: formalFlowStep > 0 ? '花卉公园 0828' : '001',
    address: formalFlowStep > 0 ? '0903' : '天河',
    companyName: '',
    inspectorName: '',
    clientName: '',
    codePrefix: 'A',
    inspectionDate: now,
    notes: '',
    createdAt: now,
    updatedAt: now,
    formalFlowStep: formalFlowStep,
  );
}

IssueRecord _issue(
  String projectId, {
  int sequence = 1,
  IssueSeverity severity = IssueSeverity.unspecified,
  String category = '需要处理这个位置',
  String room = '未分类',
  String location = '',
  String description = '现场情况说明',
  String assignee = '',
  IssueStatus status = IssueStatus.unspecified,
}) {
  final now = DateTime(2026, 8, 28, 10, 31);
  return IssueRecord(
    id: 'issue-$sequence',
    projectId: projectId,
    sequence: sequence,
    code: 'A-${sequence.toString().padLeft(3, '0')}',
    room: room,
    location: location,
    category: category,
    severity: severity,
    description: description,
    status: status,
    assignee: assignee,
    createdAt: now,
    updatedAt: now,
  );
}
