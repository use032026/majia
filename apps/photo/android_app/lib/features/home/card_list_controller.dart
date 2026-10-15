import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import '../../core/models/tab_bar_item.dart';
import '../../core/models/market_product_model.dart';
import '../../core/models/wallet_model.dart';
import '../../core/models/auth_status_model.dart';
import '../../core/config/category_market_paging.dart';
import '../../core/config/config_data_manager.dart';
import '../../core/network/market_websocket.dart';
import '../../core/network/st_service.dart';
import '../../core/models/user_state.dart';
import '../../shared/widgets/card_factory.dart';

/// 路由跳转回调（context.push 的抽象，便于注入）
typedef RouteOpener = void Function(String path, Map<String, dynamic> params);

/// 卡片列表控制器
/// 对齐 iOS STProjectListViewController 的核心逻辑
/// 管理：卡片调度、WebSocket 订阅、钱包轮询、数据加载
class CardListController with ChangeNotifier {
  final WidgetRef ref;

  /// 在 [dispose] 开头置 true，异步回调中不再 [notifyListeners] 或使用 [ref]
  bool _inactive = false;

  StreamSubscription<MarketWSMessage>? _marketWsSub;

  void _notifySafe() {
    if (_inactive) return;
    notifyListeners();
  }

  /// 路由跳转回调（由页面注入 context.push）
  RouteOpener? _routeOpener;
  RouteOpener? get routeOpener => _routeOpener;
  void setRouteOpener(RouteOpener opener) => _routeOpener = opener;

  /// 原始卡片列表
  List<ConfigCardItemData> _cards = [];
  List<ConfigCardItemData> get cards => _cards;

  /// 过滤后的卡片列表（isShow = true）
  List<ConfigCardItemData> get filteredCards =>
      _cards.where((c) => c.isShow).toList();

  // ==================== 卡片缓存（对齐 iOS nativeCardCache / webCardCache） ====================

  /// 原生卡片数据缓存（key: "${cardStyle}_${cardId}"）
  /// 对齐 iOS: NSMutableDictionary *nativeCardCache
  final Map<String, dynamic> _nativeCardCache = {};

  /// Web/H5 卡片数据缓存（key: "${link}"）
  /// 对齐 iOS: NSMutableDictionary *webCardCache
  final Map<String, dynamic> _webCardCache = {};

  /// 写入原生卡片缓存
  void cacheNativeCardData(ConfigCardItemData card, dynamic data) {
    final key = '${card.cardStyle}_${card.cardId}';
    _nativeCardCache[key] = data;
    debugPrint('💾 Native card cached: $key');
  }

  /// 读取原生卡片缓存
  dynamic getNativeCardCachedData(ConfigCardItemData card) {
    final key = '${card.cardStyle}_${card.cardId}';
    return _nativeCardCache[key];
  }

  /// 写入 Web 卡片缓存
  void cacheWebCardData(String link, dynamic data) {
    if (link.isEmpty) return;
    _webCardCache[link] = data;
    debugPrint('💾 Web card cached: $link');
  }

  /// 读取 Web 卡片缓存
  dynamic getWebCardCachedData(String link) {
    return _webCardCache[link];
  }

  // WebSocket
  bool _isMarketSocketRunning = false;

  // 钱包轮询
  Timer? _walletPollingTimer;
  bool _isPollingWallet = false;

  // 页面状态
  bool _isFirstLoad = true;
  bool _isVisible = false;

  /// 卡片数据缓存（类型化加载数据，按 cardStyle 索引）
  /// 外部通过此 Map 将缓存数据传递给 CardFactory.createCard
  final Map<String, dynamic> cardDataCache = {};

  /// 加载中状态（对齐 iOS loading 状态同步）
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  /// 对齐 iOS STProjectListViewController.requestPageInfo（page_id）
  /// schema 未下发 cards 时用接口补全；部分页面可要求首次加载即以 page 接口为准。
  final int? pageListId;

  /// 首次进入即请求 page 接口刷新 cards/bg/nav。
  ///
  /// iOS `STNewMineViewController` 使用 `STProjectListViewController` 的配置化页面
  /// 能力；Flutter 的 `/mine` 也应优先使用接口返回的展示布局，而不是旧静态页面。
  final bool preferPageApiOnInitialLoad;

  /// 「我的」Tab（`router == '/mine'`）：拉起实名/邮箱等配置与返佣、`UserState.walletAry` 等与 iOS 「我的」域一致，
  /// 与 [_loadCardData] 中网关卡片（VIP 等）互补。
  final bool enableMineBusinessLayer;

  /// 底栏 Tab 元数据（用于下拉刷新后写回 bg/nav）
  final TabBarItemData? sourceTabBarItem;

  /// CMS 页面壳层（bg/nav），对齐 iOS `setBg` / `addNaviBar`
  TabBarItemData? _pageChrome;
  TabBarItemData? get pageChrome => _pageChrome;

  CardListController({
    required this.ref,
    List<ConfigCardItemData>? cards,
    this.pageListId,
    this.preferPageApiOnInitialLoad = false,
    this.enableMineBusinessLayer = false,
    this.sourceTabBarItem,
  }) {
    _pageChrome = sourceTabBarItem;
    if (cards != null) {
      _cards = cards;
      debugPrint(
        '📄 CardListController: initialized with ${cards.length} cards',
      );
      for (final c in cards) {
        debugPrint(
          '📄 CardListController card: style="${c.cardStyle}" isShow=${c.isShow} title="${c.title}"',
        );
      }
    }
  }

