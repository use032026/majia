import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

/// 卡片工具单例
/// 对齐 iOS: ConfigCardItemData.cardToolHandler
///
/// 提供统一的涨跌色、字体、圆角等风格常量
/// 避免在各卡片 Widget 中硬编码颜色/字体值
class CardTool {
  CardTool._();

  static const String iosDarkModeTextColorKey = 'text';
  static const String iosDarkModeTotalBgColorKey = 'totalBg';
  static const String iosDarkModeChildBgColorKey = 'childBg';
  static const String iosDarkModeThemeColorKey = 'theme';

  /// iOS STHeaderCardView / 文案次级色 `#60656D`
  static const Color iosSubtitleGrey = Color(0xFF60656D);

  /// iOS STBalanceCardView 标题 `#9A9DA2`
  static const Color iosMutedLabel = Color(0xFF9A9DA2);

  /// 列表页底色（对齐首页 UITableView / grouped 浅灰）
  static const Color iosPageBackgroundGrey = Color(0xFFF7F7F7);

  /// 行情列表涨跌色（对齐 Figma APP 白标 2.0 `2175:88242` / `2175:88560`）
  static const Color iosHqListTeal = Color(0xFF1BCC83);
  static const Color iosHqListCoral = Color(0xFFF95959);
  static const Color iosHqListPillFlat = Color(0xFF949494);
  static const Color iosHqListSubtitle = Color(0xFF9A9DA2);

  /// 列表胶囊背景（涨 / 跌 / 平；对齐 iOS `STMarketProductModel.zdfColor`，跟随涨跌色偏好）
  static Color iosHqListPillBg(num changePercent) {
    if (changePercent > 0) return priceColor(1);
    if (changePercent < 0) return priceColor(-1);
    return iosHqListPillFlat;
  }

  /// 列表迷你走势线颜色（优先按点序首尾，否则按涨跌幅）
  static Color iosHqListSparkColor(List<double> points, {num? changePercent}) {
    if (points.length >= 2) {
      final d = points.last - points.first;
      if (d > 1e-9) return priceColor(1);
      if (d < -1e-9) return priceColor(-1);
    }
    final cp = changePercent ?? 0;
    if (cp > 0) return priceColor(1);
    if (cp < 0) return priceColor(-1);
    return iosHqListPillFlat;
  }

  /// 白底上展示的涨跌幅文字色（与 [iosHqListPillBg] 涨跌判定一致，跟随涨跌色偏好）
  static Color iosHqListLegibleChangeColor(num changePercent) {
    if (changePercent > 0) return priceColor(1);
    if (changePercent < 0) return priceColor(-1);
    return iosHqListPillFlat;
  }

  /// 列表首行品种名：ASCII 交易代码则大写（对齐 STMarketListView / Selfmarket1 宫格）
  static String hqSymbolTitleLine(String symbol, String name) {
    final s = symbol.trim();
    if (s.isEmpty) return name;
    final ascii = RegExp(r'^[A-Za-z0-9./]+$').hasMatch(s);
    return ascii ? s.toUpperCase() : s;
  }

  /// 解析 `#RGB` / `#RRGGBB` / `#AARRGGBB`（对齐 ConfigCardItemData.bgColor）
  static Color? parseHexColor(String? raw, {double alpha = 1.0}) {
    if (raw == null || raw.isEmpty) return null;
    var s = raw.trim();
    if (s.startsWith('#')) s = s.substring(1);
    final aByte = (alpha.clamp(0.0, 1.0) * 255).round();

    if (s.length == 3) {
      final r = int.tryParse(s[0] + s[0], radix: 16);
      final g = int.tryParse(s[1] + s[1], radix: 16);
      final b = int.tryParse(s[2] + s[2], radix: 16);
      if (r == null || g == null || b == null) return null;
      return Color.fromARGB(aByte, r, g, b);
    }

    if (s.length == 6) {
      final v = int.tryParse(s, radix: 16);
      if (v == null) return null;
      return Color.fromARGB(aByte, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);
    }

    if (s.length == 8) {
      final v = int.tryParse(s, radix: 16);
      if (v == null) return null;
      return Color(v);
    }

    return null;
  }

