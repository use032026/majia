import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../core/models/tab_bar_item.dart';
import '../../core/models/market_product_model.dart';
import '../../core/models/news_item_model.dart';
import '../../core/models/banner_item_model.dart';
import '../../core/config/category_market_paging.dart';
import '../../core/config/config_data_manager.dart';
import '../../core/network/st_service.dart';
import 'base_card.dart';
import 'header_card.dart';
import 'balance_card.dart';
import 'account_card.dart';
import 'banner_card.dart';
import 'market_card.dart';
import 'list_card.dart';
import 'grid_card.dart';
import 'slip_card.dart';
import 'ad_card.dart';
import 'horse_card.dart';
import 'navi_card.dart';
import 'newslist_card.dart';
import 'market_quote_cards.dart';
import 'mine_page_cards.dart';
import 'unlock_card.dart';
import 'home_vip_card.dart';
import 'card_item_route.dart';

/// 卡片导航回调（对齐 iOS CardRouterOpen → STRouterManager.openPageWithRouter:params:）
typedef CardNavigateCallback =
    void Function(String path, Map<String, dynamic>? params, {String? action});

/// 分类 Tab 切换后刷新 `categorymarket_*` 列表
typedef CategoryMarketReloadCallback = Future<void> Function();

/// 分页加载分类行情
typedef CategoryMarketLoadMoreCallback =
    Future<void> Function(ConfigCardItemData card);

/// 底部 Tab「行情」列表占位卡片（分类行情统一按 iOS `categorymarket_2` 展示）
final ConfigCardItemData marketTabDummyCategoryCard = ConfigCardItemData(
  cardId: 'market_tab_category',
  cardStyle: 'categorymarket_2',
);

/// 卡片工厂
/// 对齐 iOS ConfigCardHandlerBlockRegistry + STConfigCardHandler.cardToolHandler
///
/// 职责：
/// 1. 根据 cardStyle 创建对应的 Widget
/// 2. 按 cardStyle 分发数据加载请求
class CardFactory {
  /// 从 item map 中提取导航参数（对齐 iOS RouterModel 模式）
  /// 优先级: routerModel 对象 → router + link → 纯 link
  static ({String path, Map<String, dynamic>? params}) extractItemRoute(
    Map<String, dynamic> item,
  ) => extractCardItemRoute(item);

