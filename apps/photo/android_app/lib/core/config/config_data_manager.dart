import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tab_bar_item.dart';
import '../models/market_product_model.dart';
import 'category_market_paging.dart';

String _tabBarConfigDebugEntry(dynamic item, int idx) {
  if (item is! Map<String, dynamic>) {
    return '{$idx invalid_item}';
  }
  final page = item['page'] is Map<String, dynamic>
      ? item['page'] as Map<String, dynamic>
      : const <String, dynamic>{};
  final title = item['title'] as String? ?? '';
  final tabCode = item['page_code'] as String? ?? '';
  final router = page['router'] as String? ?? item['router'] as String? ?? '';
  final showPermission = item['show_permission'] as String? ?? '';
  final isHome = item['is_home'] == true;
  return '{$idx title=$title code=$tabCode router=$router '
      'show=$showPermission isHome=${isHome ? 1 : 0}}';
}

String tabBarConfigDebugSummary(Map<String, dynamic>? config, String source) {
  if (config == null) {
    return 'source=$source invalid_config';
  }
  final tabBar = config['tab_bar'] is List<dynamic>
      ? config['tab_bar'] as List<dynamic>
      : (config['tabBar'] is List<dynamic>
            ? config['tabBar'] as List<dynamic>
            : const <dynamic>[]);
  final serverCount = config['tab_bar_count'] ?? config['tabBarCount'];
  final entries = <String>[];
  for (int i = 0; i < tabBar.length; i++) {
    entries.add(_tabBarConfigDebugEntry(tabBar[i], i));
  }
  return 'source=$source server_tab_bar_count=${serverCount ?? '(null)'} '
      'actual_tab_bar_count=${tabBar.length} entries=${entries.join(', ')}';
}

/// 全局配置与数据管理器
/// 对齐 iOS STConfigDataManager 单例
class ConfigDataManager extends ChangeNotifier {
  // ==================== 应用配置 ====================

  /// 原始应用配置字典
  Map<String, dynamic>? appConfigDic;

  /// 解析后的 Tab 列表
  List<TabBarItemData> _tabs = [];
  List<TabBarItemData> get tabs => _tabs;

  /// GlobalConfig
  double cardCorner = 8.0;
  double cardHorGap = 12.0;
  double cardVerGap = 8.0;
  double cardBorder = 0.0;
  String tabBarStyle = 'default';

  /// Tab 索引
  int currentHomepageIndex = 0;
  int currentSecHomepageIndex = 0;
  int currentMarketpageIndex = 0;
  int currentTradepageIndex = 0;
  int currentMinepageIndex = 0;

  /// H5 配置（新模式 inline / 旧模式 API 获取）
  Map<String, dynamic>? h5Config;

  /// TAB 是否已初始化
  bool get hasTabs => _tabs.isNotEmpty;

  // ==================== 全局产品列表 ====================

  /// 全局产品列表（行情卡片 / 自选 / 分类行情共用）
  List<MarketProductModel> productList = [];

  /// title → index 快速查找
  final Map<String, int> _productsDict = {};

  /// 根据 symbo 查找产品索引（O(1)）
  int productIndexForSymbol(String symbol) {
    return _productsDict[symbol] ?? -1;
  }

  /// 重建产品索引字典
  void rebuildProductsDict() {
    _productsDict.clear();
    for (int i = 0; i < productList.length; i++) {
      _productsDict[productList[i].symbol] = i;
    }
  }

  /// 应用 WebSocket 价格更新
  void applySocketUpdate(SocketUpdateListModel model, int index) {
    if (index < 0 || index >= productList.length) return;
    final existing = productList[index];
    final points = _pointsByApplyingSocketUpdate(existing.points, model);
    var nextPct = model.changePercent;
    if (nextPct.abs() < 1e-12 &&
        model.change.abs() > 1e-12 &&
        model.price.abs() > 1e-12) {
      final denom = model.price - model.change;
      if (denom.abs() > 1e-12) {
        nextPct = (model.change / denom) * 100.0;
      }
    }
    final now = DateTime.now();
    final buyChanged = _priceChanged(existing.buy, model.buy);
    final sellChanged = _priceChanged(existing.sell, model.sell);
    productList[index] = existing.copyWith(
      price: model.price,
      buy: model.buy,
      sell: model.sell,
      spread: model.spread,
      change: model.change,
      changePercent: nextPct,
      high: model.high > existing.high ? model.high : existing.high,
      low: model.low < existing.low || existing.low == 0
          ? model.low
          : existing.low,
      points: points,
      buyPriceChangeDirection: buyChanged
          ? _priceChangeDirection(existing.buy, model.buy)
          : existing.buyPriceChangeDirection,
      sellPriceChangeDirection: sellChanged
          ? _priceChangeDirection(existing.sell, model.sell)
          : existing.sellPriceChangeDirection,
      lastBuyPriceChangeAt: buyChanged ? now : existing.lastBuyPriceChangeAt,
      lastSellPriceChangeAt: sellChanged ? now : existing.lastSellPriceChangeAt,
    );
    notifyListeners();
  }

