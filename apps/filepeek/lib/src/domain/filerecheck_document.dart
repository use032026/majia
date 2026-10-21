import 'dart:convert';
import 'dart:typed_data';

/// Pure Dart inspection and working-copy model. No file system access occurs here.
enum FileKind { json, csv, txt, log }

enum DiagnosticSeverity { info, warning, error }

enum DiagnosticCode {
  invalidJson,
  csvUnexpectedQuote,
  csvUnexpectedTextAfterQuote,
  csvUnclosedQuote,
  csvMissingHeader,
  csvEmptyHeader,
  csvDuplicateHeader,
  csvColumnMismatch,
}

enum FileRecheckErrorCode {
  tooLarge,
  invalidUtf8,
  binaryContent,
  tooManyLines,
  tooManyColumns,
  unsupportedType,
  invalidOperation,
  invalidComparison,
  diffLimit,
}

class FileRecheckException implements Exception {
  const FileRecheckException(this.code, this.message);

  final FileRecheckErrorCode code;
  final String message;

  @override
  String toString() => 'FileRecheckException(${code.name}): $message';
}

class Diagnostic {
  const Diagnostic(
    this.severity,
    this.message, {
    required this.code,
    this.line,
    this.column,
    this.expectedColumns,
    this.actualColumns,
  });

  final DiagnosticCode code;
  final DiagnosticSeverity severity;
  final String message;
  final int? line;
  final int? column;
  final int? expectedColumns;
  final int? actualColumns;
}

enum LogSeverity { debug, info, warning, error, none }

class ContentLine {
  const ContentLine(this.number, this.text, this.severity);

  final int number;
  final String text;
  final LogSeverity severity;
}

class SearchHit {
  const SearchHit(this.line, this.column, this.text);

  final int line;
  final int column;
  final String text;
}

class CsvRow {
  const CsvRow(this.cells, this.sourceLine, this.dataIndex);

  final List<String> cells;
  final int sourceLine;

  /// Zero-based position in [CsvTable.rows], stable in filtered results.
  final int dataIndex;
}

class CsvTable {
  const CsvTable(this.headers, this.rows);

  final List<String> headers;
  final List<CsvRow> rows;
}

enum JsonDifferenceKind { added, removed, changed }

class JsonDifference {
  const JsonDifference(this.path, this.kind, {this.before, this.after});

  final String path;
  final JsonDifferenceKind kind;
  final String? before;
  final String? after;
}

class FileRecheckDocument {
  FileRecheckDocument._(
    this.fileName,
    this.kind,
    this.byteSize,
    this.hasUtf8Bom,
    this.sourceText,
  ) : _workingText = sourceText {
    _refresh();
  }

  static const int maxBytes = 5 * 1024 * 1024;
  static const int maxLines = 10000;
  static const int maxColumns = 200;
  static const int maxDifferences = 500;
  static const int maxUndoDepth = 10;

  final String fileName;
  final FileKind kind;
  final int byteSize;
  final bool hasUtf8Bom;
  final String sourceText;
  String _workingText;
  final List<String> _undo = [];
  List<Diagnostic> _diagnostics = const [];
  List<ContentLine> _lines = const [];
  CsvTable? _csvTable;

  String get workingText => _workingText;
  bool get isModified => _workingText != sourceText;
  bool get canUndo => _undo.isNotEmpty;
  int get undoDepth => _undo.length;
  List<Diagnostic> get diagnostics => List.unmodifiable(_diagnostics);
  List<ContentLine> get lines => List.unmodifiable(_lines);
  CsvTable? get csvTable => _csvTable;
  bool get isValid =>
      !_diagnostics.any((item) => item.severity == DiagnosticSeverity.error);

  static FileRecheckDocument inspect({
    required String fileName,
    required Uint8List bytes,
  }) {
    final decoded = _decode(bytes);
    final kind = _detectKind(fileName, decoded.text);
    return FileRecheckDocument._(
      fileName,
      kind,
      bytes.length,
      decoded.bom,
      decoded.text,
    );
  }

