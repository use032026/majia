import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 行情列表 UI 开关（与 iOS `STMarketManager` / `STMarketDefine.h` 同源）。
abstract final class MarketListUiPrefs {
  MarketListUiPrefs._();

  static const String kListKlineKey = 'STMarketListKlineSwitch';
  static const String kListStyleKey = 'STMarketListStyleSwitch';
  static const String kListSortKey = 'STMarketListRiseFallSort';
  static const String _legacyListKlineKey = 'CmsMarketListKlineSwitch';
  static const String _legacyListStyleKey = 'CmsMarketListStyleSwitch';

  static final ValueNotifier<bool?> listKlineSwitchChanges =
      ValueNotifier<bool?>(null);
  static final ValueNotifier<bool?> listStyleSwitchChanges =
      ValueNotifier<bool?>(null);

  /// iOS `STMarketDefine`：`OrderDefault` / `OrderDesce` / `OrderAsce`
  static const String sortDefault = 'OrderDefault';
  static const String sortDesce = 'OrderDesce';
  static const String sortAsce = 'OrderAsce';

  static Future<bool> readListKlineSwitch() async {
    final p = await SharedPreferences.getInstance();
    if (!p.containsKey(kListKlineKey) && p.containsKey(_legacyListKlineKey)) {
      final legacy = p.getBool(_legacyListKlineKey) ?? true;
      await p.setBool(kListKlineKey, legacy);
      listKlineSwitchChanges.value = legacy;
      return legacy;
    }
    final value = p.getBool(kListKlineKey) ?? true;
    listKlineSwitchChanges.value = value;
    return value;
  }

  static Future<void> writeListKlineSwitch(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(kListKlineKey, value);
    listKlineSwitchChanges.value = value;
  }

  /// 返回 Flutter UI 语义：`false`=涨跌幅列表，`true`=买卖价列表。
  ///
  /// iOS `STMarketManager.listStyleSwitch` 的存储语义与按钮选中态相反：
  /// `true` 为默认涨跌幅样式，`false` 为买卖价样式。
  static Future<bool> readListStyleSwitch() async {
    final p = await SharedPreferences.getInstance();
    if (!p.containsKey(kListStyleKey) && p.containsKey(_legacyListStyleKey)) {
      final legacyShowBuySell = p.getBool(_legacyListStyleKey) ?? false;
      await p.setBool(kListStyleKey, !legacyShowBuySell);
      listStyleSwitchChanges.value = legacyShowBuySell;
      return legacyShowBuySell;
    }
    final iosValue = p.getBool(kListStyleKey) ?? true;
    final showBuySell = !iosValue;
    listStyleSwitchChanges.value = showBuySell;
    return showBuySell;
  }

  static Future<void> writeListStyleSwitch(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(kListStyleKey, !value);
    listStyleSwitchChanges.value = value;
  }

  static Future<String> readListSortOrder() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(kListSortKey) ?? sortDefault;
  }

  static Future<void> writeListSortOrder(String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(kListSortKey, value);
  }

  static String cycleSortOrder(String current) {
    if (current == sortDefault) return sortDesce;
    if (current == sortDesce) return sortAsce;
    return sortDefault;
  }
}
