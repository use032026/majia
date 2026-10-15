import 'package:flutter/foundation.dart' show kProfileMode, kReleaseMode;

enum AppBuildMode { debug, profile, release }

/// 多品牌白标配置模型
/// 对齐 iOS 的 EditInfo/ + apply_config.sh 机制
class BrandConfig {
  static const String _defaultThemeKey = 'normal';
  final String brandKey; // jufu / jingcheng / futren
  final String apiDomainRelease;
  final String apiDomainProfile;
  final String apiDomainDebug;

  /// H5 根域名（兜底拼接；与 iOS Debug/Release 环境一致）
  final String h5DomainRelease;
  final String h5DomainProfile;
  final String h5DomainDebug;
  final String packageNameRelease;
  final String packageNameProfile;
  final String packageNameDebug;
  final String appNameEn;
  final String appNameZh;
  final String themeMain;
  final String themeAssist;
  final Map<String, String> lightColors;
  final Map<String, String> darkColors;
  final String riseColor;
  final String fallColor;
  final String equalColor;
  final List<String> enabledCards; // 卡片白名单
  /// iOS `STAPPStartThemeKey` 动态主题数据，结构：`<themeName>/<category>/<colorName> -> hex`
  final Map<String, Map<String, Map<String, String>>> startupThemeData;

  /// iOS `STAPPStartCurrentThemeKey`
  final String currentThemeKey;

  /// 对齐 iOS Info.plist `CMSDefaultCountry`
  final String defaultCountryCode;

  const BrandConfig({
    required this.brandKey,
    required this.apiDomainRelease,
    required this.apiDomainProfile,
    required this.apiDomainDebug,
    required this.h5DomainRelease,
    required this.h5DomainProfile,
    required this.h5DomainDebug,
    required this.packageNameRelease,
    required this.packageNameProfile,
    required this.packageNameDebug,
    required this.appNameEn,
    required this.appNameZh,
    required this.themeMain,
    required this.themeAssist,
    required this.lightColors,
    required this.darkColors,
    required this.riseColor,
    required this.fallColor,
    required this.equalColor,
    required this.enabledCards,
    required this.startupThemeData,
    required this.currentThemeKey,
    this.defaultCountryCode = 'ID',
  });

  /// 默认聚富品牌配置（从 EditInfo/iOS_jufu/config.json 转换而来）
  /// API / 上传：Debug/Profile/Release 均使用正式域名 `api-x.myjufu.com`。
  /// H5：Debug/Profile/Release 均使用正式域名 `h5.myjufu.com`。
  factory BrandConfig.jufu() {
    return const BrandConfig(
      brandKey: 'jufu',
      apiDomainRelease: 'https://api-x.myjufu.com',
      apiDomainProfile: 'https://api-x.myjufu.com',
      apiDomainDebug: 'https://api-x.myjufu.com',
      h5DomainRelease: 'https://h5.myjufu.com',
      h5DomainProfile: 'https://h5.myjufu.com',
      h5DomainDebug: 'https://h5.myjufu.com',
      packageNameRelease: 'com.jufu.lite',
      packageNameProfile: 'com.jufu.lite',
      packageNameDebug: 'com.jufu.lite',
      appNameEn: 'Jufu',
      appNameZh: '聚富',
      themeMain: '#00B57A',
      themeAssist: '#475569',
      lightColors: {
        'text_1': '#000000',
        'text_2': '#60656D',
        'text_3': '#9A9DA2',
        'text_4': '#D9D9D9',
        'totalBg_1': '#FFFFFF',
        'totalBg_2': '#F7F7F7',
        'childBg_ph': '#ECECEC',
        'childBg_1': '#F7F7F7',
        'childBg_2': '#FFFFFF',
      },
      darkColors: {
        'text_1': '#EDF1F8',
        'text_2': '#ABAFB7',
        'text_3': '#6E727D',
        'text_4': '#424553',
        'totalBg_1': '#18191A',
        'totalBg_2': '#18191A',
        'childBg_ph': '#2F3340',
        'childBg_1': '#212229',
        'childBg_2': '#212229',
      },
      riseColor: '#FF5177',
      fallColor: '#00C2B8',
      equalColor: '#9A9DA2',
      enabledCards: [
        'account_3',
        'ad_1',
        'banner_1',
        'grid_1',
        'header_4',
        'list_1',
        'vip_3',
        'unlock_2',
        'horse_3',
        'slip_1',
        'market_7',
        'button_1',
        'selfmarket_2',
        'category_1',
        'categorymarket_2',
        'nav_1',
        'tabnav_1',
        'tradehome_1',
      ],
      startupThemeData: {
        'normal': {
          'text': {
            'text_1': '#000000',
            'text_2': '#60656D',
            'text_3': '#9A9DA2',
            'text_4': '#D9D9D9',
          },
          'totalBg': {'totalBg_1': '#FFFFFF', 'totalBg_2': '#F7F7F7'},
          'childBg': {
            'childBg_ph': '#ECECEC',
            'childBg_1': '#F7F7F7',
            'childBg_2': '#FFFFFF',
          },
        },
        'normal_dark': {
          'text': {
            'text_1': '#EDF1F8',
            'text_2': '#ABAFB7',
            'text_3': '#6E727D',
            'text_4': '#424553',
          },
          'totalBg': {'totalBg_1': '#18191A', 'totalBg_2': '#18191A'},
          'childBg': {
            'childBg_ph': '#2F3340',
            'childBg_1': '#212229',
            'childBg_2': '#212229',
          },
        },
        'normal_theme': {
          'theme': {'main': '#00B57A', 'assist': '#4DCB73'},
        },
      },
      currentThemeKey: _defaultThemeKey,
      defaultCountryCode: 'ID',
    );
  }

