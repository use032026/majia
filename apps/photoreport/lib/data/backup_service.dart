import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';
import 'photo_storage.dart';

class BackupService {
  Future<String> create(AppDatabase database) async {
    final snapshot = await database.exportSnapshot();
    final photos = (snapshot['photos']! as List<Map<String, Object?>>)
        .map(Map<String, Object?>.from)
        .toList();
    for (final photo in photos) {
      final sourcePath = photo['path']! as String;
      final file = File(sourcePath);
      if (!await file.exists()) {
        throw StateError('照片文件缺失，无法完成备份：${p.basename(sourcePath)}');
      }
      photo['extension'] = p.extension(sourcePath).isEmpty
          ? '.jpg'
          : p.extension(sourcePath);
      photo['data'] = base64Encode(await file.readAsBytes());
      photo.remove('path');
    }
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(documents.path, 'PhotoReport', 'Backups'),
    );
    await directory.create(recursive: true);
    final now = DateTime.now();
    final stamp = now
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final destination = p.join(directory.path, 'JOVFX-$stamp.prbackup');
    final payload = {
      'format': 'photo-report-backup',
      'version': 1,
      'createdAt': now.toIso8601String(),
      'projects': snapshot['projects'],
      'issues': snapshot['issues'],
      'photos': photos,
    };
    await File(destination).writeAsString(jsonEncode(payload), flush: true);
    return destination;
  }

  Future<void> restore(
    String backupPath,
    AppDatabase database,
    PhotoStorage storage,
  ) async {
    final decoded = jsonDecode(await File(backupPath).readAsString());
    if (decoded is! Map ||
        decoded['format'] != 'photo-report-backup' ||
        decoded['version'] != 1) {
      throw const FormatException('这不是受支持的 JOVFX 备份');
    }
    final projects = _maps(decoded['projects'], '项目');
    final issues = _maps(decoded['issues'], '记录');
    final sourcePhotos = _maps(decoded['photos'], '照片');
    final restoredPhotos = <Map<String, Object?>>[];
    final newPaths = <String>[];
    var databaseRestored = false;
    try {
      for (final source in sourcePhotos) {
        final encoded = source.remove('data');
        final extension = source.remove('extension');
        if (encoded is! String || extension is! String) {
          throw const FormatException('备份中的照片数据不完整');
        }
        final path = await storage.writePhotoBytes(
          base64Decode(encoded),
          extension,
        );
        newPaths.add(path);
        source['path'] = path;
        restoredPhotos.add(source);
      }
      for (final project in projects) {
        project['last_report_path'] = '';
        project['last_report_at'] = null;
      }
      final oldPaths = await database.restoreSnapshot(
        projects,
        issues,
        restoredPhotos,
      );
      databaseRestored = true;
      try {
        await storage.deletePaths(oldPaths);
      } catch (_) {
        // 数据已恢复成功；旧孤立文件清理失败不应回滚或误报恢复失败。
      }
    } catch (_) {
      if (!databaseRestored) await storage.deletePaths(newPaths);
      rethrow;
    }
  }

  List<Map<String, Object?>> _maps(Object? value, String label) {
    if (value is! List) throw FormatException('备份中的$label数据不完整');
    return value.map((item) {
      if (item is! Map) throw FormatException('备份中的$label格式错误');
      return Map<String, Object?>.from(item);
    }).toList();
  }
}
