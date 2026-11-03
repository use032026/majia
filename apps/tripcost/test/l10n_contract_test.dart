import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'English and Simplified Chinese ARB catalogs have complete parity',
    () async {
      final english = await _readJson('lib/l10n/app_en.arb');
      final chinese = await _readJson('lib/l10n/app_zh.arb');
      final englishKeys = english.keys.where(_isMessageKey).toSet();
      final chineseKeys = chinese.keys.where(_isMessageKey).toSet();

      expect(chineseKeys.difference(englishKeys), isEmpty);
      expect(englishKeys.difference(chineseKeys), isEmpty);
      for (final key in englishKeys) {
        expect(english[key], isA<String>());
        expect(chinese[key], isA<String>());
        expect((english[key]! as String).trim(), isNotEmpty);
        expect((chinese[key]! as String).trim(), isNotEmpty);
        expect(english[key], isNot(key));
        expect(chinese[key], isNot(key));
      }
    },
  );

  test(
    'privacy permission purpose strings are localized for both languages',
    () async {
      for (final locale in <String>['en', 'zh-Hans']) {
        final contents = await File(
          'ios/Runner/$locale.lproj/InfoPlist.strings',
        ).readAsString();
        expect(contents, contains('NSCameraUsageDescription'));
        expect(contents, contains('NSPhotoLibraryUsageDescription'));
        expect(contents, anyOf(contains('not uploaded'), contains('不会上传')));
      }
    },
  );

  test('user-facing localized app name is RhinoSmart', () async {
    final english = await _readJson('lib/l10n/app_en.arb');
    final chinese = await _readJson('lib/l10n/app_zh.arb');

    expect(english['appTitle'], 'RhinoSmart');
    expect(chinese['appTitle'], 'RhinoSmart');
    for (final catalog in <Map<String, Object?>>[english, chinese]) {
      for (final key in <String>[
        'permissionCameraUnavailableBody',
        'permissionPhotoLibraryUnavailableBody',
        'privacyPolicyBody',
      ]) {
        expect(catalog[key], contains('RhinoSmart'));
        expect(catalog[key], isNot(contains('TripCost')));
        expect(catalog[key], isNot(contains('Trip Cost')));
      }
    }
  });

  test('onboarding visible copy has no direct string literals', () async {
    final contents = await Future.wait(
      <String>[
        'lib/features/onboarding/presentation/onboarding_page.dart',
        'lib/features/onboarding/presentation/quick_setup_page.dart',
      ].map((path) => File(path).readAsString()),
    ).then((files) => files.join('\n'));

    expect(
      RegExp(
        r'''Text\(\s*(['"])(?!\$\{)[^'"]*[A-Za-z\u4e00-\u9fff]''',
      ).hasMatch(contents),
      isFalse,
    );
    expect(contents, isNot(contains('currency.name')));
  });
}

Future<Map<String, Object?>> _readJson(String path) async {
  return (jsonDecode(await File(path).readAsString()) as Map<String, Object?>);
}

bool _isMessageKey(String key) => !key.startsWith('@');