  /// 子类只读访问当前卡片配置；用于页面专属控制器复制 iOS 子类行为。
  List<ConfigCardItemData> get allCards => _cards;

  bool get isVisible => _isVisible;

  bool get isFirstLoad => _isFirstLoad;

  /// 子类更新卡片状态/缓存后调用。
  void notifyDataChanged() => _notifySafe();

  /// 对齐 iOS 子类重写点：viewDidLoad 中通用列表初始化完成后。
  Future<void> afterViewDidLoad(
    STService service,
    ConfigDataManager configMgr,
  ) async {}

  /// 对齐 iOS 子类重写点：refreshPage 完成通用列表刷新后。
  Future<void> afterRefreshPage(
    STService service,
    ConfigDataManager configMgr,
  ) async {}

  /// 对齐 iOS 子类重写点：viewWillAppear 中父类逻辑之后。
  void afterWillAppear({required bool wasFirstLoad}) {}

  /// 写入原生卡片缓存并同步到 [cardDataCache]（供 Widget 读取）
  void syncNativePayload(ConfigCardItemData card, Map<String, dynamic> data) {
    cacheNativeCardData(card, data);
    cardDataCache['${card.cardStyle}_${card.cardId}'] = data;
  }

  /// 初始化视图（对齐 iOS viewDidLoad 中的 initial）
  Future<void> onViewDidLoad() async {
    final configMgr = ref.read(configDataManagerProvider);
    final service = ref.read(stServiceProvider);

    if ((preferPageApiOnInitialLoad || _cards.isEmpty) &&
        pageListId != null &&
        pageListId! > 0) {
      await _fetchCardsFromPageApi(service);
    }

    // 加载卡片数据（按 cardStyle 分发）
    await _loadCardData(service, configMgr);

    if (enableMineBusinessLayer) {
      if (ref.read(userStateProvider).isLogin) {
        await _loadMineDomainData(service);
      } else {
        await _refreshPartnerSummaryGuestIfNeeded();
      }
    }

    if (ref.read(userStateProvider).isLogin && _needsWalletPolling) {
      await _pollWalletData();
    }

    await afterViewDidLoad(service, configMgr);
  }

  Future<void> _fetchCardsFromPageApi(STService service) async {
    final pid = pageListId;
    if (pid == null || pid <= 0) return;
    try {
      final data = await service.fetchPageConfiguration(pageId: pid);
      if (data == null) return;

      _applyPageInfoPayload(data);

      if (data['nav'] != null) {
        final rawNav = data['nav'];
        if (rawNav is Map<String, dynamic>) {
          final nav = NavInfo.fromJson(rawNav);
          final actionCount = nav.actionItems?.length ?? 0;
          final subTabCount = nav.subTabs?.length ?? 0;
          debugPrint(
            '🧭 PageNavConfig page_id=$pid '
            'nav_style="${nav.navigationStyle ?? ''}" '
            'title="${nav.title ?? ''}" '
            'icon="${nav.icon ?? ''}" '
            'actions=$actionCount sub_tabs=$subTabCount '
            'raw=${nav.toJson()}',
          );
        } else {
          debugPrint('🧭 PageNavConfig page_id=$pid nav=(non-map) $rawNav');
        }
      }

      final raw =
          (data['cards'] as List<dynamic>?) ??
          ((data['page'] as Map<String, dynamic>?)?['cards'] as List<dynamic>?);
      if (raw == null || raw.isEmpty) return;
      _cards = raw
          .map((e) => ConfigCardItemData.fromJson(e as Map<String, dynamic>))
          .toList();
      _debugPrintPageApiCardStyles(pid, raw, _cards);
      _writePageChromeToConfig(cardItems: _cards);
      debugPrint(
        '📄 CardListController: page API loaded ${_cards.length} cards (page_id=$pid)',
      );
    } catch (e) {
      debugPrint('⚠️ _fetchCardsFromPageApi: $e');
    }
  }

  void _debugPrintPageApiCardStyles(
    int pageId,
    List<dynamic> rawCards,
    List<ConfigCardItemData> parsedCards,
  ) {
    for (var i = 0; i < rawCards.length; i++) {
      final raw = rawCards[i];
      if (raw is! Map) {
        debugPrint(
          'CardListController page API card_style page_id=$pageId '
          'index=$i raw=(non-map) $raw',
        );
        continue;
      }
      final rawMap = Map<dynamic, dynamic>.from(raw);
      final parsed = i < parsedCards.length ? parsedCards[i] : null;
      debugPrint(
        'CardListController page API card_style page_id=$pageId '
        'index=$i '
        'code="${rawMap['code'] ?? rawMap['cardId'] ?? ''}" '
        'card_style="${rawMap['card_style'] ?? ''}" '
        'style="${rawMap['style'] ?? ''}" '
        'cardStyle="${rawMap['cardStyle'] ?? ''}" '
        'parsed_cardStyle="${parsed?.cardStyle ?? ''}" '
        'isShow=${parsed?.isShow ?? ''} '
        'title="${rawMap['title'] ?? parsed?.title ?? ''}"',
      );
    }
  }