  /// 创建卡片 Widget
  ///
  /// [useMinePageVariants] 仅在 `router == '/mine'` 的页面置为 true，
  /// 用于把 `header_1` / `balance_2` / `grid_1` / `vip_1` / `account_3` / `list_1`
  /// 替换为「我的」专用变体（依赖 `UserState` 和 `icon_asset` 本地资源）。
  /// 其它页面（首页 / 行情等）必须保持 false，否则会拦截下发 `icon` URL 的 `grid_1` 等通用卡片。
  static Widget createCard(
    BuildContext context,
    ConfigCardItemData card, {
    CardNavigateCallback? onNavigate,
    Map<String, dynamic>? dataCache,
    CategoryMarketReloadCallback? onReloadCategoryMarket,
    CategoryMarketLoadMoreCallback? onLoadMoreCategoryMarket,
    bool useMinePageVariants = false,
    ValueListenable<bool>? pageVisibleListenable,
    bool compactTop = false,
  }) {
    if (!card.isShow) return const SizedBox.shrink();

    // type: native / web / online(mini) — 优先于 style 前缀（对齐 iOS ConfigCardItemData）
    var td = card.cardTypedef;
    if (td == null || td.isEmpty) {
      if (card.cardType == 'web') {
        td = 'web';
      } else if (card.cardType == 'online') {
        td = 'mini';
      }
    }
    if (td == 'web') {
      return WebCard(
        cardData: card,
        compactTop: compactTop,
        pageVisibleListenable: pageVisibleListenable,
      );
    }
    if (td == 'mini') {
      return MiniEmbedCard(cardData: card);
    }

    /// page-mine 专用变体（仅 /mine 页启用，与 iOS 中 header_1 / header_4 / balance_1 /
    /// balance_2 / grid_1 / vip_1 / account_3 / list_1 对应）。其它页同 `cardStyle` 走通用卡片，
    /// 加载后端下发的 `icon` URL 而非本地 `icon_asset`。
    if (useMinePageVariants) {
      if (card.cardStyle.startsWith('header_')) {
        return HeaderCard(cardData: card);
      }
      if (card.cardStyle.startsWith('balance_')) {
        return BalanceCard(cardData: card);
      }
      if (card.cardStyle == 'grid_1') {
        return MineGridQuickCard1(cardData: card, onNavigate: onNavigate);
      }
      if (card.cardStyle == 'vip_1') {
        return HomeVipCard(
          cardData: card,
          onNavigate: onNavigate,
          dataCache: dataCache,
        );
      }
      if (card.cardStyle == 'account_3') {
        return MineAccountCard3(cardData: card);
      }
      if (card.cardStyle == 'list_1') {
        return MineListCard1(cardData: card, onNavigate: onNavigate);
      }
    }

    // 按 cardStyle 前缀匹配对应的卡片 Widget
    // 后缀 _1/_2/_3 表示同一类卡片的布局变体（如 grid_1 / grid_2 网格列数不同）
    if (card.cardStyle.startsWith('header_')) {
      return HeaderCard(cardData: card);
    } else if (card.cardStyle.startsWith('balance_')) {
      return BalanceCard(cardData: card);
    } else if (card.cardStyle.startsWith('account_')) {
      return AccountCard(cardData: card);
    } else if (card.cardStyle.startsWith('banner_')) {
      return BannerCard(
        cardData: card,
        onNavigate: onNavigate,
        compactTop: compactTop,
      );
    } else if (card.cardStyle.startsWith('market_')) {
      return MarketCard(
        cardData: card,
        onNavigate: onNavigate,
        dataCache: dataCache,
      );
    } else if (card.cardStyle.startsWith('list_')) {
      return ListCard(cardData: card, onNavigate: onNavigate);
    } else if (card.cardStyle.startsWith('grid_')) {
      return GridCard(cardData: card, onNavigate: onNavigate);
    } else if (card.cardStyle.startsWith('slip_')) {
      return SlipCard(cardData: card, onNavigate: onNavigate);
    } else if (card.cardStyle == 'ad_1') {
      return AdCard(cardData: card, onNavigate: onNavigate);
    } else if (card.cardStyle.startsWith('vip_')) {
      return HomeVipCard(
        cardData: card,
        onNavigate: onNavigate,
        dataCache: dataCache,
      );
    } else if (card.cardStyle.startsWith('selfmarket_')) {
      if (cardStyleIsVariantOne(card.cardStyle) ||
          cardStyleIsVariantTwo(card.cardStyle)) {
        return SelfMarketCardTwo(
          cardData: card,
          onNavigate: onNavigate,
          dataCache: dataCache,
        );
      }
      return MarketCard(
        cardData: card,
        onNavigate: onNavigate,
        dataCache: dataCache,
      );
    } else if (card.cardStyle.startsWith('categorymarket_')) {
      return CategoryMarketCardTwo(
        cardData: card,
        onNavigate: onNavigate,
        dataCache: dataCache,
      );
    } else if (card.cardStyle.startsWith('category_')) {
      // 后台 category_* 变体统一按 iOS 注册的 category_1 横向分类渲染。
      return CategoryTabsCardOne(
        cardData: card,
        onReloadCategoryMarket: onReloadCategoryMarket,
      );
    } else if (card.cardStyle.startsWith('newslist_')) {
      // 传递缓存的数据到 NewslistCard
      final cachedKey = '${card.cardStyle}_news';
      final cachedItems = dataCache?[cachedKey] as List<NewsItemModel>?;
      return NewslistCard(
        cardData: card,
        onNavigate: onNavigate,
        items: cachedItems,
      );
    } else if (card.cardStyle.startsWith('unlock_')) {
      return UnlockCard(
        cardData: card,
        onNavigate: onNavigate,
        dataCache: dataCache,
      );
    } else if (_isHorseCardStyle(card.cardStyle)) {
      // 后台 horse_1 / horse_2 / horse_3 共用同一套跑马灯视觉，统一按 horse_3 渲染。
      return Horse3Card(cardData: card, onNavigate: onNavigate);
    } else if (card.cardStyle.startsWith('button_')) {
      return _buildButtonCard(context, card, onNavigate: onNavigate);
    } else if (card.cardStyle.startsWith('nav_')) {
      return NaviCard(cardData: card, onNavigate: onNavigate);
    } else if (card.cardStyle.startsWith('tabnav_')) {
      return TabNaviCard(cardData: card, onNavigate: onNavigate);
    }

    // 未知 cardStyle → 占位
    return _buildUnknownCard(context, card);
  }