  static FileKind _detectKind(String fileName, String text) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.json')) return FileKind.json;
    if (lower.endsWith('.csv')) return FileKind.csv;
    if (lower.endsWith('.txt') || lower.endsWith('.text')) return FileKind.txt;
    if (lower.endsWith('.log')) return FileKind.log;
    final trimmed = text.trimLeft();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return FileKind.json;
    }
    throw const FileRecheckException(
      FileRecheckErrorCode.unsupportedType,
      'Only JSON, CSV, TXT and LOG files are supported.',
    );
  }

  static _DecodedText _decode(Uint8List bytes) {
    if (bytes.length > maxBytes) {
      throw const FileRecheckException(
        FileRecheckErrorCode.tooLarge,
        'The file exceeds the 5 MiB limit.',
      );
    }
    final bom =
        bytes.length >= 3 &&
        bytes[0] == 0xef &&
        bytes[1] == 0xbb &&
        bytes[2] == 0xbf;
    final String text;
    try {
      text = utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      throw const FileRecheckException(
        FileRecheckErrorCode.invalidUtf8,
        'The file is not valid UTF-8.',
      );
    }
    // Dart's UTF-8 decoder already strips a leading BOM.
    final normalized = text;
    if (normalized.runes.any(
      (rune) =>
          rune == 0 ||
          (rune < 0x20 && rune != 0x09 && rune != 0x0a && rune != 0x0d),
    )) {
      throw const FileRecheckException(
        FileRecheckErrorCode.binaryContent,
        'The file contains binary or unsupported control characters.',
      );
    }
    _checkLines(normalized);
    return _DecodedText(normalized, bom);
  }

  static void _checkLines(String text) {
    final count = const LineSplitter().convert(text).length;
    if (count > maxLines) {
      throw const FileRecheckException(
        FileRecheckErrorCode.tooManyLines,
        'The file exceeds the 10,000-line limit.',
      );
    }
  }

  void _refresh() {
    final physicalLines = const LineSplitter().convert(_workingText);
    // LineSplitter omits the final empty line after a newline. The displayed
    // line number count should match the imported physical line limit.
    final displayLines = physicalLines.isEmpty ? <String>[''] : physicalLines;
    _lines = List.unmodifiable([
      for (var i = 0; i < displayLines.length; i++)
        ContentLine(
          i + 1,
          displayLines[i],
          kind == FileKind.log
              ? _logSeverity(displayLines[i])
              : LogSeverity.none,
        ),
    ]);
    _csvTable = null;
    if (kind == FileKind.json) {
      _diagnostics = _jsonDiagnostics(_workingText);
    } else if (kind == FileKind.csv) {
      final parsed = _parseCsv(_workingText);
      _diagnostics = parsed.diagnostics;
      _csvTable = parsed.table;
    } else {
      _diagnostics = const [];
    }
  }

  static LogSeverity _logSeverity(String text) {
    if (RegExp(r'\b(FATAL|ERROR|ERR)\b', caseSensitive: false).hasMatch(text)) {
      return LogSeverity.error;
    }
    if (RegExp(r'\b(WARN|WARNING)\b', caseSensitive: false).hasMatch(text)) {
      return LogSeverity.warning;
    }
    if (RegExp(r'\b(INFO|NOTICE)\b', caseSensitive: false).hasMatch(text)) {
      return LogSeverity.info;
    }
    if (RegExp(r'\b(DEBUG|TRACE)\b', caseSensitive: false).hasMatch(text)) {
      return LogSeverity.debug;
    }
    return LogSeverity.none;
  }

  List<SearchHit> search(String query) {
    if (query.isEmpty) return const [];
    final needle = query.toLowerCase();
    if (needle.length > 200) {
      throw const FileRecheckException(
        FileRecheckErrorCode.invalidOperation,
        'Search terms are limited to 200 characters.',
      );
    }
    return List.unmodifiable([
      for (final line in _lines)
        if (line.text.toLowerCase().contains(needle))
          SearchHit(
            line.number,
            line.text.toLowerCase().indexOf(needle) + 1,
            line.text,
          ),
    ]);
  }

  List<CsvRow> filterCsv(String query) {
    final table = _requireCsvTable();
    if (query.isEmpty) return table.rows;
    final needle = query.toLowerCase();
    if (needle.length > 200) {
      throw const FileRecheckException(
        FileRecheckErrorCode.invalidOperation,
        'Filters are limited to 200 characters.',
      );
    }
    return List.unmodifiable(
      table.rows.where(
        (row) => row.cells.any((cell) => cell.toLowerCase().contains(needle)),
      ),
    );
  }

  void formatJson() {
    if (kind != FileKind.json || !isValid) {
      throw const FileRecheckException(
        FileRecheckErrorCode.invalidOperation,
        'A valid JSON file is required for formatting.',
      );
    }
    final decoded = _parseJson(_workingText);
    final formatted = const JsonEncoder.withIndent('  ').convert(decoded);
    _apply(formatted);
  }

  void editCsvCell(int rowIndex, int columnIndex, String value) {
    final table = _requireCsvTable();
    if (rowIndex < 0 ||
        rowIndex >= table.rows.length ||
        columnIndex < 0 ||
        columnIndex >= table.headers.length) {
      throw const FileRecheckException(
        FileRecheckErrorCode.invalidOperation,
        'The selected CSV cell does not exist.',
      );
    }
    if (value.runes.any(
      (rune) =>
          rune == 0 ||
          (rune < 0x20 && rune != 0x09 && rune != 0x0a && rune != 0x0d),
    )) {
      throw const FileRecheckException(
        FileRecheckErrorCode.binaryContent,
        'The cell contains unsupported control characters.',
      );
    }
    final rows = [
      table.headers,
      for (final row in table.rows) List<String>.from(row.cells),
    ];
    rows[rowIndex + 1][columnIndex] = value;
    _apply(rows.map((row) => row.map(_escapeCsv).join(',')).join('\n'));
  }

  CsvTable _requireCsvTable() {
    final table = _csvTable;
    if (kind != FileKind.csv || table == null || !isValid) {
      throw const FileRecheckException(
        FileRecheckErrorCode.invalidOperation,
        'A valid CSV table is required.',
      );
    }
    return table;
  }

  static String _escapeCsv(String cell) {
    if (cell.contains(',') ||
        cell.contains('"') ||
        cell.contains('\n') ||
        cell.contains('\r')) {
      return '"${cell.replaceAll('"', '""')}"';
    }
    return cell;
  }

  /// Replaces only the in-memory working copy. Invalid JSON or CSV is retained
  /// for repair and reported through [diagnostics]; resource limits fail before
  /// any state or undo history changes.
  void replaceWorkingText(String text) => _apply(text);

  void _apply(String updated) {
    final bytes = utf8.encode(updated);
    if (utf8.decode(bytes) != updated) {
      throw const FileRecheckException(
        FileRecheckErrorCode.invalidUtf8,
        'The edited text contains an invalid Unicode sequence.',
      );
    }
    if (bytes.length + (hasUtf8Bom ? 3 : 0) > maxBytes) {
      throw const FileRecheckException(
        FileRecheckErrorCode.tooLarge,
        'The edited file would exceed the 5 MiB limit.',
      );
    }
    _checkLines(updated);
    if (updated.runes.any(
      (rune) =>
          rune == 0 ||
          (rune < 0x20 && rune != 0x09 && rune != 0x0a && rune != 0x0d),
    )) {
      throw const FileRecheckException(
        FileRecheckErrorCode.binaryContent,
        'The edited text contains unsupported control characters.',
      );
    }
    if (kind == FileKind.csv) _parseCsv(updated);
    if (updated == _workingText) return;
    _undo.add(_workingText);
    if (_undo.length > maxUndoDepth) _undo.removeAt(0);
    _workingText = updated;
    _refresh();
  }

  bool undo() {
    if (_undo.isEmpty) return false;
    _workingText = _undo.removeLast();
    _refresh();
    return true;
  }

  void reset() {
    _undo.clear();
    _workingText = sourceText;
    _refresh();
  }

  Uint8List exportBytes() {
    final encoded = utf8.encode(_workingText);
    return Uint8List.fromList(
      hasUtf8Bom ? [0xef, 0xbb, 0xbf, ...encoded] : encoded,
    );
  }

  List<JsonDifference> compareJson(Uint8List otherBytes) {
    if (kind != FileKind.json || !isValid) {
      throw const FileRecheckException(
        FileRecheckErrorCode.invalidComparison,
        'A valid JSON document is required for comparison.',
      );
    }
    final other = _decode(otherBytes).text;
    if (_jsonDiagnostics(other).isNotEmpty) {
      throw const FileRecheckException(
        FileRecheckErrorCode.invalidComparison,
        'The comparison file is not valid JSON.',
      );
    }
    final differences = <JsonDifference>[];
    var visited = 0;
    void add(
      String path,
      JsonDifferenceKind kind,
      Object? before,
      Object? after,
    ) {
      if (differences.length >= maxDifferences || path.length > 512) {
        throw const FileRecheckException(
          FileRecheckErrorCode.diffLimit,
          'The JSON comparison exceeds the output limit.',
        );
      }
      differences.add(
        JsonDifference(
          path.isEmpty ? '/' : path,
          kind,
          before: kind == JsonDifferenceKind.added ? null : _shortValue(before),
          after: kind == JsonDifferenceKind.removed ? null : _shortValue(after),
        ),
      );
    }

    void walk(Object? left, Object? right, String path, int depth) {
      visited++;
      if (depth > 64 || visited > 20000) {
        throw const FileRecheckException(
          FileRecheckErrorCode.diffLimit,
          'The JSON comparison exceeds the depth or node limit.',
        );
      }
      if (left is Map<String, dynamic> && right is Map<String, dynamic>) {
        final keys = {...left.keys, ...right.keys}.toList()..sort();
        for (final key in keys) {
          final next =
              '$path/${key.replaceAll('~', '~0').replaceAll('/', '~1')}';
          if (!left.containsKey(key)) {
            add(next, JsonDifferenceKind.added, null, right[key]);
          } else if (!right.containsKey(key)) {
            add(next, JsonDifferenceKind.removed, left[key], null);
          } else {
            walk(left[key], right[key], next, depth + 1);
          }
        }
      } else if (left is List && right is List) {
        final length = left.length > right.length ? left.length : right.length;
        for (var i = 0; i < length; i++) {
          final next = '$path/$i';
          if (i >= left.length) {
            add(next, JsonDifferenceKind.added, null, right[i]);
          } else if (i >= right.length) {
            add(next, JsonDifferenceKind.removed, left[i], null);
          } else {
            walk(left[i], right[i], next, depth + 1);
          }
        }
      } else if (jsonEncode(left) != jsonEncode(right)) {
        add(path, JsonDifferenceKind.changed, left, right);
      }
    }

    walk(_parseJson(_workingText), _parseJson(other), '', 0);
    return List.unmodifiable(differences);
  }

  static String _shortValue(Object? value) {
    final text = jsonEncode(value);
    return text.length <= 160 ? text : '${text.substring(0, 157)}...';
  }

  String buildReport({
    String languageCode = 'en',
    String? filter,
    List<JsonDifference>? differences,
  }) {
    final zh = languageCode.toLowerCase().startsWith('zh');
    final buffer = StringBuffer()
      ..writeln(zh ? 'Fylto 文件检查报告' : 'Fylto inspection report')
      ..writeln(zh ? '文件：$fileName' : 'File: $fileName')
      ..writeln(
        zh
            ? '类型：${kind.name.toUpperCase()}'
            : 'Type: ${kind.name.toUpperCase()}',
      )
      ..writeln(zh ? '原文件大小：$byteSize 字节' : 'Source size: $byteSize bytes')
      ..writeln(
        zh
            ? '编码：UTF-8${hasUtf8Bom ? '（含 BOM）' : ''}'
            : 'Encoding: UTF-8${hasUtf8Bom ? ' with BOM' : ''}',
      )
      ..writeln(
        zh
            ? '工作副本已修改：${isModified ? '是' : '否'}'
            : 'Working copy modified: ${isModified ? 'yes' : 'no'}',
      )
      ..writeln(zh ? '行数：${_lines.length}' : 'Lines: ${_lines.length}')
      ..writeln(
        zh
            ? '状态：${isValid ? '有效' : '有错误'}'
            : 'Status: ${isValid ? 'valid' : 'has errors'}',
      );
    if (kind == FileKind.csv && _csvTable != null) {
      buffer.writeln(
        zh
            ? 'CSV：${_csvTable!.rows.length} 行数据，${_csvTable!.headers.length} 列'
            : 'CSV: ${_csvTable!.rows.length} data rows, '
                  '${_csvTable!.headers.length} columns',
      );
    }
    if (_diagnostics.isEmpty) {
      buffer.writeln(zh ? '诊断：无' : 'Diagnostics: none');
    } else {
      buffer.writeln(zh ? '诊断：' : 'Diagnostics:');
      for (final item in _diagnostics) {
        buffer.writeln(
          zh
              ? '- ${_diagnosticZh(item)}${item.line == null ? '' : '（${item.line} 行 ${item.column ?? 1} 列）'}'
              : '- ${item.severity.name}: ${item.message}'
                    '${item.line == null ? '' : ' at ${item.line}:${item.column ?? 1}'}',
        );
      }
    }
    if (filter != null && filter.trim().isNotEmpty) {
      final oneLineFilter = filter.replaceAll(RegExp(r'[\r\n]'), ' ');
      final safeFilter = oneLineFilter.length > 200
          ? '${oneLineFilter.substring(0, 200)}…'
          : oneLineFilter;
      buffer.writeln(zh ? '筛选：$safeFilter' : 'Filter: $safeFilter');
    }
    if (differences != null) {
      buffer.writeln(
        zh
            ? 'JSON 差异：${differences.length} 处'
            : 'JSON differences: ${differences.length}',
      );
      for (final item in differences) {
        final kindLabel = zh
            ? switch (item.kind) {
                JsonDifferenceKind.added => '新增',
                JsonDifferenceKind.removed => '删除',
                JsonDifferenceKind.changed => '变化',
              }
            : item.kind.name;
        buffer.writeln('- $kindLabel: ${item.path}');
      }
    }
    return buffer.toString();
  }

  static String _diagnosticZh(Diagnostic item) => switch (item.code) {
    DiagnosticCode.invalidJson => 'JSON 格式错误',
    DiagnosticCode.csvUnexpectedQuote => 'CSV 未加引号的单元格中出现引号',
    DiagnosticCode.csvUnexpectedTextAfterQuote => 'CSV 引号结束后出现多余文本',
    DiagnosticCode.csvUnclosedQuote => 'CSV 引号未闭合',
    DiagnosticCode.csvMissingHeader => 'CSV 缺少表头',
    DiagnosticCode.csvEmptyHeader => 'CSV 表头含空列名',
    DiagnosticCode.csvDuplicateHeader => 'CSV 表头有重复列名',
    DiagnosticCode.csvColumnMismatch =>
      'CSV 列数不匹配：应有 ${item.expectedColumns} 列，实际 ${item.actualColumns} 列',
  };

  static List<Diagnostic> _jsonDiagnostics(String text) {
    try {
      _parseJson(text);
      return const [];
    } on FormatException catch (error) {
      final offset = error.offset ?? 0;
      final safeOffset = offset.clamp(0, text.length);
      final prefix = text.substring(0, safeOffset);
      final line = '\n'.allMatches(prefix).length + 1;
      final lastNewline = prefix.lastIndexOf('\n');
      final column = safeOffset - lastNewline;
      return [
        Diagnostic(
          DiagnosticSeverity.error,
          error.message,
          code: DiagnosticCode.invalidJson,
          line: line,
          column: column,
        ),
      ];
    }
  }

  static Object? _parseJson(String text) {
    var depth = 0;
    var quoted = false;
    var escaped = false;
    for (var i = 0; i < text.length; i++) {
      final char = text.codeUnitAt(i);
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (char == 0x5c) {
          escaped = true;
        } else if (char == 0x22) {
          quoted = false;
        }
      } else if (char == 0x22) {
        quoted = true;
      } else if (char == 0x7b || char == 0x5b) {
        depth++;
        if (depth > 64) {
          throw FormatException(
            'JSON exceeds the 64-level depth limit.',
            text,
            i,
          );
        }
      } else if (char == 0x7d || char == 0x5d) {
        depth--;
      }
    }
    return jsonDecode(text);
  }

  static _CsvParseResult _parseCsv(String text) {
    final records = <CsvRow>[];
    final diagnostics = <Diagnostic>[];
    final cells = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;
    var justClosedQuote = false;
    var atCellStart = true;
    var line = 1;
    var recordLine = 1;
    void addCell() {
      cells.add(cell.toString());
      cell.clear();
      atCellStart = true;
      justClosedQuote = false;
      if (cells.length > maxColumns) {
        throw const FileRecheckException(
          FileRecheckErrorCode.tooManyColumns,
          'The CSV file exceeds the 200-column limit.',
        );
      }
    }

    void addRecord() {
      addCell();
      records.add(
        CsvRow(
          List.unmodifiable(cells),
          recordLine,
          records.isEmpty ? -1 : records.length - 1,
        ),
      );
      cells.clear();
      recordLine = line + 1;
      if (records.length > maxLines) {
        throw const FileRecheckException(
          FileRecheckErrorCode.tooManyLines,
          'The CSV file exceeds the 10,000-row limit.',
        );
      }
    }

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            inQuotes = false;
            justClosedQuote = true;
          }
        } else if (char == '\r') {
          if (i + 1 < text.length && text[i + 1] == '\n') i++;
          cell.write('\n');
          line++;
        } else {
          cell.write(char);
          if (char == '\n') line++;
        }
      } else if (char == '"') {
        if (!atCellStart) {
          diagnostics.add(
            Diagnostic(
              DiagnosticSeverity.error,
              'Unexpected quote in an unquoted CSV cell.',
              code: DiagnosticCode.csvUnexpectedQuote,
              line: line,
              column:
                  i -
                  (text.lastIndexOf('\n', i) > text.lastIndexOf('\r', i)
                      ? text.lastIndexOf('\n', i)
                      : text.lastIndexOf('\r', i)),
            ),
          );
          return _CsvParseResult(null, diagnostics);
        }
        inQuotes = true;
        atCellStart = false;
      } else if (char == ',') {
        addCell();
      } else if (char == '\n' || char == '\r') {
        if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        addRecord();
        line++;
      } else {
        if (justClosedQuote) {
          diagnostics.add(
            Diagnostic(
              DiagnosticSeverity.error,
              'Unexpected text after a quoted CSV cell.',
              code: DiagnosticCode.csvUnexpectedTextAfterQuote,
              line: line,
            ),
          );
          return _CsvParseResult(null, diagnostics);
        }
        cell.write(char);
        atCellStart = false;
      }
    }
    if (inQuotes) {
      diagnostics.add(
        Diagnostic(
          DiagnosticSeverity.error,
          'Unclosed quoted CSV cell.',
          code: DiagnosticCode.csvUnclosedQuote,
          line: recordLine,
        ),
      );
      return _CsvParseResult(null, diagnostics);
    }
    if (text.isNotEmpty && !text.endsWith('\n') && !text.endsWith('\r')) {
      addRecord();
    }
    if (records.isEmpty) {
      diagnostics.add(
        const Diagnostic(
          DiagnosticSeverity.error,
          'CSV needs a header row.',
          code: DiagnosticCode.csvMissingHeader,
        ),
      );
      return _CsvParseResult(null, diagnostics);
    }
    final headers = records.first.cells;
    if (headers.any((header) => header.isEmpty)) {
      diagnostics.add(
        Diagnostic(
          DiagnosticSeverity.warning,
          'CSV contains an empty column header.',
          code: DiagnosticCode.csvEmptyHeader,
          line: records.first.sourceLine,
        ),
      );
    }
    if (headers.toSet().length != headers.length) {
      diagnostics.add(
        Diagnostic(
          DiagnosticSeverity.warning,
          'CSV contains duplicate column headers.',
          code: DiagnosticCode.csvDuplicateHeader,
          line: records.first.sourceLine,
        ),
      );
    }
    for (final row in records.skip(1)) {
      if (row.cells.length != headers.length) {
        diagnostics.add(
          Diagnostic(
            DiagnosticSeverity.error,
            'Expected ${headers.length} columns, found ${row.cells.length}.',
            code: DiagnosticCode.csvColumnMismatch,
            line: row.sourceLine,
            expectedColumns: headers.length,
            actualColumns: row.cells.length,
          ),
        );
        if (diagnostics.length >= 20) break;
      }
    }
    if (diagnostics.any((item) => item.severity == DiagnosticSeverity.error)) {
      return _CsvParseResult(null, diagnostics);
    }
    return _CsvParseResult(
      CsvTable(headers, List.unmodifiable(records.skip(1))),
      diagnostics,
    );
  }
}

class _DecodedText {
  const _DecodedText(this.text, this.bom);
  final String text;
  final bool bom;
}

class _CsvParseResult {
  const _CsvParseResult(this.table, this.diagnostics);
  final CsvTable? table;
  final List<Diagnostic> diagnostics;
}
