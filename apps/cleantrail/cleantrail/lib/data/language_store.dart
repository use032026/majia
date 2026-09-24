import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract interface class LanguageStore {
  Future<String?> load();
  Future<void> save(String languageCode);
}

class FileLanguageStore implements LanguageStore {
  FileLanguageStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;

  Future<File> _languageFile() async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    return File('${directory.path}/cleantrail-language.txt');
  }

  @override
  Future<String?> load() async {
    final file = await _languageFile();
    if (!await file.exists()) return null;
    final languageCode = (await file.readAsString()).trim();
    return switch (languageCode) {
      'zh' || 'en' => languageCode,
      _ => null,
    };
  }

  @override
  Future<void> save(String languageCode) async {
    if (languageCode != 'zh' && languageCode != 'en') {
      throw ArgumentError.value(languageCode, 'languageCode');
    }
    final file = await _languageFile();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(languageCode, flush: true);
    await temporary.rename(file.path);
  }
}

class MemoryLanguageStore implements LanguageStore {
  String? value;

  @override
  Future<String?> load() async => value;

  @override
  Future<void> save(String languageCode) async => value = languageCode;
}
