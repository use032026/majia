import 'dart:io';
import 'dart:ui';

import 'package:file_selector/file_selector.dart' as selector;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'csv_gateway.dart';

typedef OpenFile =
    Future<selector.XFile?> Function({
      required List<selector.XTypeGroup> acceptedTypeGroups,
    });

class NativeCsvGateway implements CsvGateway {
  NativeCsvGateway({
    Future<Directory> Function()? temporaryDirectoryProvider,
    Future<ShareResult> Function(ShareParams)? share,
    OpenFile? openFile,
  }) : _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _share = share ?? ((params) async => SharePlus.instance.share(params)),
       _openFile = openFile ?? _openSystemFile;

  static const maxFileBytes = 5 * 1024 * 1024;
  static const _exportDirectoryName = 'cleantrail-exports';

  final Future<Directory> Function() _temporaryDirectoryProvider;
  final Future<ShareResult> Function(ShareParams) _share;
  final OpenFile _openFile;

  static Future<selector.XFile?> _openSystemFile({
    required List<selector.XTypeGroup> acceptedTypeGroups,
  }) => selector.openFile(acceptedTypeGroups: acceptedTypeGroups);

  Future<Directory> _exportDirectory() async {
    final temporary = await _temporaryDirectoryProvider();
    return Directory('${temporary.path}/$_exportDirectoryName');
  }

  @override
  Future<void> cleanupTemporaryFiles() async {
    final directory = await _exportDirectory();
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  @override
  Future<PickedDataFile?> pickDataFile() async {
    const dataType = selector.XTypeGroup(
      label: 'Tabular data',
      extensions: ['csv', 'tsv', 'txt', 'xlsx'],
      mimeTypes: [
        'text/csv',
        'text/tab-separated-values',
        'text/plain',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ],
      uniformTypeIdentifiers: [
        'public.comma-separated-values-text',
        'public.tab-separated-values-text',
        'public.plain-text',
        'org.openxmlformats.spreadsheetml.sheet',
      ],
    );
    final file = await _openFile(acceptedTypeGroups: [dataType]);
    if (file == null) return null;
    if (await file.length() > maxFileBytes) {
      throw const FormatException('fileTooLarge');
    }
    try {
      return PickedDataFile(
        fileName: file.name,
        bytes: await file.readAsBytes(),
      );
    } on FileSystemException {
      throw const FormatException('unreadableFile');
    }
  }

  @override
  Future<ExportOutcome> export({
    required String baseName,
    required String csv,
    required String report,
    required String shareText,
    required bool complete,
    Rect? shareOrigin,
  }) async {
    await cleanupTemporaryFiles();
    final directory = await _exportDirectory();
    await directory.create(recursive: true);
    final safeName = baseName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final stateLabel = complete ? 'clean' : 'draft';
    final csvFile = File('${directory.path}/${safeName}_$stateLabel.csv');
    final reportFile = File('${directory.path}/${safeName}_quality_report.md');
    try {
      await csvFile.writeAsString(csv, flush: true);
      await reportFile.writeAsString(report, flush: true);
      final result = await _share(
        ShareParams(
          title: 'CleanTrail export',
          text: shareText,
          sharePositionOrigin: shareOrigin,
          files: [XFile(csvFile.path), XFile(reportFile.path)],
          fileNameOverrides: [
            '${safeName}_$stateLabel.csv',
            '${safeName}_quality_report.md',
          ],
        ),
      );
      return switch (result.status) {
        ShareResultStatus.success => ExportOutcome.completed,
        ShareResultStatus.dismissed => ExportOutcome.incomplete,
        ShareResultStatus.unavailable => ExportOutcome.unconfirmed,
      };
    } finally {
      try {
        if (await csvFile.exists()) await csvFile.delete();
      } on Object {
        // The next launch/export retries cleanup of the dedicated directory.
      }
      try {
        if (await reportFile.exists()) await reportFile.delete();
      } on Object {
        // Keep cleanup attempts independent so one failure cannot skip another.
      }
    }
  }
}
