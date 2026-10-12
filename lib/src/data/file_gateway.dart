import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:share_plus/share_plus.dart';

class ImportedFile {
  const ImportedFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

abstract class FileGateway {
  Future<ImportedFile?> pickFile();
  Future<ImportedFile?> initialSharedFile();
  Stream<ImportedFile> get sharedFiles;
  Future<void> shareFile(String fileName, Uint8List bytes, Rect anchor);
  Future<void> clearOldExports();
}

class SystemFileGateway implements FileGateway {
  static const maxBytes = 5 * 1024 * 1024;
  static const _sharedImportChannel = MethodChannel('filepeek/share_import');

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

  Future<ImportedFile?> _fromShared(List<SharedMediaFile> items) async {
    for (final item in items) {
      // Android marks shared CSV/TXT attachments as text because of their MIME
      // type. A literal shared string must never be treated as a file path.
      if (item.type != SharedMediaType.file &&
          item.type != SharedMediaType.text) {
        continue;
      }
      final path = item.path;
      if (!path.startsWith('/') || !await File(path).exists()) continue;
      final name = Uri.file(path).pathSegments.last;
      if (!RegExp(
        r'\.(json|csv|txt|log)$',
        caseSensitive: false,
      ).hasMatch(name)) {
        continue;
      }
      try {
        return await _readPath(path, name);
      } finally {
        if (Platform.isIOS) {
          try {
            await _sharedImportChannel.invokeMethod<void>('consumeSharedFile', {
              'path': path,
            });
          } on PlatformException {
            // Reading the copied bytes already completed.
          } on MissingPluginException {
            // A previous app build may not have the cleanup channel yet.
          }
        }
      }
    }
    return null;
  }

  @override
  Future<ImportedFile?> initialSharedFile() async {
    if (Platform.isIOS) {
      final path = await _sharedImportChannel.invokeMethod<String>(
        'pendingSharedFile',
      );
      if (path != null) {
        try {
          return await _fromShared([
            SharedMediaFile(path: path, type: SharedMediaType.file),
          ]);
        } finally {
          await ReceiveSharingIntent.instance.reset();
        }
      }
    }
    final items = await ReceiveSharingIntent.instance.getInitialMedia();
    try {
      return await _fromShared(items);
    } finally {
      await ReceiveSharingIntent.instance.reset();
    }
  }

  @override
  Stream<ImportedFile> get sharedFiles => ReceiveSharingIntent.instance
      .getMediaStream()
      .asyncMap(_fromShared)
      .where((file) => file != null)
      .cast<ImportedFile>();

  Future<Directory> _exportsDir() async {
    final root = await getTemporaryDirectory();
    final dir = Directory('${root.path}/filepeek_exports');
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
