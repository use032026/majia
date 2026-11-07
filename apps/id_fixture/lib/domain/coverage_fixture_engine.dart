import 'dart:convert';
import 'coverage_data.g.dart';
import 'coverage_profiles.dart';
import 'fixture_models.dart';

/// Version 1.1 public-format fixtures; no government database is contacted.
class CoverageFixtureEngine {
  CoverageFixtureEngine._();
  static const engineVersion = '1.1.0';
  static const prng = 'fnv1a32-seeded-mulberry32-v1';
  static const asOf = '2026-11-05';
  static const maxPackageBytes = 1024 * 1024;
  static const dataHash = coverageDataHash;
  static String get snapshotCanonical => coverageSnapshotCanonical;
  static final profiles = coverageProfiles;
  static RuleProfile profile(String id) => profiles.firstWhere(
    (p) => p.id == id,
    orElse: () => throw _error('未知规则档案', 'Unknown rule profile'),
  );
  static FormatException _error(String zh, String en) =>
      FormatException('$zh / $en');
  static bool _full(RegExp re, String value) {
    final m = re.matchAsPrefix(value);
    return m != null && m.end == value.length;
  }

  static Map<String, dynamic> _exact(
    Object? value,
    List<String> allowed, {
    List<String>? required,
  }) {
    if (value is! Map ||
        value.keys.any((k) => k is! String || !allowed.contains(k)) ||
        (required ?? allowed).any((k) => !value.containsKey(k))) {
      throw _error('文件字段或结构不符合本产品格式', 'Unexpected package fields or structure');
    }
    return Map<String, dynamic>.from(value);
  }

  static bool _validDate(Object? value) {
    if (value is! String ||
        !_full(RegExp(r'[0-9]{4}-[0-9]{2}-[0-9]{2}'), value)) {
      return false;
    }
    final p = value.split('-').map(int.parse).toList(),
        y = p[0],
        m = p[1],
        d = p[2];
    return y > 0 &&
        m > 0 &&
        m <= 12 &&
        d > 0 &&
        d <=
            [
              31,
              y % 4 == 0 && (y % 100 != 0 || y % 400 == 0) ? 29 : 28,
              31,
              30,
              31,
              30,
              31,
              31,
              30,
              31,
              30,
              31,
            ][m - 1];
  }

