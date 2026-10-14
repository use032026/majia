import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'domain.dart';

const maxBackupBytes = 10 * 1024 * 1024;

class TripBackupCodec {
  static Uint8List encode(AppData data) => Uint8List.fromList(
    utf8.encode(
      const JsonEncoder.withIndent('  ').convert({
        'format': 'trip_delta_backup',
        'backupVersion': 1,
        'data': data.toJson(),
      }),
    ),
  );

  static AppData decode(Uint8List bytes) {
    if (bytes.length > maxBackupBytes) {
      throw const FormatException('Backup is too large');
    }
    try {
      final root = jsonDecode(utf8.decode(bytes));
      if (root is! Map<String, dynamic> ||
          root['format'] != 'trip_delta_backup' ||
          root['backupVersion'] != 1) {
        throw const FormatException('Unsupported backup format');
      }
      final data = AppData.fromJson(root['data']);
      final tripIds = <String>{};
      for (final trip in data.trips) {
        if (trip.id.isEmpty || !tripIds.add(trip.id)) {
          throw const FormatException('Duplicate or empty trip ID');
        }
        final expenseIds = <String>{};
        for (final expense in trip.expenses) {
          if (expense.id.isEmpty || !expenseIds.add(expense.id)) {
            throw const FormatException('Duplicate or empty expense ID');
          }
        }
      }
      return data;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid backup data');
    }
  }
}

abstract class BackupGateway {
  Future<bool> save(String name, Uint8List bytes);
  Future<Uint8List?> pick();
}

class SystemBackupGateway implements BackupGateway {
  @override
  Future<bool> save(String name, Uint8List bytes) async {
    try {
      return await FilePicker.saveFile(
            fileName: name,
            type: FileType.custom,
            allowedExtensions: const ['json'],
            bytes: bytes,
          ) !=
          null;
    } finally {
      // The iOS picker first writes the export into app Documents, then copies
      // it to the user-selected provider. Remove only that staging copy.
      if (Platform.isIOS) {
        try {
          final directory = await getApplicationDocumentsDirectory();
          final staging = File('${directory.path}/$name');
          if (await staging.exists()) await staging.delete();
        } catch (_) {
          // A failed cleanup must not turn a completed user export into an error.
        }
      }
    }
  }

  @override
  Future<Uint8List?> pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final selected = result.files.single;
    if (selected.size > maxBackupBytes) {
      throw const FormatException('Backup is too large');
    }
    final path = selected.path;
    if (path != null) {
      final file = File(path);
      if (await file.length() > maxBackupBytes) {
        throw const FormatException('Backup is too large');
      }
      return file.readAsBytes();
    }
    final bytes = selected.bytes;
    if (bytes == null) throw const FormatException('Backup cannot be read');
    return bytes;
  }
}
