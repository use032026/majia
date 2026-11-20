import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract interface class WebStartupPreference {
  Future<bool> readEnabled();
  Future<void> saveEnabled();
}

/// Separate from trip data and backups; an explicit local opt-in only.
class FileWebStartupPreference implements WebStartupPreference {
  FileWebStartupPreference({Directory? directory}) : _directory = directory;
  final Directory? _directory;
  static const fileName = 'trip_delta_web_startup_v1.json';

  Future<File> _file() async {
    final directory = _directory ?? await getApplicationSupportDirectory();
    return File('${directory.path}/$fileName');
  }

  @override
  Future<bool> readEnabled() async {
    try {
      final file = await _file();
      if (!await file.exists() || await file.length() > 1024) return false;
      final value = jsonDecode(await file.readAsString());
      return value is Map<String, dynamic> &&
          value.length == 2 &&
          value['schemaVersion'] is int &&
          value['schemaVersion'] == 1 &&
          value['enabled'] is bool &&
          value['enabled'] == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> saveEnabled() async {
    final destination = await _file();
    await destination.parent.create(recursive: true);
    final pending = File(
      '${destination.path}.pending.$pid.${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await pending.writeAsString(
        jsonEncode({'schemaVersion': 1, 'enabled': true}),
        flush: true,
      );
      await pending.rename(destination.path);
    } finally {
      if (await pending.exists()) await pending.delete();
    }
  }
}
