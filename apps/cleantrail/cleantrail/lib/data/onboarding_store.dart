import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract interface class OnboardingStore {
  Future<bool> isCompleted();
  Future<void> markCompleted();
}

class FileOnboardingStore implements OnboardingStore {
  FileOnboardingStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;

  Future<File> _completionFile() async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    return File('${directory.path}/cleantrail-onboarding-v1.txt');
  }

  @override
  Future<bool> isCompleted() async {
    final file = await _completionFile();
    if (!await file.exists()) return false;
    return (await file.readAsString()).trim() == 'completed';
  }

  @override
  Future<void> markCompleted() async {
    final file = await _completionFile();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString('completed', flush: true);
    await temporary.rename(file.path);
  }
}

class MemoryOnboardingStore implements OnboardingStore {
  bool completed;

  MemoryOnboardingStore({this.completed = false});

  @override
  Future<bool> isCompleted() async => completed;

  @override
  Future<void> markCompleted() async => completed = true;
}
