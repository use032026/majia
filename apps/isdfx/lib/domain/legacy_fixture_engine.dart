// Frozen 1.0.0 rules for exact replay of existing packages.
import 'dart:convert';

import 'fixture_models.dart';

class LegacyFixtureEngine {
  LegacyFixtureEngine._();

  static const engineVersion = '1.0.0';
  static const prng = 'fnv1a32-seeded-mulberry32-v1';
  static const asOf = '2026-11-04';
  static const maxPackageBytes = 1024 * 1024;
  static const snapshotCanonical =
      'IDFIXTURE|engine:1.0.0|cn:GB11643-1999:demo-2022:110101,110102,110105|ny:dmv-id:9digits|us:ng-passport-book:A-Z+8digits|asof:2026-11-04';
  static const dataHash =
      'sha256:d4f79e09d7b2a746842b72357ed8bd438ef640eab9f318afd21f56d7452d07c1';

  static const profiles = <RuleProfile>[
    RuleProfile(
      id: 'cn-id-demo',
      country: 'CN',
      documentType: 'national-id',
      nameZh: '公民身份号码',
      nameEn: 'Citizen ID number',
      enabled: true,
      fidelity: 'demo',
      version: 'gb11643-1999-demo-2022-v1',
      coverageZh: '小范围演示 · 北京地区代码快照',
      coverageEn: 'Limited demo · Beijing code snapshot',
      limitationsZh:
          '只采用2022年北京3个代码的固定演示快照，不覆盖全国或历史代码。生日1900–2025、顺序001–999是本原型的测试范围。通过检查不代表已签发，也不保证不会与真实号码重合。',
      limitationsEn:
          'Fixed demo snapshot of three Beijing codes from 2022; no nationwide or historical coverage. Years 1900–2025 and sequences 001–999 are prototype test limits. Passing does not establish issuance or prevent a collision with a real number.',
      modes: ['positive', 'length', 'charset', 'checksum'],
      constraints: [
        'length',
        'charset',
        'address',
        'date',
        'sequence',
        'checksum',
        'sex',
        'issuance',
      ],
      addressCodes: [
        AddressCode(
          code: '110101',
          nameZh: '北京市东城区',
          nameEn: 'Dongcheng, Beijing',
        ),
        AddressCode(
          code: '110102',
          nameZh: '北京市西城区',
          nameEn: 'Xicheng, Beijing',
        ),
        AddressCode(
          code: '110105',
          nameZh: '北京市朝阳区',
          nameEn: 'Chaoyang, Beijing',
        ),
      ],
      sources: [
        RuleSource(
          title: 'GB 11643-1999 · 官方托管标准全文',
          url:
              'https://zjw.beijing.gov.cn/Portals/0/zhuanti/fazhan/%E8%BA%AB%E4%BB%BD%E8%AF%81GB11643-1999.pdf',
        ),
        RuleSource(
          title: '北京市民政局 · 2022年行政区划代码（2023-06-12发布）',
          url: 'https://mzj.beijing.gov.cn/art/2023/6/12/art_9984_644480.html',
        ),
      ],
    ),
    RuleProfile(
      id: 'us-ny-dmv',
      country: 'US',
      documentType: 'driver-license',
      nameZh: '纽约州驾照 · DMV ID',
      nameEn: 'New York licence · DMV ID',
      enabled: true,
      fidelity: 'format',
      version: 'ny-dmv-id-format-20261104-v1',
      coverageZh: '纽约州 · 仅9位数字格式',
      coverageEn: 'New York · nine-digit format only',
      limitationsZh:
          '仅检查9位数字，不检查发号算法。DMV ID与同卡document number不同，不适用于全美。真实签发及持有人未知。',
      limitationsEn:
          'Checks nine digits only, not an issuance algorithm. DMV ID is separate from the document number and is not a nationwide format. Issuance and holder are unknown.',
      modes: ['positive', 'length', 'charset'],
      constraints: ['length', 'charset', 'issuance'],
      sources: [
        RuleSource(
          title: 'New York DMV · Information about Transaction Entries',
          url:
              'https://dmv.ny.gov/transaction-message/information-about-transaction-entries',
        ),
      ],
    ),
    RuleProfile(
      id: 'us-passport-ng',
      country: 'US',
      documentType: 'passport',
      nameZh: '新一代护照本号码',
      nameEn: 'Next Generation Passport Book',
      enabled: true,
      fidelity: 'format',
      version: 'us-ng-book-format-20261104-v1',
      coverageZh: '新一代护照本 · 仅字母加8位数字',
      coverageEn: 'Next Generation book · letter plus eight digits',
      limitationsZh:
          '只演示公开的字母加8位数字结构，A–Z为格式测试字符集，不代表每个前缀实际用于该类护照。不覆盖护照卡、旧版或实际签发检查。',
      limitationsEn:
          'Demonstrates the published letter-plus-eight-digits structure. A–Z is a format-test alphabet, not evidence that every prefix is issued for this passport type. Excludes passport cards, older formats and issuance checks.',
      modes: ['positive', 'length', 'charset'],
      constraints: ['length', 'charset', 'issuance'],
      sources: [
        RuleSource(
          title:
              'U.S. Department of State · Design and Security of our Documents',
          url:
              'https://travel.state.gov/en/passports/apply/help/security-design.html',
        ),
      ],
    ),
    RuleProfile(
      id: 'vn-id',
      country: 'VN',
      documentType: 'national-id',
      nameZh: '个人身份号码',
      nameEn: 'Personal identification number',
      enabled: false,
      fidelity: 'not_connected',
      version: 'unverified',
      coverageZh: '现行完整规则待核实',
      coverageEn: 'Current complete rules pending verification',
      limitationsZh: '基础12位结构有官方说明；现行完整正文与代码表未核全，本应用不生成越南号码。',
      limitationsEn:
          'Official material describes a 12-digit structure; current complete text and code tables remain unverified. Generation is disabled.',
      modes: [],
      constraints: [],
      sources: [
        RuleSource(
          title: '越南政府公报 · 118/2026/TT-BCA',
          url:
              'https://congbao.chinhphu.vn/van-ban/thong-tu-so-118-2026-tt-bca-470080.htm',
        ),
      ],
    ),
  ];

