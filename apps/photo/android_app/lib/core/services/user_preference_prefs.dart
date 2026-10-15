import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/ios_language_catalog.dart';
import '../models/user_state.dart';

/// 用户偏好本地存储键（与 iOS `NSUserDefaults` / 登录 `data` 字段对齐）
abstract final class UserPreferencePrefs {
  UserPreferencePrefs._();

  static const String riseAndFallType = 'rise_and_fall_type';
  static const String oneKeyClose = 'one_key_close';
  static const String timezone = 'user_timezone';
  static const String iosOldTimezoneKey = 'STUserTimeZonekey';

  /// 与 iOS `STUserInfoManger` 的偏好字典 key 前缀一致。
  static const String iosPreferenceSetKey = 'STUserPreferenceSetKey';

  /// 与 iOS `STUserInfoManger` 的 `NSUserDefaults` Key 一致。
  static const String transactionAccount = 'STTransactionAccount';
  static const String transactionAccountType = 'STTransactionAccountType';
  static const String transactionAccountIsActive =
      'STTransactionAccountIsActive';

  /// Flutter 历史键（与旧版对齐）
  static const String appLanguage = 'app_language';
  static const String appLanguageName = 'app_language_name';
  static const String appLanguageManuallySelected =
      'app_language_manually_selected';

  /// 与 iOS `DarkModeKey` 一致（0=Unspecified/Auto,1=Light,2=Dark）
  static const String appDarkModeKey = 'appDarkModeKey';

  /// 兼容旧版 Flutter 持久化：只读场景保留
  static const String themeModeKey = 'theme_mode';

  /// 与 iOS `AppModeIsNewConfig` 对齐：是否启用配置化首页调试模式
  static const String appModeIsNewConfig = 'AppModeIsNewConfig';

  /// 与 iOS `STBundle` / `-[STBundle configCurrentLanguageCode:languageName:]` 写入的 Key 一致
  static const String iosLanguageCodeKey = 'STLanguageCode';
  static const String iosLanguageNameKey = 'STLanguageName';

  static String _scopedPreferenceKey(String key, String userId) {
    final id = userId.trim();
    if (id.isEmpty) return key;
    return '$iosPreferenceSetKey+$id.$key';
  }

  static String _userIdForPrefs(SharedPreferences p, String? userId) {
    final explicit = userId?.trim() ?? '';
    if (explicit.isNotEmpty) return explicit;
    return p.getString('user_id')?.trim() ?? '';
  }

  static bool _canUseLegacyPreference(
    SharedPreferences p,
    String requestedUserId,
  ) {
    if (requestedUserId.isEmpty) return true;
    return (p.getString('user_id')?.trim() ?? '') == requestedUserId;
  }

  static T? _readScopedPreference<T>(
    SharedPreferences p,
    String key, {
    String? userId,
  }) {
    final id = _userIdForPrefs(p, userId);
    final scoped = p.get(_scopedPreferenceKey(key, id));
    if (scoped is T) return scoped;
    final legacy = _canUseLegacyPreference(p, id) ? p.get(key) : null;
    if (legacy is T) return legacy;
    return null;
  }

