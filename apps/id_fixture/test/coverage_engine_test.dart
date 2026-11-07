import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:id_fixture/domain/fixture_engine.dart';

Map<String, dynamic> config(
  String id, [
  Map<String, dynamic> extra = const {},
]) => {'profileId': id, 'seed': ' 中文 🧪 seed ', 'count': 3, ...extra};
String? state(List<RuleCheck> checks, String id) =>
    checks.where((c) => c.id == id).firstOrNull?.status;
Map<String, dynamic> copy(Map<String, dynamic> input) =>
    jsonDecode(jsonEncode(input)) as Map<String, dynamic>;
List<Map<String, dynamic>> packages(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
void main() {
  test(
    'new JS packages replay bit-exactly including all modes and Unicode seeds',
    () {
      final all = packages('test/fixtures/coverage_js_golden_packages.json');
      expect(all.length, 66);
      for (var i = 0; i < all.length; i++) {
        final p = FixtureEngine.inspectPackage(jsonEncode(all[i])),
            r = FixtureEngine.replayPackage(p);
        expect(r.matches, true, reason: 'new JS package $i');
        expect(
          jsonEncode(r.batch.cases.map((v) => v.toJson()).toList()) ==
              jsonEncode(p['cases']),
          true,
          reason: 'case bytes $i',
        );
        expect(r.batch.config, p['config']);
        expect(r.batch.meta['engineVersion'], '1.1.0');
        expect(r.batch.meta['dataHash'], FixtureEngine.dataHash);
        final regenerated = FixtureEngine.createPackage(r.batch)
          ..['exportedAt'] = p['exportedAt'];
        expect(
          jsonEncode(regenerated) == jsonEncode(p),
          true,
          reason: 'canonical package bytes $i',
        );
      }
    },
  );
  test(
    'facade retains all 52 frozen packages and real native/browser exports',
    () {
      final all = packages('test/fixtures/js_golden_packages.json');
      for (final path in [
        'test/fixtures/prototype-exported-package.json',
        'test/fixtures/android-aot-original-export.json',
      ]) {
        all.add(
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
        );
      }
      for (final p in all) {
        final r = FixtureEngine.replayPackage(
          FixtureEngine.inspectPackage(jsonEncode(p)),
        );
        expect(r.matches, true);
        expect(
          jsonEncode(r.batch.cases.map((v) => v.toJson()).toList()) ==
              jsonEncode(p['cases']),
          true,
        );
        expect(r.batch.meta['engineVersion'], '1.0.0');
        expect(r.batch.meta['dataHash'], p['dataHash']);
      }
    },
  );
  test(
    'ordered CN regional profiles, catalogs and new fields are immutable',
    () {
      expect(FixtureEngine.profiles.map((p) => p.id), [
        'cn-id',
        'hk-id',
        'mo-id',
        'tw-id',
        'vn-id',
        'us-ny-dmv',
        'us-passport-ng',
        'cn-id-demo',
      ]);
      expect(FixtureEngine.profiles.last.archived, true);
      expect(
        FixtureEngine.profiles.take(4).map((p) => p.country),
        everyElement('CN'),
      );
      expect(FixtureEngine.profiles.take(4).map((p) => p.region), [
        'mainland',
        'HK',
        'MO',
        'TW',
      ]);
      final cn = FixtureEngine.profile('cn-id').addressCodes;
      expect(cn.length, 2851);
      expect(cn.map((a) => a.groupCode).toSet().length, 31);
      expect(
        cn.where((a) => a.kind == 'prefecture_direct_reference').length,
        4,
      );
      expect(
        cn.firstWhere((a) => a.code == '133100').kind,
        'official_reported_identity_prefix',
      );
      expect(cn.every((a) => a.parentCode.isNotEmpty), true);
      final tw = FixtureEngine.profile('tw-id').addressCodes;
      expect(tw.where((a) => a.current).length, 22);
      expect(tw.where((a) => !a.current).map((a) => a.code), [
        'L',
        'R',
        'S',
        'Y',
      ]);
      final vn = FixtureEngine.profile('vn-id').addressCodes;
      expect(vn.length, 63);
      expect(vn.map((a) => a.groupCode).toSet().length, 34);
      expect(vn.any((a) => a.code == '023'), false);
      expect(() => FixtureEngine.profiles.clear(), throwsUnsupportedError);
      expect(() => cn.clear(), throwsUnsupportedError);
      expect(
        () => FixtureEngine.profile('cn-id').modes.clear(),
        throwsUnsupportedError,
      );
      expect(() => FixtureEngine.profile('unknown'), throwsFormatException);
    },
  );
  test(
    'all 2851 mainland references generate with independently checked MOD11-2',
    () {
      for (final a in FixtureEngine.profile('cn-id').addressCodes) {
        final item = FixtureEngine.generate(
          config('cn-id', {
            'count': 1,
            'addressCode': a.code,
            'sex': 'female',
            'birthDate': '2026-11-05',
          }),
        ).cases.single;
        expect(item.value.startsWith('${a.code}20261105'), true);
        expect(state(item.checks, 'address'), 'pass');
        expect(state(item.checks, 'issuance'), 'unknown');
        var sum = 0;
        for (var i = 0; i < 18; i++) {
          sum +=
              (item.value[i] == 'X' ? 10 : int.parse(item.value[i])) *
              ((1 << (17 - i)) % 11);
        }
        expect(sum % 11, 1);
        expect(int.parse(item.value[16]) % 2, 0);
      }
    },
  );
  test(
    'HK official-client arithmetic vectors cover one/two prefixes and 0/A',
    () {
      for (final value in [
        'A1234563',
        'A0000070',
        'A000002A',
        'AA0000030',
        'AA000009A',
      ]) {
        expect(
          state(FixtureEngine.validate('hk-id', value), 'checksum'),
          'pass',
        );
      }
      expect(
        state(FixtureEngine.validate('hk-id', 'A123456A'), 'checksum'),
        'fail',
      );
      for (final prefix in ['A', 'Z', 'AA', 'AZ', 'ZZ']) {
        for (final item in FixtureEngine.generate(
          config('hk-id', {'prefix': prefix, 'count': 100}),
        ).cases) {
          final v = item.value,
              body = v.substring(0, v.length - 1),
              letters = body.substring(0, body.length - 6),
              digits = body.substring(body.length - 6);
          final expanded =
              '${letters.length == 1 ? ' ' : letters[0]}${letters[letters.length - 1]}$digits';
          var sum = 0;
          for (var i = 0; i < 8; i++) {
            final ch = expanded[i],
                n = ch == ' '
                    ? 36
                    : i < 2
                    ? ch.codeUnitAt(0) - 55
                    : int.parse(ch);
            sum += n * (9 - i);
          }
          sum += v.endsWith('A') ? 10 : int.parse(v[v.length - 1]);
          expect(sum % 11, 0);
        }
      }
      for (final prefix in ['', 'a', 'AAA', ' A', 'A1', 'A\n']) {
        expect(
          () => FixtureEngine.generate(config('hk-id', {'prefix': prefix})),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'TW government vector and 26 mappings work; historic selection requires opt-in',
    () {
      expect(
        state(
          FixtureEngine.validate(
            'tw-id',
            'B120667503',
            context: {'sex': 'male'},
          ),
          'checksum',
        ),
        'pass',
      );
      const values = [
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        34,
        18,
        19,
        20,
        21,
        22,
        35,
        23,
        24,
        25,
        26,
        27,
        28,
        29,
        32,
        30,
        31,
        33,
      ];
      for (final a in FixtureEngine.profile('tw-id').addressCodes) {
        if (!a.current) {
          expect(
            () => FixtureEngine.generate(
              config('tw-id', {'addressCode': a.code}),
            ),
            throwsFormatException,
          );
        }
        final batch = FixtureEngine.generate(
          config('tw-id', {
            'addressCode': a.code,
            'allowHistorical': !a.current,
            'sex': 'female',
            'count': 100,
          }),
        );
        for (final item in batch.cases) {
          final v = item.value, n = values[v.codeUnitAt(0) - 65];
          var sum = n ~/ 10 + (n % 10) * 9;
          for (var i = 1; i < 10; i++) {
            sum += int.parse(v[i]) * (i == 9 ? 1 : 9 - i);
          }
          expect(sum % 10, 0);
          expect(v[1], '2');
        }
      }
      expect(
        () => FixtureEngine.generate(
          config('tw-id', {'birthDate': '2000-01-01'}),
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'VN keeps both code systems and historical prefix/year/sex without invented checksum',
    () {
      for (final a in FixtureEngine.profile('vn-id').addressCodes) {
        final b = FixtureEngine.generate(
          config('vn-id', {
            'addressCode': a.code,
            'currentProvinceAdminCode': a.groupCode,
            'birthDate': '1999-12-31',
            'sex': 'female',
            'count': 1,
          }),
        );
        expect(b.config['legacyBirthplaceCode'], a.code);
        expect(b.config['currentProvinceAdminCode'], a.groupCode);
        expect(b.cases.single.value.startsWith('${a.code}199'), true);
        for (final id in ['checksum', 'newIssuance', 'issuance']) {
          expect(state(b.cases.single.checks, id), 'unknown');
        }
        expect(b.meta['assurance'], 'format_only');
        expect(b.config['assurance'], 'format_only');
        expect(b.config['ruleVersion'], b.meta['profileVersion']);
      }
      for (final extra in [
        {'assurance': 'official'},
        {'ruleVersion': 'wrong'},
        {'addressCode': '24'},
        {'addressCode': '027', 'currentProvinceAdminCode': '27'},
        {'addressCode': '027', 'legacyBirthplaceCode': '024'},
      ]) {
        expect(
          () => FixtureEngine.generate(config('vn-id', extra)),
          throwsFormatException,
        );
      }
      final january = FixtureEngine.generate(
        config('vn-id', {
          'addressCode': '027',
          'currentProvinceAdminCode': '24',
          'birthDate': '2000-01-01',
          'sex': 'male',
        }),
      );
      final december = FixtureEngine.generate(
        config('vn-id', {
          'addressCode': '027',
          'currentProvinceAdminCode': '24',
          'birthDate': '2000-12-31',
          'sex': 'male',
        }),
      );
      expect(
        january.cases.map((v) => v.value),
        december.cases.map((v) => v.value),
      );
      expect(january.cases.first.value.startsWith('027200'), true);
    },
  );
  test(
    'all new modes produce unique 100-case batches with faithful failures and unknowns',
    () {
      for (final p in FixtureEngine.profiles.take(5)) {
        for (final mode in p.modes) {
          final b = FixtureEngine.generate(
            config(p.id, {'mode': mode, 'count': 100}),
          );
          expect(b.cases.map((v) => v.value).toSet().length, 100);
          for (final item in b.cases) {
            expect(
              item.expectedFailureIds,
              item.checks.where((c) => c.status == 'fail').map((c) => c.id),
            );
            expect(item.expectedFailureIds.isEmpty, mode == 'positive');
            if (mode != 'positive') {
              expect(item.expectedFailureIds, contains(mode));
            }
            expect(state(item.checks, 'issuance'), 'unknown');
            if (['mo-id', 'vn-id'].contains(p.id)) {
              expect(state(item.checks, 'checksum'), 'unknown');
            }
          }
          expect(
            FixtureEngine.replayPackage(FixtureEngine.createPackage(b)).matches,
            true,
          );
        }
      }
      expect(
        FixtureEngine.generate(
          config('mo-id', {'count': 100}),
        ).cases.any((v) => !['1', '5', '7'].contains(v.value[0])),
        true,
      );
      for (final id in ['mo-id', 'vn-id']) {
        expect(
          () => FixtureEngine.generate(config(id, {'mode': 'checksum'})),
          throwsFormatException,
        );
      }
      for (final mode in ['length', 'checksum']) {
        for (final v in FixtureEngine.generate(
          config('hk-id', {'prefix': 'AA', 'mode': mode, 'count': 100}),
        ).cases) {
          expect(v.expectedFailureIds, contains(mode));
        }
      }
    },
  );
  test(
    'fixed date bounds, Gregorian days and UTF16 seed bounds never drift with clock',
    () {
      for (final id in ['cn-id', 'vn-id']) {
        for (final date in ['1900-01-01', '2000-02-29', '2026-11-05']) {
          expect(
            () => FixtureEngine.generate(config(id, {'birthDate': date})),
            returnsNormally,
          );
        }
        for (final date in [
          '1899-12-31',
          '1900-02-29',
          '2026-11-06',
          '2100-01-01',
          '2025-02-29',
          '2000-01-01\n',
        ]) {
          expect(
            () => FixtureEngine.generate(config(id, {'birthDate': date})),
            throwsFormatException,
          );
        }
      }
      expect(
        () => FixtureEngine.generate(
          config('cn-id-demo', {'birthDate': '2026-01-01'}),
        ),
        throwsFormatException,
      );
      for (final p in FixtureEngine.profiles.take(5)) {
        for (final seed in [' 中文 🧪 ', '𝄞', 'x' * 64, '😀' * 32, '\ud800']) {
          expect(
            FixtureEngine.generate(config(p.id, {'seed': seed})).toJson(),
            FixtureEngine.generate(config(p.id, {'seed': seed})).toJson(),
          );
        }
        for (final seed in ['', ' \t\n', '\ufeff', '😀' * 33]) {
          expect(
            () => FixtureEngine.generate(config(p.id, {'seed': seed})),
            throwsFormatException,
          );
        }
        for (final count in [0, 101, 1.5, '3', null]) {
          expect(
            () => FixtureEngine.generate(config(p.id, {'count': count})),
            throwsFormatException,
          );
        }
        expect(
          FixtureEngine.generate(
                config(p.id, {'seed': ' x '}),
              ).cases.first.value ==
              FixtureEngine.generate(
                config(p.id, {'seed': 'x'}),
              ).cases.first.value,
          false,
        );
      }
    },
  );
  test(
    'package versions, strict structure, byte limits and changed cases reject or report differences',
    () {
      Map<String, dynamic> fresh() =>
          FixtureEngine.createPackage(FixtureEngine.generate(config('cn-id')));
      for (final field in [
        'engineVersion',
        'profileVersion',
        'prng',
        'dataHash',
      ]) {
        final p = fresh()..[field] = 'wrong';
        expect(
          () => FixtureEngine.inspectPackage(jsonEncode(p)),
          throwsFormatException,
        );
      }
      for (final p in [
        fresh()..['engineVersion'] = '1.0.0',
        fresh()..['extra'] = true,
        fresh()..['config'] = {},
        fresh()..['cases'] = [],
      ]) {
        expect(
          () => FixtureEngine.inspectPackage(jsonEncode(p)),
          throwsFormatException,
        );
      }
      final p = fresh(), entry = (p['cases'] as List).first as Map;
      entry['value'] = '0${(entry['value'] as String).substring(1)}';
      expect(FixtureEngine.replayPackage(p).matches, false);
      final q = fresh();
      q['cases'][0]['checks'][0]['status'] = 'unknown';
      expect(FixtureEngine.replayPackage(q).matches, false);
      final l = fresh();
      l['cases'][0]['checks'][0]['labelEn'] = 'modified';
      expect(
        () => FixtureEngine.inspectPackage(jsonEncode(l)),
        throwsFormatException,
      );
      for (final text in [
        '{}',
        'null',
        '[]',
        'not json',
        ' ' * (1024 * 1024 + 1),
        '🧪' * 262145,
      ]) {
        expect(() => FixtureEngine.inspectPackage(text), throwsFormatException);
      }
      for (final id in ['cn-id', 'hk-id', 'mo-id', 'tw-id', 'vn-id']) {
        final b = FixtureEngine.generate(config(id)),
            pkg = FixtureEngine.createPackage(b);
        (pkg['config'] as Map).remove('seed');
        expect(
          () => FixtureEngine.inspectPackage(jsonEncode(pkg)),
          throwsFormatException,
        );
        expect(
          state(
            FixtureEngine.validate(id, '${b.cases.first.value}\n'),
            'charset',
          ),
          'fail',
        );
      }
      final vn = FixtureEngine.createPackage(
        FixtureEngine.generate(config('vn-id')),
      );
      (vn['config'] as Map).remove('legacyBirthplaceCode');
      expect(
        () => FixtureEngine.inspectPackage(jsonEncode(vn)),
        throwsFormatException,
      );
    },
  );
}