  static const _checkLabels = <String, List<String>>{
    'length': ['长度符合规则', 'Length matches the rule'],
    'charset': ['字符组成符合规则', 'Character structure matches the rule'],
    'address': ['属于本演示地区快照', 'Included in this demo code snapshot'],
    'date': ['出生日期为有效日历日期', 'Birth date is a valid calendar date'],
    'sequence': ['演示顺序码001–999', 'Demo sequence is 001–999'],
    'checksum': ['MOD 11-2校验位', 'MOD 11-2 check character'],
    'sex': ['编码性别符合所选测试参数', 'Encoded sex matches the selected test parameter'],
    'issuance': ['真实签发、持有人及有效状态', 'Actual issuance, holder and validity'],
  };

  static RuleProfile profile(String id) {
    for (final item in profiles) {
      if (item.id == id) return item;
    }
    throw _error('未知规则档案', 'Unknown rule profile');
  }

  static FormatException _error(String zh, String en) =>
      FormatException('$zh / $en');

  static Map<String, dynamic> _exactMap(
    Object? value,
    List<String> allowed, {
    List<String>? required,
  }) {
    if (value is! Map ||
        value.keys.any((key) => key is! String || !allowed.contains(key)) ||
        (required ?? allowed).any((key) => !value.containsKey(key))) {
      throw _error('文件字段或结构不符合本产品格式', 'Unexpected package fields or structure');
    }
    return Map<String, dynamic>.from(value);
  }

  static bool _validDate(Object? input) {
    if (input is! String || !_fullMatch(RegExp(r'\d{4}-\d{2}-\d{2}'), input)) {
      return false;
    }
    final parts = input.split('-').map(int.parse).toList();
    final year = parts[0], month = parts[1], day = parts[2];
    if (year < 1 || month < 1 || month > 12 || day < 1) return false;
    final days = [
      31,
      year % 4 == 0 && (year % 100 != 0 || year % 400 == 0) ? 29 : 28,
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
    ];
    return day <= days[month - 1];
  }

