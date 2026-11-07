/// Synthetic local test fixtures only. No identity or issuance lookup occurs.
class RuleSource {
  const RuleSource({required this.title, required this.url});
  final String title;
  final String url;
}

class AddressCode {
  const AddressCode({
    required this.code,
    required this.nameZh,
    required this.nameEn,
    this.groupCode = '',
    this.groupNameZh = '',
    this.groupNameEn = '',
    this.parentCode = '',
    this.parentNameZh = '',
    this.parentNameEn = '',
    this.kind = '',
    this.current = true,
  });
  final String groupCode;
  final String groupNameZh;
  final String groupNameEn;
  final String parentCode;
  final String parentNameZh;
  final String parentNameEn;
  final String kind;
  final bool current;
  final String code;
  final String nameZh;
  final String nameEn;
}

class RuleProfile {
  const RuleProfile({
    required this.id,
    required this.country,
    required this.documentType,
    required this.nameZh,
    required this.nameEn,
    required this.enabled,
    required this.fidelity,
    required this.version,
    required this.coverageZh,
    required this.coverageEn,
    required this.limitationsZh,
    required this.limitationsEn,
    required this.modes,
    required this.constraints,
    required this.sources,
    this.addressCodes = const [],
    this.region = '',
    this.archived = false,
  });
  final String id;
  final String country;
  final String region;
  final bool archived;
  final String documentType;
  final String nameZh;
  final String nameEn;
  final bool enabled;
  final String fidelity;
  final String version;
  final String coverageZh;
  final String coverageEn;
  final String limitationsZh;
  final String limitationsEn;
  final List<String> modes;
  final List<String> constraints;
  final List<AddressCode> addressCodes;
  final List<RuleSource> sources;
}

class RuleCheck {
  const RuleCheck({
    required this.id,
    required this.status,
    required this.labelZh,
    required this.labelEn,
  });
  final String id;
  final String status;
  final String labelZh;
  final String labelEn;
  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status,
    'labelZh': labelZh,
    'labelEn': labelEn,
  };
}

class FixtureCase {
  FixtureCase({
    required this.value,
    required List<RuleCheck> checks,
    required List<String> expectedFailureIds,
  }) : checks = List.unmodifiable(checks),
       expectedFailureIds = List.unmodifiable(expectedFailureIds);
  final String value;
  final List<RuleCheck> checks;
  final List<String> expectedFailureIds;
  Map<String, dynamic> toJson() => {
    'value': value,
    'checks': checks.map((check) => check.toJson()).toList(),
    'expectedFailureIds': expectedFailureIds,
  };
}

class FixtureBatch {
  FixtureBatch({
    required this.profileId,
    required Map<String, dynamic> config,
    required List<FixtureCase> cases,
    required Map<String, dynamic> meta,
  }) : config = Map.unmodifiable(config),
       cases = List.unmodifiable(cases),
       meta = Map.unmodifiable(meta);
  final String profileId;
  final Map<String, dynamic> config;
  final List<FixtureCase> cases;
  final Map<String, dynamic> meta;
  Map<String, dynamic> toJson() => {
    'profileId': profileId,
    'config': config,
    'cases': cases.map((entry) => entry.toJson()).toList(),
    'meta': meta,
  };
}

class ReplayDifference {
  const ReplayDifference({required this.index, required this.reason});
  final int index;
  final String reason;
}

class ReplayResult {
  ReplayResult({
    required this.batch,
    required this.matches,
    required List<ReplayDifference> differences,
  }) : differences = List.unmodifiable(differences);
  final FixtureBatch batch;
  final bool matches;
  final List<ReplayDifference> differences;
}
