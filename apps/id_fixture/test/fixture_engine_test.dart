import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:id_fixture/domain/fixture_models.dart';
import 'package:id_fixture/domain/legacy_fixture_engine.dart';

Map<String, dynamic> cn([Map<String, dynamic> overrides = const {}]) => {
  'profileId': 'cn-id-demo',
  'count': 1,
  'seed': 'review-fixture',
  'mode': 'positive',
  'birthDate': '2000-02-29',
  'sex': 'any',
  'addressCode': '110101',
  ...overrides,
};

Map<String, dynamic> ny([Map<String, dynamic> overrides = const {}]) => {
  'profileId': 'us-ny-dmv',
  'count': 1,
  'seed': 'review-fixture',
  'mode': 'positive',
  ...overrides,
};

Map<String, dynamic> passport([Map<String, dynamic> overrides = const {}]) => {
  'profileId': 'us-passport-ng',
  'count': 1,
  'seed': 'review-fixture',
  'mode': 'positive',
  ...overrides,
};

String status(List<RuleCheck> checks, String id) =>
    checks.firstWhere((check) => check.id == id).status;

Map<String, dynamic> copied(Map<String, dynamic> input) =>
    jsonDecode(jsonEncode(input)) as Map<String, dynamic>;

List<Map<String, dynamic>> fixturePackages() =>
    (jsonDecode(
              File('test/fixtures/js_golden_packages.json').readAsStringSync(),
            )
            as List)
        .cast<Map<String, dynamic>>();