  static bool _fullMatch(RegExp expression, String value) {
    final match = expression.matchAsPrefix(value);
    return match != null && match.end == value.length;
  }

  static Map<String, dynamic> _normalizeConfig(Map<String, dynamic> input) {
    final id = input['profileId'];
    if (id is! String) throw _error('未知规则档案', 'Unknown rule profile');
    final rule = profile(id);
    if (!rule.enabled) {
      throw _error(
        '该规则仍待核实，暂不生成',
        'This rule remains unverified; generation is disabled',
      );
    }
    final isCn = rule.id == 'cn-id-demo';
    _exactMap(
      input,
      [
        'profileId',
        'count',
        'seed',
        'mode',
        if (isCn) ...['birthDate', 'sex', 'addressCode'],
      ],
      required: ['profileId'],
    );
    final count = input.containsKey('count') ? input['count'] : 1;
    final seed = input.containsKey('seed') ? input['seed'] : 'fixture-01';
    final mode = input.containsKey('mode') ? input['mode'] : 'positive';
    if (count is! num ||
        !count.isFinite ||
        count != count.truncate() ||
        count < 1 ||
        count > 100) {
      throw _error('生成数量须为1–100的整数', 'Count must be an integer from 1 to 100');
    }
    // Match JavaScript UTF-16 length and ECMAScript trim semantics verbatim.
    final jsWhitespace = RegExp(
      r'^[\u0009-\u000d\u0020\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff]*$',
    );
    if (seed is! String ||
        seed.isEmpty ||
        seed.length > 64 ||
        jsWhitespace.hasMatch(seed)) {
      throw _error('复现种子须为1–64个字符', 'Seed must contain 1–64 characters');
    }
    if (mode is! String || !rule.modes.contains(mode)) {
      throw _error('此规则不支持所选测试模式', 'Unsupported test mode for this profile');
    }
    final config = <String, dynamic>{
      'profileId': rule.id,
      'count': count.toInt(),
      'seed': seed,
      'mode': mode,
    };
    if (isCn) {
      final birthDate = input.containsKey('birthDate')
          ? input['birthDate']
          : '2000-01-01';
      final addressCode = input.containsKey('addressCode')
          ? input['addressCode']
          : '110101';
      final sex = input.containsKey('sex') ? input['sex'] : 'any';
      if (!_validDate(birthDate) ||
          (birthDate as String).compareTo('1900-01-01') < 0 ||
          birthDate.compareTo('2025-12-31') > 0) {
        throw _error(
          '合成生日须为1900–2025内的有效日期',
          'Synthetic birth date must be valid and within 1900–2025',
        );
      }
      if (!rule.addressCodes.any((entry) => entry.code == addressCode)) {
        throw _error(
          '地区不在固定演示快照内',
          'Address is not in the fixed demo snapshot',
        );
      }
      if (!['any', 'male', 'female'].contains(sex)) {
        throw _error('编码性别参数无效', 'Invalid encoded-sex parameter');
      }
      config.addAll({
        'birthDate': birthDate,
        'sex': sex,
        'addressCode': addressCode,
      });
    }
    return config;
  }

  static RuleCheck _check(String id, String status) {
    final labels = _checkLabels[id]!;
    return RuleCheck(
      id: id,
      status: status,
      labelZh: labels[0],
      labelEn: labels[1],
    );
  }

