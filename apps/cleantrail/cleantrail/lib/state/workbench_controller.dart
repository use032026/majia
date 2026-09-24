import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../data/csv_gateway.dart';
import '../data/import_decoder.dart';
import '../data/project_store.dart';
import '../domain/data_project.dart';
import '../domain/export_builder.dart';
import '../domain/quality_engine.dart';

class WorkbenchController extends ChangeNotifier {
  WorkbenchController({
    required this.engine,
    required this.store,
    required this.gateway,
    this.exportBuilder = const ExportBuilder(),
    this.importDecoder = const TabularImportDecoder(),
  });

  final QualityEngine engine;
  final ProjectStore store;
  final CsvGateway gateway;
  final ExportBuilder exportBuilder;
  final TabularImportDecoder importDecoder;

  DataProject? project;
  bool busy = false;
  String? errorCode;
  final List<DataProject> _undoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;

  void dismissError() {
    if (errorCode == null) return;
    errorCode = null;
    notifyListeners();
  }

  Future<void> load() async {
    errorCode = null;
    busy = true;
    notifyListeners();
    try {
      try {
        await gateway.cleanupTemporaryFiles();
      } on Object {
        // Stale export cleanup is retried on the next export and must not hide
        // an otherwise valid saved project.
      }
      final restored = await store.load();
      project = restored;
      _undoStack.clear();
    } on Object {
      errorCode = 'restoreFailed';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<ImportDraft?> prepareImport() async {
    errorCode = null;
    busy = true;
    notifyListeners();
    try {
      final file = await gateway.pickDataFile();
      if (file == null) return null;
      return importDecoder.inspect(file);
    } on FormatException catch (error) {
      errorCode = error.message;
      return null;
    } on Object {
      errorCode = 'importFailed';
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> importSelected(
    ImportDraft draft,
    ImportSelection selection,
  ) async {
    errorCode = null;
    busy = true;
    notifyListeners();
    try {
      final imported = importDecoder.decode(draft, selection);
      final next = engine.importCsv(
        fileName: imported.fileName,
        source: imported.csv,
      );
      try {
        await store.save(next);
      } on Object {
        errorCode = 'saveFailed';
        return;
      }
      project = next;
      _undoStack.clear();
    } on CsvImportException catch (error) {
      errorCode = error.code;
    } on FormatException catch (error) {
      errorCode = error.message;
    } on Object {
      errorCode = 'importFailed';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> loadSample() async {
    const sample = '''date,value,region
2026-01-01,12,North
2026/02/01,14, North 
2026-03-01,,South
2026-04-01,not set,South
2026-05-01,18,East
2026-05-01,18,East
''';
    errorCode = null;
    busy = true;
    notifyListeners();
    try {
      final next = engine.importCsv(
        fileName: 'quality_sample.csv',
        source: sample,
      );
      await store.save(next);
      project = next;
      _undoStack.clear();
    } on CsvImportException catch (error) {
      errorCode = error.code;
    } on Object {
      errorCode = 'saveFailed';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> resolveIssue(
    String issueId, {
    String? replacement,
    bool ignore = false,
  }) async {
    final current = project;
    if (current == null) return;
    errorCode = null;
    try {
      final next = engine.resolve(
        current,
        issueId,
        replacement: replacement,
        ignore: ignore,
      );
      if (identical(next, current)) return;
      await store.save(next);
      _undoStack.add(current);
      project = next;
      notifyListeners();
    } on CsvImportException catch (error) {
      errorCode = error.code;
      notifyListeners();
    } on Object {
      errorCode = 'saveFailed';
      notifyListeners();
    }
  }

  Future<void> undo() async {
    if (_undoStack.isEmpty) return;
    errorCode = null;
    final previous = _undoStack.last;
    try {
      await store.save(previous);
    } on Object {
      errorCode = 'saveFailed';
      notifyListeners();
      return;
    }
    _undoStack.removeLast();
    project = previous;
    notifyListeners();
  }

  Future<void> clear() async {
    errorCode = null;
    try {
      await store.clear();
    } on Object {
      errorCode = 'clearFailed';
      notifyListeners();
      return;
    }
    project = null;
    _undoStack.clear();
    notifyListeners();
  }

  Future<void> export({required bool chinese, Rect? shareOrigin}) async {
    final current = project;
    if (current == null) return;
    busy = true;
    errorCode = null;
    notifyListeners();
    try {
      final bundle = exportBuilder.build(current, chinese: chinese);
      final baseName = current.fileName.replaceFirst(
        RegExp(r'\.(csv|tsv|txt|xlsx)$', caseSensitive: false),
        '',
      );
      await gateway.export(
        baseName: baseName,
        csv: bundle.csv,
        report: bundle.report,
        complete: current.openIssues.isEmpty,
        shareOrigin: shareOrigin,
        shareText: chinese
            ? 'CleanTrail 清洗文件与质量报告'
            : 'CleanTrail cleaned data and quality report',
      );
    } on Object {
      errorCode = 'exportFailed';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