  static AppBuildMode get currentBuildMode {
    if (kReleaseMode) return AppBuildMode.release;
    if (kProfileMode) return AppBuildMode.profile;
    return AppBuildMode.debug;
  }

  String apiBaseUrlFor(AppBuildMode mode) {
    return switch (mode) {
      AppBuildMode.release => apiDomainRelease,
      AppBuildMode.profile => apiDomainProfile,
      AppBuildMode.debug => apiDomainDebug,
    }.trim();
  }

  String h5BaseUrlFor(AppBuildMode mode) {
    return switch (mode) {
      AppBuildMode.release => h5DomainRelease,
      AppBuildMode.profile => h5DomainProfile,
      AppBuildMode.debug => h5DomainDebug,
    }.trim();
  }

  String packageNameFor(AppBuildMode mode) {
    return switch (mode) {
      AppBuildMode.release => packageNameRelease,
      AppBuildMode.profile => packageNameProfile,
      AppBuildMode.debug => packageNameDebug,
    }.trim();
  }

  /// 当前编译模式下的 API 根 URL（无尾斜杠）
  String get apiBaseUrlForBuildMode => apiBaseUrlFor(currentBuildMode);

  /// 当前编译模式下的 H5 根 URL（无尾斜杠；兜底页拼接用）
  String get h5BaseUrlForBuildMode => h5BaseUrlFor(currentBuildMode);

  /// 当前编译模式下的业务包名（对齐 iOS `STRequestHeaderPkgName`）。
  String get packageNameForBuildMode => packageNameFor(currentBuildMode);

  /// Header /「我的」访客副标题：欢迎来到{中文品牌}投资（对齐 iOS 未登录文案）
  String get guestInvestWelcomeLine {
    final zh = appNameZh.trim();
    if (zh.isEmpty) return '欢迎体验';
    return '欢迎来到$zh投资';
  }