  /// Only supported constraints are checked. Issuance always remains unknown.
  static List<RuleCheck> validate(
    String profileId,
    String value, {
    Map<String, dynamic> context = const {},
  }) {
    final rule = profile(profileId);
    if (!rule.enabled) throw _error('该档案尚未启用', 'This profile is disabled');
    if (value.length > 128) {
      throw _error(
        '号码必须为不超过128字符的字符串',
        'Value must be a string of at most 128 characters',
      );
    }
    final lengthOk = value.length == (profileId == 'cn-id-demo' ? 18 : 9);
    final checks = [_check('length', lengthOk ? 'pass' : 'fail')];
    if (profileId != 'cn-id-demo') {
      final expression = profileId == 'us-ny-dmv'
          ? RegExp(r'[0-9]+')
          : RegExp(r'[A-Z][0-9]*');
      checks.add(
        _check('charset', _fullMatch(expression, value) ? 'pass' : 'fail'),
      );
    } else {
      final characterOk = _fullMatch(RegExp(r'[0-9]{17}[0-9X]'), value);
      checks.add(_check('charset', characterOk ? 'pass' : 'fail'));
      final hasPositions = lengthOk && characterOk;
      checks.add(
        _check(
          'address',
          !hasPositions
              ? 'unknown'
              : rule.addressCodes.any(
                  (entry) => entry.code == value.substring(0, 6),
                )
              ? 'pass'
              : 'unknown',
        ),
      );
      if (hasPositions) {
        final date =
            '${value.substring(6, 10)}-${value.substring(10, 12)}-${value.substring(12, 14)}';
        checks.add(
          _check(
            'date',
            _validDate(date) && date.compareTo(asOf) <= 0 ? 'pass' : 'fail',
          ),
        );
        checks.add(
          _check(
            'sequence',
            value.substring(14, 17) != '000' ? 'pass' : 'fail',
          ),
        );
        // Independent from the generator's lookup: full weighted congruence.
        var sum = 0;
        for (var index = 0; index < 18; index++) {
          final digit = value[index] == 'X' ? 10 : int.parse(value[index]);
          sum += digit * ((1 << (17 - index)) % 11);
        }
        checks.add(_check('checksum', sum % 11 == 1 ? 'pass' : 'fail'));
      } else {
        checks.addAll([
          _check('date', 'unknown'),
          _check('sequence', 'unknown'),
          _check('checksum', 'unknown'),
        ]);
      }
      final sex = context['sex'];
      if (sex != null && sex != '' && sex != 'any') {
        final matches =
            hasPositions && int.parse(value[16]) % 2 == (sex == 'male' ? 1 : 0);
        checks.add(
          _check(
            'sex',
            !hasPositions
                ? 'unknown'
                : matches
                ? 'pass'
                : 'fail',
          ),
        );
      }
    }
    checks.add(_check('issuance', 'unknown'));
    return List.unmodifiable(checks);
  }

