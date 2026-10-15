import '../../core/models/tab_bar_item.dart';
import '../../core/network/st_service.dart';
import 'package:jufu/shared/widgets/st_localized_prompt.dart';

/// 行情子类目（商品 / 指数 / 外汇…）数据来源说明（对齐 MediaServiceClient）：
///
/// 1. **CMS 卡片 `category_*`**：`payload.items[]` 每项含 **`symbol_group`**（NSInteger）与 **`title`**
///    （见 `CategoryModel.m` / `CategoryItemModel -initWithDic:`，字段 `symbol_group`、`title`）。
/// 2. **原生行情页 `STMarketHqController`**：未走 CMS 时使用本地 **`STMarketRankType`** 数组（`rankTypes`）
///    与本地化标题。当前 iOS 壳页固定顺序为：
///    - 非 B 端：商品 / 指数 / 外汇 / 加密
///    - B 端：商品 / 指数 / 外汇
/// 3. **列表请求**：`requestProductListWithRankType:` → `get_symbols_data`，查询参数里的 **`symbol_group`**
///    由 rankType 映射（与 [`symbolGroupParam`] / `STService+Market` 一致）。
///
/// 筛选逻辑：选中 Tab → [`ConfigDataManager.selectedCategorySymbolGroup`] → [`CategoryMarketListPage.rankType`]
/// → [`CardFactory.loadMarketTabCategoryProducts`] → HTTP **`symbol_group`** = rankType。
class MarketCategoryTab {
  final String label;

  /// 与 iOS `STMarketRankType` 数值一致
  final int symbolGroup;

  /// iOS JSON localization key for native fixed market tabs.
  final String? localizationKey;

  const MarketCategoryTab({
    required this.label,
    required this.symbolGroup,
    this.localizationKey,
  });
}

/// 解析 Tab `cardItems`、兜底子类目与 B 面裁剪，供 [MarketTabShellPage] 使用。
abstract final class MarketTabShellConfig {
  MarketTabShellConfig._();

  /// 无标题时的中文兜底（Figma 行情页文案）
  static String defaultTitleForSymbolGroup(int group) {
    switch (group) {
      case 0:
        return '热门';
      case 1:
        return '外汇';
      case 2:
        return '商品';
      case 3:
        return '股票';
      case 4:
        return '加密';
      case 5:
        return '指数';
      case 6:
        return '金属';
      case 7:
        return '美国股票';
      case 8:
        return '香港股票';
      default:
        return '分类';
    }
  }

  static String? localizationKeyForSymbolGroup(int group) {
    switch (group) {
      case 1:
        return 'foreign_exchange';
      case 2:
        return 'goods';
      case 4:
        return 'encryption';
      case 5:
        return 'index_number';
      default:
        return null;
    }
  }

  static int _sortOrder(Map<String, dynamic> m) {
    final v = m['sort'] ?? m['order'] ?? m['sort_order'] ?? m['position'];
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }

  static int? _parseSymbolGroup(Map<String, dynamic> m) {
    final g =
        m['symbol_group'] ??
        m['symbolGroup'] ??
        m['rank_type'] ??
        m['rankType'] ??
        m['group_id'] ??
        m['groupId'] ??
        m['group'];
    if (g != null) {
      if (g is int) return g;
      final p = int.tryParse(g.toString());
      if (p != null) return p;
    }
    final idRaw = m['id'];
    if (idRaw is int && idRaw >= 0 && idRaw <= 8) return idRaw;
    if (idRaw != null) {
      final ip = int.tryParse('$idRaw');
      if (ip != null && ip >= 0 && ip <= 8) return ip;
    }
    return null;
  }

  /// 单条 `category_*` 卡片 `items[]` 上的分组 id（与 iOS `CategoryItemModel` 多键一致；无效为 -1）
  static int categoryItemSymbolGroup(Map<String, dynamic> m) =>
      _parseSymbolGroup(m) ?? -1;

  static String _parseTitle(Map<String, dynamic> m, int symbolGroup) {
    final raw = m['title'] ?? m['name'] ?? m['label'] ?? m['group_name'];
    final s = raw?.toString().trim() ?? '';
    if (s.isNotEmpty) return s;
    return defaultTitleForSymbolGroup(symbolGroup);
  }

  /// 从 `cardDetail` / payload 取类目条目（对齐 `CategoryModel.m` 的 `items`，兼容易错键名）
  static List<dynamic>? _itemsFromCardDetail(Map<String, dynamic>? detail) {
    if (detail == null) return null;

    List<dynamic>? pick(Map<String, dynamic> d) {
      for (final k in const ['items', 'list', 'tabs', 'groups']) {
        final v = d[k];
        if (v is List && v.isNotEmpty) return v;
      }
      return null;
    }

    final top = pick(detail);
    if (top != null) return top;
    final cat = detail['category'];
    if (cat is Map<String, dynamic>) {
      final nested = pick(Map<String, dynamic>.from(cat));
      if (nested != null) return nested;
    }
    return null;
  }