  static Future<void> saveRiseAndFallType(int type, {String? userId}) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(
      _scopedPreferenceKey(riseAndFallType, _userIdForPrefs(p, userId)),
      type,
    );
  }

  static Future<void> saveOneKeyClose(bool value, {String? userId}) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(
      _scopedPreferenceKey(oneKeyClose, _userIdForPrefs(p, userId)),
      value,
    );
  }

  static Future<void> saveTimezone(String tz, {String? userId}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _scopedPreferenceKey(timezone, _userIdForPrefs(p, userId)),
      tz,
    );
  }

  static Future<void> saveAppLanguage(
    String code, {
    bool manuallySelected = true,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(appLanguage, code);
    await p.setString(iosLanguageCodeKey, code);
    await p.setStringList('AppleLanguages', _appleLanguagesFor(code));
    await p.setBool(appLanguageManuallySelected, manuallySelected);
  }

  static Future<void> saveAppLanguageName(String name) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(appLanguageName, name);
    await p.setString(iosLanguageNameKey, name);
  }

  static Future<String?> readAppLanguageName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(appLanguageName) ?? p.getString(iosLanguageNameKey);
  }

  static Future<int?> readRiseAndFallType({String? userId}) async {
    final p = await SharedPreferences.getInstance();
    return _readScopedPreference<int>(p, riseAndFallType, userId: userId);
  }

  static Future<bool?> readOneKeyClose({String? userId}) async {
    final p = await SharedPreferences.getInstance();
    return _readScopedPreference<bool>(p, oneKeyClose, userId: userId);
  }

  static Future<String?> readTimezone({String? userId}) async {
    final p = await SharedPreferences.getInstance();
    final current = _readScopedPreference<String>(p, timezone, userId: userId);
    if (current != null && current.isNotEmpty) return current;

    final id = _userIdForPrefs(p, userId);
    final scopedOldKey = _scopedPreferenceKey(iosOldTimezoneKey, id);
    Object? oldRaw = p.get(scopedOldKey);
    final shouldCheckLegacy = _canUseLegacyPreference(p, id);
    if (oldRaw == null && shouldCheckLegacy) {
      oldRaw = p.get(iosOldTimezoneKey);
    }
    if (oldRaw == null) return null;

    final oldHour = oldRaw is num
        ? oldRaw.toInt()
        : int.tryParse(oldRaw.toString().trim());
    final migrated = oldHour == 0 ? 'UTC+00:00' : 'UTC+08:00';
    await p.setString(_scopedPreferenceKey(timezone, id), migrated);
    await p.remove(scopedOldKey);
    if (shouldCheckLegacy) {
      await p.remove(iosOldTimezoneKey);
    }
    return migrated;
  }

  static Future<void> saveTransactionAccountSelection({
    String? account,
    String? accountType,
    String? isActive,
  }) async {
    final p = await SharedPreferences.getInstance();
    final normalizedAccount = account?.trim() ?? '';
    final normalizedType = accountType?.trim() ?? '';
    final normalizedActive = isActive?.trim() ?? '';

    if (normalizedAccount.isNotEmpty) {
      await p.setString(transactionAccount, normalizedAccount);
    }
    if (normalizedType.isNotEmpty) {
      await p.setString(transactionAccountType, normalizedType);
    }
    if (normalizedActive.isNotEmpty) {
      await p.setString(transactionAccountIsActive, normalizedActive);
    } else if (normalizedAccount.isNotEmpty || normalizedType.isNotEmpty) {
      await p.setString(transactionAccountIsActive, '-1');
    }
  }

  static Future<({String account, String accountType, String isActive})>
  readTransactionAccountSelection() async {
    final p = await SharedPreferences.getInstance();
    return (
      account: p.getString(transactionAccount) ?? '',
      accountType: p.getString(transactionAccountType) ?? '',
      isActive: p.getString(transactionAccountIsActive) ?? '',
    );
  }

  static Future<void> clearTransactionAccountSelection() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(transactionAccount);
    await p.remove(transactionAccountType);
    await p.remove(transactionAccountIsActive);
  }

  static String defaultAppLanguageForPlatformLocale(Locale locale) {
    final language = locale.languageCode.toLowerCase();
    if (language != 'zh') return 'en-US';

    final script = locale.scriptCode?.toLowerCase();
    if (script != null && script.isNotEmpty) {
      return script == 'hans' ? 'zh-Hans' : 'en-US';
    }

    final country = locale.countryCode?.toLowerCase();
    if (country == null || country.isEmpty || country == 'cn') {
      return 'zh-Hans';
    }
    return 'en-US';
  }

  static Future<String> readAppLanguage({String? fallback}) async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString(appLanguage) ?? p.getString(iosLanguageCodeKey);
    if (saved != null && saved.trim().isNotEmpty) return saved;

    final fallbackCode = fallback?.trim();
    final defaultCode = (fallbackCode != null && fallbackCode.isNotEmpty)
        ? fallbackCode
        : defaultAppLanguageForPlatformLocale(
            ui.PlatformDispatcher.instance.locale,
          );
    final canon = IosLanguageCatalog.canonicalize(defaultCode);
    await saveAppLanguage(canon, manuallySelected: false);
    return canon;
  }

  static List<String> _appleLanguagesFor(String code) {
    final normalized = code.trim();
    final lower = normalized.toLowerCase();
    if (lower == 'zh-hans' ||
        lower == 'zh' ||
        lower.startsWith('zh-hans') ||
        lower.startsWith('zh-cn')) {
      return const ['zh-Hans', 'zh', 'en'];
    }
    if (lower.startsWith('en')) {
      return const ['en', 'en-US', 'zh-Hans'];
    }
    if (normalized.isNotEmpty) {
      return [normalized, 'en'];
    }
    return const ['zh-Hans', 'en'];
  }

  static Future<int?> readAppDarkMode() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(appDarkModeKey);
  }

  static Future<void> saveAppDarkMode(int mode) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(appDarkModeKey, mode);
  }

  static Future<bool> readAppModeIsNewConfig() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(appModeIsNewConfig) ?? false;
  }

  static Future<void> saveAppModeIsNewConfig(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(appModeIsNewConfig, value);
  }

  /// 从登录/匿名 `data` 合并偏好并落盘
  static Future<void> mergeFromLoginPayload(Map<String, dynamic> data) async {
    final userId = UserState.pickString(data, ['user_id', 'userId', 'id']);

    final riseRaw = UserState.pickString(data, [
      'rise_and_fall_type',
      'riseAndFallType',
    ]);
    if (riseRaw != null && riseRaw.isNotEmpty) {
      final t = _parseRiseFallType(riseRaw);
      await saveRiseAndFallType(t, userId: userId);
    }

    if (data.containsKey('one_key_close') ||
        data.containsKey('oneKeyClose') ||
        data.containsKey('one_key_close_status')) {
      final v = UserState.parseApiBool(
        data['one_key_close'] ??
            data['oneKeyClose'] ??
            data['one_key_close_status'],
      );
      await saveOneKeyClose(v, userId: userId);
    }

    final tz = UserState.pickString(data, [
      'timezone',
      'time_zone',
      'selected_timezone',
      'user_timezone',
    ]);
    if (tz != null && tz.isNotEmpty) {
      await saveTimezone(tz, userId: userId);
    }

    final txAccount = UserState.pickString(data, [
      'transaction_account',
      'transactionAccount',
    ]);
    final txType = UserState.pickString(data, [
      'transaction_account_type',
      'transactionAccountType',
    ]);
    String? txActive;
    if (data.containsKey('is_active') && data['is_active'] != null) {
      txActive = data['is_active'].toString();
    } else if (txAccount != null || txType != null) {
      txActive = '-1';
    }
    if (txAccount != null || txType != null || txActive != null) {
      await saveTransactionAccountSelection(
        account: txAccount,
        accountType: txType,
        isActive: txActive,
      );
    }

    final langRaw = UserState.pickString(data, [
      'app_language',
      'appLanguage',
      'language_code',
      'languageCode',
      'language',
      'locale',
      'lang',
    ]);
    final langName = UserState.pickString(data, [
      'app_language_name',
      'appLanguageName',
      'language_name',
      'languageName',
      'locale_name',
      'localeName',
    ]);
    if (langRaw != null && langRaw.trim().isNotEmpty) {
      final p = await SharedPreferences.getInstance();
      final hasSavedLanguage =
          (p.getString(appLanguage)?.trim().isNotEmpty ?? false) ||
          (p.getString(iosLanguageCodeKey)?.trim().isNotEmpty ?? false);
      if (hasSavedLanguage || p.getBool(appLanguageManuallySelected) == true) {
        return;
      }
      final canon = IosLanguageCatalog.canonicalize(langRaw.trim());
      await saveAppLanguage(canon, manuallySelected: false);
      if (langName != null && langName.trim().isNotEmpty) {
        await saveAppLanguageName(langName.trim());
      }
    }
  }

  static int _parseRiseFallType(String raw) {
    final s = raw.trim();
    final n = int.tryParse(s);
    if (n != null && (n == 0 || n == 1)) return n;
    return RiseAndFallType.fromString(s);
  }
}

