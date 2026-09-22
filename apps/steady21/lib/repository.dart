import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'domain.dart';

abstract interface class ExperimentRepository {
  Future<AppSnapshot> load();
  Future<void> save(AppSnapshot snapshot);
}

class JsonFileRepository implements ExperimentRepository {
  JsonFileRepository({
    Future<Directory> Function()? directoryProvider,
    this.defaultLocaleCode = 'zh',
  }) : assert(defaultLocaleCode == 'zh' || defaultLocaleCode == 'en'),
       _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;
  final String defaultLocaleCode;

  Future<File> _file() async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}steady21.json');
  }

  @override
  Future<AppSnapshot> load() async {
    final file = await _file();
    if (!await file.exists()) return AppSnapshot(localeCode: defaultLocaleCode);
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('Invalid root payload');
    return AppSnapshot.fromJson(Map<String, Object?>.from(decoded));
  }

  @override
  Future<void> save(AppSnapshot snapshot) async {
    final file = await _file();
    final temporary = File('${file.path}.tmp');
    try {
      await temporary.writeAsString(
        const JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
        flush: true,
      );
      await temporary.rename(file.path);
    } catch (_) {
      if (await temporary.exists()) {
        await temporary.delete();
      }
      rethrow;
    }
  }
}

class MemoryRepository implements ExperimentRepository {
  MemoryRepository([this.snapshot = const AppSnapshot()]);

  AppSnapshot snapshot;
  Object? loadFailure;
  Object? saveFailure;

  @override
  Future<AppSnapshot> load() async {
    if (loadFailure case final failure?) throw failure;
    return snapshot;
  }

  @override
  Future<void> save(AppSnapshot value) async {
    if (saveFailure case final failure?) throw failure;
    snapshot = value;
  }
}
