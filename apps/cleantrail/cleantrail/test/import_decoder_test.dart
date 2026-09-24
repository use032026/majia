import 'package:cleantrail/data/csv_gateway.dart';
import 'package:cleantrail/data/import_decoder.dart';
import 'package:cleantrail/domain/quality_engine.dart';
import 'package:enough_convert/gbk.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const decoder = TabularImportDecoder();

  test('detects UTF-8 comma-separated text', () {
    final draft = decoder.inspect(
      PickedDataFile(
        fileName: 'orders.csv',
        bytes: 'name,amount\nNorth,12\n'.codeUnits,
      ),
    );

    expect(draft.detectedFormat, ImportFormat.csv);
    expect(draft.detectedEncoding, ImportEncoding.utf8);
  });

  test('detects and normalizes a GBK tab-separated text file', () {
    final draft = decoder.inspect(
      PickedDataFile(
        fileName: 'report.txt',
        bytes: const GbkCodec().encode('名称\t金额\n北京\t12\n上海\t14\n'),
      ),
    );

    expect(draft.detectedFormat, ImportFormat.tsv);
    expect(draft.detectedEncoding, ImportEncoding.gbk);
    final imported = decoder.decode(
      draft,
      const ImportSelection(
        format: ImportFormat.tsv,
        encoding: ImportEncoding.gbk,
      ),
    );
    final project = const QualityEngine().importCsv(
      fileName: imported.fileName,
      source: imported.csv,
    );
    expect(project.headers, ['名称', '金额']);
    expect(project.records.first.values, ['北京', '12']);
  });

  test('lists Excel worksheets and imports only the selected sheet', () {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'North');
    workbook['North'].appendRow([
      TextCellValue('region'),
      TextCellValue('amount'),
    ]);
    workbook['North'].appendRow([TextCellValue('North'), IntCellValue(12)]);
    workbook['South'].appendRow([
      TextCellValue('region'),
      TextCellValue('amount'),
    ]);
    workbook['South'].appendRow([TextCellValue('South'), IntCellValue(14)]);
    final bytes = workbook.encode();
    expect(bytes, isNotNull);

    final draft = decoder.inspect(
      PickedDataFile(fileName: 'regions.xlsx', bytes: bytes!),
    );

    expect(draft.detectedFormat, ImportFormat.xlsx);
    expect(draft.sheetNames, ['North', 'South']);
    final imported = decoder.decode(
      draft,
      const ImportSelection(format: ImportFormat.xlsx, sheetName: 'South'),
    );
    final project = const QualityEngine().importCsv(
      fileName: imported.fileName,
      source: imported.csv,
    );
    expect(project.fileName, 'regions.xlsx');
    expect(project.records.single.values, ['South', '14']);
  });

  test('rejects unsupported files before changing a project', () {
    expect(
      () => decoder.inspect(
        PickedDataFile(fileName: 'report.json', bytes: '{}'.codeUnits),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'unsupportedFormat',
        ),
      ),
    );
  });

  test('rejects bytes that are neither valid UTF-8 nor GBK', () {
    expect(
      () => decoder.inspect(
        PickedDataFile(fileName: 'broken.csv', bytes: [0x81]),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'invalidEncoding',
        ),
      ),
    );
  });
}
