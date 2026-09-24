import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:enough_convert/gbk.dart';
import 'package:excel/excel.dart';

import 'csv_gateway.dart';

enum ImportFormat { csv, tsv, xlsx }

enum ImportEncoding { utf8, gbk }

class ImportDraft {
  const ImportDraft({
    required this.file,
    required this.detectedFormat,
    this.detectedEncoding,
    this.sheetNames = const [],
  });

  final PickedDataFile file;
  final ImportFormat detectedFormat;
  final ImportEncoding? detectedEncoding;
  final List<String> sheetNames;

  bool get isSpreadsheet => detectedFormat == ImportFormat.xlsx;
}

class ImportSelection {
  const ImportSelection({required this.format, this.encoding, this.sheetName});

  final ImportFormat format;
  final ImportEncoding? encoding;
  final String? sheetName;
}

class DecodedImport {
  const DecodedImport({required this.fileName, required this.csv});

  final String fileName;
  final String csv;
}

class TabularImportDecoder {
  const TabularImportDecoder();

  ImportDraft inspect(PickedDataFile file) {
    final extension = _extensionOf(file.fileName);
    if (extension == 'xlsx') {
      final workbook = _decodeWorkbook(file.bytes);
      final sheets = workbook.tables.entries
          .where((entry) => entry.value.maxRows > 0)
          .map((entry) => entry.key)
          .toList(growable: false);
      if (sheets.isEmpty) throw const FormatException('emptyFile');
      return ImportDraft(
        file: file,
        detectedFormat: ImportFormat.xlsx,
        sheetNames: sheets,
      );
    }
    if (!const {'csv', 'tsv', 'txt'}.contains(extension)) {
      throw const FormatException('unsupportedFormat');
    }

    final encoding = _detectEncoding(file.bytes);
    final source = _decodeText(file.bytes, encoding);
    return ImportDraft(
      file: file,
      detectedFormat: _detectTextFormat(source, extension),
      detectedEncoding: encoding,
    );
  }

  DecodedImport decode(ImportDraft draft, ImportSelection selection) {
    if (draft.isSpreadsheet) {
      if (selection.format != ImportFormat.xlsx) {
        throw const FormatException('unsupportedFormat');
      }
      return DecodedImport(
        fileName: draft.file.fileName,
        csv: _spreadsheetAsCsv(draft.file.bytes, selection.sheetName),
      );
    }

    if (selection.format == ImportFormat.xlsx) {
      throw const FormatException('unsupportedFormat');
    }
    final encoding = selection.encoding ?? draft.detectedEncoding;
    if (encoding == null) throw const FormatException('invalidEncoding');
    final source = _decodeText(draft.file.bytes, encoding);
    if (selection.format == ImportFormat.csv) {
      return DecodedImport(fileName: draft.file.fileName, csv: source);
    }

    try {
      final rows = const CsvToListConverter(
        fieldDelimiter: '\t',
        eol: '\n',
        shouldParseNumbers: false,
        allowInvalid: false,
        convertEmptyTo: '',
      ).convert(_normalizeLines(source));
      return DecodedImport(
        fileName: draft.file.fileName,
        csv: const ListToCsvConverter().convert(rows),
      );
    } on Object {
      throw const FormatException('invalidCsv');
    }
  }

  Excel _decodeWorkbook(List<int> bytes) {
    try {
      return Excel.decodeBytes(bytes);
    } on Object {
      throw const FormatException('invalidSpreadsheet');
    }
  }

  String _spreadsheetAsCsv(List<int> bytes, String? sheetName) {
    if (sheetName == null) throw const FormatException('missingSheet');
    final workbook = _decodeWorkbook(bytes);
    final sheet = workbook.tables[sheetName];
    if (sheet == null) throw const FormatException('missingSheet');
    if (sheet.maxRows > 10001) throw const FormatException('tooManyRows');
    if (sheet.maxColumns == 0 || sheet.maxColumns > 100) {
      throw const FormatException('invalidColumnCount');
    }
    if ((sheet.maxRows - 1) * sheet.maxColumns > 100000) {
      throw const FormatException('tooManyCells');
    }
    final rows = sheet.rows
        .map(
          (row) =>
              row.map((cell) => _cellText(cell?.value)).toList(growable: false),
        )
        .toList(growable: false);
    return const ListToCsvConverter().convert(rows);
  }

  String _cellText(CellValue? value) {
    return switch (value) {
      null => '',
      TextCellValue() => value.value.toString(),
      DateCellValue() => _date(value.year, value.month, value.day),
      DateTimeCellValue() =>
        '${_date(value.year, value.month, value.day)} '
            '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}:'
            '${_twoDigits(value.second)}',
      TimeCellValue() =>
        '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}:'
            '${_twoDigits(value.second)}',
      FormulaCellValue() => '=${value.formula}',
      _ => value.toString(),
    };
  }

  ImportEncoding _detectEncoding(List<int> bytes) {
    try {
      const Utf8Decoder(allowMalformed: false).convert(bytes);
      return ImportEncoding.utf8;
    } on FormatException {
      try {
        _decodeGbk(bytes);
        return ImportEncoding.gbk;
      } on FormatException {
        throw const FormatException('invalidEncoding');
      }
    }
  }

  String _decodeText(List<int> bytes, ImportEncoding encoding) {
    try {
      return switch (encoding) {
        ImportEncoding.utf8 => const Utf8Decoder(
          allowMalformed: false,
        ).convert(bytes),
        ImportEncoding.gbk => _decodeGbk(bytes),
      };
    } on FormatException {
      throw const FormatException('invalidEncoding');
    }
  }

  String _decodeGbk(List<int> bytes) {
    return const GbkCodec(allowInvalid: false).decode(bytes);
  }

  ImportFormat _detectTextFormat(String source, String extension) {
    final normalized = _normalizeLines(source);
    final lines = const LineSplitter()
        .convert(normalized)
        .where((line) => line.trim().isNotEmpty)
        .take(8);
    var commas = 0;
    var tabs = 0;
    for (final line in lines) {
      commas += _countOutsideQuotes(line, ',');
      tabs += _countOutsideQuotes(line, '\t');
    }
    if (tabs > commas) return ImportFormat.tsv;
    if (commas > tabs) return ImportFormat.csv;
    return extension == 'tsv' ? ImportFormat.tsv : ImportFormat.csv;
  }

  int _countOutsideQuotes(String line, String delimiter) {
    var quoted = false;
    var count = 0;
    for (var index = 0; index < line.length; index++) {
      final character = line[index];
      if (character == '"') {
        if (quoted && index + 1 < line.length && line[index + 1] == '"') {
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (!quoted && character == delimiter) {
        count++;
      }
    }
    return count;
  }

  String _normalizeLines(String source) => source
      .replaceFirst('\ufeff', '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');

  String _extensionOf(String fileName) {
    final separator = fileName.lastIndexOf('.');
    return separator < 0 ? '' : fileName.substring(separator + 1).toLowerCase();
  }

  String _date(int year, int month, int day) =>
      '$year-${_twoDigits(month)}-${_twoDigits(day)}';

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
