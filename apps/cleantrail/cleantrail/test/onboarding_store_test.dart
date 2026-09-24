import 'dart:io';

import 'package:cleantrail/data/onboarding_store.dart';
import 'package:cleantrail/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new installs have not completed onboarding', () async {
    final store = MemoryOnboardingStore();

    expect(await loadOnboardingCompleted(store), isFalse);

    await store.markCompleted();
    expect(await loadOnboardingCompleted(store), isTrue);
  });

  test('file store persists onboarding completion', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cleantrail-onboarding-',
    );
    addTearDown(() async => directory.delete(recursive: true));
    final store = FileOnboardingStore(directoryProvider: () async => directory);

    expect(await store.isCompleted(), isFalse);
    await store.markCompleted();
    expect(await store.isCompleted(), isTrue);
  });
}
