import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../domain/diary_entry.dart';

class DiaryLoadResult {
  const DiaryLoadResult({
    required this.snapshot,
    this.recoveredFromBackup = false,
  });

  final DiarySnapshot snapshot;
  final bool recoveredFromBackup;
}

abstract interface class DiaryRepository {
  Future<DiaryLoadResult> load();
  Future<void> save(DiarySnapshot snapshot, {bool discardHistory = false});
}

typedef FileRenamer = Future<File> Function(File source, String targetPath);

class DiaryDataException implements Exception {
  const DiaryDataException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FileDiaryRepository implements DiaryRepository {
  FileDiaryRepository(this.directory, {FileRenamer? renamer})
    : _rename = renamer ?? _defaultRename;

  static const String dataFileName = 'echo_page_data_v1.json';
  static const String backupFileName = 'echo_page_data_v1.backup.json';
  static const String pendingFileName = 'echo_page_data_v1.pending.json';
  static const String purgeBackupFileName =
      'echo_page_data_v1.purge-backup.json';
  static const String rollbackFileName = 'echo_page_data_v1.rollback.json';

  final Directory directory;
  final FileRenamer _rename;
  bool _loadedFromBackup = false;

  static Future<FileDiaryRepository> createDefault() async {
    return FileDiaryRepository(await getApplicationDocumentsDirectory());
  }

  File get _current => File('${directory.path}/$dataFileName');
  File get _backup => File('${directory.path}/$backupFileName');
  File get _pending => File('${directory.path}/$pendingFileName');
  File get _purgeBackup => File('${directory.path}/$purgeBackupFileName');
  File get _rollback => File('${directory.path}/$rollbackFileName');

  static Future<File> _defaultRename(File source, String targetPath) {
    return source.rename(targetPath);
  }

  @override
  Future<DiaryLoadResult> load() async {
    await directory.create(recursive: true);
    if (!await _current.exists() && !await _backup.exists()) {
      return const DiaryLoadResult(snapshot: DiarySnapshot.empty());
    }

    try {
      final snapshot = await _read(_current);
      _loadedFromBackup = false;
      return DiaryLoadResult(snapshot: snapshot);
    } catch (_) {
      try {
        final recovered = await _read(_backup);
        _loadedFromBackup = true;
        return DiaryLoadResult(snapshot: recovered, recoveredFromBackup: true);
      } catch (_) {
        throw const DiaryDataException(
          'The local diary file and its backup could not be read.',
        );
      }
    }
  }

  Future<DiarySnapshot> _read(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const FormatException('Diary data must be a JSON object.');
    }
    return DiarySnapshot.fromJson(Map<String, Object?>.from(decoded));
  }

  @override
  Future<void> save(
    DiarySnapshot snapshot, {
    bool discardHistory = false,
  }) async {
    await directory.create(recursive: true);
    final payload = const JsonEncoder.withIndent(
      '  ',
    ).convert(snapshot.toJson());
    await _pending.writeAsString('$payload\n', flush: true);
    if (discardHistory) {
      await _saveDiscardingHistory();
      return;
    }
    if (!_loadedFromBackup && await _isReadable(_current)) {
      await _current.copy(_backup.path);
    }
    try {
      await _rename(_pending, _current.path);
      _loadedFromBackup = false;
    } catch (error) {
      await _deleteIfPresent(_pending);
      rethrow;
    }
  }

  Future<void> _saveDiscardingHistory() async {
    final hadBackup = await _backup.exists();
    final Uint8List? oldBackup = hadBackup ? await _backup.readAsBytes() : null;
    await _pending.copy(_purgeBackup.path);
    try {
      await _rename(_purgeBackup, _backup.path);
      try {
        await _rename(_pending, _current.path);
      } catch (_) {
        if (oldBackup == null) {
          await _deleteIfPresent(_backup);
        } else {
          await _rollback.writeAsBytes(oldBackup, flush: true);
          await _rename(_rollback, _backup.path);
        }
        rethrow;
      }
      _loadedFromBackup = false;
    } catch (_) {
      await _deleteIfPresent(_pending);
      await _deleteIfPresent(_purgeBackup);
      await _deleteIfPresent(_rollback);
      rethrow;
    }
  }

  Future<bool> _isReadable(File file) async {
    if (!await file.exists()) return false;
    try {
      await _read(file);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _deleteIfPresent(File file) async {
    if (await file.exists()) await file.delete();
  }
}