/// 涨跌类型 ↔ 接口字符串（对齐 iOS `riseGreen` / `riseRed`）
abstract final class RiseAndFallApi {
  RiseAndFallApi._();

  static String toApiValue(int type) =>
      type == RiseAndFallType.riseRed ? 'riseRed' : 'riseGreen';

  static int fromApiValue(dynamic raw) {
    if (raw == null) return RiseAndFallType.riseGreen;
    if (raw is num) {
      return raw.toInt() == 1
          ? RiseAndFallType.riseRed
          : RiseAndFallType.riseGreen;
    }
    final s = raw.toString().trim();
    final n = int.tryParse(s);
    if (n == 1) return RiseAndFallType.riseRed;
    if (n == 0) return RiseAndFallType.riseGreen;
    return RiseAndFallType.fromString(s);
  }
}

/// 语言 code → `Locale`（与 iOS / [IosLanguageCatalog] 一致）
Locale localeFromLanguageCode(String code) {
  try {
    return IosLanguageCatalog.localeFromStored(code);
  } catch (_) {
    return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
  }
}

/// `Locale` → 请求头 / 存储 code
String languageCodeFromLocale(Locale locale) {
  if (locale.languageCode == 'zh') {
    if (locale.scriptCode == 'Hans') return 'zh-Hans';
    if (locale.scriptCode == 'Hant' || locale.countryCode == 'TW') {
      return 'zh-TW';
    }
    return 'zh-Hans';
  }
  if (locale.languageCode == 'en' && locale.countryCode == 'US') {
    return 'en-US';
  }
  if (locale.countryCode != null &&
      locale.countryCode!.isNotEmpty &&
      locale.countryCode!.length <= 3) {
    return '${locale.languageCode}-${locale.countryCode}';
  }
  return locale.languageCode;
}