  List<double> _pointsByApplyingSocketUpdate(
    List<double> existing,
    SocketUpdateListModel model,
  ) {
    final incoming = model.points;
    if (incoming != null && incoming.length >= 2) {
      return incoming;
    }
    if (model.price <= 0) {
      return existing;
    }
    if (existing.isEmpty) {
      return [model.price];
    }
    if (existing.length == 1) {
      return [existing.first, model.price];
    }
    final next = List<double>.from(existing);
    next.removeAt(0);
    next.add(model.price);
    return next;
  }

  bool _priceChanged(double oldPrice, double newPrice) {
    if (oldPrice <= 0 || newPrice <= 0) return false;
    return (oldPrice - newPrice).abs() > 1e-12;
  }

  int _priceChangeDirection(double oldPrice, double newPrice) {
    return newPrice < oldPrice ? -1 : 1;
  }

  /// 合并产品到全局列表（按 title 去重，保留 points 更长的版本）
  void mergeProducts(List<MarketProductModel> newProducts) {
    for (final newProduct in newProducts) {
      final existingIndex = productIndexForSymbol(newProduct.symbol);
      if (existingIndex >= 0) {
        final existing = productList[existingIndex];
        final better =
            newProduct.points.length > existing.points.length ||
            (existing.points.length < 2 && newProduct.points.length >= 2);
        if (better) {
          productList[existingIndex] = newProduct.withCoalescedPresentationFrom(
            existing,
          );
        } else {
          final e = productList[existingIndex];
          if (e.changePercent.abs() < 1e-12 &&
              newProduct.changePercent.abs() > 1e-12) {
            productList[existingIndex] = e.copyWith(
              changePercent: newProduct.changePercent,
              change: newProduct.change,
              price: newProduct.price != 0 ? newProduct.price : e.price,
              inOptional: newProduct.inOptional,
            );
          }
        }
      } else {
        productList.add(newProduct);
      }
    }
    rebuildProductsDict();
  }

  // ==================== 分类行情分页状态 ====================

  int selectedCategorySymbolGroup = -1;
  int categoryMarketPageSize = kCategoryMarketSymbolsPageDefault;
  int categoryMarketNextOffset = 0;
  bool categoryMarketHasMore = true;
  bool categoryMarketLoading = false;
  bool categoryMarketLoadMoreRequest = false;

  /// 重置分类行情分页
  void resetCategoryMarketPaging() {
    categoryMarketNextOffset = 0;
    categoryMarketHasMore = true;
    categoryMarketLoading = false;
    categoryMarketLoadMoreRequest = false;
  }

  /// 横向分类 Tab 选中（对齐 iOS category_1 → selectedCategorySymbolGroup）
  void applyCategorySymbolGroupSelection(int group) {
    selectedCategorySymbolGroup = group;
    resetCategoryMarketPaging();
    notifyListeners();
  }

  // ==================== 配置解析 ====================