  static List<String> _keys(String id) => [
    'profileId',
    'count',
    'seed',
    'mode',
    if (['cn-id', 'vn-id'].contains(id)) ...[
      'birthDate',
      'sex',
      'addressCode',
      if (id == 'vn-id') ...[
        'currentProvinceAdminCode',
        'legacyBirthplaceCode',
        'ruleVersion',
        'assurance',
      ],
    ] else if (id == 'tw-id') ...[
      'addressCode',
      'sex',
      'allowHistorical',
    ] else if (id == 'hk-id')
      'prefix',
  ];
  static Map<String, dynamic> _normalize(Map<String, dynamic> input) {
    final id = input['profileId'];
    if (id is! String) throw _error('未知规则档案', 'Unknown rule profile');
    final p = profile(id);
    _exact(input, _keys(id), required: ['profileId']);
    final count = input.containsKey('count') ? input['count'] : 1,
        seed = input.containsKey('seed') ? input['seed'] : 'fixture-01',
        mode = input.containsKey('mode') ? input['mode'] : 'positive';
    if (count is! num ||
        !count.isFinite ||
        count != count.truncate() ||
        count < 1 ||
        count > 100) {
      throw _error('生成数量须为1–100的整数', 'Count must be an integer from 1 to 100');
    }
    final whitespace = RegExp(
      r'^[\u0009-\u000d\u0020\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff]*$',
    );
    if (seed is! String ||
        seed.isEmpty ||
        seed.length > 64 ||
        whitespace.hasMatch(seed)) {
      throw _error('复现种子须为1–64个字符', 'Seed must contain 1–64 characters');
    }
    if (mode is! String || !p.modes.contains(mode)) {
      throw _error('此规则不支持所选测试模式', 'Unsupported test mode for this profile');
    }
    final c = <String, dynamic>{
      'profileId': id,
      'count': count.toInt(),
      'seed': seed,
      'mode': mode,
    };
    if (['cn-id', 'vn-id', 'tw-id'].contains(id)) {
      final sex = input.containsKey('sex') ? input['sex'] : 'any';
      if (!['any', 'male', 'female'].contains(sex)) {
        throw _error('编码性别参数无效', 'Invalid encoded-sex parameter');
      }
      if (id != 'tw-id') {
        final d = input.containsKey('birthDate')
            ? input['birthDate']
            : '2000-01-01';
        if (!_validDate(d) ||
            (d as String).compareTo('1900-01-01') < 0 ||
            d.compareTo(asOf) > 0) {
          throw _error(
            '合成生日须在1900-01-01至2026-11-05内',
            'Synthetic birth date must be valid and within 1900-01-01 through 2026-11-05',
          );
        }
        c['birthDate'] = d;
      }
      c['sex'] = sex;
      c['addressCode'] = input.containsKey('addressCode')
          ? input['addressCode']
          : p.addressCodes.first.code;
      final matches = p.addressCodes.where((a) => a.code == c['addressCode']);
      if (matches.isEmpty) {
        throw _error(
          '地区不在版本化公开参考表内',
          'Address is not in the versioned public reference table',
        );
      }
      final a = matches.first;
      if (id == 'tw-id') {
        final h = input.containsKey('allowHistorical')
            ? input['allowHistorical']
            : false;
        if (h is! bool || (!a.current && !h)) {
          throw _error(
            '历史地区须显式启用',
            'Historical regions require explicit opt-in',
          );
        }
        c['allowHistorical'] = h;
      }
      if (id == 'vn-id') {
        c['currentProvinceAdminCode'] =
            input.containsKey('currentProvinceAdminCode')
            ? input['currentProvinceAdminCode']
            : a.groupCode;
        c['legacyBirthplaceCode'] = input.containsKey('legacyBirthplaceCode')
            ? input['legacyBirthplaceCode']
            : c['addressCode'];
        if (c['legacyBirthplaceCode'] != c['addressCode']) {
          throw _error(
            '历史出生地码与选择不匹配',
            'Historical birthplace code does not match the selection',
          );
        }
        c['ruleVersion'] = input.containsKey('ruleVersion')
            ? input['ruleVersion']
            : p.version;
        c['assurance'] = input.containsKey('assurance')
            ? input['assurance']
            : 'format_only';
        if (c['ruleVersion'] != p.version || c['assurance'] != 'format_only') {
          throw _error('越南规则范围元数据不匹配', 'Vietnam rule-scope metadata mismatch');
        }
        if (c['currentProvinceAdminCode'] != a.groupCode) {
          throw _error(
            '当前导航省市与历史出生地码不匹配',
            'Current navigation area does not match the historical birthplace code',
          );
        }
      }
    }
    if (id == 'hk-id') {
      final prefix = input.containsKey('prefix') ? input['prefix'] : 'A';
      if (prefix is! String || !_full(RegExp(r'[A-Z]{1,2}'), prefix)) {
        throw _error(
          '香港前缀须为1–2个大写字母',
          'Hong Kong prefix must contain one or two uppercase letters',
        );
      }
      c['prefix'] = prefix;
    }
    return c;
  }