  /// 对齐 iOS `requestPageInfoWithCompletion`：刷新 bg/nav + cards
  void _applyPageInfoPayload(Map<String, dynamic> data) {
    final base = _pageChrome ?? sourceTabBarItem;
    if (base == null) return;

    NavInfo? navInfo = base.navInfo;
    final navRaw = data['nav'];
    if (navRaw is Map<String, dynamic>) {
      navInfo = NavInfo.fromJson(navRaw);
    } else if (navRaw == null) {
      navInfo = null;
    }

    final updated = base.copyWith(
      bgColor:
          data['bg_color']?.toString() ??
          data['bgColor']?.toString() ??
          base.bgColor,
      bgIcon:
          data['bg_image']?.toString() ??
          data['bg_icon']?.toString() ??
          data['bgIcon']?.toString() ??
          base.bgIcon,
      bgIconDark:
          data['bg_image_dark']?.toString() ??
          data['bg_icon_dark']?.toString() ??
          data['bgIconDark']?.toString() ??
          base.bgIconDark,
      navInfo: navInfo,
    );

    _pageChrome = updated;
    _writePageChromeToConfig(cardItems: base.cardItems);
    _notifySafe();
  }

  void _writePageChromeToConfig({List<ConfigCardItemData>? cardItems}) {
    final tab = _pageChrome ?? sourceTabBarItem;
    if (tab == null) return;
    final mgr = ref.read(configDataManagerProvider);
    final idx = mgr.indexOfTabBarItem(
      tabId: tab.tabId,
      pageId: tab.pageId > 0 ? tab.pageId : pageListId,
    );
    if (idx != null) {
      mgr.updateTabBarItem(
        idx,
        tab.copyWith(cardItems: cardItems ?? tab.cardItems),
      );
    }
  }

  /// 初始化卡片列表
  void initialize(List<ConfigCardItemData> cards) {
    _cards = cards;
    cardDataCache.clear();
    _clearCardCache();
    _notifySafe();
  }

  /// 重新拉取所有 `categorymarket` 族卡片（分类 Tab 切换后调用）
  Future<void> reloadCategoryMarketCards() async {
    final service = ref.read(stServiceProvider);
    final configMgr = ref.read(configDataManagerProvider);
    configMgr.resetCategoryMarketPaging();
    for (final card in _cards) {
      if (!card.isShow) continue;
      if (card.cardStyle.startsWith('categorymarket_')) {
        await _reloadCategoryMarketCard(
          card,
          service,
          configMgr,
          append: false,
        );
      }
    }
    _notifySafe();
  }

  /// `categorymarket` 分页
  Future<void> loadMoreCategoryMarket(ConfigCardItemData card) async {
    final mgr = ref.read(configDataManagerProvider);
    if (!mgr.categoryMarketHasMore || mgr.categoryMarketLoading) return;
    final service = ref.read(stServiceProvider);
    await _reloadCategoryMarketCard(card, service, mgr, append: true);
    _notifySafe();
  }

  Future<void> _reloadCategoryMarketCard(
    ConfigCardItemData card,
    STService service,
    ConfigDataManager configMgr, {
    required bool append,
  }) async {
    configMgr.categoryMarketLoading = true;
    configMgr.categoryMarketLoadMoreRequest = append;
    _notifySafe();
    try {
      final rank = configMgr.selectedCategorySymbolGroup;
      final rt = (rank >= 0 && rank <= 8) ? rank : 0;
      final offset = append ? configMgr.categoryMarketNextOffset : 0;
      final limit = configMgr.categoryMarketPageSize > 0
          ? configMgr.categoryMarketPageSize
          : kCategoryMarketSymbolsPageDefault;

      List<CategoryMarketProductModel> prevModels = [];
      if (append) {
        final rawPrev =
            cardDataCache['${card.cardStyle}_${card.cardId}']?['products']
                as List?;
        if (rawPrev != null) {
          for (final e in rawPrev) {
            if (e is CategoryMarketProductModel) {
              prevModels.add(e);
            } else if (e is Map<String, dynamic>) {
              prevModels.add(CategoryMarketProductModel.fromJson(e));
            }
          }
        }
      }

      final products = await CardFactory.loadCategoryMarketCardData(
        card: card,
        service: service,
        configMgr: configMgr,
        rankType: rt,
        offset: offset,
        limit: limit,
      );

      final merged = append ? [...prevModels, ...products] : products;
      syncNativePayload(card, {'products': merged});
      debugPrint(
        '📊 CategoryMarket ${card.cardStyle}: ${merged.length} rows append=$append',
      );
    } catch (e) {
      debugPrint('⚠️ categorymarket: $e');
    } finally {
      configMgr.categoryMarketLoading = false;
      configMgr.categoryMarketLoadMoreRequest = false;
      _notifySafe();
    }
  }

  void _applyCategoryDefaultSelection(
    ConfigCardItemData card,
    ConfigDataManager configMgr,
  ) {
    final items = card.cardDetail?['items'] as List?;
    if (items == null || items.isEmpty) return;
    if (configMgr.selectedCategorySymbolGroup >= 0) return;
    final first = items.first;
    if (first is! Map) return;
    final g = first['symbol_group'] ?? first['symbolGroup'];
    final gi = g is int ? g : int.tryParse('$g');
    if (gi != null && gi >= 0) {
      configMgr.selectedCategorySymbolGroup = gi;
    }
  }