  /// `category_` 横向类目（对齐 `ConfigDefine.h` Card_Style_Category）；排除 `categorymarket_`
  static bool _isCategoryTabCardStyle(String cardStyle) {
    final s = cardStyle.trim().toLowerCase();
    if (s.startsWith('categorymarket')) return false;
    if (s.startsWith('category_')) return true;
    // 少数配置写作 category1 / category2
    return RegExp(r'^category\d').hasMatch(s);
  }

  /// 合并 **所有** `category_*` 卡片的 items，按 `symbol_group` 去重（保留首次出现顺序）。
  /// 不因 `isShow == false` 跳过——Tab `cardItems` 中的类目配置常与首页卡片显隐独立。
  static List<MarketCategoryTab> parseCategoryOneTabs(
    List<ConfigCardItemData> cards,
  ) {
    final seen = <int>{};
    final out = <MarketCategoryTab>[];
    for (final c in cards) {
      if (!_isCategoryTabCardStyle(c.cardStyle)) continue;
      final rawList = _itemsFromCardDetail(
        c.cardDetail != null ? Map<String, dynamic>.from(c.cardDetail!) : null,
      );
      if (rawList == null) continue;
      for (final e in rawList) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final gi = _parseSymbolGroup(m);
        if (gi == null || gi < 0) continue;
        if (seen.contains(gi)) continue;
        seen.add(gi);
        out.add(MarketCategoryTab(label: _parseTitle(m, gi), symbolGroup: gi));
      }
    }
    return out;
  }

  /// iOS `STMarketHqController` 固定分类顺序：
  /// - 非 B 端：商品 → 指数 → 外汇 → 加密
  /// - B 端：商品 → 指数 → 外汇
  static List<MarketCategoryTab> iosFallbackTabs({required bool isBUser}) {
    final full = [2, 5, 1, 4]
        .map(
          (group) => MarketCategoryTab(
            label: stLocalizedTextFromZhHans(defaultTitleForSymbolGroup(group)),
            symbolGroup: group,
            localizationKey: localizationKeyForSymbolGroup(group),
          ),
        )
        .toList();
    if (isBUser) {
      return full.where((t) => t.symbolGroup != 4).toList();
    }
    return full;
  }

  static List<MarketCategoryTab> _dropCryptoForB(
    List<MarketCategoryTab> tabs,
    bool isBUser,
  ) {
    if (!isBUser) return tabs;
    return tabs.where((t) => t.symbolGroup != 4).toList();
  }

  /// B 面去加密后、或配置仅含无效项时，避免子 Tab 为空（否则横条不渲染任何文字）
  static List<MarketCategoryTab> _ensureNonEmpty(
    List<MarketCategoryTab> tabs,
    bool isBUser,
  ) {
    if (tabs.isNotEmpty) return tabs;
    return iosFallbackTabs(isBUser: isBUser);
  }

  /// `get_symbol_group` 返回列表 → Tab（字段对齐 Common：`symbol_group`、`title`/`name`）
  static List<MarketCategoryTab> tabsFromSymbolGroupApi(List<dynamic> raw) {
    final rows = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is! Map) continue;
      rows.add(Map<String, dynamic>.from(e));
    }
    rows.sort((a, b) => _sortOrder(a).compareTo(_sortOrder(b)));

    final seen = <int>{};
    final out = <MarketCategoryTab>[];
    for (final m in rows) {
      final gi = _parseSymbolGroup(m);
      if (gi == null || gi < 0) continue;
      if (seen.contains(gi)) continue;
      seen.add(gi);
      out.add(MarketCategoryTab(label: _parseTitle(m, gi), symbolGroup: gi));
    }
    return out;
  }

  /// 服务端 `category_*` 配置优先；缺失时回退 iOS `STMarketHqController`
  /// 的固定分类，不再额外用 `get_symbol_group` 扩充更多标签。
  static Future<List<MarketCategoryTab>> resolveCategoryTabsAsync({
    required List<ConfigCardItemData> tabCards,
    required bool isBUser,
    required STService service,
  }) async {
    final parsed = parseCategoryOneTabs(tabCards);
    if (parsed.isNotEmpty) {
      return _ensureNonEmpty(_dropCryptoForB(parsed, isBUser), isBUser);
    }
    return iosFallbackTabs(isBUser: isBUser);
  }

  /// 同步路径（无网络）：配置 → 硬编码兜底。
  static List<MarketCategoryTab> resolveCategoryTabs({
    required List<ConfigCardItemData> tabCards,
    required bool isBUser,
  }) {
    final parsed = parseCategoryOneTabs(tabCards);
    if (parsed.isNotEmpty) {
      return _ensureNonEmpty(_dropCryptoForB(parsed, isBUser), isBUser);
    }
    return iosFallbackTabs(isBUser: isBUser);
  }
}