  /// 对齐 iOS `UIColor+CardHex` / `STDarkModeTool` 的颜色语义。
  ///
  /// CMS 下发或卡片源码里的浅色 hex（如 `#000000`、`#FFFFFF`、`#00B57A`）
  /// 在 iOS 会按当前主题映射到 `text_1`、`childBg_2`、`theme.main` 等动态色。
  /// Flutter 端需要 BuildContext 才能读取当前 light/dark 与启动主题色，因此保留
  /// [parseHexColor] 作为纯解析，并通过本方法承载 iOS 兼容语义。
  static Color? parseAdaptiveHexColor(
    BuildContext context,
    String? raw, {
    double alpha = 1.0,
    String? category,
  }) {
    final normalized = _normalizeHex6(raw);
    if (normalized == null) return parseHexColor(raw, alpha: alpha);

    final palette = Theme.of(context).extension<AppPalette>();
    final isDark =
        palette?.isDark ?? Theme.of(context).brightness == Brightness.dark;
    final brand = palette?.brand;
    final token = _adaptiveTokenForHex(normalized, category: category);

    if (brand != null) {
      if (token != null) {
        final mapped = brand.resolveThemeColor(
          category: token.category,
          colorName: token.colorName,
          isDark: isDark,
          fallback: '#$normalized',
        );
        return parseHexColor(mapped, alpha: alpha);
      }
      if (normalized == '00B57A') {
        return parseHexColor(
          brand.resolveThemeMain(isDark: isDark),
          alpha: alpha,
        );
      }
      if (normalized == '4DCB73') {
        return parseHexColor(
          brand.resolveThemeAssist(isDark: isDark),
          alpha: alpha,
        );
      }
    }

    return parseHexColor('#$normalized', alpha: alpha);
  }

  static String? _normalizeHex6(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var s = raw.trim().toUpperCase();
    while (s.startsWith('0X')) {
      s = s.substring(2);
    }
    while (s.startsWith('#')) {
      s = s.substring(1);
    }
    if (s.length < 6) return null;
    s = s.substring(0, 6);
    if (!RegExp(r'^[0-9A-F]{6}$').hasMatch(s)) return null;
    return s;
  }

  static ({String category, String colorName})? _adaptiveTokenForHex(
    String normalizedHex, {
    String? category,
  }) {
    final scoped = category?.trim();
    final scopedToken = scoped == null || scoped.isEmpty
        ? null
        : _tokenForCategory(normalizedHex, scoped);
    if (scopedToken != null) return scopedToken;

    return _tokenForCategory(normalizedHex, iosDarkModeTextColorKey) ??
        _tokenForCategory(normalizedHex, iosDarkModeChildBgColorKey) ??
        _tokenForCategory(normalizedHex, iosDarkModeTotalBgColorKey);
  }

  static ({String category, String colorName})? _tokenForCategory(
    String normalizedHex,
    String category,
  ) {
    final colors = switch (category) {
      iosDarkModeTextColorKey => const {
        '000000': 'text_1',
        '60656D': 'text_2',
        '9A9DA2': 'text_3',
        'D9D9D9': 'text_4',
      },
      iosDarkModeTotalBgColorKey => const {
        'FFFFFF': 'totalBg_1',
        'F7F7F7': 'totalBg_2',
      },
      iosDarkModeChildBgColorKey => const {
        'ECECEC': 'childBg_ph',
        'F7F7F7': 'childBg_1',
        'FFFFFF': 'childBg_2',
      },
      _ => const <String, String>{},
    };
    final colorName = colors[normalizedHex];
    if (colorName == null) return null;
    return (category: category, colorName: colorName);
  }

  /// 总资产等金额展示（对齐 iOS HandleStringThousandth 两位小数）
  static String formatBalanceAmount(String raw) {
    if (raw.isEmpty) return '--';
    final normalized = raw.replaceAll(',', '');
    final n = double.tryParse(normalized);
    if (n == null) return raw;
    return NumberFormat('#,##0.00').format(n);
  }

