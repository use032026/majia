import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_cost/core/domain/core_models.dart';
import 'package:trip_cost/core/export/expense_export_service.dart';

import '../../helpers/m4_fakes.dart';
import '../../helpers/m5_fixtures.dart';

void main() {
  late Directory temporaryDirectory;
  late _FakeDocumentGateway gateway;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('m8-export-');
    gateway = _FakeDocumentGateway(temporaryDirectory);
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'creates UTF-8 BOM CSV with required snapshot fields and safe cells',
    () async {
      final repository = MemoryExpenseRepository([
        fixtureExpense(title: '=SUM(1,2)', actual: '105'),
        fixtureExpense(
          id: 'expense-2',
          title: '咖啡, "特选"',
          occurredAt: DateTime.utc(2026, 8, 16, 7),
        ),
        fixtureExpense(
          id: 'expense-3',
          estimate: '-20',
          entryType: ExpenseEntryType.refund,
          relatedExpenseId: 'expense-1',
        ),
      ]);
      final service = ExpenseExportService(
        expenseRepository: repository,
        platformGateway: gateway,
        temporaryDirectory: () async => temporaryDirectory,
        clock: () => DateTime.utc(2026, 8, 17, 8),
      );

      final file = await service.createCsv(locale: 'zh-Hans');

      final bytes = await file.readAsBytes();
      expect(bytes.take(3), <int>[0xEF, 0xBB, 0xBF]);
      final contents = utf8.decode(bytes.skip(3).toList());
      expect(contents, startsWith('"消费日期","商户或项目"'));
      expect(contents, contains('"\'=SUM(1,2)"'));
      expect(contents, contains('"咖啡, ""特选"""'));
      expect(contents, contains('"JPY","CNY","0.05","2026-08-17"'));
      expect(contents, contains('"105"'));
      expect(contents, contains('"-400","JPY"'));
      expect(contents, isNot(contains('"\'-400"')));
      expect(contents, contains('"关联原交易 ID"'));
      expect(contents, contains('"expense-1"'));
      expect(contents.contains('\n') && !contents.contains('\r\n'), isFalse);
    },
  );

  test('sends localized paginatable rows to native PDF renderer', () async {
    final service = ExpenseExportService(
      expenseRepository: MemoryExpenseRepository([
        fixtureExpense(title: '晚餐', actual: '102.5'),
      ]),
      platformGateway: gateway,
      temporaryDirectory: () async => temporaryDirectory,
      clock: () => DateTime.utc(2026, 8, 17, 8),
    );

    final file = await service.createPdf(locale: 'zh-Hans');

    expect(await file.exists(), isTrue);
    expect(gateway.pdfDocument!['title'], 'RhinoSmart 消费导出');
    final rows = gateway.pdfDocument!['rows']! as List<Object?>;
    final row = rows.single! as Map<String, Object?>;
    expect(row['transactionCurrency'], 'JPY');
    expect(row['homeCurrency'], 'CNY');
    expect(row['actualAmount'], '102.5');
    expect(row['rateSource'], isNotEmpty);
  });

  test('reports empty and oversized data sets explicitly', () async {
    final empty = ExpenseExportService(
      expenseRepository: MemoryExpenseRepository(),
      platformGateway: gateway,
    );
    await expectLater(
      empty.createCsv(locale: 'en'),
      throwsA(
        isA<ExpenseExportException>().having(
          (error) => error.code,
          'code',
          ExpenseExportException.empty,
        ),
      ),
    );

    final repeated = List.generate(
      ExpenseExportService.maximumRows + 1,
      (index) => fixtureExpense(id: 'expense-$index'),
    );
    final oversized = ExpenseExportService(
      expenseRepository: MemoryExpenseRepository(repeated),
      platformGateway: gateway,
    );
    await expectLater(
      oversized.createPdf(locale: 'en'),
      throwsA(
        isA<ExpenseExportException>().having(
          (error) => error.code,
          'code',
          ExpenseExportException.tooLarge,
        ),
      ),
    );
  });

  test('trip export contains only expenses from the selected trip', () async {
    final service = ExpenseExportService(
      expenseRepository: MemoryExpenseRepository([
        fixtureExpense(title: 'Tokyo dinner'),
        fixtureExpense(
          id: 'expense-2',
          tripId: 'trip-2',
          title: 'Paris dinner',
        ),
      ]),
      platformGateway: gateway,
      temporaryDirectory: () async => temporaryDirectory,
      clock: () => DateTime.utc(2026, 8, 17, 8),
    );

    final file = await service.createCsv(locale: 'en', tripId: 'trip-1');
    final contents = await file.readAsString();

    expect(contents, contains('Tokyo dinner'));
    expect(contents, isNot(contains('Paris dinner')));
  });
}

final class _FakeDocumentGateway implements DocumentPlatformGateway {
  _FakeDocumentGateway(this.directory);

  final Directory directory;
  Map<String, Object?>? pdfDocument;

  @override
  Future<String> generatePdf(Map<String, Object?> document) async {
    pdfDocument = document;
    final file = File('${directory.path}/output.pdf');
    await file.writeAsBytes(<int>[0x25, 0x50, 0x44, 0x46]);
    return file.path;
  }

  @override
  Future<String?> pickBackupFile() async => null;

  @override
  Future<void> shareFiles(List<String> paths) async {}
}
