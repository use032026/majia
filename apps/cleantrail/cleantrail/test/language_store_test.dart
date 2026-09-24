import 'dart:io';

import 'package:cleantrail/data/language_store.dart';
import 'package:cleantrail/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first launch uses Chinese for every Chinese system locale', () async {
    for (final systemLocale in const [
      Locale('zh'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
        countryCode: 'TW',
      ),
    ]) {
      final store = MemoryLanguageStore();

      final locale = await loadInitialLocale(
        store: store,
        systemLocale: systemLocale,
      );

      expect(locale, const Locale('zh'));
      expect(store.value, 'zh');
    }
  });

  test('first launch uses English for every non-Chinese locale', () async {
    for (final systemLocale in const [
      Locale('en'),
      Locale('ja'),
      Locale('fr'),
      Locale('es'),
    ]) {
      final store = MemoryLanguageStore();

      final locale = await loadInitialLocale(
        store: store,
        systemLocale: systemLocale,
      );

      expect(locale, const Locale('en'));
      expect(store.value, 'en');
    }
  });

  test('saved language takes precedence after first launch', () async {
    final store = MemoryLanguageStore()..value = 'en';

    final locale = await loadInitialLocale(
      store: store,
      systemLocale: const Locale('zh'),
    );

    expect(locale, const Locale('en'));
    expect(store.value, 'en');
  });

  test('file store persists only supported language codes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cleantrail-language-',
    );
    addTearDown(() async => directory.delete(recursive: true));
    final store = FileLanguageStore(directoryProvider: () async => directory);

    expect(await store.load(), isNull);
    await store.save('zh');
    expect(await store.load(), 'zh');
    await store.save('en');
    expect(await store.load(), 'en');
    await expectLater(store.save('fr'), throwsArgumentError);
  });
}