void main() {
  test(
    'JavaScript package goldens replay bit-exactly across all modes and seeds',
    () {
      final packages = fixturePackages();
      expect(packages.length, 52);
      for (var index = 0; index < packages.length; index++) {
        final pkg = LegacyFixtureEngine.inspectPackage(
          jsonEncode(packages[index]),
        );
        final replay = LegacyFixtureEngine.replayPackage(pkg);
        expect(replay.matches, isTrue, reason: 'JS fixture index $index');
        expect(replay.differences, isEmpty, reason: 'JS fixture index $index');
        // Compare boolean results so test failures never print complete numbers.
        expect(
          jsonEncode(
                replay.batch.cases.map((entry) => entry.toJson()).toList(),
              ) ==
              jsonEncode(pkg['cases']),
          isTrue,
          reason: 'Cases or labels differ for JS fixture index $index',
        );
        expect(replay.batch.meta['dataHash'], LegacyFixtureEngine.dataHash);
        expect(
          replay.batch.meta['engineVersion'],
          LegacyFixtureEngine.engineVersion,
        );
        expect(replay.batch.meta['prng'], LegacyFixtureEngine.prng);
      }
    },
  );

  test('the actual browser-exported package replays without migration', () {
    final text = File(
      'test/fixtures/prototype-exported-package.json',
    ).readAsStringSync();
    final pkg = LegacyFixtureEngine.inspectPackage(text);
    final replay = LegacyFixtureEngine.replayPackage(pkg);
    expect(replay.matches, isTrue);
    expect(replay.batch.config['mode'], 'checksum');
    expect(replay.batch.cases.length, 3);
  });

  test('registry and batches are immutable and Vietnam stays disabled', () {
    expect(LegacyFixtureEngine.profile('vn-id').enabled, isFalse);
    expect(
      () => LegacyFixtureEngine.generate({'profileId': 'vn-id'}),
      throwsFormatException,
    );
    expect(
      () => LegacyFixtureEngine.validate('vn-id', 'test-only'),
      throwsFormatException,
    );
    expect(() => LegacyFixtureEngine.profile('unknown'), throwsFormatException);
    expect(() => LegacyFixtureEngine.profiles.clear(), throwsUnsupportedError);
    expect(
      () => LegacyFixtureEngine.profile('cn-id-demo').addressCodes.clear(),
      throwsUnsupportedError,
    );
    final batch = LegacyFixtureEngine.generate(cn());
    expect(() => batch.config['seed'] = 'mutated', throwsUnsupportedError);
    expect(() => batch.cases.clear(), throwsUnsupportedError);
    expect(() => batch.cases.first.checks.clear(), throwsUnsupportedError);
  });

  test('official GB appendix vector validates independently including X', () {
    // Public normative example; not a test identity or a real-person input.
    final value = ['110105', '19491231', '002', 'X'].join();
    final checks = LegacyFixtureEngine.validate(
      'cn-id-demo',
      value,
      context: {'sex': 'female'},
    );
    for (final id in [
      'length',
      'charset',
      'address',
      'date',
      'sequence',
      'checksum',
      'sex',
    ]) {
      expect(status(checks, id), 'pass', reason: id);
    }
    expect(status(checks, 'issuance'), 'unknown');
    final changed = '${value.substring(0, value.length - 1)}0';
    expect(
      status(LegacyFixtureEngine.validate('cn-id-demo', changed), 'checksum'),
      'fail',
    );
  });

  test('Gregorian dates respect century leap rules and configured bounds', () {
    for (final date in ['1900-01-01', '2000-02-29', '2025-12-31']) {
      expect(
        () => LegacyFixtureEngine.generate(cn({'birthDate': date})),
        returnsNormally,
      );
    }
    for (final date in [
      '1900-02-29',
      '2001-02-29',
      '2020-04-31',
      '2020-00-01',
      '2020-01-00',
      '1899-12-31',
      '2026-01-01',
      '2020-1-01',
      'not-a-date',
    ]) {
      expect(
        () => LegacyFixtureEngine.generate(cn({'birthDate': date})),
        throwsFormatException,
        reason: date,
      );
    }
    final value = LegacyFixtureEngine.generate(cn()).cases.first.value;
    final impossible = '${value.substring(0, 6)}19000229${value.substring(14)}';
    expect(
      status(LegacyFixtureEngine.validate('cn-id-demo', impossible), 'date'),
      'fail',
    );
    final unknownAddress = '999999${value.substring(6)}';
    expect(
      status(
        LegacyFixtureEngine.validate('cn-id-demo', unknownAddress),
        'address',
      ),
      'unknown',
    );
  });

  test(
    'CN parameters govern encoded sex, fixed segments and unique batches',
    () {
      for (final sex in ['male', 'female', 'any']) {
        final batch = LegacyFixtureEngine.generate(
          cn({'count': 100, 'sex': sex, 'addressCode': '110102'}),
        );
        expect(batch.cases.map((entry) => entry.value).toSet().length, 100);
        for (final entry in batch.cases) {
          expect(entry.value.startsWith('11010220000229'), isTrue);
          expect(entry.expectedFailureIds, isEmpty);
          expect(status(entry.checks, 'checksum'), 'pass');
          expect(status(entry.checks, 'issuance'), 'unknown');
          if (sex != 'any') {
            expect(int.parse(entry.value[16]) % 2, sex == 'male' ? 1 : 0);
          }
        }
      }
    },
  );

  test('all positive profiles support 100 unique values, issuance unknown', () {
    for (final config in [
      cn({'count': 100}),
      ny({'count': 100}),
      passport({'count': 100}),
    ]) {
      final batch = LegacyFixtureEngine.generate(config);
      expect(batch.cases.length, 100);
      expect(batch.cases.map((entry) => entry.value).toSet().length, 100);
      for (final entry in batch.cases) {
        expect(entry.checks.where((check) => check.status == 'fail'), isEmpty);
        expect(status(entry.checks, 'issuance'), 'unknown');
        if (batch.profileId == 'us-ny-dmv') {
          expect(RegExp(r'^[0-9]{9}$').hasMatch(entry.value), isTrue);
        }
        if (batch.profileId == 'us-passport-ng') {
          expect(RegExp(r'^[A-Z][0-9]{8}$').hasMatch(entry.value), isTrue);
        }
      }
    }
  });

  test(
    'negative cases report all actual failures including coupled effects',
    () {
      for (final profile in LegacyFixtureEngine.profiles.where(
        (entry) => entry.enabled,
      )) {
        final base = profile.id == 'cn-id-demo'
            ? cn()
            : profile.id == 'us-ny-dmv'
            ? ny()
            : passport();
        for (final mode in profile.modes.where((mode) => mode != 'positive')) {
          final batch = LegacyFixtureEngine.generate({
            ...base,
            'mode': mode,
            'count': 100,
          });
          expect(batch.cases.map((entry) => entry.value).toSet().length, 100);
          for (final entry in batch.cases) {
            final failures = entry.checks
                .where((check) => check.status == 'fail')
                .map((check) => check.id)
                .toList();
            expect(entry.expectedFailureIds, failures);
            expect(failures, contains(mode));
            expect(status(entry.checks, 'issuance'), 'unknown');
          }
        }
      }
    },
  );

  test('generator checksum has an independent congruence oracle', () {
    final batch = LegacyFixtureEngine.generate(
      cn({'count': 100, 'seed': 'independent-checksum-oracle'}),
    );
    for (final entry in batch.cases) {
      var sum = 0;
      for (var index = 0; index < entry.value.length; index++) {
        final digit = entry.value[index] == 'X'
            ? 10
            : int.parse(entry.value[index]);
        sum += digit * ((1 << (17 - index)) % 11);
      }
      expect(sum % 11, 1);
    }
  });

  test(
    'configuration bounds reject nulls, invalid types and foreign fields',
    () {
      for (final count in [
        0,
        -1,
        101,
        1.5,
        '2',
        null,
        double.nan,
        double.infinity,
      ]) {
        expect(
          () => LegacyFixtureEngine.generate(ny({'count': count})),
          throwsFormatException,
        );
      }
      for (final seed in ['', ' ', 'x' * 65, '🧪' * 33, 42, null]) {
        expect(
          () => LegacyFixtureEngine.generate(ny({'seed': seed})),
          throwsFormatException,
        );
      }
      for (final override in [
        {'mode': null},
        {'mode': 'checksum'},
        {'birthDate': '2000-01-01'},
        {'url': 'https://example.invalid'},
      ]) {
        expect(
          () => LegacyFixtureEngine.generate(ny(override)),
          throwsFormatException,
        );
      }
      for (final override in [
        {'sex': null},
        {'sex': 'other'},
        {'addressCode': '110108'},
        {'birthDate': null},
      ]) {
        expect(
          () => LegacyFixtureEngine.generate(cn(override)),
          throwsFormatException,
        );
      }
      expect(
        () => LegacyFixtureEngine.validate('cn-id-demo', 'x' * 129),
        throwsFormatException,
      );
      expect(
        LegacyFixtureEngine.generate({
          'profileId': 'us-ny-dmv',
        }).config['count'],
        1,
      );
      expect(
        LegacyFixtureEngine.generate(ny({'count': 1.0})).config['count'],
        1,
      );
    },
  );

  test(
    'complete configuration is deterministic and preserves seed verbatim',
    () {
      for (final config in [
        cn({'count': 10}),
        ny({'count': 10}),
        passport({'count': 10}),
      ]) {
        final first = LegacyFixtureEngine.generate(config);
        expect(
          jsonEncode(first.toJson()) ==
              jsonEncode(LegacyFixtureEngine.generate(config).toJson()),
          isTrue,
        );
        expect(
          jsonEncode(first.toJson()) !=
              jsonEncode(
                LegacyFixtureEngine.generate({
                  ...config,
                  'seed': 'different',
                }).toJson(),
              ),
          isTrue,
        );
      }
      final spaced = LegacyFixtureEngine.generate(ny({'seed': ' sample-01 '}));
      final plain = LegacyFixtureEngine.generate(ny({'seed': 'sample-01'}));
      expect(spaced.config['seed'], ' sample-01 ');
      expect(spaced.cases.first.value != plain.cases.first.value, isTrue);
      expect(
        LegacyFixtureEngine.replayPackage(
          LegacyFixtureEngine.createPackage(spaced),
        ).matches,
        isTrue,
      );
      // This is not ECMAScript whitespace, so the JS-exported seed is allowed.
      expect(
        () => LegacyFixtureEngine.generate(ny({'seed': '\u0085'})),
        returnsNormally,
      );
    },
  );

  test(
    'NY leading zero remains a string through package inspection and replay',
    () {
      FixtureBatch? selected;
      for (var index = 0; index < 1000; index++) {
        final batch = LegacyFixtureEngine.generate(
          ny({'seed': 'leading-zero-$index'}),
        );
        if (batch.cases.first.value.startsWith('0')) {
          selected = batch;
          break;
        }
      }
      expect(selected != null, isTrue);
      final pkg = LegacyFixtureEngine.inspectPackage(
        jsonEncode(LegacyFixtureEngine.createPackage(selected!)),
      );
      final value = (pkg['cases'] as List).first['value'];
      expect(value is String, isTrue);
      expect((value as String).startsWith('0'), isTrue);
      expect(value.length, 9);
      expect(LegacyFixtureEngine.replayPackage(pkg).matches, isTrue);
    },
  );

  test(
    'every profile and mode round-trips; reordered configuration is accepted',
    () {
      for (final profile in LegacyFixtureEngine.profiles.where(
        (entry) => entry.enabled,
      )) {
        for (final mode in profile.modes) {
          final batch = LegacyFixtureEngine.generate({
            'profileId': profile.id,
            'count': 3,
            'mode': mode,
            'seed': 'round-trip',
          });
          final pkg = LegacyFixtureEngine.createPackage(batch);
          final config = pkg['config'] as Map<String, dynamic>;
          pkg['config'] = Map<String, dynamic>.fromEntries(
            config.entries.toList().reversed,
          );
          final replay = LegacyFixtureEngine.replayPackage(
            LegacyFixtureEngine.inspectPackage(jsonEncode(pkg)),
          );
          expect(replay.matches, isTrue);
          expect(
            jsonEncode(batch.toJson()) == jsonEncode(replay.batch.toJson()),
            isTrue,
          );
        }
      }
    },
  );

  test(
    'wrong versions, hashes and synthetic claims never silently upgrade',
    () {
      final base = LegacyFixtureEngine.createPackage(
        LegacyFixtureEngine.generate(ny()),
      );
      for (final field in [
        'engineVersion',
        'prng',
        'profileVersion',
        'dataHash',
        'profileId',
        'schema',
        'schemaVersion',
      ]) {
        final pkg = copied(base);
        pkg[field] = 'unavailable-version';
        expect(
          () => LegacyFixtureEngine.inspectPackage(jsonEncode(pkg)),
          throwsFormatException,
          reason: field,
        );
      }
      for (final field in ['synthetic', 'issuanceChecked']) {
        final pkg = copied(base);
        pkg[field] = field == 'issuanceChecked';
        expect(
          () => LegacyFixtureEngine.inspectPackage(jsonEncode(pkg)),
          throwsFormatException,
          reason: field,
        );
      }
    },
  );

  test('changed values and expected checks become replay differences', () {
    final base = LegacyFixtureEngine.createPackage(
      LegacyFixtureEngine.generate(ny()),
    );
    final changedValue = copied(base);
    final entry = (changedValue['cases'] as List).first as Map;
    entry['value'] = entry['value'] == '000000000' ? '111111111' : '000000000';
    final valueReplay = LegacyFixtureEngine.replayPackage(
      LegacyFixtureEngine.inspectPackage(jsonEncode(changedValue)),
    );
    expect(valueReplay.matches, isFalse);
    expect(valueReplay.differences.any((entry) => entry.index == 0), isTrue);
    final changedCheck = copied(base);
    final checkEntry = (changedCheck['cases'] as List).first as Map;
    (checkEntry['checks'] as List).first['status'] = 'fail';
    checkEntry['expectedFailureIds'] = ['length'];
    final checkReplay = LegacyFixtureEngine.replayPackage(
      LegacyFixtureEngine.inspectPackage(jsonEncode(changedCheck)),
    );
    expect(checkReplay.matches, isFalse);
    expect(checkReplay.differences.length, greaterThanOrEqualTo(2));
  });

  test('malformed, oversized and executable-looking data is rejected', () {
    for (final text in [
      '',
      '{',
      'null',
      '[]',
      '42',
      'x' * (LegacyFixtureEngine.maxPackageBytes + 1),
      'é' * (LegacyFixtureEngine.maxPackageBytes ~/ 2 + 1),
    ]) {
      expect(
        () => LegacyFixtureEngine.inspectPackage(text),
        throwsFormatException,
      );
    }
    final base = LegacyFixtureEngine.createPackage(
      LegacyFixtureEngine.generate(ny()),
    );
    final mutations = <void Function(Map<String, dynamic>)>[
      (pkg) => pkg['cases'] = [],
      (pkg) {
        pkg['cases'] = List.filled(101, (pkg['cases'] as List).first);
        (pkg['config'] as Map)['count'] = 101;
      },
      (pkg) => (pkg['cases'] as List).first['value'] = 123,
      (pkg) => pkg['url'] = 'https://example.invalid',
      (pkg) => pkg['code'] = 'shouldNeverRun()',
      (pkg) => (pkg['cases'] as List).first['checks'][0]['labelZh'] =
          '<script>run()</script>',
      (pkg) => (pkg['cases'] as List).first['expectedFailureIds'] = [
        'invented-rule',
      ],
      (pkg) => (pkg['config'] as Map).remove('count'),
      (pkg) => pkg['exportedAt'] = 'yesterday',
      (pkg) => (pkg['config'] as Map)['__proto__'] = {'polluted': true},
      (pkg) => (pkg['cases'] as List).first['checks'].add(
        (pkg['cases'] as List).first['checks'][0],
      ),
    ];
    for (var index = 0; index < mutations.length; index++) {
      final pkg = copied(base);
      mutations[index](pkg);
      expect(
        () => LegacyFixtureEngine.inspectPackage(jsonEncode(pkg)),
        throwsFormatException,
        reason: 'mutation $index',
      );
    }
    final cyclic = <String, dynamic>{};
    cyclic['self'] = cyclic;
    expect(
      () => LegacyFixtureEngine.replayPackage(cyclic),
      throwsFormatException,
    );
  });

  test(
    'shape checks do not accept trailing line breaks as numeric characters',
    () {
      expect(
        status(
          LegacyFixtureEngine.validate('us-ny-dmv', '12345678\n'),
          'charset',
        ),
        'fail',
      );
      expect(
        status(
          LegacyFixtureEngine.validate('us-passport-ng', 'A1234567\n'),
          'charset',
        ),
        'fail',
      );
      final short = LegacyFixtureEngine.validate(
        'cn-id-demo',
        '1',
        context: {'sex': 'male'},
      );
      expect(status(short, 'length'), 'fail');
      expect(status(short, 'checksum'), 'unknown');
      expect(status(short, 'sex'), 'unknown');
    },
  );
}
