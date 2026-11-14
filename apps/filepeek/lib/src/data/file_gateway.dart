import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ImportedFile {
  const ImportedFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

abstract class FileGateway {
  Future<ImportedFile?> pickFile();
  Future<void> shareFile(String fileName, Uint8List bytes, Rect anchor);
  Future<void> clearOldExports();
}

class SystemFileGateway implements FileGateway {
  static const maxBytes = 5 * 1024 * 1024;
  Future<void>? _cleanup;

  @override
  Future<ImportedFile?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'csv', 'txt', 'log'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final selected = result.files.single;
    if (selected.size > maxBytes) {
      throw const FileSystemException('File exceeds the 5 MiB limit');
    }
    if (selected.path != null) {
      return _readPath(selected.path!, selected.name);
    }
    final bytes = selected.bytes;
    if (bytes != null && bytes.length <= maxBytes) {
      return ImportedFile(selected.name, bytes);
    }
    throw const FileSystemException('The selected file could not be read');
  }

  Future<ImportedFile> _readPath(String path, String name) async {
    final file = File(path);
    if (await file.length() > maxBytes) {
      throw const FileSystemException('File exceeds the 5 MiB limit');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.openRead(0, maxBytes + 1)) {
      bytes.add(chunk);
    }
    if (bytes.length > maxBytes) {
      throw const FileSystemException('File exceeds the 5 MiB limit');
    }
    return ImportedFile(name, bytes.takeBytes());
  }

  Future<Directory> _exportsDir() async {
    final root = await getTemporaryDirectory();
    final dir = Directory('${root.path}/filerecheck_exports');
    await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<void> clearOldExports() {
    return _cleanup ??= _clearOldExports().whenComplete(() {
      _cleanup = null;
    });
  }

  Future<void> _clearOldExports() async {
    final dir = await _exportsDir();
    final items = await dir.list().toList();
    for (final item in items) {
      try {
        await item.delete(recursive: true);
      } on FileSystemException {
        // A receiver may still hold a file; the OS also owns cache eviction.
      }
    }
  }

  @override
  Future<void> shareFile(String fileName, Uint8List bytes, Rect anchor) async {
    final cleanup = _cleanup;
    if (cleanup != null) {
      try {
        await cleanup;
      } catch (_) {
        // Temporary cleanup must not prevent a user-initiated share.
      }
    }
    final dir = await _exportsDir();
    final sanitized = fileName.replaceAll(RegExp(r'[/\\\x00-\x1F\x7F]'), '_');
    final safeName = switch (sanitized) {
      '' || '.' || '..' => 'export.txt',
      _ => sanitized,
    };
    final shareDir = await dir.createTemp('share_');
    final path = '${shareDir.path}/$safeName';
    await File(path).writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], sharePositionOrigin: anchor),
    );
  }
}
