import 'package:cleantrail/domain/data_project.dart';
import 'package:cleantrail/domain/quality_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = QualityEngine();
  const source = '''date,value,region
2026-01-01,12,North
2026/02/01,14, North 
2026-03-01,,South
2026-04-01,not set,South
2026-05-01,18,East
2026-05-01,18,East
''';

  test('detects each supported issue type without changing source rows', () {
    final project = engine.importCsv(
      fileName: 'sample.csv',
      source: source,
      now: DateTime.utc(2026),
    );

    expect(project.records, hasLength(6));
    expect(project.originalRecords, hasLength(6));
    expect(
      project.issues.map((issue) => issue.kind).toSet(),
      containsAll({
        IssueKind.missingValue,
        IssueKind.duplicateRow,
        IssueKind.surroundingWhitespace,
        IssueKind.inconsistentType,
        IssueKind.inconsistentDate,
      }),
    );
    expect(project.originalRecords[1].values[2], ' North ');
  });

  test(
    'confirmed replacement changes working copy and creates audit action',
    () {
      final project = engine.importCsv(fileName: 'sample.csv', source: source);
      final issue = project.issues.singleWhere(
        (item) => item.kind == IssueKind.surroundingWhitespace,
      );

      final repaired = engine.resolve(
        project,
        issue.id,
        now: DateTime.utc(2026, 1, 2),
      );

      expect(repaired.records[1].values[2], 'North');
      expect(repaired.originalRecords[1].values[2], ' North ');
      expect(repaired.audit.single.action, 'replaced');
      expect(
        repaired.issues
            .singleWhere((item) => item.id.startsWith('${issue.id}#fixed-'))
            .status,
        IssueStatus.fixed,
      );
    },
  );

  test('duplicate repair removes only the later row', () {
    final project = engine.importCsv(fileName: 'sample.csv', source: source);
    final issue = project.issues.singleWhere(
      (item) => item.kind == IssueKind.duplicateRow,
    );

    final repaired = engine.resolve(project, issue.id);

    expect(repaired.records, hasLength(5));
    expect(repaired.originalRecords, hasLength(6));
    expect(repaired.audit.single.action, 'removedRow');
  });

  test('every repair is followed by a fresh inspection', () {
    final project = engine.importCsv(
      fileName: 'dates.csv',
      source: 'date,value\n2026-01-01,1\n 2026/02/01 ,2\n2026-03-01,3\n',
    );
    final whitespace = project.issues.singleWhere(
      (item) => item.kind == IssueKind.surroundingWhitespace,
    );

    final repaired = engine.resolve(project, whitespace.id);

    expect(
      repaired.openIssues.where(
        (item) => item.kind == IssueKind.inconsistentDate,
      ),
      hasLength(1),
    );
    expect(repaired.fixedCount, 1);
  });

  test(
    'mixed dates preserve format order and reject invalid calendar days',
    () {
      final project = engine.importCsv(
        fileName: 'mixed-dates.csv',
        source:
            'date,value\n'
            '2024-02-29,1\n'
            '2024/2/29,2\n'
            '02/3/2024,3\n'
            '3-02-2024,4\n'
            '2023-02-29,5\n',
      );
      final dateIssues = project.issues.where(
        (item) => item.kind == IssueKind.inconsistentDate,
      );

      expect(
        {for (final issue in dateIssues) issue.originalValue: issue.suggestion},
        {
          '2024/2/29': '2024-02-29',
          '02/3/2024': '2024-02-03',
          '3-02-2024': '2024-02-03',
          '2023-02-29': null,
        },
      );
    },
  );

  test('empty replacement cannot falsely resolve a missing value', () {
    final project = engine.importCsv(
      fileName: 'missing.csv',
      source: 'name,value\nA,\n',
    );

    expect(
      () => engine.resolve(project, project.issues.single.id, replacement: ''),
      throwsA(
        isA<CsvImportException>().having(
          (error) => error.code,
          'code',
          'replacementRequired',
        ),
      ),
    );
  });

  test('invalid input is rejected with a stable error code', () {
    expect(
      () => engine.importCsv(fileName: 'empty.csv', source: 'header\n'),
      throwsA(
        isA<CsvImportException>().having(
          (error) => error.code,
          'code',
          'noDataRows',
        ),
      ),
    );
  });

  test('project JSON round trip preserves working and source state', () {
    final project = engine.importCsv(fileName: 'sample.csv', source: source);
    final restored = DataProject.fromJson(project.toJson());

    expect(restored.fileName, project.fileName);
    expect(restored.records.last.values, project.records.last.values);
    expect(restored.issues.length, project.issues.length);
  });

  test('ignored issue stays suppressed after a later repair', () {
    final project = engine.importCsv(fileName: 'sample.csv', source: source);
    final duplicate = project.issues.singleWhere(
      (item) => item.kind == IssueKind.duplicateRow,
    );
    final ignored = engine.resolve(project, duplicate.id, ignore: true);
    final whitespace = ignored.openIssues.singleWhere(
      (item) => item.kind == IssueKind.surroundingWhitespace,
    );

    final repaired = engine.resolve(ignored, whitespace.id);

    expect(
      repaired.issues.where((item) => item.id == duplicate.id),
      hasLength(1),
    );
    expect(
      repaired.issues.singleWhere((item) => item.id == duplicate.id).status,
      IssueStatus.ignored,
    );
    expect(
      repaired.issues.map((item) => item.id).toSet(),
      hasLength(repaired.issues.length),
    );
  });

  test('kept defects continue to reduce the quality score', () {
    final project = engine.importCsv(
      fileName: 'missing.csv',
      source: 'name,value\nA,\n',
    );
    final ignored = engine.resolve(
      project,
      project.openIssues.single.id,
      ignore: true,
    );

    expect(ignored.openIssues, isEmpty);
    expect(ignored.ignoredCount, 1);
    expect(ignored.qualityScore, lessThan(100));
  });

  test('import preserves whitespace, empty, and duplicate headers exactly', () {
    final project = engine.importCsv(
      fileName: 'headers.csv',
      source: ' name ,,name\nAlice,1,2\n',
    );

    expect(project.headers, [' name ', '', 'name']);
  });

  test('issue-heavy files stop at the mobile review limit', () {
    final rows = List.generate(501, (index) => '$index,').join('\n');

    expect(
      () =>
          engine.importCsv(fileName: 'sparse.csv', source: 'id,value\n$rows\n'),
      throwsA(
        isA<CsvImportException>().having(
          (error) => error.code,
          'code',
          'tooManyIssues',
        ),
      ),
    );
  });

  test('a defect that recurs after repair is detected again', () {
    final project = engine.importCsv(
      fileName: 'recurrence.csv',
      source: 'value\n text \n13\n14\n15\n',
    );
    final whitespace = project.openIssues.singleWhere(
      (item) => item.kind == IssueKind.surroundingWhitespace,
    );
    final trimmed = engine.resolve(project, whitespace.id);
    final typeIssue = trimmed.openIssues.singleWhere(
      (item) => item.kind == IssueKind.inconsistentType,
    );
    final withRecurringWhitespace = engine.resolve(
      trimmed,
      typeIssue.id,
      replacement: ' 15 ',
    );

    expect(
      withRecurringWhitespace.openIssues.where(
        (item) => item.kind == IssueKind.surroundingWhitespace,
      ),
      hasLength(1),
    );
    expect(
      withRecurringWhitespace.issues.map((item) => item.id).toSet(),
      hasLength(withRecurringWhitespace.issues.length),
    );
  });

  test('an ignored defect retires when another repair removes it', () {
    final project = engine.importCsv(
      fileName: 'indirect.csv',
      source: 'value\n text \n13\n14\n15\n',
    );
    final typeIssue = project.openIssues.singleWhere(
      (item) => item.kind == IssueKind.inconsistentType,
    );
    final ignored = engine.resolve(project, typeIssue.id, ignore: true);
    final whitespace = ignored.openIssues.singleWhere(
      (item) => item.kind == IssueKind.surroundingWhitespace,
    );

    final repaired = engine.resolve(ignored, whitespace.id, replacement: '12');

    expect(repaired.openIssues, isEmpty);
    expect(repaired.ignoredCount, 0);
    expect(repaired.audit.map((item) => item.action), ['ignored', 'replaced']);
    expect(repaired.qualityScore, 100);
  });

  test('an ignored defect reopens after its original value changes', () {
    final project = engine.importCsv(
      fileName: 'changed.csv',
      source: 'value\n text \n13\n14\n15\n',
    );
    final typeIssue = project.openIssues.singleWhere(
      (item) => item.kind == IssueKind.inconsistentType,
    );
    final ignored = engine.resolve(project, typeIssue.id, ignore: true);
    final whitespace = ignored.openIssues.singleWhere(
      (item) => item.kind == IssueKind.surroundingWhitespace,
    );

    final changed = engine.resolve(ignored, whitespace.id, replacement: 'bad');

    final reopened = changed.openIssues.singleWhere(
      (item) => item.kind == IssueKind.inconsistentType,
    );
    expect(reopened.originalValue, 'bad');
    expect(changed.ignoredCount, 0);
  });

  test('500 issues are accepted while 501 are rejected', () {
    String sparseRows(int count) =>
        List.generate(count, (index) => '$index,').join('\n');

    final accepted = engine.importCsv(
      fileName: '500.csv',
      source: 'id,value\n${sparseRows(500)}\n',
    );
    expect(accepted.openIssues, hasLength(500));

    expect(
      () => engine.importCsv(
        fileName: '501.csv',
        source: 'id,value\n${sparseRows(501)}\n',
      ),
      throwsA(
        isA<CsvImportException>().having(
          (error) => error.code,
          'code',
          'tooManyIssues',
        ),
      ),
    );
  });

  test('combined cell limit is enforced independently of rows and columns', () {
    final header = List.generate(100, (index) => 'c$index').join(',');
    final row = List.generate(100, (index) => '$index').join(',');
    final rows = List.filled(1001, row).join('\n');

    expect(
      () => engine.importCsv(fileName: 'wide.csv', source: '$header\n$rows\n'),
      throwsA(
        isA<CsvImportException>().having(
          (error) => error.code,
          'code',
          'tooManyCells',
        ),
      ),
    );
  });
}
