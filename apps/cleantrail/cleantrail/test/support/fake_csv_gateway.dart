import 'dart:ui';

import 'package:cleantrail/data/csv_gateway.dart';

class FakeCsvGateway implements CsvGateway {
  FakeCsvGateway({
    this.nextFile,
    this.exportOutcome = ExportOutcome.completed,
    this.exportError,
  });

  PickedDataFile? nextFile;
  ExportOutcome exportOutcome;
  Object? exportError;
  String? exportedBaseName;
  String? exportedCsv;
  String? exportedReport;
  bool? exportedComplete;

  @override
  Future<void> cleanupTemporaryFiles() async {}

  @override
  Future<PickedDataFile?> pickDataFile() async => nextFile;

  @override
  Future<ExportOutcome> export({
    required String baseName,
    required String csv,
    required String report,
    required String shareText,
    required bool complete,
    Rect? shareOrigin,
  }) async {
    if (exportError case final error?) throw error;
    exportedBaseName = baseName;
    exportedCsv = csv;
    exportedReport = report;
    exportedComplete = complete;
    return exportOutcome;
  }
}