  /// 从 JSON 加载（未来支持动态配置）
  factory BrandConfig.fromJson(Map<String, dynamic> json) {
    final startupThemeData = _coerceStartupThemeData(
      json['startupThemeData'] ??
          json['startup_theme_data'] ??
          json['STAPPStartThemeKey'],
    );

    return BrandConfig(
      brandKey: json['brandKey'] ?? 'jufu',
      apiDomainRelease: json['API_domain_Release'] ?? '',
      apiDomainProfile:
          json['API_domain_Profile'] ??
          json['api_domain_profile'] ??
          json['apiDomainProfile'] ??
          json['API_domain_Release'] ??
          json['api_domain_release'] ??
          json['apiDomainRelease'] ??
          '',
      apiDomainDebug:
          json['API_domain_Release'] ??
          json['api_domain_release'] ??
          json['apiDomainRelease'] ??
          '',
      h5DomainRelease:
          json['H5_domain_Release'] ??
          json['h5_domain_release'] ??
          json['h5DomainRelease'] ??
          '',
      h5DomainProfile:
          json['H5_domain_Profile'] ??
          json['h5_domain_profile'] ??
          json['h5DomainProfile'] ??
          json['H5_domain_Release'] ??
          json['h5_domain_release'] ??
          json['h5DomainRelease'] ??
          '',
      h5DomainDebug:
          json['H5_domain_Release'] ??
          json['h5_domain_release'] ??
          json['h5DomainRelease'] ??
          '',
      packageNameRelease:
          json['packageNameRelease'] ??
          json['pkgNameRelease'] ??
          json['STRequestHeaderPkgName_Release'] ??
          'com.jufu.lite',
      packageNameProfile:
          json['packageNameProfile'] ??
          json['pkgNameProfile'] ??
          json['STRequestHeaderPkgName_Profile'] ??
          json['packageNameRelease'] ??
          json['pkgNameRelease'] ??
          json['STRequestHeaderPkgName_Release'] ??
          'com.jufu.lite',
      packageNameDebug:
          json['packageNameRelease'] ??
          json['pkgNameRelease'] ??
          json['STRequestHeaderPkgName_Release'] ??
          'com.jufu.lite',
      appNameEn: json['AppName_en'] ?? 'Jufu',
      appNameZh: json['AppName_zh'] ?? '聚富',
      themeMain: json['ThemeColor_main'] ?? '#00B57A',
      themeAssist: json['ThemeColor_assist'] ?? '#475569',
      lightColors: Map<String, String>.from(json['light'] ?? {}),
      darkColors: Map<String, String>.from(json['dark'] ?? {}),
      riseColor: json['RiseColor_red'] ?? '#FF5177',
      fallColor: json['RiseColor_green'] ?? '#00C2B8',
      equalColor: json['EqualColor'] ?? '#9A9DA2',
      enabledCards: List<String>.from(json['Cards'] ?? []),
      startupThemeData: startupThemeData,
      currentThemeKey:
          _normalizeThemeKey(
            json['currentThemeKey'] ??
                json['current_theme'] ??
                json['STAPPStartCurrentThemeKey'],
          ) ??
          _defaultThemeKey,
      defaultCountryCode:
          json['CMSDefaultCountry']?.toString() ??
          json['defaultCountryCode']?.toString() ??
          'ID',
    );
  }

  static Map<String, Map<String, Map<String, String>>> _coerceStartupThemeData(
    dynamic raw,
  ) {
    if (raw is! Map) return const {};
    final result = <String, Map<String, Map<String, String>>>{};
    raw.forEach((rawThemeKey, rawThemeValue) {
      if (rawThemeKey is! String) return;
      final themeName = rawThemeKey.trim();
      if (themeName.isEmpty || rawThemeValue is! Map) return;

      final categoryMap = <String, Map<String, String>>{};
      for (final entry in rawThemeValue.entries) {
        final category = entry.key;
        final values = entry.value;
        if (category is! String || category.trim().isEmpty || values is! Map) {
          continue;
        }
        final mappedValues = <String, String>{};
        for (final color in values.entries) {
          final colorName = color.key;
          final colorValue = color.value;
          if (colorName is! String ||
              colorName.trim().isEmpty ||
              colorValue == null) {
            continue;
          }
          final value = colorValue.toString();
          if (value.isNotEmpty) {
            mappedValues[colorName.trim()] = value;
          }
        }
        if (mappedValues.isNotEmpty) {
          categoryMap[category.trim()] = mappedValues;
        }
      }
      if (categoryMap.isNotEmpty) {
        result[themeName] = categoryMap;
      }
    });
    return result;
  }

