import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_report/app_controller.dart';
import 'package:photo_report/models.dart';
import 'package:photo_report/ui/app_theme.dart';
import 'package:photo_report/ui/create_flow_sheet.dart';
import 'package:photo_report/ui/onboarding_screen.dart';
import 'package:photo_report/ui/project_form_sheet.dart';
import 'package:photo_report/ui/project_list_screen.dart';

void main() {
  test('English copy covers static and interpolated product messages', () {
    const english = Locale('en');
    expect(
      AppLocalizations.text('编号 · 标注 · 整理分享', locale: english),
      'Number · Mark up · Organize · Share',
    );
    expect(
      AppLocalizations.text('删除“示例项目”？', locale: english),
      'Delete “示例项目”?',
    );
    expect(
      AppLocalizations.text('A-003 待跟进但未填写负责人', locale: english),
      'A-003 needs follow-up but has no assignee',
    );
    expect(AppLocalizations.text('3 项高优先级', locale: english), 'High: 3');
    expect(
      AppLocalizations.errorText(
        'Exception: 照片文件缺失，无法完成备份：site.jpg',
        locale: english,
      ),
      'Exception: Photo file missing; backup cannot be completed: site.jpg',
    );
  });

  test('static Chinese product copy has an English translation', () {
    final files = <File>[
      File('lib/main.dart'),
      File('lib/models.dart'),
      File('lib/report/report_service.dart'),
      ...Directory('lib/data').listSync().whereType<File>().where(
        (file) => file.path.endsWith('.dart'),
      ),
      ...Directory('lib/ui')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart')),
    ];
    final chineseLiteral = RegExp(r"'([^'\n]*[\u4e00-\u9fff][^'\n]*)'");
    final missing = <String>{};
    for (final file in files) {
      for (final match in chineseLiteral.allMatches(file.readAsStringSync())) {
        final source = match.group(1)!;
        if (source.contains(r'$')) continue;
        if (!AppLocalizations.hasEnglish(source) &&
            AppLocalizations.text(source, locale: const Locale('en')) ==
                source) {
          missing.add(source);
        }
      }
    }
    expect(missing, isEmpty, reason: 'Missing English copy: $missing');
  });

  testWidgets('settings sheet switches the visible app chrome', (tester) async {
    final controller = PhotoReportController();
    addTearDown(controller.dispose);
    controller.isLoading = false;

    await tester.pumpWidget(_LanguageHarness(controller: controller));
    expect(find.text('JOVFX'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-settings-button')));
    await tester.pumpAndSettle();
    expect(find.text('设置与数据'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-language')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-language-sheet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('language-en')));
    await tester.pumpAndSettle();

    expect(find.text('JOVFX'), findsOneWidget);
    expect(find.text('Number · Mark up · Organize · Share'), findsOneWidget);
    expect(find.byTooltip('More actions'), findsOneWidget);
  });

  testWidgets('empty home has one create action and first-use path', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = PhotoReportController()..isLoading = false;
    addTearDown(controller.dispose);

    await tester.pumpWidget(_LanguageHarness(controller: controller));

    expect(find.text('从第一个记录项目开始'), findsOneWidget);
    expect(find.text('新建项目'), findsOneWidget);
    expect(find.text('添加照片'), findsOneWidget);
    expect(find.text('整理分享'), findsOneWidget);
    expect(find.text('新建记录项目'), findsOneWidget);
    expect(find.byKey(const Key('empty-create-project')), findsOneWidget);
    expect(find.byKey(const Key('home-appbar-create')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('home-settings-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-settings-sheet')), findsOneWidget);
    expect(find.text('导出本地备份'), findsOneWidget);
    expect(find.text('从备份恢复'), findsOneWidget);
    expect(find.text('简体中文'), findsOneWidget);
    expect(find.text('所有数据默认保存在本机'), findsOneWidget);
    final languageChevron = find.descendant(
      of: find.byKey(const Key('settings-language')),
      matching: find.byIcon(Icons.chevron_right_rounded),
    );
    expect(tester.getTopRight(languageChevron).dx, greaterThan(288));
    expect(tester.getTopRight(find.text('简体中文')).dx, greaterThan(250));
    expect(tester.takeException(), isNull);
  });

  testWidgets('populated home keeps a compact app-bar create action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime(2026, 8, 28);
    final controller = PhotoReportController()
      ..isLoading = false
      ..projects = [
        ProjectOverview(
          project: ProjectRecord(
            id: 'project-1',
            name: '花卉公园 0828',
            address: '0903',
            companyName: '',
            inspectorName: '',
            clientName: '',
            codePrefix: 'A',
            inspectionDate: now,
            notes: '',
            createdAt: now,
            updatedAt: now,
            formalFlowStep: 2,
          ),
          total: 2,
          pending: 1,
          inProgress: 1,
          completed: 0,
          highSeverity: 0,
        ),
      ];
    addTearDown(controller.dispose);

    await tester.pumpWidget(_LanguageHarness(controller: controller));

    expect(find.byKey(const Key('home-appbar-create')), findsOneWidget);
    expect(find.byKey(const Key('empty-create-project')), findsNothing);
    expect(find.byKey(const Key('formal-project-mode')), findsOneWidget);
    expect(find.byKey(const Key('formal-project-progress')), findsOneWidget);
    expect(find.text('第 2/3 步 · 继续添加记录'), findsOneWidget);
    expect(find.text('处理中'), findsOneWidget);
    final markerCenterPositions = [
      const Key('compact-status-total-marker'),
      const Key('compact-status-pending-marker'),
      const Key('compact-status-in-progress-marker'),
      const Key('compact-status-completed-marker'),
    ].map((key) => tester.getCenter(find.byKey(key)).dy).toList();
    for (final position in markerCenterPositions.skip(1)) {
      expect(position, closeTo(markerCenterPositions.first, 0.01));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('English populated home keeps compact copy fully visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime(2026, 8, 28);
    final controller = PhotoReportController()
      ..isLoading = false
      ..projects = [
        ProjectOverview(
          project: ProjectRecord(
            id: 'project-1',
            name: 'Project 001',
            address: '',
            companyName: '',
            inspectorName: '',
            clientName: '',
            codePrefix: 'A',
            inspectionDate: now,
            notes: '',
            createdAt: now,
            updatedAt: now,
          ),
          total: 1,
          pending: 1,
          inProgress: 0,
          completed: 0,
          highSeverity: 1,
        ),
      ];
    addTearDown(controller.dispose);

    AppLocalizations.activeLocale = const Locale('en');
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildAppTheme(),
        home: ProjectListScreen(
          controller: controller,
          preferredLocale: const Locale('en'),
          onLocaleChanged: (_) {},
        ),
      ),
    );

    for (final copy in const [
      'JOVFX',
      'Number · Mark up · Organize · Share',
      'High: 1',
      'record',
    ]) {
      expect(find.text(copy), findsOneWidget);
    }
    expect(
      tester.getTopLeft(find.text('Number · Mark up · Organize · Share')).dy,
      greaterThan(tester.getTopLeft(find.text('JOVFX')).dy),
    );
    final totalMarker = tester.getTopLeft(
      find.byKey(const Key('compact-status-total-marker')),
    );
    final pendingMarker = tester.getTopLeft(
      find.byKey(const Key('compact-status-pending-marker')),
    );
    final inProgressMarker = tester.getTopLeft(
      find.byKey(const Key('compact-status-in-progress-marker')),
    );
    final completedMarker = tester.getTopLeft(
      find.byKey(const Key('compact-status-completed-marker')),
    );
    expect(inProgressMarker.dy, greaterThan(totalMarker.dy));
    expect(completedMarker.dy, greaterThan(pendingMarker.dy));
    expect(inProgressMarker.dx, closeTo(totalMarker.dx, 0.01));
    expect(completedMarker.dx, closeTo(pendingMarker.dx, 0.01));
    for (final copy in const [
      'Number · Mark up · Organize · Share',
      'High: 1',
      'record',
    ]) {
      final finder = find.text(copy);
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason:
            '$copy should not be truncated '
            '(available: ${paragraph.size.width}, '
            'needed: ${paragraph.getMaxIntrinsicWidth(double.infinity)})',
      );
    }
    expect(find.text('records'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English form fields stack at phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: ResponsiveFieldRow(
            children: [
              SizedBox(key: const Key('first-field'), height: 56),
              SizedBox(key: const Key('second-field'), height: 56),
            ],
          ),
        ),
      ),
    );

    final first = tester.getTopLeft(find.byKey(const Key('first-field')));
    final second = tester.getTopLeft(find.byKey(const Key('second-field')));
    expect(second.dy, greaterThan(first.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('user-entered text is never translated', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        home: LText('从第一个记录项目开始', translate: false),
      ),
    );
    expect(find.text('从第一个记录项目开始'), findsOneWidget);
    expect(find.text('Start with your first record project'), findsNothing);
  });

  testWidgets('English create screens render on a narrow phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    AppLocalizations.activeLocale = const Locale('en');

    Widget app(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildAppTheme(),
      home: Scaffold(body: child),
    );

    await tester.pumpWidget(app(const CreateFlowSheet(projects: [])));
    expect(find.text('How would you like to record this?'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(app(const ProjectFormSheet()));
    await tester.pump();
    expect(find.text('Project name *'), findsOneWidget);
    expect(find.text('Company / team'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding follows the effective locale and completes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var finished = false;
    Locale? preferredLocale;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildAppTheme(),
        home: OnboardingScreen(
          locale: const Locale('en'),
          preferredLocale: null,
          onLocaleChanged: (value) => preferredLocale = value,
          onFinished: () => finished = true,
        ),
      ),
    );

    expect(find.text('Site records start with a photo'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-language')));
    await tester.pumpAndSettle();
    expect(find.text('System default'), findsOneWidget);
    await tester.tap(find.text('简体中文').last);
    await tester.pumpAndSettle();
    expect(preferredLocale?.languageCode, 'zh');

    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Start recording'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    expect(finished, isTrue);
  });

  test(
    'language and onboarding preferences use one persisted startup state',
    () async {
      const channel = MethodChannel('com.starburst.photo_report/report');
      String? languageCode;
      var onboardingComplete = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final arguments =
                call.arguments as Map<Object?, Object?>? ?? const {};
            switch (call.method) {
              case 'getPreferredLanguage':
                return languageCode;
              case 'setPreferredLanguage':
                languageCode = arguments['languageCode'] as String?;
                return null;
              case 'clearPreferredLanguage':
                languageCode = null;
                return null;
              case 'getOnboardingComplete':
                return onboardingComplete;
              case 'setOnboardingComplete':
                onboardingComplete = arguments['isComplete'] as bool? ?? false;
                return null;
            }
            throw PlatformException(code: 'unexpected_method');
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      expect(await LanguagePreference.load(), isNull);
      await LanguagePreference.save(const Locale('en'));
      expect((await LanguagePreference.load())?.languageCode, 'en');
      await LanguagePreference.clear();
      expect(await LanguagePreference.load(), isNull);

      expect(await OnboardingPreference.load(), isFalse);
      await OnboardingPreference.complete();
      expect(await OnboardingPreference.load(), isTrue);
    },
  );
}

class _LanguageHarness extends StatefulWidget {
  const _LanguageHarness({required this.controller});

  final PhotoReportController controller;

  @override
  State<_LanguageHarness> createState() => _LanguageHarnessState();
}

class _LanguageHarnessState extends State<_LanguageHarness> {
  Locale locale = const Locale('zh', 'CN');

  @override
  Widget build(BuildContext context) {
    AppLocalizations.activeLocale = locale;
    return MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ProjectListScreen(
        controller: widget.controller,
        preferredLocale: locale,
        onLocaleChanged: (value) {
          if (value != null) setState(() => locale = value);
        },
      ),
    );
  }
}
