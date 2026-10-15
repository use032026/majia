/// 国家/地区模型（对齐 iOS `STCountryModel`）
class CountryModel {
  const CountryModel({
    required this.key,
    required this.value,
    required this.code,
    this.flagUrl = '',
    this.currencyCode = '',
    this.originalJson = const {},
  });

  final String key;
  /// 本地化展示名（对齐 iOS `value`）
  final String value;
  /// 电话区号，如 `+86`（对齐 iOS `code`）
  final String code;
  final String flagUrl;
  final String currencyCode;
  final Map<String, dynamic> originalJson;

  String get dialCode => code.startsWith('+') ? code : '+$code';

  /// 离线兜底 emoji（API `flag_url` 不可用时）
  String get flagEmoji {
    const map = {
      'CN': '🇨🇳',
      'HK': '🇭🇰',
      'TW': '🇹🇼',
      'MO': '🇲🇴',
      'SG': '🇸🇬',
      'JP': '🇯🇵',
      'KR': '🇰🇷',
      'KP': '🇰🇵',
      'US': '🇺🇸',
      'GB': '🇬🇧',
      'AU': '🇦🇺',
      'DE': '🇩🇪',
      'FR': '🇫🇷',
      'VN': '🇻🇳',
      'MN': '🇲🇳',
      'HU': '🇭🇺',
    };
    return map[key.toUpperCase()] ?? '🌐';
  }

  factory CountryModel.fromJson(Map<String, dynamic> json) {
    return CountryModel(
      key: '${json['key'] ?? ''}',
      value: '${json['value'] ?? ''}',
      code: '${json['code'] ?? ''}',
      flagUrl: '${json['flag_url'] ?? ''}',
      currencyCode: '${json['currency_code'] ?? ''}',
      originalJson: Map<String, dynamic>.from(json),
    );
  }

  static CountryModel? fromKey(String? key, List<CountryModel> all) {
    if (key == null || key.isEmpty) return null;
    for (final c in all) {
      if (c.key == key) return c;
    }
    return null;
  }

  static CountryModel? fromDialCode(String? dial, List<CountryModel> all) {
    if (dial == null || dial.isEmpty) return null;
    final normalized = dial.startsWith('+') ? dial : '+$dial';
    for (final c in all) {
      if (c.dialCode == normalized || c.code == dial) return c;
    }
    return null;
  }

  bool matchesQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return value.toLowerCase().contains(q) ||
        key.toLowerCase().contains(q) ||
        code.toLowerCase().contains(q) ||
        dialCode.toLowerCase().contains(q);
  }

  static const CountryModel china = CountryModel(
    key: 'CN',
    value: '中国',
    code: '+86',
    flagUrl: '',
  );

  static List<CountryModel> get fallbackDefaults => [
        china,
        const CountryModel(key: 'HK', value: '中国香港', code: '+852'),
        const CountryModel(key: 'TW', value: '中国台湾', code: '+886'),
        const CountryModel(key: 'SG', value: '新加坡', code: '+65'),
        const CountryModel(key: 'JP', value: '日本', code: '+81'),
        const CountryModel(key: 'KR', value: '韩国', code: '+82'),
        const CountryModel(key: 'US', value: '美国', code: '+1'),
        const CountryModel(key: 'GB', value: '英国', code: '+44'),
        const CountryModel(key: 'AU', value: '澳大利亚', code: '+61'),
      ];
}