  /// 刷新页面（对齐 iOS refreshPage）
  Future<void> refreshPage() async {
    final configMgr = ref.read(configDataManagerProvider);
    configMgr.resetCategoryMarketPaging();
    final hasVisibleCards = filteredCards.isNotEmpty;

    if (hasVisibleCards) {
      _isRefreshing = true;
      _notifySafe();
    }

    // 对齐 iOS: 登出/未登录时先清空 header/balance/account 展示数据
    if (!ref.read(userStateProvider).isLogin) {
      _clearWalletOrientedCardData();
    }

    try {
      final service = ref.read(stServiceProvider);
      if (pageListId != null && pageListId! > 0) {
        await _fetchCardsFromPageApi(service);
      }
      await _loadCardData(
        service,
        configMgr,
        showLoadingIndicator: !hasVisibleCards,
      );

      if (enableMineBusinessLayer) {
        if (ref.read(userStateProvider).isLogin) {
          await _loadMineDomainData(service);
        } else {
          await _refreshPartnerSummaryGuestIfNeeded();
        }
      }

      await afterRefreshPage(service, configMgr);

      if (_isVisible) {
        startMarketSocket();
      }
    } finally {
      if (_isRefreshing) {
        _isRefreshing = false;
        _notifySafe();
      }
    }

    _notifySafe();
  }

  /// 登录态变化（对齐 iOS STLoginPreSuccess / STLogoutSuccess → userStateChanged）
  Future<void> onLoginStateChanged() async {
    stopWalletPolling();
    await refreshPage();
    if (_isVisible && ref.read(userStateProvider).isLogin) {
      startWalletPolling();
    }
  }