  static String _makeCheckCharacter(String base) {
    const weights = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2];
    var total = 0;
    for (var index = 0; index < base.length; index++) {
      total += int.parse(base[index]) * weights[index];
    }
    return '10X98765432'[total % 11];
  }

  static FixtureBatch generate(Map<String, dynamic> input) {
    final config = _normalizeConfig(input);
    final rule = profile(config['profileId'] as String);
    final random = _JsRandom('$prng|${rule.id}|${config['seed']}');
    final sequences = <int>[];
    final count = config['count'] as int;
    if (rule.id == 'cn-id-demo') {
      for (var sequence = 1; sequence <= 999; sequence++) {
        if (config['sex'] == 'any' ||
            sequence % 2 == (config['sex'] == 'male' ? 1 : 0)) {
          sequences.add(sequence);
        }
      }
      if (count > sequences.length) {
        throw _error('请求数量超出演示组合容量', 'Requested count exceeds demo capacity');
      }
      for (var index = sequences.length - 1; index > 0; index--) {
        final other = (random.next() * (index + 1)).floor();
        final previous = sequences[index];
        sequences[index] = sequences[other];
        sequences[other] = previous;
      }
    }
    final cases = <FixtureCase>[];
    final seen = <String>{};
    var attempts = 0;
    while (cases.length < count) {
      if (++attempts > 10000) {
        throw _error(
          '无法在限定次数内生成唯一批次，请更换参数',
          'Unique-batch attempt limit reached; change parameters',
        );
      }
      String value;
      if (rule.id == 'cn-id-demo') {
        final sequence = sequences[cases.length].toString().padLeft(3, '0');
        final base =
            '${config['addressCode']}${(config['birthDate'] as String).replaceAll('-', '')}$sequence';
        value = base + _makeCheckCharacter(base);
      } else {
        final length = rule.id == 'us-ny-dmv' ? 9 : 8;
        final digits = List.generate(
          length,
          (_) => (random.next() * 10).floor(),
        ).join();
        value = rule.id == 'us-ny-dmv'
            ? digits
            : String.fromCharCode(65 + (random.next() * 26).floor()) + digits;
      }
      if (config['mode'] == 'length') {
        value = value.substring(0, value.length - 1);
      }
      if (config['mode'] == 'charset') value = '!${value.substring(1)}';
      if (config['mode'] == 'checksum') {
        value =
            value.substring(0, value.length - 1) +
            (value.endsWith('0') ? '1' : '0');
      }
      if (!seen.add(value)) continue;
      final checks = validate(rule.id, value, context: config);
      final expected = checks
          .where((check) => check.status == 'fail')
          .map((check) => check.id)
          .toList();
      if ((config['mode'] == 'positive') != expected.isEmpty) {
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
      profileId: rule.id,
      config: config,
      cases: cases,
      meta: {
        'engineVersion': engineVersion,
        'profileVersion': rule.version,
        'dataHash': dataHash,
        'prng': prng,
        'synthetic': true,
        'issuanceChecked': false,
        'asOf': asOf,
        'fidelity': rule.fidelity,
      },
    );
  }

  static Map<String, dynamic> createPackage(FixtureBatch batch) {
    final regenerated = generate(batch.config);
    if (!_sameCases(
      batch.cases.map((entry) => entry.toJson()).toList(),
      regenerated.cases,
    )) {
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
      'profileId': regenerated.profileId,
      'profileVersion': regenerated.meta['profileVersion'],
      'dataHash': dataHash,
      'synthetic': true,
      'issuanceChecked': false,
      'config': Map<String, dynamic>.from(regenerated.config),
      'cases': regenerated.cases.map((entry) => entry.toJson()).toList(),
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static bool _sameChecks(Object? candidate, List<RuleCheck> actual) {
    if (candidate is! List || candidate.length != actual.length) return false;
    for (var index = 0; index < actual.length; index++) {
      final item = candidate[index];
      if (item is! Map ||
          item['id'] != actual[index].id ||
          item['status'] != actual[index].status) {
        return false;
      }
    }
    return true;
  }

  static bool _sameStrings(Object? candidate, List<String> actual) {
    if (candidate is! List || candidate.length != actual.length) return false;
    for (var index = 0; index < actual.length; index++) {
      if (candidate[index] != actual[index]) return false;
    }
    return true;
  }

  static bool _sameCases(Object? candidate, List<FixtureCase> actual) {
    if (candidate is! List || candidate.length != actual.length) return false;
    for (var index = 0; index < actual.length; index++) {
      final entry = candidate[index];
      if (entry is! Map ||
          entry['value'] != actual[index].value ||
          !_sameChecks(entry['checks'], actual[index].checks) ||
          !_sameStrings(
            entry['expectedFailureIds'],
            actual[index].expectedFailureIds,
          )) {
        return false;
      }
    }
    return true;
  }

  static Map<String, dynamic> inspectPackage(String text) {
    if (utf8.encode(text).length > maxPackageBytes) {
      throw _error(
        '用例包必须为不超过1MB的JSON文本',
        'Fixture package must be JSON text no larger than 1 MB',
      );
    }
    Object? parsed;
    try {
      parsed = jsonDecode(text);
    } on FormatException {
      throw _error(
        '无法读取JSON，请选择本产品导出的用例包',
        'Unable to read JSON; select an exported fixture package',
      );
    }
    final pkg = _exactMap(parsed, [
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
    if (pkg['schema'] != 'id-fixture-package' ||
        pkg['schemaVersion'] != 1 ||
        pkg['synthetic'] != true ||
        pkg['issuanceChecked'] != false) {
      throw _error('不是受支持的合成用例包', 'Not a supported synthetic fixture package');
    }
    if (pkg['profileId'] is! String) {
      throw _error('未知规则档案', 'Unknown rule profile');
    }
    final rule = profile(pkg['profileId'] as String);
    if (!rule.enabled ||
        pkg['engineVersion'] != engineVersion ||
        pkg['prng'] != prng ||
        pkg['profileVersion'] != rule.version ||
        pkg['dataHash'] != dataHash) {
      throw _error(
        '精确规则、引擎、随机算法版本或数据哈希不匹配',
        'Exact rule, engine, PRNG version or data hash mismatch',
      );
    }
    final rawConfig = _exactMap(pkg['config'], [
      'profileId',
      'count',
      'seed',
      'mode',
      if (rule.id == 'cn-id-demo') ...['birthDate', 'sex', 'addressCode'],
    ]);
    final config = _normalizeConfig(rawConfig);
    if (config['profileId'] != pkg['profileId'] ||
        config.length != rawConfig.length ||
        config.entries.any((entry) => rawConfig[entry.key] != entry.value)) {
      throw _error(
        '配置缺失或内容与锁定格式不符',
        'Configuration is incomplete or differs from the locked format',
      );
    }
    final entries = pkg['cases'];
    if (entries is! List ||
        entries.length != config['count'] ||
        entries.isEmpty ||
        entries.length > 100) {
      throw _error(
        '用例条数与配置不符或超限',
        'Case count differs from configuration or exceeds the limit',
      );
    }
    final exportedAt = pkg['exportedAt'];
    if (exportedAt is! String ||
        exportedAt.length > 40 ||
        DateTime.tryParse(exportedAt) == null) {
      throw _error('导出时间字段无效', 'Invalid export timestamp');
    }
    for (final rawEntry in entries) {
      final entry = _exactMap(rawEntry, [
        'value',
        'checks',
        'expectedFailureIds',
      ]);
      final value = entry['value'],
          checks = entry['checks'],
          expected = entry['expectedFailureIds'];
      if (value is! String ||
          value.isEmpty ||
          value.length > 128 ||
          checks is! List ||
          checks.length > 8 ||
          expected is! List ||
          expected.length > 8) {
        throw _error('用例字段无效或超限', 'Invalid or oversized case fields');
      }
      final ids = <String>{};
      for (final rawCheck in checks) {
        final item = _exactMap(rawCheck, [
          'id',
          'status',
          'labelZh',
          'labelEn',
        ]);
        final id = item['id'];
        if (id is! String ||
            !_checkLabels.containsKey(id) ||
            !rule.constraints.contains(id) ||
            !['pass', 'fail', 'unknown'].contains(item['status']) ||
            !ids.add(id) ||
            item['labelZh'] != _checkLabels[id]![0] ||
            item['labelEn'] != _checkLabels[id]![1]) {
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
    return pkg;
  }

  static ReplayResult replayPackage(Map<String, dynamic> pkg) {
    late final Map<String, dynamic> inspected;
    try {
      inspected = inspectPackage(jsonEncode(pkg));
    } on JsonUnsupportedObjectError {
      throw _error('用例包包含非JSON数据', 'Package contains non-JSON data');
    }
    final batch = generate(
      Map<String, dynamic>.from(inspected['config'] as Map),
    );
    final differences = <ReplayDifference>[];
    final entries = inspected['cases'] as List;
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index] as Map;
      final actual = batch.cases[index];
      if (entry['value'] != actual.value) {
        differences.add(
          ReplayDifference(
            index: index,
            reason: '号码与固定参数重算结果不同 / Value differs from deterministic replay',
          ),
        );
      }
      if (!_sameChecks(entry['checks'], actual.checks)) {
        differences.add(
          ReplayDifference(
            index: index,
            reason:
                '预期检查状态与重算结果不同 / Expected check statuses differ from replay',
          ),
        );
      }
      if (!_sameStrings(
        entry['expectedFailureIds'],
        actual.expectedFailureIds,
      )) {
        differences.add(
          ReplayDifference(
            index: index,
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