  BrandConfig withStartupThemeData({
    required Map<String, Map<String, Map<String, String>>> startupThemeData,
    String? currentThemeKey,
  }) {
    return BrandConfig(
      brandKey: brandKey,
      apiDomainRelease: apiDomainRelease,
      apiDomainProfile: apiDomainProfile,
      apiDomainDebug: apiDomainDebug,
      h5DomainRelease: h5DomainRelease,
      h5DomainProfile: h5DomainProfile,
      h5DomainDebug: h5DomainDebug,
      packageNameRelease: packageNameRelease,
      packageNameProfile: packageNameProfile,
      packageNameDebug: packageNameDebug,
      appNameEn: appNameEn,
      appNameZh: appNameZh,
      themeMain: themeMain,
      themeAssist: themeAssist,
      lightColors: lightColors,
      darkColors: darkColors,
      riseColor: riseColor,
      fallColor: fallColor,
      equalColor: equalColor,
      enabledCards: enabledCards,
      startupThemeData: startupThemeData,
      currentThemeKey:
          _normalizeThemeKey(currentThemeKey) ?? this.currentThemeKey,
      defaultCountryCode: defaultCountryCode,
    );
  }

  static String? _normalizeThemeKey(String? key) {
    if (key == null) return null;
    final t = key.trim();
    if (t.isEmpty) return null;
    return t;
  }

  String get effectiveThemeKey =>
      _normalizeThemeKey(currentThemeKey) ?? _defaultThemeKey;

  String _themeKeyForMode(bool isDark) {
    final base = effectiveThemeKey;
    if (isDark && startupThemeData.containsKey('${base}_dark')) {
      return '${base}_dark';
    }
    if (startupThemeData.containsKey(base)) {
      return base;
    }
    if (isDark && startupThemeData.containsKey('${_defaultThemeKey}_dark')) {
      return '${_defaultThemeKey}_dark';
    }
    return _defaultThemeKey;
  }

  String _themeKeyForThemeCategory(bool isDark) {
    final base = effectiveThemeKey;
    final keyByTheme = '${base}_theme';
    if (startupThemeData.containsKey(keyByTheme)) {
      return keyByTheme;
    }
    if (startupThemeData.containsKey('${_defaultThemeKey}_theme')) {
      return '${_defaultThemeKey}_theme';
    }
    return 'normal_theme';
  }

  String _resolveThemeCategoryColor({
    required String category,
    required String colorName,
    required bool isDark,
    required String fallback,
  }) {
    final themeKey = _themeKeyForThemeCategory(isDark);
    final themedValue = startupThemeData[themeKey]?[category]?[colorName];
    if (themedValue != null && themedValue.isNotEmpty) {
      return themedValue;
    }
    return _resolveModeColor(
      category: category,
      colorName: colorName,
      isDark: isDark,
      fallback: fallback,
    );
  }

  String _resolveModeColor({
    required String category,
    required String colorName,
    required bool isDark,
    required String fallback,
  }) {
    final modeKey = _themeKeyForMode(isDark);
    final modeValue = startupThemeData[modeKey]?[category]?[colorName];
    if (modeValue != null && modeValue.isNotEmpty) {
      return modeValue;
    }
    return fallback;
  }

  String resolveThemeMain({required bool isDark}) {
    return _resolveThemeCategoryColor(
      category: 'theme',
      colorName: 'main',
      isDark: isDark,
      fallback: themeMain,
    );
  }

  String resolveThemeAssist({required bool isDark}) {
    return _resolveThemeCategoryColor(
      category: 'theme',
      colorName: 'assist',
      isDark: isDark,
      fallback: themeAssist,
    );
  }

  String resolveThemeColor({
    required String category,
    required String colorName,
    required bool isDark,
    required String fallback,
  }) {
    return _resolveModeColor(
      category: category,
      colorName: colorName,
      isDark: isDark,
      fallback: fallback,
    );
  }

  Map<String, String> resolveColorPalette({required bool isDark}) {
    final fallback = isDark ? darkColors : lightColors;
    final themeKey = _themeKeyForMode(isDark);
    final theme = startupThemeData[themeKey] ?? {};

    final textColors = theme['text'] ?? {};
    final totalBg = theme['totalBg'] ?? {};
    final childBg = theme['childBg'] ?? {};

    return {...fallback, ...textColors, ...totalBg, ...childBg};
  }
}
