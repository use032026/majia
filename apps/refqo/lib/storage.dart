import 'dart:convert';
import 'dart:io';

import 'domain.dart';

abstract class Repository {
  Future<AppData> load();
  Future<void> save(AppData data);
  Future<void> restore(AppData data);
  Future<void> erase(AppData empty);
}

class FileRepository implements Repository {
  FileRepository(this.directory);
  final Directory directory;
  bool _recoveryRequired = false;
  bool _writing = false;
  String get primaryPath => '${directory.path}/refqo.json';
  String get previousPath => '${directory.path}/refqo.previous.json';
  String get rejectedPath => '${directory.path}/refqo.rejected.json';
  String get _nextPath => '${directory.path}/refqo.next.json';
  String get _previousTempPath => '${directory.path}/refqo.previous.next.json';

  Future<AppData> _read(String path) async {
    final file = File(path);
    if (await file.length() > maxBackupBytes) {
      throw StateError('FILE_TOO_LARGE: Backup exceeds 2 MB');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBackupBytes) {
      throw StateError('FILE_TOO_LARGE: Backup exceeds 2 MB');
    }
    try {
      return decodeAppData(utf8.decode(bytes, allowMalformed: false));
    } on FormatException {
      throw StateError('INVALID_ENCODING: Backup is not UTF-8');
    }
  }

  @override
  Future<AppData> load() async {
    try {
      if (!await File(primaryPath).exists()) {
        if (await File(previousPath).exists() ||
            await File(_nextPath).exists() ||
            await File(_previousTempPath).exists() ||
            await File(rejectedPath).exists()) {
          throw StateError(
            'RECOVERY_REQUIRED: Primary is missing and a recovery file exists',
          );
        }
        _recoveryRequired = false;
        return AppData();
      }
      final data = await _read(primaryPath);
      _recoveryRequired = false;
      return data;
    } catch (_) {
      _recoveryRequired = true;
      rethrow;
    }
  }

  Future<AppData> loadPrevious() => _read(previousPath);

  Future<void> _copyAndFlush(String source, String target) async {
    await File(source).copy(target);
    final handle = await File(target).open(mode: FileMode.append);
    try {
      await handle.flush();
    } finally {
      await handle.close();
    }
  }

  Future<void> _commit(AppData data, {required bool keepPrevious}) async {
    final encoded = encodeAppData(data);
    await directory.create(recursive: true);
    final next = File(_nextPath);
    await next.writeAsString(encoded, encoding: utf8, flush: true);
    if (await File(primaryPath).exists()) {
      if (keepPrevious) {
        await _copyAndFlush(primaryPath, _previousTempPath);
        await File(_previousTempPath).rename(previousPath);
      } else {
        await _copyAndFlush(primaryPath, rejectedPath);
      }
    }
    await next.rename(primaryPath);
  }

  Future<void> _write(Future<void> Function() operation) async {
    if (_writing) {
      throw StateError('WRITE_IN_PROGRESS: Wait for the current save');
    }
    _writing = true;
    try {
      await operation();
    } finally {
      _writing = false;
    }
  }

  @override
  Future<void> save(AppData data) => _write(() async {
    if (_recoveryRequired) {
      throw StateError(
        'RECOVERY_REQUIRED: Explicitly restore a valid backup before saving',
      );
    }
    await _commit(data, keepPrevious: true);
  });

  @override
  Future<void> restore(AppData data) => _write(() async {
    await _commit(data, keepPrevious: !_recoveryRequired);
    _recoveryRequired = false;
  });

  @override
  Future<void> erase(AppData empty) => _write(() async {
    if (empty.supplies.isNotEmpty ||
        empty.slots.isNotEmpty ||
        empty.events.isNotEmpty) {
      throw StateError(
        'INVALID_ERASE: The replacement must contain no household data',
      );
    }
    await _commit(empty, keepPrevious: false);
    for (final path in [
      previousPath,
      rejectedPath,
      _nextPath,
      _previousTempPath,
    ]) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    _recoveryRequired = false;
  });
}

class MemoryRepository implements Repository {
  MemoryRepository([AppData? initial]) : data = initial ?? AppData();
  AppData data;
  bool failNextSave = false;
  @override
  Future<AppData> load() async => data;
  @override
  Future<void> save(AppData next) async {
    if (failNextSave) {
      failNextSave = false;
      throw FileSystemException('Injected save failure');
    }
    validateAppData(next);
    data = next;
  }

  @override
  Future<void> restore(AppData next) => save(next);
  @override
  Future<void> erase(AppData empty) {
    if (empty.supplies.isNotEmpty ||
        empty.slots.isNotEmpty ||
        empty.events.isNotEmpty) {
      throw StateError(
        'INVALID_ERASE: The replacement must contain no household data',
      );
    }
    return save(empty);
  }
}

/// Removes only Refqo's own interrupted share exports, never user-selected files.
Future<void> cleanTemporaryBackups(Directory directory) async {
  if (!await directory.exists()) return;
  final ownedName = RegExp(r'^refqo-backup-[0-9]+\.json$');
  await for (final entity in directory.list(followLinks: false)) {
    if (entity is File && ownedName.hasMatch(entity.uri.pathSegments.last)) {
      await entity.delete();
    }
  }
}
