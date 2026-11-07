import 'dart:convert';
import 'fixture_models.dart';
import 'coverage_fixture_engine.dart';
import 'legacy_fixture_engine.dart';
export 'fixture_models.dart';

/// Routes each profile/package to its immutable rule generation.
class FixtureEngine {
  FixtureEngine._();
  static const engineVersion = CoverageFixtureEngine.engineVersion;
  static const prng = CoverageFixtureEngine.prng;
  static const asOf = CoverageFixtureEngine.asOf;
  static const maxPackageBytes = CoverageFixtureEngine.maxPackageBytes;
  static const dataHash = CoverageFixtureEngine.dataHash;
  static String get snapshotCanonical =>
      CoverageFixtureEngine.snapshotCanonical;
  static const _legacyIds = {'cn-id-demo', 'us-ny-dmv', 'us-passport-ng'};
  static final profiles = List<RuleProfile>.unmodifiable([
    ...CoverageFixtureEngine.profiles,
    ...LegacyFixtureEngine.profiles.where((p) => p.country == 'US'),
    _archivedCn,
  ]);
  static final _archivedCn = (() {
    final p = LegacyFixtureEngine.profile('cn-id-demo');
    return RuleProfile(
      id: p.id,
      country: p.country,
      region: 'mainland',
      archived: true,
      documentType: p.documentType,
      nameZh: p.nameZh,
      nameEn: p.nameEn,
      enabled: p.enabled,
      fidelity: p.fidelity,
      version: p.version,
      coverageZh: p.coverageZh,
      coverageEn: p.coverageEn,
      limitationsZh: p.limitationsZh,
      limitationsEn: p.limitationsEn,
      modes: p.modes,
      constraints: p.constraints,
      sources: p.sources,
      addressCodes: p.addressCodes,
    );
  })();
  static RuleProfile profile(String id) => profiles.firstWhere(
    (p) => p.id == id,
    orElse: () => throw const FormatException('未知规则档案 / Unknown rule profile'),
  );
  static FixtureBatch generate(Map<String, dynamic> input) =>
      _legacyIds.contains(input['profileId'])
      ? LegacyFixtureEngine.generate(input)
      : CoverageFixtureEngine.generate(input);
  static List<RuleCheck> validate(
    String id,
    String value, {
    Map<String, dynamic> context = const {},
  }) => _legacyIds.contains(id)
      ? LegacyFixtureEngine.validate(id, value, context: context)
      : CoverageFixtureEngine.validate(id, value, context: context);
  static Map<String, dynamic> createPackage(FixtureBatch batch) =>
      _legacyIds.contains(batch.profileId)
      ? LegacyFixtureEngine.createPackage(batch)
      : CoverageFixtureEngine.createPackage(batch);
  static Map<String, dynamic> inspectPackage(String text) {
    if (utf8.encode(text).length > maxPackageBytes) {
      return CoverageFixtureEngine.inspectPackage(text);
    }
    Object? pkg;
    try {
      pkg = jsonDecode(text);
    } on FormatException {
      return CoverageFixtureEngine.inspectPackage(text);
    }
    return pkg is Map && _legacyIds.contains(pkg['profileId'])
        ? LegacyFixtureEngine.inspectPackage(text)
        : CoverageFixtureEngine.inspectPackage(text);
  }

  static ReplayResult replayPackage(Map<String, dynamic> pkg) {
    late Map<String, dynamic> inspected;
    try {
      inspected = inspectPackage(jsonEncode(pkg));
    } on JsonUnsupportedObjectError {
      throw const FormatException(
        '用例包包含非JSON数据 / Package contains non-JSON data',
      );
    }
    return _legacyIds.contains(inspected['profileId'])
        ? LegacyFixtureEngine.replayPackage(inspected)
        : CoverageFixtureEngine.replayPackage(inspected);
  }
}
