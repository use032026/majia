import 'package:flutter_test/flutter_test.dart';
import 'package:photo_report/models.dart';
import 'package:photo_report/report/report_service.dart';
import 'package:photo_report/ui/create_flow_logic.dart';

void main() {
  test(
    'reuse suggestions keep first-seen order, trimming and case distinctions',
    () {
      expect(reusableIssueSuggestions(const []), isEmpty);
      expect(
        reusableIssueSuggestions([
          '',
          '  ',
          '  主卧 ',
          '主卧',
          '\u2003客厅\t',
          'room',
          'ROOM',
          ' 😀 ',
          '第六个区域',
        ]),
        ['主卧', '客厅', 'room', 'ROOM', '😀'],
      );
    },
  );

  test(
    'reuse suggestions stop reading after the fifth distinct nonempty value',
    () {
      var visited = 0;
      Iterable<String> source() sync* {
        for (final value in [' ', 'A', ' A ', 'B', 'C', 'D', 'E']) {
          visited++;
          yield value;
        }
        throw StateError('unused historical records should not be scanned');
      }

      expect(reusableIssueSuggestions(source()), ['A', 'B', 'C', 'D', 'E']);
      expect(visited, 7);
      expect(reusableIssueSuggestions(['new', 'new', ' ']), ['new']);
    },
  );

  testWidgets(
    'report dates remain consistent across records and repeated exports',
    (tester) async {
      final payloads = <Map<Object?, Object?>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ReportService.channel, (call) async {
            expect(call.method, 'generateReport');
            payloads.add(call.arguments as Map<Object?, Object?>);
            return '/tmp/report.pdf';
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(ReportService.channel, null),
      );
      final leapDay = DateTime(2024, 2, 29, 23, 59);
      final project = ProjectRecord(
        id: 'dates',
        name: 'Dates',
        address: '',
        companyName: '',
        inspectorName: '',
        clientName: '',
        codePrefix: 'A',
        inspectionDate: leapDay,
        notes: '',
        createdAt: leapDay,
        updatedAt: leapDay,
      );
      final dates = [
        null,
        DateTime(2026, 1, 1),
        leapDay,
        DateTime(2026, 12, 31, 23, 59),
      ];
      final issues = List.generate(
        80,
        (index) => IssueRecord(
          id: 'i$index',
          projectId: project.id,
          sequence: index + 1,
          code: 'A-$index',
          room: '',
          location: '',
          category: '',
          severity: IssueSeverity.unspecified,
          description: 'Record $index',
          status: IssueStatus.unspecified,
          assignee: '',
          dueDate: dates[index % dates.length],
          createdAt: leapDay,
          updatedAt: leapDay,
        ),
      );
      final options = const ReportOptions(includeDueDate: true);
      await const ReportService().generateReport(
        project,
        issues,
        options,
        languageCode: 'en',
      );
      await const ReportService().generateReport(
        project,
        [],
        options,
        languageCode: 'zh',
      );
      expect(
        (payloads.first['project'] as Map)['inspectionDate'],
        '2024-02-29',
      );
      final sentIssues = payloads.first['issues'] as List;
      expect(sentIssues, hasLength(80));
      for (var index = 0; index < sentIssues.length; index++) {
        final issue = sentIssues[index] as Map;
        expect(issue['code'], 'A-$index');
        expect(
          issue['dueDate'],
          ['', '2026-01-01', '2024-02-29', '2026-12-31'][index % 4],
        );
      }
      expect(payloads.first['languageCode'], 'en');
      expect(payloads.last['languageCode'], 'zh');
      expect((payloads.last['project'] as Map)['inspectionDate'], '2024-02-29');
      expect(payloads.last['issues'], isEmpty);
    },
  );

  group('现场照片记录模型', () {
    test('照片标注可完整写入并恢复', () {
      final photo = PhotoRecord(
        id: 'photo-1',
        issueId: 'issue-1',
        path: '/tmp/site.jpg',
        phase: PhotoPhase.before,
        createdAt: DateTime(2026, 8, 26, 9, 30),
        annotations: const [
          PhotoAnnotation(
            kind: AnnotationKind.rectangle,
            x1: 0.1,
            y1: 0.2,
            x2: 0.8,
            y2: 0.7,
            colorValue: 0xFF22C55E,
          ),
          PhotoAnnotation(
            kind: AnnotationKind.text,
            x1: 0.15,
            y1: 0.22,
            x2: 0.15,
            y2: 0.22,
            text: '墙面开裂',
          ),
        ],
      );

      final restored = PhotoRecord.fromMap(photo.toMap());

      expect(restored.phase, PhotoPhase.before);
      expect(restored.annotations, hasLength(2));
      expect(restored.annotations.first.kind, AnnotationKind.rectangle);
      expect(restored.annotations.first.colorValue, 0xFF22C55E);
      expect(restored.annotations.last.text, '墙面开裂');
      expect(restored.annotations.last.x1, 0.15);
    });

    test('旧版照片标注缺少颜色时仍按红色恢复', () {
      final annotation = PhotoAnnotation.fromJson({
        'kind': 'arrow',
        'x1': 0.1,
        'y1': 0.2,
        'x2': 0.7,
        'y2': 0.8,
        'text': '',
      });

      expect(annotation.colorValue, defaultPhotoAnnotationColorValue);
    });

    test('记录字段和处理状态保持一致', () {
      final now = DateTime(2026, 8, 26);
      final issue = IssueRecord(
        id: 'issue-7',
        projectId: 'project-1',
        sequence: 7,
        code: 'A-007',
        room: '主卫',
        location: '东侧墙面',
        category: '瓷砖空鼓',
        severity: IssueSeverity.medium,
        description: '距地面约1.2米处检测到空鼓',
        status: IssueStatus.pending,
        assignee: '施工方',
        dueDate: DateTime(2026, 9, 5),
        createdAt: now,
        updatedAt: now,
      );

      final restored = IssueRecord.fromMap(issue.toMap());

      expect(restored.code, 'A-007');
      expect(restored.room, '主卫');
      expect(restored.severity.label, '中');
      expect(restored.status.label, '待处理');
      expect(restored.dueDate, DateTime(2026, 9, 5));
    });

    test('快速记录允许不设置优先级和状态', () {
      expect(IssueSeverity.unspecified.label, '未设置');
      expect(IssueStatus.unspecified.label, '未设置');
    });

    test('项目可持久化最近生成的 PDF', () {
      final project = ProjectRecord(
        id: 'project-1',
        name: '现场记录',
        address: '一层大厅',
        companyName: '',
        inspectorName: '',
        clientName: '',
        codePrefix: 'A',
        inspectionDate: DateTime(2026, 8, 27),
        notes: '',
        createdAt: DateTime(2026, 8, 27),
        updatedAt: DateTime(2026, 8, 27),
        lastReportPath: '/tmp/latest.pdf',
        lastReportAt: DateTime(2026, 8, 27, 11, 30),
        formalFlowStep: 2,
      );

      final restored = ProjectRecord.fromMap(project.toMap());

      expect(restored.lastReportPath, '/tmp/latest.pdf');
      expect(restored.lastReportAt, DateTime(2026, 8, 27, 11, 30));
      expect(restored.formalFlowStep, 2);
    });

    test('简洁导出默认不包含额外字段', () {
      const options = ReportOptions();

      expect(options.layout, ReportLayout.concise);
      expect(options.includePosition, isFalse);
      expect(options.includeStatus, isFalse);
      expect(options.includeProjectDetails, isFalse);
      expect(options.toMap()['layout'], 'concise');
    });

    testWidgets('PDF 原生桥接会携带每条标注的颜色', (tester) async {
      Map<Object?, Object?>? payload;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ReportService.channel, (call) async {
            payload = call.arguments as Map<Object?, Object?>;
            return '/tmp/report.pdf';
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(ReportService.channel, null),
      );
      final now = DateTime(2026, 8, 28);
      final project = ProjectRecord(
        id: 'project-color',
        name: '标注颜色测试',
        address: '',
        companyName: '',
        inspectorName: '',
        clientName: '',
        codePrefix: 'A',
        inspectionDate: now,
        notes: '',
        createdAt: now,
        updatedAt: now,
      );
      final issue = IssueRecord(
        id: 'issue-color',
        projectId: project.id,
        sequence: 1,
        code: 'A-001',
        room: '',
        location: '',
        category: '颜色测试',
        severity: IssueSeverity.unspecified,
        description: '验证导出颜色',
        status: IssueStatus.unspecified,
        assignee: '',
        createdAt: now,
        updatedAt: now,
        photos: [
          PhotoRecord(
            id: 'photo-color',
            issueId: 'issue-color',
            path: '/tmp/color.jpg',
            phase: PhotoPhase.before,
            createdAt: now,
            annotations: const [
              PhotoAnnotation(
                kind: AnnotationKind.text,
                x1: 0.2,
                y1: 0.3,
                x2: 0.2,
                y2: 0.3,
                text: '白色标注',
                colorValue: 0xFFFFFFFF,
              ),
            ],
          ),
        ],
      );

      await const ReportService().generateReport(project, [
        issue,
      ], const ReportOptions());

      final issues = payload!['issues']! as List<Object?>;
      final firstIssue = issues.single! as Map<Object?, Object?>;
      final photos = firstIssue['photos']! as List<Object?>;
      final firstPhoto = photos.single! as Map<Object?, Object?>;
      final annotations = firstPhoto['annotations']! as List<Object?>;
      final annotation = annotations.single! as Map<Object?, Object?>;
      expect(annotation['color'], 0xFFFFFFFF);
    });

    test('长说明首行标题保留Unicode边界与换行规则', () {
      final emojis = List.filled(24, '😀').join();
      expect(quickRecordTitle(' \r\n\t$emojis\r\n其余说明'), emojis);
      expect(quickRecordTitle('$emojis🐱\n后续说明'), '$emojis…');
      expect(quickRecordTitle(' \n \r\n  A\tB\rC\r\n尾行'), 'A\tB\rC');
      expect(quickRecordTitle('\u2003\r\n\t '), '图文记录');
      expect(
        quickRecordTitle('现场记录\n${List.filled(10000, '下一行说明').join('\n')}'),
        '现场记录',
      );
      expect(quickRecordTitle('${'a' * 100000}\n尾行'), '${'a' * 24}…');
    });

    test('快速记录从说明首行生成稳定标题', () {
      expect(quickRecordTitle('主卫天花板漏水\n需要检查管道'), '主卫天花板漏水');
      expect(quickRecordTitle('   '), '图文记录');
      expect(quickRecordTitle('这是一个超过二十四个字符并且需要自动截断的现场情况描述文本'), endsWith('…'));
    });

    test('正式复核只提醒缺失内容且不改变记录', () {
      final now = DateTime(2026, 8, 27);
      final project = ProjectRecord(
        id: 'project-quick',
        name: '快速项目',
        address: '',
        companyName: '',
        inspectorName: '',
        clientName: '',
        codePrefix: 'A',
        inspectionDate: now,
        notes: '',
        createdAt: now,
        updatedAt: now,
      );
      final issue = IssueRecord(
        id: 'issue-quick',
        projectId: project.id,
        sequence: 1,
        code: 'A-001',
        room: '',
        location: '',
        category: '天花板漏水',
        severity: IssueSeverity.unspecified,
        description: '天花板正在滴水',
        status: IssueStatus.unspecified,
        assignee: '',
        createdAt: now,
        updatedAt: now,
        photos: [
          PhotoRecord(
            id: 'photo-quick',
            issueId: 'issue-quick',
            path: '/tmp/quick.jpg',
            phase: PhotoPhase.before,
            createdAt: now,
          ),
        ],
      );

      final warnings = formalReadinessWarnings(project, [issue]);

      expect(warnings, contains('项目地点尚未填写'));
      expect(warnings, contains('A-001 尚未填写区域'));
      expect(warnings, isNot(contains('A-001 尚未添加现场照片')));
      expect(issueLocationLabel(issue), '未分类');
      expect(hasFormalCoreFields(issue), isFalse);
    });
  });
}
