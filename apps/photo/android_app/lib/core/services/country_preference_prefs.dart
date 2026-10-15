import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/country_model.dart';

/// 对齐 iOS `STUserCurrentCountryKey` + userId 缓存用户国家 JSON
abstract final class CountryPreferencePrefs {
  CountryPreferencePrefs._();

  static const String keyPrefix = 'STUserCurrentCountryKey';

  static String _storageKey(String userId) => '$keyPrefix+$userId';

  static Future<CountryModel?> read(String userId) async {
    if (userId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        return CountryModel.fromJson(json);
      }
      if (json is Map) {
        return CountryModel.fromJson(Map<String, dynamic>.from(json));
      }
    } catch (_) {}
    return null;
  }

  static Future<void> save(String userId, CountryModel model) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final payload = model.originalJson.isNotEmpty
        ? model.originalJson
        : {
            'key': model.key,
            'value': model.value,
            'code': model.code,
            'flag_url': model.flagUrl,
            'currency_code': model.currencyCode,
          };
    await prefs.setString(_storageKey(userId), jsonEncode(payload));
  }

  static Future<void> clear(String userId) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey(userId));
  }
}