  static String _cnCheck(String base) {
    const w = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2];
    var total = 0;
    for (var i = 0; i < 17; i++) {
      total += int.parse(base[i]) * w[i];
    }
    return '10X98765432'[total % 11];
  }

  static int _hkSum(String base) {
    final prefix = base.substring(0, base.length - 6),
        digits = base.substring(base.length - 6);
    var sum = prefix.length == 1
        ? 36 * 9 + (prefix.codeUnitAt(0) - 55) * 8
        : (prefix.codeUnitAt(0) - 55) * 9 + (prefix.codeUnitAt(1) - 55) * 8;
    for (var i = 0; i < 6; i++) {
      sum += int.parse(digits[i]) * (7 - i);
    }
    return sum;
  }

  static int _twSum(String base) {
    final mapping =
        ((coverageSnapshot['tw'] as Map)['rules'] as Map)['letter_numeric_map']
            as Map;
    final n = mapping[base[0]] as int;
    var sum = n ~/ 10 + (n % 10) * 9;
    for (var i = 1; i < 9; i++) {
      sum += int.parse(base[i]) * (9 - i);
    }
    return sum;
  }

  static RuleCheck _check(String id, String status) => RuleCheck(
    id: id,
    status: status,
    labelZh: coverageCheckLabels[id]![0],
    labelEn: coverageCheckLabels[id]![1],
  );
  static List<RuleCheck> validate(
    String id,
    String value, {
    Map<String, dynamic> context = const {},
  }) {
    final p = profile(id);
    if (value.length > 128) {
      throw _error(
        '号码必须为不超过128字符的字符串',
        'Value must be a string of at most 128 characters',
      );
    }
    final len = id == 'cn-id'
        ? 18
        : id == 'vn-id'
        ? 12
        : id == 'tw-id'
        ? 10
        : id == 'mo-id'
        ? 8
        : null;
    final hkPrefix = RegExp(r'[A-Z]{1,2}').matchAsPrefix(value)?.group(0);
    final lengthOk = len == null
        ? (hkPrefix != null
              ? value.length == hkPrefix.length + 7
              : (value.length == 8 || value.length == 9))
        : value.length == len;
    final pattern = id == 'cn-id'
        ? r'[0-9]{17}[0-9X]'
        : id == 'hk-id'
        ? r'[A-Z]{1,2}[0-9]{6}[0-9A]'
        : id == 'tw-id'
        ? r'[A-Z][12][0-9]{8}'
        : r'[0-9]+';
    final chars = _full(RegExp(pattern), value),
        positioned = lengthOk && _full(RegExp(pattern), value);
    final out = [
      _check('length', lengthOk ? 'pass' : 'fail'),
      _check('charset', chars ? 'pass' : 'fail'),
    ];
    void push(String key, bool test) => out.add(
      _check(
        key,
        !positioned
            ? 'unknown'
            : test
            ? 'pass'
            : 'fail',
      ),
    );
    if (['cn-id', 'tw-id', 'vn-id'].contains(id)) {
      final width = id == 'cn-id'
          ? 6
          : id == 'vn-id'
          ? 3
          : 1;
      out.add(
        _check(
          'address',
          !positioned
              ? 'unknown'
              : p.addressCodes.any((a) => a.code == value.substring(0, width))
              ? 'pass'
              : 'unknown',
        ),
      );
    }
    if (id == 'cn-id') {
      if (positioned) {
        final d =
            '${value.substring(6, 10)}-${value.substring(10, 12)}-${value.substring(12, 14)}';
        push('date', _validDate(d) && d.compareTo(asOf) <= 0);
        push('sequence', value.substring(14, 17) != '000');
        var sum = 0;
        for (var i = 0; i < 18; i++) {
          sum +=
              (value[i] == 'X' ? 10 : int.parse(value[i])) *
              ((1 << (17 - i)) % 11);
        }
        push('checksum', sum % 11 == 1);
      } else {
        push('date', false);
        push('sequence', false);
        push('checksum', false);
      }
    }
    if (id == 'hk-id') {
      push(
        'checksum',
        positioned &&
            (_hkSum(value.substring(0, value.length - 1)) +
                        (value.endsWith('A')
                            ? 10
                            : int.parse(value[value.length - 1]))) %
                    11 ==
                0,
      );
    }
    if (id == 'tw-id') {
      if (context['sex'] != null &&
          context['sex'] != '' &&
          context['sex'] != 'any') {
        push(
          'sex',
          positioned && value[1] == (context['sex'] == 'male' ? '1' : '2'),
        );
      }
      push(
        'checksum',
        positioned &&
            (_twSum(value.substring(0, value.length - 1)) +
                        int.parse(value[value.length - 1])) %
                    10 ==
                0,
      );
    }
    if (id == 'cn-id' &&
        context['sex'] != null &&
        context['sex'] != '' &&
        context['sex'] != 'any') {
      push(
        'sex',
        positioned &&
            int.parse(value[16]) % 2 == (context['sex'] == 'male' ? 1 : 0),
      );
    }
    if (id == 'vn-id') {
      final century = positioned ? int.parse(value[3]) : 0,
          year = positioned
              ? 1900 +
                    (int.parse(value[3]) ~/ 2) * 100 +
                    int.parse(value.substring(4, 6))
              : 0;
      if (context['birthDate'] != null && context['birthDate'] != '') {
        push(
          'year',
          _validDate(context['birthDate']) &&
              year ==
                  int.parse((context['birthDate'] as String).substring(0, 4)),
        );
      }
      if (context['sex'] != null &&
          context['sex'] != '' &&
          context['sex'] != 'any') {
        push('sex', century % 2 == (context['sex'] == 'male' ? 0 : 1));
      }
      out.addAll([
        _check('checksum', 'unknown'),
        _check('newIssuance', 'unknown'),
      ]);
    }
    if (id == 'mo-id') out.add(_check('checksum', 'unknown'));
    out.add(_check('issuance', 'unknown'));
    return List.unmodifiable(out);
  }

  static FixtureBatch generate(Map<String, dynamic> input) {
    final c = _normalize(input),
        p = profile(c['profileId'] as String),
        random = _JsRandom('$prng|${c['profileId']}|${c['seed']}');
    String digits(int n) =>
        List.generate(n, (_) => (random.next() * 10).floor()).join();
    final sequences = <int>[];
    if (p.id == 'cn-id') {
      for (var n = 1; n <= 999; n++) {
        if (c['sex'] == 'any' || n % 2 == (c['sex'] == 'male' ? 1 : 0)) {
          sequences.add(n);
        }
      }
      for (var i = sequences.length - 1; i > 0; i--) {
        final j = (random.next() * (i + 1)).floor(), a = sequences[i];
        sequences[i] = sequences[j];
        sequences[j] = a;
      }
    }
    final cases = <FixtureCase>[], seen = <String>{};
    var attempts = 0;
    while (cases.length < (c['count'] as int)) {
      if (++attempts > 10000) {
        throw _error(
          '无法在限定次数内生成唯一批次，请更换参数',
          'Unique-batch attempt limit reached; change parameters',
        );
      }
      late String value;
      if (p.id == 'cn-id') {
        final base =
            '${c['addressCode']}${(c['birthDate'] as String).replaceAll('-', '')}${sequences[cases.length].toString().padLeft(3, '0')}';
        value = base + _cnCheck(base);
      }
      if (p.id == 'hk-id') {
        final base = '${c['prefix']}${digits(6)}',
            check = (11 - _hkSum(base) % 11) % 11;
        value = base + (check == 10 ? 'A' : '$check');
      }
      if (p.id == 'mo-id') value = digits(8);
      if (p.id == 'tw-id') {
        final sex = c['sex'] == 'any'
                ? (random.next() * 2).floor() + 1
                : c['sex'] == 'male'
                ? 1
                : 2,
            base = '${c['addressCode']}$sex${digits(7)}';
        value = base + ((10 - _twSum(base) % 10) % 10).toString();
      }
      if (p.id == 'vn-id') {
        final y = int.parse((c['birthDate'] as String).substring(0, 4)),
            sex = c['sex'] == 'any'
                ? (random.next() * 2).floor()
                : c['sex'] == 'male'
                ? 0
                : 1;
        value =
            '${c['addressCode']}${((y - 1900) ~/ 100) * 2 + sex}${(y % 100).toString().padLeft(2, '0')}${digits(6)}';
      }
      if (c['mode'] == 'length') value = value.substring(0, value.length - 1);
      if (c['mode'] == 'charset') value = '!${value.substring(1)}';
      if (c['mode'] == 'checksum') {
        value =
            value.substring(0, value.length - 1) +
            (value.endsWith('0') ? '1' : '0');
      }
      if (!seen.add(value)) continue;
      final checks = validate(p.id, value, context: c),
          expected = checks
              .where((ch) => ch.status == 'fail')
              .map((ch) => ch.id)
              .toList();
      if ((c['mode'] == 'positive') != expected.isEmpty) {
        throw _error(
          '内部生成结果与测试场景不一致',
          'Generated result does not match the selected test scenario',
        );
      }
      cases.add(
        FixtureCase(value: value, checks: checks, expectedFailureIds: expected),
      );
    }
    return FixtureBatch(
      profileId: p.id,
      config: c,
      cases: cases,
      meta: {
        'engineVersion': engineVersion,
        'profileVersion': p.version,
        'dataHash': dataHash,
        'prng': prng,
        'synthetic': true,
        'issuanceChecked': false,
        'asOf': asOf,
        'fidelity': p.fidelity,
        if (p.id == 'vn-id') ...{
          'currentProvinceAdminCode': c['currentProvinceAdminCode'],
          'legacyBirthplaceCode': c['addressCode'],
          'ruleVersion': p.version,
          'assurance': 'format_only',
        },
      },
    );
  }

  static bool _sameChecks(Object? v, List<RuleCheck> checks) {
    if (v is! List || v.length != checks.length) return false;
    for (var i = 0; i < checks.length; i++) {
      if (v[i] is! Map ||
          v[i]['id'] != checks[i].id ||
          v[i]['status'] != checks[i].status) {
        return false;
      }
    }
    return true;
  }

  static bool _sameStrings(Object? v, List<String> actual) =>
      v is List &&
      v.length == actual.length &&
      List.generate(actual.length, (i) => v[i] == actual[i]).every((x) => x);
  static bool _sameCases(Object? v, List<FixtureCase> cases) {
    if (v is! List || v.length != cases.length) return false;
    for (var i = 0; i < cases.length; i++) {
      if (v[i] is! Map ||
          v[i]['value'] != cases[i].value ||
          !_sameChecks(v[i]['checks'], cases[i].checks) ||
          !_sameStrings(
            v[i]['expectedFailureIds'],
            cases[i].expectedFailureIds,
          )) {
        return false;
      }
    }
    return true;
  }

  static Map<String, dynamic> createPackage(FixtureBatch batch) {
    final b = generate(batch.config);
    if (!_sameCases(batch.cases.map((v) => v.toJson()).toList(), b.cases)) {
      throw _error(
        '批次与锁定配置不一致，不能导出',
        'Batch does not match its locked configuration',
      );
    }
    return {
      'schema': 'id-fixture-package',
      'schemaVersion': 1,
      'engineVersion': engineVersion,
      'prng': prng,
      'profileId': b.profileId,
      'profileVersion': b.meta['profileVersion'],
      'dataHash': dataHash,
      'synthetic': true,
      'issuanceChecked': false,
      'config': Map<String, dynamic>.from(b.config),
      'cases': b.cases.map((v) => v.toJson()).toList(),
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static Map<String, dynamic> inspectPackage(String text) {
    if (utf8.encode(text).length > maxPackageBytes) {
      throw _error(
        '用例包必须为不超过1MB的JSON文本',
        'Fixture package must be JSON text no larger than 1 MB',
      );
    }
    Object? raw;
    try {
      raw = jsonDecode(text);
    } on FormatException {
      throw _error(
        '无法读取JSON，请选择本产品导出的用例包',
        'Unable to read JSON; select an exported fixture package',
      );
    }
    final p = _exact(raw, [
      'schema',
      'schemaVersion',
      'engineVersion',
      'prng',
      'profileId',
      'profileVersion',
      'dataHash',
      'synthetic',
      'issuanceChecked',
      'config',
      'cases',
      'exportedAt',
    ]);
    if (p['schema'] != 'id-fixture-package' ||
        p['schemaVersion'] != 1 ||
        p['synthetic'] != true ||
        p['issuanceChecked'] != false) {
      throw _error('不是受支持的合成用例包', 'Not a supported synthetic fixture package');
    }
    if (p['profileId'] is! String) {
      throw _error('未知规则档案', 'Unknown rule profile');
    }
    final rule = profile(p['profileId'] as String);
    if (p['engineVersion'] != engineVersion ||
        p['prng'] != prng ||
        p['profileVersion'] != rule.version ||
        p['dataHash'] != dataHash) {
      throw _error(
        '精确规则、引擎、随机算法版本或数据哈希不匹配',
        'Exact rule, engine, PRNG version or data hash mismatch',
      );
    }
    final rawConfig = _exact(p['config'], _keys(rule.id)),
        c = _normalize(rawConfig);
    if (c['profileId'] != p['profileId'] ||
        c.length != rawConfig.length ||
        c.entries.any((e) => rawConfig[e.key] != e.value)) {
      throw _error(
        '配置缺失或内容与锁定格式不符',
        'Configuration is incomplete or differs from the locked format',
      );
    }
    final entries = p['cases'];
    if (entries is! List || entries.length != c['count']) {
      throw _error(
        '用例条数与配置不符或超限',
        'Case count differs from configuration or exceeds the limit',
      );
    }
    final time = p['exportedAt'];
    if (time is! String ||
        time.length > 40 ||
        DateTime.tryParse(time) == null) {
      throw _error('导出时间字段无效', 'Invalid export timestamp');
    }
    for (final rawEntry in entries) {
      final entry = _exact(rawEntry, ['value', 'checks', 'expectedFailureIds']);
      final value = entry['value'],
          checks = entry['checks'],
          expected = entry['expectedFailureIds'];
      if (value is! String ||
          value.isEmpty ||
          value.length > 128 ||
          checks is! List ||
          checks.length > 10 ||
          expected is! List ||
          expected.length > 10) {
        throw _error('用例字段无效或超限', 'Invalid or oversized case fields');
      }
      final ids = <String>{};
      for (final rawCheck in checks) {
        final ch = _exact(rawCheck, ['id', 'status', 'labelZh', 'labelEn']);
        final id = ch['id'];
        if (id is! String ||
            !rule.constraints.contains(id) ||
            !coverageCheckLabels.containsKey(id) ||
            !['pass', 'fail', 'unknown'].contains(ch['status']) ||
            !ids.add(id) ||
            ch['labelZh'] != coverageCheckLabels[id]![0] ||
            ch['labelEn'] != coverageCheckLabels[id]![1]) {
          throw _error(
            '检查项不属于该规则或被修改',
            'Check does not belong to this rule or was modified',
          );
        }
      }
      if (expected.any((id) => id is! String || !ids.contains(id)) ||
          expected.toSet().length != expected.length) {
        throw _error('预期失败项无效', 'Invalid expected-failure identifiers');
      }
    }
    return p;
  }

  static ReplayResult replayPackage(Map<String, dynamic> pkg) {
    late Map<String, dynamic> p;
    try {
      p = inspectPackage(jsonEncode(pkg));
    } on JsonUnsupportedObjectError {
      throw _error('用例包包含非JSON数据', 'Package contains non-JSON data');
    }
    final batch = generate(Map<String, dynamic>.from(p['config'] as Map)),
        differences = <ReplayDifference>[],
        entries = p['cases'] as List;
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i] as Map, a = batch.cases[i];
      if (e['value'] != a.value) {
        differences.add(
          ReplayDifference(
            index: i,
            reason: '号码与固定参数重算结果不同 / Value differs from deterministic replay',
          ),
        );
      }
      if (!_sameChecks(e['checks'], a.checks)) {
        differences.add(
          ReplayDifference(
            index: i,
            reason:
                '预期检查状态与重算结果不同 / Expected check statuses differ from replay',
          ),
        );
      }
      if (!_sameStrings(e['expectedFailureIds'], a.expectedFailureIds)) {
        differences.add(
          ReplayDifference(
            index: i,
            reason: '预期失败项与重算结果不同 / Expected failures differ from replay',
          ),
        );
      }
    }
    return ReplayResult(
      batch: batch,
      matches: differences.isEmpty,
      differences: differences,
    );
  }
}

