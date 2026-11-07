import 'dart:convert';
import 'coverage_data.g.dart';
import 'fixture_models.dart';

// Metadata shared with the JS coverage engine; public data is owned by the snapshot.
final coverageProfiles = List<RuleProfile>.unmodifiable(
  (jsonDecode(
            r'''[{"id":"cn-id","country":"CN","region":"mainland","dataKey":"mainland","nameZh":"公民身份号码 · 全国参考表","nameEn":"Citizen ID · nationwide reference","fidelity":"reference","version":"gb11643-1999-reference-20261105-v1","coverageZh":"31省级地区 · 2851个公开参考代码","coverageEn":"31 province-level areas · 2,851 public reference codes","limitationsZh":"行政区划参考表含4个市级参考及133100专项代码，不等于公安完整发号表。仅支持1900-01-01至2026-11-05合成生日及001–999顺序码；签发、持有人、实际分配与身份有效性未知。","limitationsEn":"The administrative reference includes four city-level entries and the separately reported 133100 prefix; it is not a complete police allocation table. Synthetic dates are limited to 1900-01-01 through 2026-11-05 and sequences to 001–999. Issuance, holder, allocation and identity validity remain unknown.","modes":["positive","length","charset","checksum"],"constraints":["length","charset","address","date","sequence","checksum","sex","issuance"]},{"id":"hk-id","country":"CN","region":"HK","dataKey":"hk","nameZh":"香港身份证号码","nameEn":"Hong Kong identity card number","fidelity":"checksum","version":"hk-public-client-mod11-20261105-v1","coverageZh":"1–2字母、6数字及校验字符","coverageEn":"One or two letters, six digits and a check character","limitationsZh":"采用政府公开客户端MOD11算法；输出不带括号的主体及校验字符。A–Z前缀仅用于格式测试，不代表现行签发范围；不编码生日或性别，不核验真实身份。","limitationsEn":"Uses the public government-client MOD11 algorithm. Canonical output appends the check character without parentheses. A–Z prefixes are a format-test alphabet, not an issued-prefix catalogue; birth date, sex and real identity are not verified.","modes":["positive","length","charset","checksum"],"constraints":["length","charset","checksum","issuance"]},{"id":"mo-id","country":"CN","region":"MO","dataKey":"mo","nameZh":"澳门居民身份证号码","nameEn":"Macao resident identity card number","fidelity":"format","version":"mo-bir-eight-digit-format-20261105-v1","coverageZh":"现行法定8位数字格式","coverageEn":"Current statutory eight-digit format","limitationsZh":"仅检查7位主体加1位检验数字的格式，未取得可信公开算术算法，校验位始终未知。不将历史1/5/7前缀强套为现行限制；不核验身份、居留资格或签发。","limitationsEn":"Checks the seven-digit body plus one check-digit format only. A supported public arithmetic algorithm was not established, so checksum remains unknown. Historical 1/5/7 prefixes are not imposed as current restrictions. Identity, residence status and issuance are not verified.","modes":["positive","length","charset"],"constraints":["length","charset","checksum","issuance"]},{"id":"tw-id","country":"CN","region":"TW","dataKey":"tw","nameZh":"台湾国民身分证统一编号","nameEn":"Taiwan national identification number","fidelity":"checksum","version":"tw-mod10-regions-20261105-v1","coverageZh":"22现行地区 · 可显式选4个历史前缀","coverageEn":"22 current regions · four historical prefixes by explicit choice","limitationsZh":"采用官方MOD10方法及1/2编码性别；不含居留证。地区码不等于现住地，历史L/R/S/Y须显式选择；流水配赋、真实签发和持有人未知。","limitationsEn":"Uses the official MOD10 method and encoded sex digits 1/2; excludes residence permits. Region prefix is not current residence. Historical L/R/S/Y requires explicit selection. Serial allocation, actual issuance and holder remain unknown.","modes":["positive","length","charset","checksum"],"constraints":["length","charset","address","sex","checksum","issuance"]},{"id":"vn-id","country":"VN","region":"","dataKey":"vn","nameZh":"个人身份号码 · 公开结构","nameEn":"Personal identification number · public structure","fidelity":"format","version":"vn-public-structure-63-birthplaces-20261105-v1","coverageZh":"当前34省市导航 · 63历史公开出生地码","coverageEn":"34 current navigation areas · 63 published historical birthplace codes","limitationsZh":"12位历史公开结构测试：3位出生地、世纪/编码性别、出生年及6位随机段。当前34省市仅为导航，不把两位行政码补零用作新号码前缀。2026新签发分配未知；只编码出生年，不编码月日，不添加校验算法。","limitationsEn":"Tests the published historical 12-digit structure: three-digit birthplace, century/encoded sex, birth year and six random digits. The 34 current areas are navigation only; their two-digit administrative codes are never padded into identity prefixes. Current 2026 allocation remains unknown. Only birth year is encoded, not month/day; no checksum algorithm is invented.","modes":["positive","length","charset"],"constraints":["length","charset","address","year","sex","checksum","newIssuance","issuance"]}]''',
          )
          as List)
      .map((raw) {
        final p = Map<String, dynamic>.from(raw as Map);
        final data = coverageSnapshot[p['dataKey']] as Map;
        return RuleProfile(
          id: p['id'],
          country: p['country'],
          region: p['region'],
          documentType: 'national-id',
          nameZh: p['nameZh'],
          nameEn: p['nameEn'],
          enabled: true,
          fidelity: p['fidelity'],
          version: p['version'],
          coverageZh: p['coverageZh'],
          coverageEn: p['coverageEn'],
          limitationsZh: p['limitationsZh'],
          limitationsEn: p['limitationsEn'],
          modes: List<String>.unmodifiable(p['modes'] as List),
          constraints: List<String>.unmodifiable(p['constraints'] as List),
          sources: List<RuleSource>.unmodifiable(
            (data['sources'] as List).map(
              (s) => RuleSource(title: s['title'], url: s['url']),
            ),
          ),
          addressCodes: List<AddressCode>.unmodifiable(
            ((data['addresses'] ?? []) as List).map(
              (a) => AddressCode(
                code: a['code'],
                nameZh: a['nameZh'],
                nameEn: a['nameEn'],
                groupCode: a['groupCode'] ?? '',
                groupNameZh: a['groupNameZh'] ?? '',
                groupNameEn: a['groupNameEn'] ?? '',
                parentCode: a['parentCode'] ?? '',
                parentNameZh: a['parentNameZh'] ?? '',
                parentNameEn: a['parentNameEn'] ?? '',
                kind: a['kind'] ?? '',
                current: a['current'] ?? true,
              ),
            ),
          ),
        );
      }),
);
const coverageCheckLabels = <String, List<String>>{
  "length": ["长度符合规则", "Length matches the rule"],
  "charset": ["字符组成符合规则", "Character structure matches the rule"],
  "address": [
    "属于版本化公开参考代码表",
    "Included in the versioned public reference table",
  ],
  "date": ["出生日期为有效日历日期", "Birth date is a valid calendar date"],
  "sequence": ["测试顺序码001–999", "Test sequence is 001–999"],
  "checksum": ["公开规则校验字符", "Public-rule check character"],
  "sex": ["编码性别符合所选测试参数", "Encoded sex matches the selected test parameter"],
  "year": [
    "编码出生年符合所选测试参数",
    "Encoded birth year matches the selected test parameter",
  ],
  "newIssuance": [
    "现行新签发分配规则符合性",
    "Conformity with current new-issuance allocation rules",
  ],
  "issuance": ["真实签发、持有人及有效状态", "Actual issuance, holder and validity"],
};