  /// 按 `show_permission` 过滤宫格/列表子项（对齐 iOS `cardListItemPermissionHandler`）
  static List<Map<String, dynamic>> filterItemsByShowPermission(
    List<Map<String, dynamic>> items, {
    required bool isLoggedIn,
  }) {
    return items.where((item) {
      final perm =
          (item['show_permission'] as String? ??
                  item['showPermission'] as String? ??
                  '')
              .trim();
      if (perm == 'login' && !isLoggedIn) return false;
      if (perm == 'unlogin' && isLoggedIn) return false;
      return true;
    }).toList();
  }

  // ==================== 涨跌色（对齐 iOS UIColor.riseColor / UIColor.fallColor） ====================

  /// 涨幅颜色（iOS: `STColorManager.riseColor` 绿涨时返回 `#1BCC8A`）
  static const Color riseColor = Color(0xFF1BCC8A);

  /// 跌幅颜色（iOS: `STColorManager.fallColor` 绿涨时返回 `#F95959`）
  static const Color fallColor = Color(0xFFF95959);

  /// 涨幅背景色（浅色）
  static const Color riseBgColor = Color(0x1A1BCC8A);

  /// 跌幅背景色（浅色）
  static const Color fallBgColor = Color(0x1AF95959);

  /// 涨跌类型（0=绿涨红跌 riseGreen，1=红涨绿跌 riseRed）
  /// 从 UserState.riseAndFallType 读取后设置
  static int _riseAndFallType = 0;

  /// 设置涨跌类型（对齐 iOS: STUserInfoManager.riseAndFallType）
  static void setRiseAndFallType(int type) {
    _riseAndFallType = type;
  }

  /// 根据涨跌类型和涨跌幅返回对应的颜色
  /// - _riseAndFallType == 0 (红跌绿涨): 涨→riseColor(绿), 跌→fallColor(红)
  /// - _riseAndFallType == 1 (红涨绿跌): 涨→fallColor(红), 跌→riseColor(绿)
  static Color priceColor(num? changePercent) {
    if (changePercent == null) return Colors.black87;
    if (_riseAndFallType == 1) {
      // 红涨绿跌：上涨用 fallColor（红），下跌用 riseColor（绿）
      return changePercent >= 0 ? fallColor : riseColor;
    }
    // 默认红跌绿涨：上涨用 riseColor（绿），下跌用 fallColor（红）
    return changePercent >= 0 ? riseColor : fallColor;
  }

  /// 根据涨跌幅返回对应背景色
  static Color priceBgColor(num? changePercent) {
    if (changePercent == null) return Colors.transparent;
    if (_riseAndFallType == 1) {
      return changePercent >= 0 ? fallBgColor : riseBgColor;
    }
    return changePercent >= 0 ? riseBgColor : fallBgColor;
  }

  /// 迷你走势图描边色（对齐 iOS 行情列表：按 **走势序列** 末值相对首值判断涨跌色，与 24h 涨跌幅解耦）
  /// - `points.length >= 2`：`last > first` → 视为上行用 [priceColor] 的涨侧；`last < first` → 跌侧；持平则回退 `changePercent`
  /// - 点数不足时回退 [priceColor(changePercent)]
  static Color sparklineTrendColor(List<double> points, {num? changePercent}) {
    if (points.length >= 2) {
      final d = points.last - points.first;
      if (d > 1e-9) return priceColor(1.0);
      if (d < -1e-9) return priceColor(-1.0);
    }
    return priceColor(changePercent ?? 0);
  }

  // ==================== 常用字体 ====================

  /// 卡片标题字体（对齐 iOS Semibold 18 + `#000000`）
  static const TextStyle titleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Color(0xFF000000),
    height: 1.2,
  );

  /// 卡片副标题字体（对齐 iOS Light 12 + `#60656D`）
  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: iosSubtitleGrey,
    height: 1.25,
  );

  /// 卡片价格字体
  static const TextStyle priceStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  // ==================== 通用间距 ====================

  static const double cardInternalPadding = 16;
  static const double cardItemSpacing = 8;
}