  static bool _isHorseCardStyle(String cardStyle) {
    return cardStyle.startsWith('horse_') ||
        RegExp(r'^horse[123]$').hasMatch(cardStyle);
  }

  // ==================== 卡片数据加载（对齐 iOS cardRequestDetailHandlerBlock） ====================

  /// Header / Balance / Account：使用本地已有数据
  static void loadLocalData(
    ConfigCardItemData card,
    ConfigDataManager configMgr,
  ) {
    // 这些卡片不需要额外 API 请求，数据通过钱包轮询/配置数据更新
  }

  /// Market 卡片数据加载：requestHotSymbolWithNeedPoints
  static Future<List<MarketProductModel>> loadMarketCardData({
    required ConfigCardItemData card,
    required STService service,
    required ConfigDataManager configMgr,
    int limit = 6,
  }) async {
    try {
      final symbols = await service.getHotSymbols(needPoints: true);
      final products = symbols
          .take(limit)
          .map((e) => MarketProductModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // 合并到全局 productList
      configMgr.mergeProducts(products);
      return products;
    } catch (e) {
      debugPrint('⚠️ loadMarketCardData error: $e');
      return [];
    }
  }

  /// 拉取自选接口原始列表（与 [STConfigCardHandler loadMarketDataWithCardData] 一致）
  static Future<List<dynamic>> fetchOptionalSymbolsRaw({
    required STService service,
    required bool isLoggedIn,
  }) async {
    final result = await fetchOptionalSymbolsRawWithSource(
      service: service,
      isLoggedIn: isLoggedIn,
    );
    return result.symbols;
  }

  /// 区分“真实自选列表”和“推荐兜底”。
  ///
  /// iOS `STOptionalListView.requestData` 只要 `get_symbol_watch_list` 返回
  /// 非空就切到列表态，不依赖 item 上是否额外带 `in_optional`。
  static Future<({List<dynamic> symbols, bool fromWatchlist})>
  fetchOptionalSymbolsRawWithSource({
    required STService service,
    required bool isLoggedIn,
  }) async {
    if (isLoggedIn) {
      var symbols = await service.getOptionList(needPoints: true);
      if (symbols.isNotEmpty) {
        return (symbols: symbols, fromWatchlist: true);
      }
      symbols = await service.getOptionSymbol(needPoints: false);
      return (symbols: symbols, fromWatchlist: false);
    }
    return (
      symbols: await service.getOptionSymbol(needPoints: false),
      fromWatchlist: false,
    );
  }

  static Map<String, dynamic> _asStringKeyMap(dynamic e) =>
      e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);

