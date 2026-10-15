import 'package:flutter/material.dart';

/// 与应用 **iOS 原生端**保持一致的语言常量表。
///
/// - **运行时列表数据**以 violet `GET /api/account/languages/available`（`data.languages`）
///   为准，Flutter 与该接口对齐；本类提供 **canonical、排序权重、离线兜底文案**，
///   与 iOS 在接口失败或未返回时的兜底行为一致。
abstract final class IosLanguageCatalog {
  IosLanguageCatalog._();

  /// （后端 / 老版本字段）别名 → canonical `code`
  static const Map<String, String> aliases = <String, String>{
    'en': 'en-US',
    'en_GB': 'en-US',
    'en-US': 'en-US',
    'en_us': 'en-US',
    'zh': 'zh-Hans',
    'zh-CN': 'zh-Hans',
    'zh_cn': 'zh-Hans',
    'zh_TW': 'zh-TW',
    'zh-Hant': 'zh-TW',
    'zh_Hant': 'zh-TW',
    'ko': 'ko-KR',
    'es': 'es-ES',
    'pt': 'pt-PT',
    'pt_BR': 'pt-PT',
    'pt-BR': 'pt-PT',
    'ru': 'ru-RU',
    'vi': 'vi-VN',
    'ar': 'ar-SA',
    'fil': 'fil-PH',
    'tl': 'fil-PH',
    'tl-PH': 'fil-PH',
    'fr': 'fr-FR',
    'th': 'th-TH',
    'id': 'id-ID',
    'tr': 'tr-TR',
    'ms': 'ms-MY',
  };

  static String canonicalize(String raw) {
    final k = raw.trim();
    return aliases[k] ?? k;
  }

  /// 与 iOS 客户端默认排序一致（接口未给出 `sort`/`order` 时按此升序）。
  static int sortIndex(String canonCode) {
    for (var i = 0; i < orderedRows.length; i++) {
      if (orderedRows[i].$1 == canonCode) return i;
    }
    return 1 << 20;
  }

  /// 离线 / 接口异常时的兜底顺序与简体中文展示名。
  /// 末尾保留 `ug`（维吾尔语）以兼容存量用户。
  static final List<(String code, String displayNameZh)> orderedRows =
      <(String, String)>[
        ('ko-KR', '韩语（韩国）'),
        ('id-ID', '印度尼西亚语（印度尼西亚）'),
        ('tr-TR', '土耳其语（土耳其）'),
        ('fil-PH', '菲律宾语（菲律宾）'),
        ('vi-VN', '越南语（越南）'),
        ('ru-RU', '俄语（俄罗斯）'),
        ('ar-SA', '阿拉伯语（沙特阿拉伯）'),
        ('es-ES', '欧洲西班牙语'),
        ('fr-FR', '法语（法国）'),
        ('pt-PT', '欧洲葡萄牙语'),
        ('ms-MY', '马来语（马来西亚）'),
        ('zh-TW', '繁体中文'),
        ('th-TH', '泰语（泰国）'),
        ('en-US', '美国英语'),
        ('zh-Hans', '简体中文'),
        ('ug', '维吾尔语'),
      ];

  static const Map<String, String> _displayNamesEn = <String, String>{
    'ko-KR': 'Korean (South Korea)',
    'id-ID': 'Indonesian (Indonesia)',
    'tr-TR': 'Turkish (Turkey)',
    'fil-PH': 'Filipino (Philippines)',
    'vi-VN': 'Vietnamese (Vietnam)',
    'ru-RU': 'Russian (Russia)',
    'ar-SA': 'Arabic (Saudi Arabia)',
    'es-ES': 'European Spanish',
    'fr-FR': 'French (France)',
    'pt-PT': 'European Portuguese',
    'ms-MY': 'Malay (Malaysia)',
    'zh-TW': 'Traditional Chinese',
    'th-TH': 'Thai (Thailand)',
    'en-US': 'American English',
    'zh-Hans': 'Simplified Chinese',
    'ug': 'Uyghur',
  };

  /// `MaterialApp` 需覆盖列表内全部语言以便切换（无 ARB 时仍走 delegate fallback）
  static List<Locale> supportedMaterialLocales() {
    return orderedRows.map((e) => localeFromCode(e.$1)).toList();
  }

