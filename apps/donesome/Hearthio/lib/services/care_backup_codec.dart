import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/care_item.dart';
import '../models/care_space.dart';
import 'care_repository.dart';

class CareBackupException implements Exception {
  const CareBackupException(this.message);

  final String message;

  @override
  String toString() => 'CareBackupException: $message';
}

class DecodedCareBackup {
  const DecodedCareBackup({
    required this.items,
    required this.spaces,
    required this.photos,
  });

  final List<CareItem> items;
  final List<CareSpace> spaces;
  final Map<String, Uint8List> photos;
}

class _ExpandedSizeLimitExceeded implements Exception {}

class _BoundedOutputMemoryStream extends OutputMemoryStream {
  _BoundedOutputMemoryStream(this.maxBytes)
    : super(
        size: maxBytes <= 0
            ? 1
            : maxBytes < OutputMemoryStream.defaultBufferSize
            ? maxBytes
            : OutputMemoryStream.defaultBufferSize,
      );

  final int maxBytes;

  void _check(int additionalBytes) {
    if (additionalBytes < 0 || length + additionalBytes > maxBytes) {
      throw _ExpandedSizeLimitExceeded();
    }
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final writeLength = length ?? bytes.length;
    _check(writeLength);
    super.writeBytes(bytes, length: writeLength);
  }

  @override
  void writeStream(InputStream stream) {
    _check(stream.length);
    super.writeStream(stream);
  }
}

class CareBackupCodec {
  static const maxArchiveBytes = 50 * 1024 * 1024;
  static const maxFiles = 250;
  static const maxSingleFileBytes = 20 * 1024 * 1024;
  static const maxTotalExpandedBytes = 100 * 1024 * 1024;
  static const maxDataFileBytes = 5 * 1024 * 1024;
  static final _unsafeBasenameCharacters = RegExp(r'[^A-Za-z0-9._-]');

  static Uint8List encode({
    required List<CareItem> items,
    List<CareSpace> spaces = const [],
    required Map<String, List<int>> photoBytesByPath,
  }) {
    final archive = Archive();
    final archivePaths = <String, String>{};
    var index = 0;
    var expandedBytes = 0;
    for (final sourcePath in _allPhotoPaths(items)) {
      final bytes = photoBytesByPath[sourcePath];
      if (bytes == null) {
        throw CareBackupException(
          '档案引用的照片缺失：${_safeBasename(sourcePath)}，备份已停止',
        );
      }
      if (bytes.length > maxSingleFileBytes) {
        throw const CareBackupException('单张照片超过备份大小限制');
      }
      expandedBytes += bytes.length;
      if (expandedBytes > maxTotalExpandedBytes) {
        throw const CareBackupException('备份解压后超过大小限制');
      }
      final safeName = _safeBasename(sourcePath);
      archivePaths[sourcePath] = 'photos/${index++}_$safeName';
    }

    if (archivePaths.length + 1 > maxFiles) {
      throw const CareBackupException('备份文件数量超过限制');
    }
    final backupItems = items
        .map((item) => _remapItemPhotos(item, archivePaths))
        .toList(growable: false);
    final data = CareDataEnvelope(items: backupItems, spaces: spaces).encode();
    CareDataEnvelope.decode(data);
    final dataBytes = utf8.encode(data);
    if (dataBytes.length > maxDataFileBytes) {
      throw const CareBackupException('备份数据超过大小限制');
    }
    expandedBytes += dataBytes.length;
    if (expandedBytes > maxTotalExpandedBytes) {
      throw const CareBackupException('备份解压后超过大小限制');
    }
    archive.add(ArchiveFile.bytes('data.json', dataBytes));
    for (final entry in archivePaths.entries) {
      final bytes = photoBytesByPath[entry.key]!;
      archive.add(ArchiveFile.bytes(entry.value, bytes));
    }
    final encoded = ZipEncoder().encodeBytes(archive);
    if (encoded.length > maxArchiveBytes) {
      throw const CareBackupException('备份压缩包超过大小限制');
    }
    return encoded;
  }

