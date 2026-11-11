import 'dart:math' as math;

import 'package:csv/csv.dart';

import 'data_project.dart';

class CsvImportException implements Exception {
  const CsvImportException(this.code);
  final String code;
}

class QualityEngine {
  const QualityEngine();

  static const maxRows = 10000;
  static const maxColumns = 100;
  static const maxCells = 100000;
  static const maxIssues = 500;

  static final _isoDatePattern = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$');
  static final _slashYmdPattern = RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2})$');
  static final _slashMdyPattern = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$');
  static final _dashDmyPattern = RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{4})$');

  DataProject importCsv({
    required String fileName,
    required String source,
    DateTime? now,
  }) {
    final normalized = source
        .replaceFirst('\ufeff', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    if (normalized.trim().isEmpty) {
      throw const CsvImportException('emptyFile');
    }

    late final List<List<dynamic>> matrix;
    try {
      matrix = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
        allowInvalid: false,
        convertEmptyTo: '',
      ).convert(normalized);
    } on Object {
      throw const CsvImportException('invalidCsv');
    }

    if (matrix.length < 2) {
      throw const CsvImportException('noDataRows');
    }
    if (matrix.length - 1 > maxRows) {
      throw const CsvImportException('tooManyRows');
    }
    final width = matrix.map((row) => row.length).fold<int>(0, math.max);
    if (width == 0 || width > maxColumns) {
      throw const CsvImportException('invalidColumnCount');
    }
    if ((matrix.length - 1) * width > maxCells) {
      throw const CsvImportException('tooManyCells');
    }

    // Headers are user data too. Preserve them byte-for-byte after CSV decoding;
    // presentation fallbacks belong in the UI, never in the exported dataset.
    final headers = List<String>.generate(
      width,
      (index) =>
          index < matrix.first.length ? matrix.first[index].toString() : '',
    );
    final records = <DataRecord>[];
    for (var rowIndex = 1; rowIndex < matrix.length; rowIndex++) {
      final values = List<String>.generate(
        width,
        (column) => column < matrix[rowIndex].length
            ? matrix[rowIndex][column].toString()
            : '',
      );
      records.add(DataRecord(id: 'row-$rowIndex', values: values));
    }

    final timestamp = now ?? DateTime.now();
    final issues = inspect(headers: headers, records: records);
    return DataProject(
      id: 'project-${timestamp.microsecondsSinceEpoch}',
      fileName: fileName,
      headers: headers,
      originalRecords: records,
      records: records,
      issues: issues,
      audit: const [],
      importedAt: timestamp,
      updatedAt: timestamp,
    );
  }

  List<DataIssue> inspect({
    required List<String> headers,
    required List<DataRecord> records,
  }) {
    final issues = <DataIssue>[];
    void addIssue(DataIssue issue) {
      if (issues.length >= maxIssues) {
        throw const CsvImportException('tooManyIssues');
      }
      issues.add(issue);
    }

    final duplicateRows = <String>{};
    final seen = <String, String>{};

    for (final row in records) {
      final signature = row.values
          .map((value) => value.trim().toLowerCase())
          .join('\u001f');
      if (seen.containsKey(signature)) {
        duplicateRows.add(row.id);
        addIssue(
          DataIssue(
            id: 'duplicate-${row.id}',
            kind: IssueKind.duplicateRow,
            rowId: row.id,
            columnIndex: null,
            originalValue: row.values.join(' | '),
            suggestion: null,
          ),
        );
      } else {
        seen[signature] = row.id;
      }
    }

    final numericColumns = <int>{};
    for (var column = 0; column < headers.length; column++) {
      final values = records
          .where((row) => !duplicateRows.contains(row.id))
          .map((row) => row.values[column].trim())
          .where((value) => value.isNotEmpty)
          .toList();
      if (values.length >= 3) {
        final numeric = values
            .where((value) => num.tryParse(value) != null)
            .length;
        if (numeric >= math.max(2, (values.length * 0.7).ceil())) {
          numericColumns.add(column);
        }
      }
    }

    final dateColumns = <int>{};
    final mixedDateColumns = <int>{};
    for (var column = 0; column < headers.length; column++) {
      final header = headers[column].toLowerCase();
      if (!_looksLikeDateHeader(header)) continue;
      final formats = <String>{};
      var parsedCount = 0;
      var valueCount = 0;
      for (final row in records) {
        if (duplicateRows.contains(row.id)) continue;
        final value = row.values[column].trim();
        if (value.isEmpty) continue;
        valueCount++;
        final parsed = _parseDate(value);
        if (parsed != null) {
          parsedCount++;
          formats.add(parsed.$2);
        }
      }
      if (valueCount >= 2 &&
          parsedCount >= math.max(2, (valueCount * 0.6).ceil())) {
        dateColumns.add(column);
      }
      if (dateColumns.contains(column) && formats.length > 1) {
        mixedDateColumns.add(column);
      }
    }

    for (final row in records) {
      if (duplicateRows.contains(row.id)) continue;
      for (var column = 0; column < headers.length; column++) {
        final value = row.values[column];
        final idBase = '${row.id}-$column';
        if (value.isEmpty) {
          addIssue(
            DataIssue(
              id: 'missing-$idBase',
              kind: IssueKind.missingValue,
              rowId: row.id,
              columnIndex: column,
              originalValue: value,
              suggestion: null,
            ),
          );
          continue;
        }
        if (value != value.trim()) {
          addIssue(
            DataIssue(
              id: 'whitespace-$idBase',
              kind: IssueKind.surroundingWhitespace,
              rowId: row.id,
              columnIndex: column,
              originalValue: value,
              suggestion: value.trim(),
            ),
          );
        }
        final inspectedValue = value.trim();
        if (dateColumns.contains(column)) {
          final parsed = _parseDate(inspectedValue);
          if (parsed == null ||
              (mixedDateColumns.contains(column) && parsed.$2 != 'iso')) {
            addIssue(
              DataIssue(
                id: 'date-$idBase',
                kind: IssueKind.inconsistentDate,
                rowId: row.id,
                columnIndex: column,
                originalValue: value,
                suggestion: parsed == null ? null : _isoDate(parsed.$1),
              ),
            );
            continue;
          }
        }
        if (numericColumns.contains(column) &&
            num.tryParse(inspectedValue) == null) {
          addIssue(
            DataIssue(
              id: 'type-$idBase',
              kind: IssueKind.inconsistentType,
              rowId: row.id,
              columnIndex: column,
              originalValue: value,
              suggestion: null,
            ),
          );
        }
      }
    }
    return issues;
  }

  DataProject resolve(
    DataProject project,
    String issueId, {
    String? replacement,
    bool ignore = false,
    DateTime? now,
  }) {
    final issue = project.issues.singleWhere(
      (item) => item.id == issueId && item.status == IssueStatus.open,
    );
    final timestamp = now ?? DateTime.now();
    final issues = [...project.issues];
    final issueIndex = issues.indexWhere((item) => item.id == issueId);
    final records = [...project.records];
    var action = ignore ? 'ignored' : 'replaced';
    var toValue = issue.originalValue;

    if (!ignore) {
      if (issue.kind == IssueKind.duplicateRow) {
        records.removeWhere((row) => row.id == issue.rowId);
        action = 'removedRow';
        toValue = '';
      } else {
        final newValue = replacement ?? issue.suggestion;
        if (newValue == null ||
            ((issue.kind == IssueKind.missingValue ||
                    issue.kind == IssueKind.inconsistentType ||
                    issue.kind == IssueKind.inconsistentDate) &&
                newValue.trim().isEmpty)) {
          throw const CsvImportException('replacementRequired');
        }
        final recordIndex = records.indexWhere((row) => row.id == issue.rowId);
        if (recordIndex < 0 || issue.columnIndex == null) return project;
        final values = [...records[recordIndex].values];
        values[issue.columnIndex!] = newValue;
        records[recordIndex] = records[recordIndex].copyWith(values: values);
        toValue = newValue;
      }
    }

    issues[issueIndex] = issue.copyWith(
      status: ignore ? IssueStatus.ignored : IssueStatus.fixed,
    );
    final columnName = issue.columnIndex == null
        ? '—'
        : '#${issue.columnIndex! + 1} '
              '${project.headers[issue.columnIndex!].isEmpty ? '<empty header>' : project.headers[issue.columnIndex!]}';
    final actionLog = AuditAction(
      issueId: issue.id,
      kind: issue.kind,
      rowId: issue.rowId,
      columnName: columnName,
      action: action,
      fromValue: issue.originalValue,
      toValue: toValue,
      occurredAt: timestamp,
    );
    final freshIssues = inspect(headers: project.headers, records: records);
    final priorHistory = issues
        .where((item) => item.status != IssueStatus.open && item.id != issue.id)
        .toList();
    final historicalIssues = <DataIssue>[];
    for (final historical in priorHistory) {
      if (historical.status == IssueStatus.fixed) {
        historicalIssues.add(historical);
        continue;
      }
      final stillPresent = freshIssues.indexWhere(
        (fresh) =>
            fresh.id == historical.id &&
            fresh.originalValue == historical.originalValue,
      );
      if (stillPresent >= 0) {
        freshIssues.removeAt(stillPresent);
        historicalIssues.add(historical);
      }
    }
    if (ignore) {
      historicalIssues.add(issues[issueIndex]);
      freshIssues.removeWhere((item) => item.id == issue.id);
    } else {
      historicalIssues.add(
        issues[issueIndex].copyWith(
          id: '${issue.id}#fixed-${project.audit.length + 1}',
        ),
      );
    }
    final freshIds = freshIssues.map((item) => item.id).toSet();
    for (var index = 0; index < historicalIssues.length; index++) {
      final historical = historicalIssues[index];
      if (historical.status == IssueStatus.fixed &&
          freshIds.contains(historical.id)) {
        historicalIssues[index] = historical.copyWith(
          id: '${historical.id}#fixed-history-${index + 1}',
        );
      }
    }
    return project.copyWith(
      records: records,
      issues: [...freshIssues, ...historicalIssues],
      audit: [...project.audit, actionLog],
      updatedAt: timestamp,
    );
  }

  bool _looksLikeDateHeader(String header) =>
      header.contains('date') ||
      header.contains('time') ||
      header.contains('日期') ||
      header.contains('时间');

  (DateTime, String)? _parseDate(String value) {
    final iso = _isoDatePattern.firstMatch(value);
    if (iso != null) return _safeDate(iso, 1, 2, 3, 'iso');
    final slashYmd = _slashYmdPattern.firstMatch(value);
    if (slashYmd != null) return _safeDate(slashYmd, 1, 2, 3, 'slashYmd');
    final slashMdy = _slashMdyPattern.firstMatch(value);
    if (slashMdy != null) return _safeDate(slashMdy, 3, 1, 2, 'slashMdy');
    final dashDmy = _dashDmyPattern.firstMatch(value);
    if (dashDmy != null) return _safeDate(dashDmy, 3, 2, 1, 'dashDmy');
    return null;
  }

  (DateTime, String)? _safeDate(
    RegExpMatch match,
    int yearGroup,
    int monthGroup,
    int dayGroup,
    String format,
  ) {
    final year = int.parse(match.group(yearGroup)!);
    final month = int.parse(match.group(monthGroup)!);
    final day = int.parse(match.group(dayGroup)!);
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return (date, format);
  }

  String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
