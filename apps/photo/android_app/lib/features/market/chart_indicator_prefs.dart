import 'package:shared_preferences/shared_preferences.dart';

import 'chart_prefs_keys.dart';

/// 主图 / 副图指标持久化与旧版「单一指标键」迁移
abstract final class ChartIndicatorPrefs {
  ChartIndicatorPrefs._();

  static const Set<String> _mainIds = {'MA', 'EMA', 'BOLL'};
  static const Set<String> _subIds = {'MACD', 'KDJ', 'RSI'};

  /// 读取主图、副图指标 id；兼容旧键 [MarketChartPrefKeys.subIndicator] 曾存放「主或副」合一的情况。
  static (String main, String sub) readMainSub(SharedPreferences sp) {
    final rawMain = sp.getString(MarketChartPrefKeys.mainIndicator);
    final rawSub = sp.getString(MarketChartPrefKeys.subIndicator);

    var mainInd = 'MA';
    var subInd = 'MACD';

    if (rawMain != null && _mainIds.contains(rawMain)) {
      mainInd = rawMain;
    }
    if (rawSub != null && _subIds.contains(rawSub)) {
      subInd = rawSub;
    }

    if (rawMain == null && rawSub != null) {
      if (_mainIds.contains(rawSub)) {
        mainInd = rawSub;
        subInd = 'MACD';
      }
    }

    return (mainInd, subInd);
  }

  static List<int> parsePeriodList(String? raw, List<int> fallback) {
    if (raw == null) {
      return List<int>.from(fallback);
    }
    if (raw.trim().isEmpty) return <int>[];
    final parts = raw.split(RegExp(r'[,，\s]+'));
    final out = <int>[];
    for (final p in parts) {
      final v = int.tryParse(p.trim());
      if (v != null && v > 0 && v < 500) out.add(v);
    }
    return out.isEmpty ? List<int>.from(fallback) : out;
  }

  /// 解析三个正整数（MACD / KDJ）
  static (int a, int b, int c) parseTriple(
    String? raw,
    (int a, int b, int c) fallback,
  ) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    final parts = raw.split(RegExp(r'[,，\s]+'));
    final nums = <int>[];
    for (final p in parts) {
      final v = int.tryParse(p.trim());
      if (v != null && v > 0 && v < 500) nums.add(v);
    }
    if (nums.length >= 3) return (nums[0], nums[1], nums[2]);
    return fallback;
  }

  static int parseSinglePeriod(String? raw, int fallback) {
    final list = parsePeriodList(raw, [fallback]);
    return list.first;
  }
}