  /// 底部行情 Tab「自选」列表：请求 + `mergeProducts` + [MarketProductModel]（与卡片 `selfmarket_*` 同源）
  static Future<List<MarketProductModel>> loadMarketTabSelfProducts({
    required STService service,
    required ConfigDataManager configMgr,
    required bool isLoggedIn,
  }) async {
    try {
      final result = await fetchOptionalSymbolsRawWithSource(
        service: service,
        isLoggedIn: isLoggedIn,
      );
      final out = <MarketProductModel>[];
      for (final e in result.symbols) {
        final self = SelfMarketProductModel.fromJson(_asStringKeyMap(e));
        out.add(
          MarketProductModel(
            symbol: self.symbol,
            name: self.name,
            price: self.price,
            buy: self.buy,
            sell: self.sell,
            spread: self.spread,
            change: self.change,
            changePercent: self.changePercent,
            precision: self.precision,
            points: self.points,
            subTitle: self.subTitle,
            isSingleIcon: self.isSingleIcon,
            icon: self.icon,
            currencyBaseIcon: self.currencyBaseIcon,
            currencyProfitIcon: self.currencyProfitIcon,
            inOptional: result.fromWatchlist || self.inOptional,
            symbolGroup: self.symbolGroup,
          ),
        );
      }
      configMgr.mergeProducts(out);
      return out;
    } catch (e) {
      debugPrint('⚠️ loadMarketTabSelfProducts error: $e');
      return [];
    }
  }

  /// SelfMarket 卡片数据加载
  static Future<List<SelfMarketProductModel>> loadSelfMarketCardData({
    required ConfigCardItemData card,
    required STService service,
    required ConfigDataManager configMgr,
    required bool isLoggedIn,
  }) async {
    try {
      final result = await fetchOptionalSymbolsRawWithSource(
        service: service,
        isLoggedIn: isLoggedIn,
      );

      final products = result.symbols.map((e) {
        final product = SelfMarketProductModel.fromJson(_asStringKeyMap(e));
        if (result.fromWatchlist) product.inOptional = true;
        return product;
      }).toList();

      // 合并到全局 productList
      configMgr.mergeProducts(
        products
            .map(
              (p) => MarketProductModel(
                symbol: p.symbol,
                name: p.name,
                price: p.price,
                buy: p.buy,
                sell: p.sell,
                spread: p.spread,
                change: p.change,
                changePercent: p.changePercent,
                precision: p.precision,
                points: p.points,
                subTitle: p.subTitle,
                isSingleIcon: p.isSingleIcon,
                icon: p.icon,
                currencyBaseIcon: p.currencyBaseIcon,
                currencyProfitIcon: p.currencyProfitIcon,
                inOptional: p.inOptional,
                symbolGroup: p.symbolGroup,
              ),
            )
            .toList(),
      );

      return products;
    } catch (e) {
      debugPrint('⚠️ loadSelfMarketCardData error: $e');
      return [];
    }
  }

  /// CategoryMarket 卡片数据加载（分页）
  static Future<List<CategoryMarketProductModel>> loadCategoryMarketCardData({
    required ConfigCardItemData card,
    required STService service,
    required ConfigDataManager configMgr,
    int rankType = 0,
    int offset = 0,
    int limit = kCategoryMarketSymbolsPageDefault,
    String sortOrder = 'OrderAsce',
  }) async {
    try {
      final result = Map<String, dynamic>.from(
        await service.getProductListByRank(
          rankType: rankType,
          offset: offset,
          limit: limit,
          sortOrder: sortOrder,
        ),
      );

      final data = STService.marketListDataFromRoot(result);
      final symbols = STService.symbolArrayFromMarketDataMap(data);

      final serverPs = categoryMarketPageSizeFromServerMap(data);
      if (serverPs != null) {
        configMgr.categoryMarketPageSize = serverPs;
      }

      final products = symbols
          .map((e) => CategoryMarketProductModel.fromJson(_asStringKeyMap(e)))
          .toList();

      // 更新分页状态
      configMgr.categoryMarketNextOffset =
          (data['next_offset'] as num?)?.toInt() ?? offset + symbols.length;
      configMgr.categoryMarketHasMore =
          (data['has_more'] as bool?) ?? (symbols.length >= limit);
      configMgr.categoryMarketLoading = false;

      // 合并到全局 productList
      configMgr.mergeProducts(
        products
            .map(
              (p) => MarketProductModel(
                symbol: p.symbol,
                name: p.name,
                price: p.price,
                buy: p.buy,
                sell: p.sell,
                spread: p.spread,
                change: p.change,
                changePercent: p.changePercent,
                precision: p.precision,
                points: p.sparklinePrices,
                subTitle: p.subTitle,
                isSingleIcon: p.isSingleIcon,
                icon: p.icon,
                currencyBaseIcon: p.currencyBaseIcon,
                currencyProfitIcon: p.currencyProfitIcon,
              ),
            )
            .toList(),
      );

      return products;
    } catch (e) {
      debugPrint('⚠️ loadCategoryMarketCardData error: $e');
      configMgr.categoryMarketLoading = false;
      return [];
    }
  }