  /// 从原始配置解析 Tab 列表
  void parseAppConfig(Map<String, dynamic> config) {
    appConfigDic = config;

    // GlobalConfig（兼容两层结构：config.GlobalConfig.xxx 或 config.xxx 顶层）
    final globalConfig = config['GlobalConfig'] as Map<String, dynamic>?;
    if (globalConfig != null) {
      cardCorner = (globalConfig['cardCorner'] as num?)?.toDouble() ?? 8.0;
      cardHorGap = (globalConfig['cardHorGap'] as num?)?.toDouble() ?? 12.0;
      cardVerGap = (globalConfig['cardVerGap'] as num?)?.toDouble() ?? 8.0;
      cardBorder = (globalConfig['cardBorder'] as num?)?.toDouble() ?? 0.0;
      tabBarStyle = globalConfig['tabBarStyle'] as String? ?? 'default';
    } else {
      // 服务端实际格式：字段在 config 顶层（card_corner, tab_bar_style, 蛇形命名）
      cardCorner =
          (config['card_corner'] as num?)?.toDouble() ??
          (config['cardCorner'] as num?)?.toDouble() ??
          8.0;
      cardHorGap =
          (config['card_hor_gap'] as num?)?.toDouble() ??
          (config['cardHorGap'] as num?)?.toDouble() ??
          12.0;
      cardVerGap =
          (config['card_ver_gap'] as num?)?.toDouble() ??
          (config['cardVerGap'] as num?)?.toDouble() ??
          8.0;
      cardBorder =
          (config['card_border'] as num?)?.toDouble() ??
          (config['cardBorder'] as num?)?.toDouble() ??
          0.0;
      tabBarStyle =
          config['tab_bar_style'] as String? ??
          config['tabBarStyle'] as String? ??
          'default';
    }

    // H5 配置（新模式）
    final rawH5Config = config['h5_config'];
    if (rawH5Config is Map) {
      h5Config = Map<String, dynamic>.from(rawH5Config);
    }

    // 解析 tab_bar（蛇形 tab_bar；部分环境为驼峰 tabBar）
    final tabBarList =
        (config['tab_bar'] ?? config['tabBar']) as List<dynamic>?;
    if (tabBarList != null) {
      final parsedTabs = <TabBarItemData>[];
      for (final raw in tabBarList) {
        if (raw is! Map<String, dynamic>) {
          continue;
        }
        final tab = TabBarItemData.fromJson(raw);
        parsedTabs.add(tab);

        final nav = tab.navInfo;
        if (nav != null) {
          final navPretty = jsonEncode(nav.toJson());
          final actionCount = nav.actionItems?.length ?? 0;
          final subTabCount = nav.subTabs?.length ?? 0;
          debugPrint(
            '🧭 TabNavConfig tab="${tab.tabId}" '
            'router=${tab.router} '
            'nav_style="${nav.navigationStyle ?? ''}" '
            'title="${nav.title ?? ''}" '
            'icon="${nav.icon ?? ''}" '
            'actions=$actionCount sub_tabs=$subTabCount '
            'raw=$navPretty',
          );
        } else {
          debugPrint(
            '🧭 TabNavConfig tab="${tab.tabId}" router=${tab.router} no nav',
          );
        }
      }
      _tabs = parsedTabs;

      // 计算各路由 Tab 索引
      for (int i = 0; i < _tabs.length; i++) {
        final router = _tabs[i].router;
        if (router == '/home') currentHomepageIndex = i;
        if (router == '/tab') currentSecHomepageIndex = i;
        if (router == '/market') currentMarketpageIndex = i;
        if (router == '/trade' || router == '/trade1') {
          currentTradepageIndex = i;
        }
        if (router == '/mine') currentMinepageIndex = i;
      }
    }

    // 通知所有监听者（TabShell 重建）
    notifyListeners();
  }

  /// 更新指定下标的底栏 Tab（对齐 iOS `STTabViewController` 登录态刷新后写回配置）
  void updateTabBarItem(int index, TabBarItemData tab) {
    if (index < 0 || index >= _tabs.length) return;
    _tabs[index] = tab;
    notifyListeners();
  }

  /// 按 [tabId] 或 [pageId] 更新 `/tab` 复合页配置
  int? indexOfCompoundTab({String? tabId, int? pageId}) {
    for (int i = 0; i < _tabs.length; i++) {
      final t = _tabs[i];
      if (t.router != '/tab') continue;
      if (tabId != null && tabId.isNotEmpty && t.tabId == tabId) return i;
      if (pageId != null && pageId > 0 && t.pageId == pageId) return i;
    }
    return null;
  }

  /// 按 tabId / pageId 查找底栏 Tab 下标（对齐 iOS 写回 tabBarItemData）
  int? indexOfTabBarItem({String? tabId, int? pageId}) {
    for (int i = 0; i < _tabs.length; i++) {
      final t = _tabs[i];
      if (tabId != null && tabId.isNotEmpty && t.tabId == tabId) return i;
      if (pageId != null && pageId > 0 && t.pageId == pageId) return i;
    }
    return null;
  }

  /// 获取配置的 H5 URL（新模式 > 旧模式兜底）
  String h5Url(String key, [String fallback = '']) {
    if (h5Config != null && h5Config![key] != null) {
      return h5Config![key] as String;
    }
    return fallback;
  }

  /// 合并 H5 地址数据（来自旧模式 getH5Addresses API 的补充字段）
  /// 对齐 iOS: STRootViewController.viewDidLoad → requestH5Address → 填充 STH5AddressModel
  /// 在 parseAppConfig 之后调用，补充 appConfig 中 h5_config 未覆盖的字段
  void mergeH5AddressData(Map<String, dynamic> data) {
    h5Config ??= {};
    // 只合并新值，不覆盖已有字段（appConfig 的 h5_config 优先级更高）
    for (final entry in data.entries) {
      h5Config!.putIfAbsent(entry.key, () => entry.value);
    }
    notifyListeners();
  }