  /// 登出或未登录时清空余额/账户卡片缓存（对齐 iOS refreshPage 前 update*Card）
  void _clearWalletOrientedCardData() {
    final configMgr = ref.read(configDataManagerProvider);
    final cleared = <String, dynamic>{
      'wallets': const [],
      'last_update': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
    configMgr.updateBalanceCardData(cleared);
    configMgr.updateAccountCardData(cleared);
    configMgr.updateHeaderCardData(cleared);
  }

  /// 仅刷新 `selfmarket_*` 卡片（自选 API），用于一键添加后更新列表形态。
  Future<void> refreshSelfMarketCards() async {
    final service = ref.read(stServiceProvider);
    final configMgr = ref.read(configDataManagerProvider);
    final loggedIn = ref.read(userStateProvider).isLogin;
    for (final card in _cards) {
      if (!card.isShow) continue;
      if (!card.cardStyle.startsWith('selfmarket_')) continue;
      try {
        final products = await CardFactory.loadSelfMarketCardData(
          card: card,
          service: service,
          configMgr: configMgr,
          isLoggedIn: loggedIn,
        );
        syncNativePayload(card, {'products': products});
      } catch (e) {
        debugPrint('⚠️ refreshSelfMarketCards [${card.cardStyle}]: $e');
      }
    }
    _notifySafe();
  }

  /// 按 cardStyle 分发数据加载
  Future<void> _loadCardData(
    STService service,
    ConfigDataManager configMgr, {
    bool showLoadingIndicator = true,
  }) async {
    if (showLoadingIndicator) {
      _isLoading = true;
      _notifySafe();
    }

    debugPrint(
      '📄 CardListController._loadCardData: loading ${_cards.length} cards',
    );
    final loggedIn = ref.read(userStateProvider).isLogin;
    for (final card in _cards) {
      if (card.cardStyle.startsWith('category_')) {
        _applyCategoryDefaultSelection(card, configMgr);
      }
    }

    for (final card in _cards) {
      if (!card.isShow) {
        debugPrint(
          '📄 CardListController: skipping hidden card style="${card.cardStyle}"',
        );
        continue;
      }

      try {
        if (card.cardStyle.startsWith('market_')) {
          final products = await CardFactory.loadMarketCardData(
            card: card,
            service: service,
            configMgr: configMgr,
          );
          syncNativePayload(card, {'products': products});
          debugPrint('📊 Market card loaded: ${products.length} products');
        } else if (card.cardStyle.startsWith('selfmarket_')) {
          final products = await CardFactory.loadSelfMarketCardData(
            card: card,
            service: service,
            configMgr: configMgr,
            isLoggedIn: loggedIn,
          );
          syncNativePayload(card, {'products': products});
          debugPrint('📊 SelfMarket card loaded: ${products.length} products');
        } else if (card.cardStyle.startsWith('categorymarket_')) {
          await _reloadCategoryMarketCard(
            card,
            service,
            configMgr,
            append: false,
          );
        } else if (card.cardStyle.startsWith('vip_')) {
          final data = await CardFactory.loadVipCardData(
            card: card,
            service: service,
          );
          if (data != null) {
            syncNativePayload(card, data);
            ref.read(userStateProvider.notifier).updateVipLevelPayload(data);
          }
        } else if (card.cardStyle.startsWith('unlock_')) {
          final progress = await CardFactory.loadUnlockCardData(
            card: card,
            service: service,
          );
          if (progress != null) {
            progress['activity_url'] = ref
                .read(userStateProvider)
                .h5AddressModel
                ?.tradeUnlockActivityUrl;
            syncNativePayload(card, progress);
          }
        } else if (card.cardStyle.startsWith('banner_')) {
          // Banner items 来自 cardDetail（payload），无需独立 API 请求
          debugPrint('🖼️ Banner card items from cardDetail');
        } else if (card.cardStyle.startsWith('newslist_')) {
          final newsItems = await CardFactory.loadNewsListCardData(
            card: card,
            service: service,
            limit: 4,
          );
          cardDataCache['${card.cardStyle}_news'] = newsItems;
          cacheNativeCardData(card, {'newsItems': newsItems});
          debugPrint('📰 Newslist card loaded: ${newsItems.length} items');
        } else if (card.cardStyle.startsWith('nav_') ||
            card.cardStyle.startsWith('tabnav_')) {
          // Navigation cards — items from cardDetail, no API needed
          debugPrint('🧭 NaviBar card items from cardDetail');
        } else if (card.cardTypedef == 'web' ||
            card.cardTypedef == 'mini' ||
            card.cardType == 'web' ||
            card.cardType == 'online') {
          debugPrint('🌐 Embed card skip API: ${card.cardStyle}');
        }
        // header_/balance_/account_ 等使用本地数据，不需要请求
      } catch (e) {
        debugPrint('⚠️ Card data load error [${card.cardStyle}]: $e');
      }
    }

    if (showLoadingIndicator) {
      _isLoading = false;
      _notifySafe();
    }
  }

  // ==================== 卡片数据刷新（对齐 iOS update*CardData） ====================

  /// 刷新 Header 卡片数据（viewWillAppear 时调用）
  void _refreshHeaderCardData() {
    // 延迟到首帧后，避免在 didChangeDependencies 构建阶段修改 Provider。
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_inactive) return;
      final configMgr = ref.read(configDataManagerProvider);
      final userData = <String, dynamic>{
        'last_update': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };
      configMgr.updateHeaderCardData(userData);
    });
  }

  /// 清除卡片缓存（key 与 [cacheNativeCardData] 一致：`style_id`）
  void _clearCardCache() {
    final nativeKeys = _cards.map((c) => '${c.cardStyle}_${c.cardId}').toSet();
    _nativeCardCache.removeWhere((key, _) => !nativeKeys.contains(key));
  }

  /// 确保钱包轮询定时器运行（当页面再次可见时重启）
  /// 对齐 iOS: viewWillAppear 中检查 polling 状态，如已停止则重新 start
  void _ensureWalletPolling() {
    if (!_needsWalletPolling) return;
    if (_walletPollingTimer != null && _walletPollingTimer!.isActive) return;
    // 重新启动轮询（_isPollingWallet 已在 stop 时重置为 false）
    startWalletPolling();
  }

  /// 刷新非本地卡片数据（对齐 iOS: viewWillAppear → update*CardData）
  /// 按 cardStyle 刷新需要 API 请求的卡片类型
  void _refreshCardData() {
    final service = ref.read(stServiceProvider);
    final configMgr = ref.read(configDataManagerProvider);
    final loggedIn = ref.read(userStateProvider).isLogin;

    for (final card in _cards) {
      if (!card.isShow) continue;

      if (card.cardStyle.startsWith('market_')) {
        CardFactory.loadMarketCardData(
          card: card,
          service: service,
          configMgr: configMgr,
        ).then((products) {
          if (_inactive) return;
          syncNativePayload(card, {'products': products});
          _notifySafe();
        });
      } else if (card.cardStyle.startsWith('selfmarket_')) {
        CardFactory.loadSelfMarketCardData(
          card: card,
          service: service,
          configMgr: configMgr,
          isLoggedIn: loggedIn,
        ).then((products) {
          if (_inactive) return;
          syncNativePayload(card, {'products': products});
          _notifySafe();
        });
      } else if (card.cardStyle.startsWith('categorymarket_')) {
        _reloadCategoryMarketCard(card, service, configMgr, append: false).then(
          (_) {
            if (_inactive) return;
            _notifySafe();
          },
        );
      } else if (card.cardStyle.startsWith('newslist_')) {
        CardFactory.loadNewsListCardData(card: card, service: service).then((
          items,
        ) {
          if (_inactive) return;
          cardDataCache['${card.cardStyle}_news'] = items;
          _notifySafe();
        });
      } else if (card.cardStyle.startsWith('vip_')) {
        CardFactory.loadVipCardData(card: card, service: service).then((data) {
          if (_inactive || data == null) return;
          syncNativePayload(card, data);
          ref.read(userStateProvider.notifier).updateVipLevelPayload(data);
          _notifySafe();
        });
      }
      // banner_/unlock_ 数据来自 cardDetail payload，无需刷新
    }
  }

  // ==================== 生命周期（对齐 iOS） ====================

  /// viewWillAppear（对齐 iOS STProjectListViewController viewWillAppear）
  void onWillAppear() {
    final wasFirstLoad = _isFirstLoad;
    _isVisible = true;

    if (enableMineBusinessLayer) {
      final mineUser = ref.read(userStateProvider);
      if (mineUser.isNeedJumpToTrade) {
        ref.read(userStateProvider.notifier).updateNeedJumpToTrade(false);
        return;
      }
    }

    if (!_isFirstLoad) {
      // 非首次加载：
      // 1. 刷新钱包数据（单次轮询）
      if (_needsWalletPolling) {
        _pollWalletData();
      }
      // 2. 重启钱包轮询定时器（对齐 iOS: viewWillAppear → start polling）
      _ensureWalletPolling();
      // 3. 刷新各类卡片数据（对齐 iOS: viewWillAppear → update*CardData）
      _refreshCardData();
      // 4. 「我的」域接口（实名、返佣等），对齐原 MinePage viewWillAppear
      if (enableMineBusinessLayer) {
        final loggedIn = ref.read(userStateProvider).isLogin;
        if (loggedIn) {
          unawaited(_loadMineDomainData(ref.read(stServiceProvider)));
        } else {
          unawaited(_refreshPartnerSummaryGuestIfNeeded());
        }
      }
    }

    // 刷新 Header 卡片数据（对齐 iOS: viewWillAppear → updateHeaderCardData）
    _refreshHeaderCardData();

    // 对齐 iOS STProjectListViewController.viewWillAppear → requestUserInfo
    _requestUserInfoIfNeeded();

    afterWillAppear(wasFirstLoad: wasFirstLoad);
  }

  /// viewDidAppear
  void onDidAppear() {
    if (_isFirstLoad) {
      _isFirstLoad = false;
    }

    // 对齐 iOS viewDidAppear：页面每次重新可见都要夺回行情订阅。
    startMarketSocket();

    // 启动钱包轮询
    startWalletPolling();
  }

  /// viewWillDisappear
  void onWillDisappear() {
    _isVisible = false;

    // 停止行情订阅
    stopMarketSocket();

    // 停止钱包轮询
    stopWalletPolling();
  }

  // ==================== WebSocket 行情订阅 ====================

  /// 检查是否需要行情卡片的 WebSocket
  bool get _hasMarketCards {
    return _cards.any(
      (c) =>
          c.cardStyle.startsWith('market_') ||
          c.cardStyle.startsWith('selfmarket_') ||
          c.cardStyle.startsWith('categorymarket_'),
    );
  }

  /// 检查是否需要钱包轮询（未真实登录时不轮询，对齐 iOS 仅 isLogin 拉钱包）
  bool get _needsWalletPolling {
    if (enableMineBusinessLayer) return true;
    if (!ref.read(userStateProvider).isLogin) return false;
    return _cards.any(
      (c) =>
          c.cardStyle.startsWith('balance_') ||
          c.cardStyle.startsWith('account_'),
    );
  }

  /// 启动行情 WebSocket
  void startMarketSocket() {
    if (_inactive || _isMarketSocketRunning || !_hasMarketCards) return;

    final ws = ref.read(marketWebSocketProvider);
    ws.connect();
    ws.sendEnterMarketList(0); // rankType = 0（全部）

    _marketWsSub?.cancel();
    _marketWsSub = ws.messageStream.listen((message) {
      if (_inactive) return;
      if (message.type == 'UPDATE_SYMBOL_LIST_PRICE') {
        _onPriceUpdate(message);
      }
    });

    _isMarketSocketRunning = true;
    debugPrint('📡 Market WebSocket started');
  }

  /// 停止行情 WebSocket
  void stopMarketSocket() {
    _marketWsSub?.cancel();
    _marketWsSub = null;
    if (!_isMarketSocketRunning) return;

    _isMarketSocketRunning = false;
    try {
      final ws = ref.read(marketWebSocketProvider);
      ws.sendEnterEmpty();
      ws.disconnect();
    } catch (e) {
      debugPrint('📡 stopMarketSocket: $e');
    }
    debugPrint('📡 Market WebSocket stopped');
  }

  /// 处理价格更新
  void _onPriceUpdate(MarketWSMessage message) {
    if (_inactive) return;
    final dataList = message.data['data'] as List<dynamic>?;
    if (dataList == null) return;

    final configMgr = ref.read(configDataManagerProvider);

    for (final item in dataList) {
      final update = SocketUpdateListModel.fromJson(
        item as Map<String, dynamic>,
      );
      final index = configMgr.productIndexForSymbol(update.symbol);
      if (index >= 0) {
        configMgr.applySocketUpdate(update, index);
        _syncCachedProductUpdate(configMgr.productList[index]);
      }
    }

    _notifySafe();
  }

  void _syncCachedProductUpdate(MarketProductModel updated) {
    if (updated.symbol.isEmpty) return;

    for (final payload in cardDataCache.values) {
      if (payload is! Map) continue;
      final products = payload['products'];
      if (products is! List) continue;

      for (var i = 0; i < products.length; i++) {
        final product = products[i];
        if (product is MarketProductModel && product.symbol == updated.symbol) {
          products[i] = product.copyWith(
            price: updated.price,
            buy: updated.buy,
            sell: updated.sell,
            spread: updated.spread,
            change: updated.change,
            changePercent: updated.changePercent,
            high: updated.high,
            low: updated.low,
            points: updated.points,
            buyPriceChangeDirection: updated.buyPriceChangeDirection,
            sellPriceChangeDirection: updated.sellPriceChangeDirection,
            lastBuyPriceChangeAt: updated.lastBuyPriceChangeAt,
            lastSellPriceChangeAt: updated.lastSellPriceChangeAt,
          );
        } else if (product is SelfMarketProductModel &&
            product.symbol == updated.symbol) {
          product.price = updated.price;
          product.buy = updated.buy;
          product.sell = updated.sell;
          product.spread = updated.spread;
          product.change = updated.change;
          product.changePercent = updated.changePercent;
          product.precision = updated.precision;
          product.points = updated.points;
        } else if (product is CategoryMarketProductModel &&
            product.symbol == updated.symbol) {
          product.price = updated.price;
          product.buy = updated.buy;
          product.sell = updated.sell;
          product.spread = updated.spread;
          product.change = updated.change;
          product.changePercent = updated.changePercent;
          product.precision = updated.precision;
          product.sparklinePrices = updated.points;
        } else if (product is Map) {
          final symbol = product['symbol']?.toString() ?? '';
          if (symbol != updated.symbol) continue;
          product['price'] = updated.price;
          product['last_price'] = updated.price;
          product['buy'] = updated.buy;
          product['ask'] = updated.buy;
          product['sell'] = updated.sell;
          product['bid'] = updated.sell;
          product['spread'] = updated.spread;
          product['change'] = updated.change;
          product['change_percent'] = updated.changePercent;
          product['precision'] = updated.precision;
          product['points'] = updated.points;
        }
      }
    }
  }

  // ==================== 钱包轮询 ====================

  /// 启动钱包轮询
  void startWalletPolling() {
    if (_inactive || _isPollingWallet || !_needsWalletPolling) return;

    _isPollingWallet = true;

    // 每 5 秒轮询一次
    _walletPollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_inactive) return;
      _pollWalletData();
    });

    // 立即执行一次
    _pollWalletData();
    debugPrint('💰 Wallet polling started');
  }

  /// 停止钱包轮询
  void stopWalletPolling() {
    _walletPollingTimer?.cancel();
    _walletPollingTimer = null;
    _isPollingWallet = false;
  }

  /// 轮询钱包数据
  Future<void> _pollWalletData() async {
    if (_inactive) return;
    if (!_needsWalletPolling) return;
    if (!enableMineBusinessLayer && !ref.read(userStateProvider).isLogin) {
      return;
    }
    if (enableMineBusinessLayer && !ref.read(userStateProvider).isLogin) return;
    try {
      final service = ref.read(stServiceProvider);
      final configMgr = ref.read(configDataManagerProvider);
      final wallets = await service.getWalletList();
      if (_inactive) return;
      debugPrint('💰 Wallet data refreshed: ${wallets.length} wallets');

      if (enableMineBusinessLayer) {
        final models = wallets
            .whereType<Map<String, dynamic>>()
            .map(WalletModel.fromJson)
            .toList();
        ref.read(userStateProvider.notifier).updateWallets(models);
      }

      // 更新余额/账户卡片数据（对齐 iOS: 轮询回调 → updateBalanceCardData + updateAccountCardData）
      final walletData = <String, dynamic>{
        'wallets': wallets,
        'last_update': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };
      configMgr.updateBalanceCardData(walletData);
      configMgr.updateAccountCardData(walletData);
    } catch (e) {
      debugPrint('💰 Wallet polling error: $e');
    }
  }

  // ==================== 「我的」域数据（对齐 iOS NewMine / STProjectListViewController 刷新） ====================

  bool get _mineHasAccount3Card =>
      enableMineBusinessLayer &&
      _cards.any((c) => c.cardStyle == 'account_3' && c.isShow);

  /// 访客态仍拉取返佣摘要（对齐 iOS 未登录返佣卡可展示接口数值；失败则保持 `--`）
  Future<void> _refreshPartnerSummaryGuestIfNeeded() async {
    if (!_mineHasAccount3Card) return;
    if (ref.read(userStateProvider).isLogin) return;
    if (_inactive) return;
    try {
      await _mineFetchPartnerSummary(
        ref.read(stServiceProvider),
        ref.read(userStateProvider.notifier),
      );
      _notifySafe();
    } catch (e) {
      debugPrint('⚠️ _refreshPartnerSummaryGuestIfNeeded: $e');
    }
  }

  Future<void> _loadMineDomainData(STService service) async {
    if (!ref.read(userStateProvider).isLogin) return;
    if (_inactive) return;
    final notifier = ref.read(userStateProvider.notifier);
    try {
      await Future.wait([
        _mineFetchWalletStack(service, notifier),
        _mineFetchPartnerSummary(service, notifier),
        _mineFetchTransactionGroup(service, notifier),
        _mineFetchProfileNickname(service, notifier),
        _mineFetchVipPayload(service, notifier),
        _mineFetchTradeAccounts(service, notifier),
      ]);
    } catch (e) {
      debugPrint('⚠️ _loadMineDomainData: $e');
    }
  }

  Future<void> _mineFetchWalletStack(
    STService service,
    UserStateNotifier notifier,
  ) async {
    await Future.wait([
      _mineFetchWalletList(service, notifier),
      _mineFetchVerificationConfig(service, notifier),
      _mineFetchAuthStatus(service, notifier),
    ]);
  }

  Future<void> _mineFetchWalletList(
    STService service,
    UserStateNotifier notifier,
  ) async {
    try {
      final walletData = await service.getWalletList();
      final wallets = walletData
          .whereType<Map<String, dynamic>>()
          .map(WalletModel.fromJson)
          .toList();
      notifier.updateWallets(wallets);
    } catch (e) {
      debugPrint('Mine domain walletList: $e');
    }
  }

  Future<void> _mineFetchVerificationConfig(
    STService service,
    UserStateNotifier notifier,
  ) async {
    try {
      final rawList = await service.getVerificationConfig();
      final config = rawList
          .whereType<Map<String, dynamic>>()
          .map(STVerificationModel.fromJson)
          .toList();
      notifier.updateVerificationConfig(config);
    } catch (e) {
      debugPrint('Mine domain verificationConfig: $e');
    }
  }

  Future<void> _mineFetchAuthStatus(
    STService service,
    UserStateNotifier notifier,
  ) async {
    try {
      final authData = await service.getAuthStatus();
      if (authData['status'] != null) {
        notifier.updateAuthStatus(AuthStatusModel.fromJson(authData));
      } else {
        notifier.updateAuthStatus(const AuthStatusModel(status: 'none'));
      }
    } catch (e) {
      debugPrint('Mine domain authStatus: $e');
    }
  }

  Future<void> _mineFetchTransactionGroup(
    STService service,
    UserStateNotifier notifier,
  ) async {
    try {
      final data = await service.getTransactionGroupDetail();
      final list = data['margin_ratio_list'] as List<dynamic>?;
      if (list != null && list.isNotEmpty) {
        final first = list.first as Map<String, dynamic>;
        notifier.updateTransactionAccounts({
          'margin_call_ratio': first['margin_call_ratio'],
          'margin_stop_out_ratio': first['margin_stop_out_ratio'],
        });
      }
    } catch (e) {
      debugPrint('Mine domain transactionGroup: $e');
    }
  }

  Future<void> _mineFetchPartnerSummary(
    STService service,
    UserStateNotifier notifier,
  ) async {
    try {
      final response = await service.getPartnerSummary();
      final total = response['total_commission_amount']?.toString() ?? '0.00';
      final available =
          response['available_commission_amount']?.toString() ?? '0.00';
      final withdrawn =
          response['withdraw_commission_amount']?.toString() ?? '0.00';
      notifier.updateCommissionData(
        totalRevenue: total,
        canWithdraw: available,
        withdrawnFunds: withdrawn,
      );
    } catch (e) {
      debugPrint('Mine domain partnerSummary: $e');
    }
  }

  Future<void> _mineFetchTradeAccounts(
    STService service,
    UserStateNotifier notifier,
  ) async {
    try {
      final raw = await service.getTradeAccounts();
      final list = <STAccountModel>[];
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          list.add(STAccountModel.fromJson(e));
        } else if (e is Map) {
          list.add(
            STAccountModel.fromJson(
              Map<String, dynamic>.from(Map<dynamic, dynamic>.from(e)),
            ),
          );
        }
      }
      notifier.updateAccounts(list);
    } catch (e) {
      debugPrint('Mine domain tradeAccounts: $e');
    }
  }

  Future<void> _mineFetchVipPayload(
    STService service,
    UserStateNotifier notifier,
  ) async {
    try {
      final raw = await service.getLevel();
      Map<String, dynamic>? data;
      final d = raw['data'];
      if (d is Map<String, dynamic>) {
        data = Map<String, dynamic>.from(d);
      } else if (d is Map) {
        data = Map<String, dynamic>.from(Map<dynamic, dynamic>.from(d));
      } else if (raw.containsKey('current_level') ||
          raw.containsKey('progress')) {
        data = Map<String, dynamic>.from(raw);
      }
      if (data != null) notifier.updateVipLevelPayload(data);
    } catch (e) {
      debugPrint('Mine domain vip: $e');
    }
  }

  Future<void> _mineFetchProfileNickname(
    STService service,
    UserStateNotifier notifier,
  ) async {
    try {
      final raw = await service.getUserProfile();
      Map<String, dynamic> data = raw;
      if (raw['data'] is Map<String, dynamic>) {
        data = raw['data'] as Map<String, dynamic>;
      }
      final name =
          UserState.pickString(data, [
            'nickName',
            'nickname',
            'name',
            'user_name',
            'userName',
          ]) ??
          '';
      if (name.isNotEmpty) {
        notifier.updateNickname(name);
      }
    } catch (e) {
      debugPrint('Mine domain nickname: $e');
    }
  }

  /// 对齐 iOS `requestUserInfo`（无 userInfo 时补拉）
  void _requestUserInfoIfNeeded() {
    final user = ref.read(userStateProvider);
    if (!user.isLogin) return;
    if (user.nickname.isNotEmpty && user.userId.isNotEmpty) return;
    unawaited(
      _mineFetchProfileNickname(
        ref.read(stServiceProvider),
        ref.read(userStateProvider.notifier),
      ),
    );
  }

  @override
  void dispose() {
    _inactive = true;
    stopMarketSocket();
    stopWalletPolling();
    super.dispose();
  }
}