  /// 底部行情 Tab「行情」列表：与首页 `categorymarket_*` 相同 [loadCategoryMarketCardData] 路径
  static Future<List<MarketProductModel>> loadMarketTabCategoryProducts({
    required STService service,
    required ConfigDataManager configMgr,
    required int rankType,
    required int offset,
    required int limit,
    String sortOrder = 'OrderAsce',
  }) async {
    final cats = await loadCategoryMarketCardData(
      card: marketTabDummyCategoryCard,
      service: service,
      configMgr: configMgr,
      rankType: rankType,
      offset: offset,
      limit: limit,
      sortOrder: sortOrder,
    );
    return cats
        .map(
          (p) => MarketProductModel(
            symbol: p.symbol,
            name: p.name,
            price: p.price,
            buy: p.buy,
            sell: p.sell,
            spread: p.spread,
            change: p.change,
            changePercent: p.changePercent,
            precision: p.precision,
            points: p.sparklinePrices,
            subTitle: p.subTitle,
            isSingleIcon: p.isSingleIcon,
            icon: p.icon,
            currencyBaseIcon: p.currencyBaseIcon,
            currencyProfitIcon: p.currencyProfitIcon,
          ),
        )
        .toList();
  }

  /// VIP 卡片数据加载
  static Future<Map<String, dynamic>?> loadVipCardData({
    required ConfigCardItemData card,
    required STService service,
  }) async {
    try {
      final raw = await service.getLevel();
      final d = raw['data'];
      if (d is Map<String, dynamic>) return Map<String, dynamic>.from(d);
      if (d is Map) {
        return Map<String, dynamic>.from(Map<dynamic, dynamic>.from(d));
      }
      if (raw.containsKey('current_level') || raw.containsKey('progress')) {
        return Map<String, dynamic>.from(raw);
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ loadVipCardData error: $e');
      return null;
    }
  }

  /// 新闻资讯卡片数据加载（对齐 iOS: requestNewsListWithParams:@{@"limit":@4}）
  static Future<List<NewsItemModel>> loadNewsListCardData({
    required ConfigCardItemData card,
    required STService service,
    int limit = 4,
  }) async {
    try {
      final rawList = await service.getNewsList(limit: limit);
      return rawList
          .map((e) => NewsItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('⚠️ loadNewsListCardData error: $e');
      return [];
    }
  }

  /// 交易解锁卡片数据加载（对齐 iOS STConfigCardHandler unlock 分支）
  static Future<Map<String, dynamic>?> loadUnlockCardData({
    required ConfigCardItemData card,
    required STService service,
  }) async {
    try {
      final results = await Future.wait([
        service.getTradeUnlockTaskProgress(),
        service.getTradeUnlockSymbolConfig(),
      ]);

      Map<String, dynamic> unwrap(dynamic raw) {
        if (raw is! Map) return {};
        final map = Map<String, dynamic>.from(raw);
        final data = map['data'];
        if (data is Map) return Map<String, dynamic>.from(data);
        return map;
      }

      final unlockInfo = Map<String, dynamic>.from(unwrap(results[0]));
      final symbolRoot = unwrap(results[1]);
      unlockInfo['symbols'] =
          symbolRoot['symbol_configs'] ?? symbolRoot['symbols'] ?? [];

      final stage = (unlockInfo['stage'] as num?)?.toInt() ?? 0;
      unlockInfo['title'] = stage == 0 ? '新人奖励' : '正在解锁';
      unlockInfo['title_key'] = stage == 0 ? 'newcomer_rewards' : 'unlocking';
      unlockInfo['view_detail'] = '查看详情';
      unlockInfo['view_detail_key'] = 'view_details';

      final symbolsRaw = unlockInfo['symbols'];
      if (symbolsRaw is List) {
        final sorted =
            symbolsRaw
                .whereType<Map>()
                .map((e) {
                  final map = Map<String, dynamic>.from(e);
                  final sym = (map['symbol'] ?? '').toString();
                  final amt =
                      num.tryParse(
                        '${map['settlement_per_unit_amount'] ?? map['settlementPerUnitAmount'] ?? 0}',
                      ) ??
                      0;
                  return (sym, amt);
                })
                .where((e) => e.$1.isNotEmpty)
                .toList()
              ..sort((a, b) => b.$2.compareTo(a.$2));
        for (var i = 0; i < sorted.length && i < 3; i++) {
          unlockInfo['symbol${i + 1}'] = sorted[i].$1;
        }
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final activityEnd = (unlockInfo['activity_end'] as num?)?.toInt() ?? 0;
      final validUntil = (unlockInfo['valid_until'] as num?)?.toInt() ?? 0;
      if (stage == 0 && now < activityEnd) {
        unlockInfo['count_down'] = activityEnd - now;
      } else if (stage == 1 && now < validUntil) {
        unlockInfo['count_down'] = validUntil - now;
      } else {
        unlockInfo['count_down'] = 0;
      }

      final tasksRaw = unlockInfo['tasks'];
      var totalAmount = 0;
      var currentTask = 0;
      if (tasksRaw is List) {
        for (var i = 0; i < tasksRaw.length; i++) {
          final task = tasksRaw[i];
          if (task is! Map) continue;
          final map = Map<String, dynamic>.from(task);
          totalAmount +=
              int.tryParse(
                '${map['unlock_amount'] ?? map['unlockAmount'] ?? 0}',
              ) ??
              0;
          final done =
              map['is_completed'] == true || map['isCompleted'] == true;
          if (!done && currentTask == 0) currentTask = i;
        }
      }
      unlockInfo['total_amount'] = '$totalAmount';
      unlockInfo['current_task'] = currentTask;

      return unlockInfo;
    } catch (e) {
      debugPrint('⚠️ loadUnlockCardData error: $e');
      return null;
    }
  }

  /// Banner 卡片数据加载
  /// Banner items 来自服务端配置的 cardDetail.items（非独立 API 请求）
  /// 对齐 iOS: BannerItemModel.initWithDic 直接从 payload 解析
  static List<BannerItemModel> loadBannerCardData({
    required ConfigCardItemData card,
    required STService service,
  }) {
    final detail = card.cardDetail;
    final rawItems = detail?['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((e) => BannerItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
    debugPrint('🖼️ Banner card data: ${items.length} items from cardDetail');
    return items;
  }

  // ==================== 内置卡片组件 ====================

  static Widget _buildButtonCard(
    BuildContext context,
    ConfigCardItemData card, {
    CardNavigateCallback? onNavigate,
  }) {
    // 优先从 cardDetail.items 取导航参数，兜底用 card.link
    final detail = card.cardDetail;
    final rawItems = detail?['items'] as List<dynamic>? ?? [];
    final items = rawItems.map((e) => e as Map<String, dynamic>).toList();
    final firstItem = items.isNotEmpty ? items.first : null;
    final route = firstItem != null
        ? extractItemRoute(firstItem)
        : (path: '', params: null);
    final hasRoute = route.path.isNotEmpty;
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton(
          onPressed: () {
            if (hasRoute) {
              onNavigate?.call(route.path, route.params);
            } else {
              final link = card.link ?? '';
              if (link.isNotEmpty) onNavigate?.call('/web', {'link': link});
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            card.title ?? '按钮',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  static Widget _buildUnknownCard(
    BuildContext context,
    ConfigCardItemData card,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          border: Border.all(color: context.adaptiveDivider, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '🃏 ${card.cardStyle}: ${card.title ?? ""}',
            style: TextStyle(color: context.adaptiveTextHint, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