/// Bit-exact port of JS Math.imul/unsigned shifts, also avoiding wide products.
class _JsRandom {
  _JsRandom(String seed) {
    for (final point in _jsCodePoints(seed)) {
      _state = _multiply32(_state ^ point, 16777619);
    }
  }
  int _state = 2166136261;
  static int _unsigned(int value) => value.toUnsigned(32);
  static int _multiply32(int a, int b) {
    final low = (a & 0xffff) * (b & 0xffff);
    final high =
        (((a >>> 16) & 0xffff) * (b & 0xffff) +
            (a & 0xffff) * ((b >>> 16) & 0xffff)) &
        0xffff;
    return _unsigned(low + (high << 16));
  }

  static Iterable<int> _jsCodePoints(String input) sync* {
    final units = input.codeUnits;
    for (var index = 0; index < units.length; index++) {
      final first = units[index];
      if (first >= 0xd800 && first <= 0xdbff && index + 1 < units.length) {
        final second = units[index + 1];
        if (second >= 0xdc00 && second <= 0xdfff) {
          yield 0x10000 + ((first - 0xd800) << 10) + second - 0xdc00;
          index++;
          continue;
        }
      }
      yield first;
    }
  }

  double next() {
    _state = _unsigned(_state + 0x6d2b79f5);
    var value = _multiply32(_state ^ (_state >>> 15), 1 | _state);
    value = _unsigned(
      value ^ _unsigned(value + _multiply32(value ^ (value >>> 7), 61 | value)),
    );
    return _unsigned(value ^ (value >>> 14)) / 4294967296;
  }
}