  // ==================== 卡片数据更新（对齐 iOS STConfigDataManager） ====================

  /// 更新指定 cardStyle 前缀的卡片数据
  /// 遍历所有 Tab 及其子 Tab 的 cardItems，找到匹配 cardStyle 的卡片，
  /// 将其 cardDetail 替换为新数据，并触发 UI 刷新。
  void _updateCardDataForStyle(String stylePrefix, Map<String, dynamic> data) {
    bool changed = false;

    for (int t = 0; t < _tabs.length; t++) {
      final tab = _tabs[t];
      final newItems = <ConfigCardItemData>[];

      for (final card in tab.cardItems) {
        if (card.cardStyle.startsWith(stylePrefix)) {
          newItems.add(card.copyWith(cardDetail: data));
          changed = true;
        } else {
          newItems.add(card);
        }
      }

      if (changed) {
        _tabs[t] = tab.copyWith(cardItems: newItems);
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  /// 更新 Header 卡片数据
  void updateHeaderCardData(Map<String, dynamic> data) {
    _updateCardDataForStyle('header_', data);
  }

  /// 更新余额卡片数据
  void updateBalanceCardData(Map<String, dynamic> data) {
    _updateCardDataForStyle('balance_', data);
  }

  /// 更新账户卡片数据
  void updateAccountCardData(Map<String, dynamic> data) {
    _updateCardDataForStyle('account_', data);
  }

  /// 更新行情卡片数据
  void updateMarketCardData(Map<String, dynamic> data) {
    _updateCardDataForStyle('market_', data);
  }

  /// 更新自选行情卡片数据
  void updateSelfMarketCardData(Map<String, dynamic> data) {
    _updateCardDataForStyle('selfmarket_', data);
  }

  /// 更新分类行情卡片数据
  void updateCategoryMarketCardData(Map<String, dynamic> data) {
    _updateCardDataForStyle('categorymarket_', data);
  }

  // ==================== App 配置离线缓存 ====================

  static const String _cacheKey = 'app_config_cache';
  static const Duration _cacheMaxAge = Duration(hours: 24);

  /// 保存 App 配置到离线缓存（SharedPreferences）
  Future<void> saveAppConfigToCache(Map<String, dynamic> config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': config,
      };
      await prefs.setString(_cacheKey, jsonEncode(cacheData));
      debugPrint('💾 App config cached to SharedPreferences');
    } catch (e) {
      debugPrint('⚠️ Failed to cache app config: $e');
    }
  }

  /// 从离线缓存加载 App 配置（SharedPreferences）
  /// 返回 null 表示无缓存或已过期
  Future<Map<String, dynamic>?> loadAppConfigFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached == null || cached.isEmpty) return null;

      final cacheData = jsonDecode(cached) as Map<String, dynamic>;
      final timestamp = cacheData['timestamp'] as int? ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // 检查是否过期
      if (now - timestamp > _cacheMaxAge.inMilliseconds) {
        debugPrint('💾 App config cache expired');
        await prefs.remove(_cacheKey);
        return null;
      }

      final config = cacheData['data'] as Map<String, dynamic>?;
      if (config == null) return null;

      debugPrint('💾 App config loaded from cache');
      return config;
    } catch (e) {
      debugPrint('⚠️ Failed to load cached app config: $e');
      return null;
    }
  }
}

// ==================== Riverpod Providers ====================

/// ConfigDataManager 全局单例（ChangeNotifier）
final configDataManagerProvider = ChangeNotifierProvider<ConfigDataManager>((
  ref,
) {
  return ConfigDataManager();
});

/// App 配置原始字典
final appConfigProvider = Provider<Map<String, dynamic>?>((ref) {
  return ref.watch(configDataManagerProvider).appConfigDic;
});

/// Tab 列表
final tabBarProvider = Provider<List<TabBarItemData>>((ref) {
  return ref.watch(configDataManagerProvider).tabs;
});

/// 全局产品列表
final productListProvider = Provider<List<MarketProductModel>>((ref) {
  return ref.watch(configDataManagerProvider).productList;
});

/// H5 配置
final h5ConfigProvider = Provider<Map<String, dynamic>?>((ref) {
  return ref.watch(configDataManagerProvider).h5Config;
});