  static Locale localeFromCode(String canonicalCode) {
    switch (canonicalCode) {
      case 'zh-Hans':
        return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
      case 'zh-TW':
        return const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
          countryCode: 'TW',
        );
      case 'en-US':
        return const Locale('en', 'US');
      case 'ko-KR':
        return const Locale('ko', 'KR');
      case 'id-ID':
        return const Locale('id', 'ID');
      case 'tr-TR':
        return const Locale('tr', 'TR');
      case 'fil-PH':
        return const Locale('fil');
      case 'vi-VN':
        return const Locale('vi', 'VN');
      case 'ru-RU':
        return const Locale('ru', 'RU');
      case 'ar-SA':
        return const Locale('ar', 'SA');
      case 'es-ES':
        return const Locale('es', 'ES');
      case 'fr-FR':
        return const Locale('fr', 'FR');
      case 'pt-PT':
        return const Locale('pt', 'PT');
      case 'ms-MY':
        return const Locale('ms', 'MY');
      case 'th-TH':
        return const Locale('th', 'TH');
      case 'ug':
        return const Locale('ug');
      default:
        return _localeFromLooseTag(canonicalCode);
    }
  }

  /// 接口可能返回暂未列入 [orderedRows] 的 tag（与新语言同步时）。
  static Locale _localeFromLooseTag(String tag) {
    final normalized = tag.trim().replaceAll('_', '-');
    if (normalized.isEmpty) {
      return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
    }

    final parts = normalized.split('-').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) {
      return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
    }

    final language = parts[0].toLowerCase();
    if (parts.length == 1) return Locale(language);

    final second = parts[1];

    // 形如 en-US / ar-SA / xxx-XXX（3 字母区域亦偶见）
    if (second.length == 2 ||
        (second.length == 3 && RegExp(r'^[A-Za-z]{3}$').hasMatch(second))) {
      final region = second.toUpperCase();
      return Locale.fromSubtags(languageCode: language, countryCode: region);
    }

    // 形如 zh-hans（大小写不拘）
    if (second.length == 4 && RegExp(r'^[A-Za-z]{4}$').hasMatch(second)) {
      final script =
          '${second[0].toUpperCase()}${second.substring(1).toLowerCase()}';

      final third = parts.length >= 3 ? parts[2] : null;
      String? cc;
      if (third != null && (third.length == 2 || third.length == 3)) {
        cc = third.toUpperCase();
      }

      return Locale.fromSubtags(
        languageCode: language,
        scriptCode: script,
        countryCode: cc,
      );
    }

    return Locale(language);
  }

  /// 偏好 / 路由层：存储 code → `Locale`
  static Locale localeFromStored(String code) =>
      localeFromCode(canonicalize(code));

  /// 设置主页「偏好」里展示用（简体中文 / 韩语…）
  static String displayLabelZh(String storedOrRawCode) {
    final c = canonicalize(storedOrRawCode.trim());
    for (final row in orderedRows) {
      if (row.$1 == c) return row.$2;
    }
    return storedOrRawCode.trim();
  }

  static String displayLabelForUiLanguage(
    String storedOrRawCode, {
    required String currentLanguageCode,
    String? fallbackLabel,
  }) {
    final c = canonicalize(storedOrRawCode.trim());
    final current = canonicalize(currentLanguageCode.trim());
    if (_isEnglish(current)) {
      return _displayNamesEn[c] ?? fallbackLabel?.trim() ?? storedOrRawCode;
    }
    if (_isChinese(current)) {
      return displayLabelZh(c);
    }
    final fallback = fallbackLabel?.trim();
    return (fallback != null && fallback.isNotEmpty)
        ? fallback
        : displayLabelZh(c);
  }

  static bool _isEnglish(String code) {
    final lower = code.toLowerCase();
    return lower == 'en' || lower.startsWith('en-');
  }

  static bool _isChinese(String code) {
    final lower = code.toLowerCase();
    return lower == 'zh' || lower.startsWith('zh-') || lower.startsWith('zh_');
  }
}
