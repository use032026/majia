import 'dart:typed_data';
import 'dart:ui';

class PickedDataFile {
  PickedDataFile({required this.fileName, required List<int> bytes})
    : bytes = Uint8List.fromList(bytes);

  final String fileName;
  final Uint8List bytes;
}

enum ExportOutcome { completed, incomplete, unconfirmed, failed }

abstract interface class CsvGateway {
  Future<void> cleanupTemporaryFiles();
  Future<PickedDataFile?> pickDataFile();
  Future<ExportOutcome> export({
    required String baseName,
    required String csv,
    required String report,
    required String shareText,
    required bool complete,
    Rect? shareOrigin,
  });
}
