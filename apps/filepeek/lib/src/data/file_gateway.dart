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
    return ImportedFile(name, await file.readAsBytes());
  }

  Future<Directory> _exportsDir() async {
    final root = await getTemporaryDirectory();
    final dir = Directory('${root.path}/filerecheck_exports');
    await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<void> clearOldExports() async {
    final dir = await _exportsDir();
    for (final item in dir.listSync()) {
      try {
        await item.delete(recursive: true);
      } on FileSystemException {
        // A receiver may still hold a file; the OS also owns cache eviction.
      }
    }
  }

  @override
  Future<void> shareFile(String fileName, Uint8List bytes, Rect anchor) async {
    final dir = await _exportsDir();
    final safeName = fileName.replaceAll(RegExp(r'[/\\\x00-\x1F\x7F]'), '_');
    final shareDir = await dir.createTemp('share_');
    final path = '${shareDir.path}/$safeName';
    await File(path).writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], sharePositionOrigin: anchor),
    );
  }
}