  static DecodedCareBackup decode(List<int> bytes) {
    if (bytes.length > maxArchiveBytes) {
      throw const CareBackupException('备份压缩包超过大小限制');
    }
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    if (archive.files.length > maxFiles) {
      throw const CareBackupException('备份文件数量超过限制');
    }

    var expandedBytes = 0;
    final names = <String>{};
    ArchiveFile? dataFile;
    final photoFiles = <String, ArchiveFile>{};
    for (final file in archive.files) {
      if (!file.isFile || file.isSymbolicLink) {
        throw const CareBackupException('备份中包含不允许的目录或链接');
      }
      if (!_isAllowedPath(file.name)) {
        throw const CareBackupException('备份中包含不允许的路径');
      }
      if (!names.add(file.name)) {
        throw const CareBackupException('备份中包含重复文件');
      }
      if (file.size < 0 || file.size > maxSingleFileBytes) {
        throw const CareBackupException('备份中存在超大文件');
      }
      expandedBytes += file.size;
      if (expandedBytes > maxTotalExpandedBytes) {
        throw const CareBackupException('备份解压后超过大小限制');
      }
      if (file.name == 'data.json') {
        if (file.size > maxDataFileBytes) {
          throw const CareBackupException('备份数据超过大小限制');
        }
        dataFile = file;
      } else {
        photoFiles[file.name] = file;
      }
    }
    if (dataFile == null) {
      throw const CareBackupException('备份缺少 data.json');
    }

    var actualExpandedBytes = 0;
    final dataBytes = _readFileBytes(
      dataFile,
      maxBytes: _smaller(maxDataFileBytes, maxTotalExpandedBytes),
      expandedLimitMessage: '备份数据解压时超过大小限制',
      copyBytes: false,
    );
    actualExpandedBytes += dataBytes.length;
    final decoded = jsonDecode(utf8.decode(dataBytes));
    final envelope = decoded is List
        ? CareDataEnvelope.fromLegacyDecoded(decoded)
        : CareDataEnvelope.fromDecoded(decoded);
    final availablePhotoPaths = photoFiles.keys.toSet();
    final replacements = <String, String>{};
    for (final path in _allPhotoPaths(envelope.items)) {
      final archivePath = _archivePhotoPath(path, availablePhotoPaths);
      if (archivePath == null) {
        throw const CareBackupException('备份数据引用了缺失的照片');
      }
      replacements[path] = archivePath;
    }
    final normalizedItems = envelope.items
        .map((item) => _remapItemPhotos(item, replacements))
        .toList(growable: false);
    final photos = <String, Uint8List>{};
    for (final entry in photoFiles.entries) {
      final remaining = maxTotalExpandedBytes - actualExpandedBytes;
      final content = _readFileBytes(
        entry.value,
        maxBytes: _smaller(maxSingleFileBytes, remaining),
        expandedLimitMessage: '备份照片解压时超过大小限制',
      );
      actualExpandedBytes += content.length;
      photos[entry.key] = content;
    }
    return DecodedCareBackup(
      items: normalizedItems,
      spaces: envelope.spaces,
      photos: photos,
    );
  }

  static Iterable<String> _allPhotoPaths(List<CareItem> items) sync* {
    final seen = <String>{};
    for (final item in items) {
      for (final path in item.photos) {
        if (seen.add(path)) yield path;
      }
      for (final record in item.records) {
        for (final path in record.photos) {
          if (seen.add(path)) yield path;
        }
      }
    }
  }

  static Uint8List _readFileBytes(
    ArchiveFile file, {
    required int maxBytes,
    required String expandedLimitMessage,
    bool copyBytes = true,
  }) {
    final output = _BoundedOutputMemoryStream(maxBytes);
    try {
      file.decompress(output);
    } on _ExpandedSizeLimitExceeded {
      throw CareBackupException(expandedLimitMessage);
    }
    final bytes = output.getBytes();
    if (bytes.length != file.size) {
      throw const CareBackupException('备份文件声明大小与实际内容不一致');
    }
    final expectedCrc = file.crc32;
    if (expectedCrc != null && getCrc32(bytes) != expectedCrc) {
      throw const CareBackupException('备份文件校验失败');
    }
    return copyBytes ? Uint8List.fromList(bytes) : bytes;
  }

  static int _smaller(int first, int second) => first < second ? first : second;

  static CareItem _remapItemPhotos(
    CareItem item,
    Map<String, String> replacements,
  ) => item.copyWith(
    photos: item.photos
        .where(replacements.containsKey)
        .map((path) => replacements[path]!)
        .toList(growable: false),
    records: item.records
        .map(
          (record) => record.copyWith(
            beforePhotos: record.beforePhotos
                .where(replacements.containsKey)
                .map((path) => replacements[path]!)
                .toList(growable: false),
            afterPhotos: record.afterPhotos
                .where(replacements.containsKey)
                .map((path) => replacements[path]!)
                .toList(growable: false),
          ),
        )
        .toList(growable: false),
  );

  static String? _archivePhotoPath(String original, Set<String> available) {
    if (available.contains(original)) return original;
    final legacyPath = 'photos/${_safeBasename(original)}';
    if (available.contains(legacyPath)) return legacyPath;
    return null;
  }

  static bool _isAllowedPath(String path) {
    if (path == 'data.json') return true;
    if (!path.startsWith('photos/')) return false;
    final remainder = path.substring('photos/'.length);
    return remainder.isNotEmpty &&
        remainder != '.' &&
        remainder != '..' &&
        !remainder.contains('/') &&
        !remainder.contains('\\') &&
        !remainder.contains('\u0000');
  }

  static String _safeBasename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final name = normalized.split('/').last;
    final safe = name.replaceAll(_unsafeBasenameCharacters, '_');
    return safe.isEmpty || safe == '.' || safe == '..' ? 'photo.bin' : safe;
  }
}
