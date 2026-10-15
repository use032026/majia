import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/card_tool.dart';
import '../../core/config/config_data_manager.dart';
import '../../core/providers/app_events.dart';
import '../../core/providers/event_bus.dart';
import '../../core/providers/tab_shell_navigation.dart';
import '../../shared/widgets/st_nav_action.dart';
import '../../core/models/market_product_model.dart';
import '../../core/models/tab_bar_item.dart';
import '../../core/models/user_state.dart';
import '../../core/network/market_websocket.dart';
import '../../core/network/st_service.dart';
import 'category_market_list_page.dart';
import 'market_tab_config.dart';
import 'market_tab_schema.dart';
import 'optional_list_page.dart';
import '../../shared/widgets/st_localized_prompt.dart';

/// 底部 Tab `router == /market` 或 schema `page-market` + `/tab`（对齐 iOS [STMarketController]）
///
/// - **主分段**：默认「自选 / 行情」；若传入 [mainSegments]（来自 CMS `nav.tabs`），则标题与
///   `title_color` / `title_sel_color` / `title_font` / `title_sel_font` / `title_weight` 等与
///   [CompoundTabPage] 一致。
/// - **左右滑动**：主分段之间为横向 [PageView]（对齐 iOS `UIPageViewController` / 自选 ⟷ 分类行情）。
/// - **子页**：无 [mainSegments] 时固定为 [OptionalListPage] + [MarketHqSection]；有 [mainSegments] 时
///   按各子项 `page.cards` 构建：含 `category_*` → [MarketHqSection]，否则 → [OptionalListPage]。
/// - **顶栏右侧**：优先当前分段 `tabActionItems`，否则 [navActionItems]（CMS `nav.buttons`）；
///   仍无则回落内置编辑/搜索图标（仅两段 legacy 时）。
///
/// 子类目与兜底见 [MarketTabShellConfig]（`category_1` → `symbol_group`）。
class MarketTabShellPage extends ConsumerStatefulWidget {
  final String? title;

  /// 合并后的 `category_*` 等（无 [mainSegments] 时供 [MarketHqSection]；有 [mainSegments] 时可为空，由各子项自带 cards）
  final List<ConfigCardItemData> tabCards;

  /// CMS `nav.tabs`：主分段标题与样式；与 [TabBarItemData.navInfo] 子项同源
  final List<SubTabItem>? mainSegments;

  /// CMS `nav.buttons`，与 [CompoundTabPage] 一致
  final List<ActionItem>? navActionItems;

  /// 有 [mainSegments] 时的初始选中下标（默认 0，即 CMS 第一个子 Tab）
  final int? initialMainSegmentIndex;

  /// 底栏/复合壳中可能已被 IndexedStack 构建但不可见；不可见时不进入行情 socket 房间。
  final bool isActive;

  const MarketTabShellPage({
    super.key,
    this.title,
    this.tabCards = const [],
    this.mainSegments,
    this.navActionItems,
    this.initialMainSegmentIndex,
    this.isActive = true,
  });

  @override
  ConsumerState<MarketTabShellPage> createState() => _MarketTabShellPageState();
}

class _MarketTabShellPageState extends ConsumerState<MarketTabShellPage>
    with WidgetsBindingObserver {
  StreamSubscription<MarketWSMessage>? _wsSub;
  late final VoidCallback _accountChangedListener;

  late int _mainIndex;
  late final PageController _mainPageController;

  static const Color _kTabMuted = Color(0xFF9A9DA2);
  static const Color _kTabSelected = Color(0xFF000000);
  static const Color _kBarActionIcon = Color(0xFF343434);
  static const Color _kDarkShellBg = Color(0xFF18191A);
  static const Color _kDarkTabSelected = Color(0xFFEDF1F8);
  static const Color _kDarkTabMuted = Color(0xFF6E727D);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final segs = widget.mainSegments;
    if (segs != null && segs.isNotEmpty) {
      final init = widget.initialMainSegmentIndex;
      _mainIndex = init != null ? init.clamp(0, segs.length - 1) : 0;
    } else {
      _mainIndex = 1;
    }
    _mainPageController = PageController(initialPage: _mainIndex);
    _accountChangedListener = () {
      if (!mounted || !widget.isActive) return;
      ref.read(marketWebSocketProvider).reConnect();
      _attachMarketWebSocket();
    };
    EventBus().on(EventBus.accountChanged, _accountChangedListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive) return;
      _attachMarketWebSocket();
    });
  }

  int _mainSegmentPageCount() {
    final segs = widget.mainSegments;
    if (segs != null && segs.isNotEmpty) return segs.length;
    return 2;
  }

  @override
  void didUpdateWidget(covariant MarketTabShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final n = _mainSegmentPageCount();
    if (_mainIndex >= n) {
      final ni = n > 0 ? n - 1 : 0;
      setState(() => _mainIndex = ni);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_mainPageController.hasClients) {
          _mainPageController.jumpToPage(ni);
        }
      });
    }
    if (!oldWidget.isActive && widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.isActive) return;
        _attachMarketWebSocket();
      });
    } else if (oldWidget.isActive && !widget.isActive) {
      _detachMarketWebSocket(sendEmpty: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    EventBus().off(EventBus.accountChanged, _accountChangedListener);
    _mainPageController.dispose();
    _detachMarketWebSocket(sendEmpty: widget.isActive);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!widget.isActive) return;
    final ws = ref.read(marketWebSocketProvider);
    if (state == AppLifecycleState.resumed) {
      _attachMarketWebSocket();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _detachMarketWebSocket(sendEmpty: true);
      ws.disconnect();
    }
  }

  bool _segmentUsesCategorySocket(int index) {
    final segs = widget.mainSegments;
    if (segs != null && index >= 0 && index < segs.length) {
      return _marketSubTabHasCategoryCards(segs[index]);
    }
    return index == 1;
  }

  void _attachMarketWebSocket() {
    if (!mounted || !widget.isActive) {
      _detachMarketWebSocket(sendEmpty: false);
      return;
    }
    final ws = ref.read(marketWebSocketProvider);
    if (ws.state == WSConnectionState.disconnected) {
      ws.reset();
    }
    ws.connect();
    _wsSub?.cancel();
    _wsSub = ws.messageStream.listen(_onMarketWsMessage);
    _sendEnterForVisibleMarket();
  }

  void _detachMarketWebSocket({required bool sendEmpty}) {
    _wsSub?.cancel();
    _wsSub = null;
    if (sendEmpty) {
      try {
        ref.read(marketWebSocketProvider).sendEnterEmpty();
      } catch (_) {}
    }
  }

  void _sendEnterForVisibleMarket() {
    if (!mounted || !widget.isActive) return;
    final ws = ref.read(marketWebSocketProvider);
    if (ws.state == WSConnectionState.disconnected) {
      ws.reset();
      ws.connect();
    }
    if (_segmentUsesCategorySocket(_mainIndex)) {
      final g = ref.read(configDataManagerProvider).selectedCategorySymbolGroup;
      final rt = (g >= 0 && g <= 8) ? g : 0;
      ws.sendEnterMarketList(rt);
    } else {
      ws.sendEnterMarketList(0);
    }
  }

  void _onMarketWsMessage(MarketWSMessage message) {
    if (!mounted || !widget.isActive) return;
    if (message.type != 'UPDATE_SYMBOL_LIST_PRICE') return;
    final dataList = message.data['data'] as List<dynamic>?;
    if (dataList == null) return;
    final configMgr = ref.read(configDataManagerProvider);
    for (final item in dataList) {
      final m = item is Map<String, dynamic>
          ? item
          : Map<String, dynamic>.from(item as Map);
      final update = SocketUpdateListModel.fromJson(m);
      final index = configMgr.productIndexForSymbol(update.symbol);
      if (index >= 0) {
        configMgr.applySocketUpdate(update, index);
      }
    }
  }

  void _onMainPageChanged(int index) {
    if (!mounted || index == _mainIndex) return;
    setState(() => _mainIndex = index);
    _sendEnterForVisibleMarket();
  }

  void _selectMainTab(int index) {
    if (!mounted || index == _mainIndex) return;
    setState(() => _mainIndex = index);
    _sendEnterForVisibleMarket();
    _mainPageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _marketBarTrailingIcon({
    required IconData icon,
    required FutureOr<void> Function() onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? _kDarkTabSelected : _kBarActionIcon;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 52,
        child: Center(child: Icon(icon, color: iconColor, size: 22)),
      ),
    );
  }

  Widget _legacyMainTabLabel({
    required String localizationKey,
    required String fallback,
    required int index,
  }) {
    final selected = _mainIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = isDark ? _kDarkTabSelected : _kTabSelected;
    final mutedColor = isDark ? _kDarkTabMuted : _kTabMuted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _selectMainTab(index),
      child: Center(
        child: STLocalizedTextByKey(
          localizationKey,
          fallback: fallback,
          style: TextStyle(
            fontSize: selected ? 20 : 16,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? selectedColor : mutedColor,
            height: 1.15,
          ),
        ),
      ),
    );
  }

  Widget _cmsMainTabLabel(SubTabItem st, int index) {
    final selected = _mainIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selColor =
        CardTool.parseAdaptiveHexColor(
          context,
          st.titleSelColor,
          category: CardTool.iosDarkModeTextColorKey,
        ) ??
        (isDark ? _kDarkTabSelected : _kTabSelected);
    final unselColor =
        CardTool.parseAdaptiveHexColor(
          context,
          st.titleColor,
          category: CardTool.iosDarkModeTextColorKey,
        ) ??
        (isDark ? _kDarkTabMuted : _kTabMuted);
    final fontSize = (selected ? st.titleSelFont : st.titleFont).toDouble();
    final weight = _marketCmsFontWeightOrDefault(
      selected ? st.titleSelWeight : st.titleWeight,
      selected ? FontWeight.w700 : FontWeight.w500,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _selectMainTab(index),
      child: Center(
        child: Text(
          st.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: weight,
            color: selected ? selColor : unselColor,
            height: 1.15,
          ),
        ),
      ),
    );
  }

  List<ActionItem> _currentTrailingActionItems() {
    final segs = widget.mainSegments;
    if (segs != null &&
        _mainIndex >= 0 &&
        _mainIndex < segs.length &&
        segs[_mainIndex].tabActionItems.isNotEmpty) {
      return segs[_mainIndex].tabActionItems;
    }
    return widget.navActionItems ?? const [];
  }

  bool _usesCurrentSegmentTrailingActions() {
    final segs = widget.mainSegments;
    return segs != null &&
        _mainIndex >= 0 &&
        _mainIndex < segs.length &&
        segs[_mainIndex].tabActionItems.isNotEmpty;
  }

  bool _isMarketSearchAction(ActionItem action) {
    final route = action.router?.trim();
    if (route == '/market/search') return true;
    final title = action.title?.trim().toLowerCase();
    if (title == '搜索' || title == 'search') return true;
    final icon = '${action.icon ?? ''} ${action.iconDark ?? ''}'.toLowerCase();
    return icon.contains('search');
  }

  bool _isMarketEditAction(ActionItem action) {
    final route = action.router?.trim();
    if (route == '/market/watchlist_edit' || route == '/market/edit') {
      return true;
    }
    final title = action.title?.trim().toLowerCase();
    if (title == '编辑' || title == 'edit') return true;
    final icon = '${action.icon ?? ''} ${action.iconDark ?? ''}'.toLowerCase();
    return icon.contains('edit');
  }

  ActionItem? _firstWhereOrNull(
    List<ActionItem> items,
    bool Function(ActionItem) test,
  ) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }

  Future<void> _onConfigNavAction(ActionItem a, {RenderBox? anchor}) async {
    await handleStNavAction(context, a, anchor: anchor);
  }

  List<Widget> _buildTrailingWidgets() {
    final items = _currentTrailingActionItems();
    if (items.isNotEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final usesSegmentActions = _usesCurrentSegmentTrailingActions();
      final searchAction = _firstWhereOrNull(items, _isMarketSearchAction);
      final editAction = _firstWhereOrNull(items, _isMarketEditAction);
      final hasMarketActions = searchAction != null || editAction != null;
      final showEdit =
          usesSegmentActions || !_segmentUsesCategorySocket(_mainIndex);
      final shown = hasMarketActions
          ? [
              if (showEdit && editAction != null) editAction,
              if (searchAction != null) searchAction,
            ]
          : (items.length == 1 ? [items.last] : items.take(2).toList());
      return [
        for (final a in shown)
          _MarketShellNavActionButton(
            action: a,
            isDark: isDark,
            onPressed: () => _onConfigNavAction(a),
          ),
      ];
    }
    final showEdit = !_segmentUsesCategorySocket(_mainIndex);
    return [
      if (showEdit) ...[
        _marketBarTrailingIcon(
          icon: Icons.edit_outlined,
          onTap: () async {
            final changed = await context.push<bool>('/market/watchlist_edit');
            if (changed == true && mounted) {
              notifyWatchlistChanged(ref);
            }
          },
        ),
        const SizedBox(width: 10),
      ],
      _marketBarTrailingIcon(
        icon: Icons.search_rounded,
        onTap: () => context.push('/market/search'),
      ),
    ];
  }

  List<Widget> _shellIndexedChildren() {
    final segs = widget.mainSegments;
    if (segs != null && segs.isNotEmpty) {
      return segs.map(_shellSegmentBody).toList();
    }
    return [
      OptionalListPage(
        key: const PageStorageKey<String>('market_shell_optional'),
        embedded: true,
        title: null,
      ),
      MarketHqSection(
        key: const PageStorageKey<String>('market_shell_hq'),
        tabCards: widget.tabCards,
      ),
    ];
  }

  Widget _shellSegmentBody(SubTabItem st) {
    if (_marketSubTabHasCategoryCards(st)) {
      return MarketHqSection(
        key: ValueKey<String>('hq_${st.pageId}'),
        tabCards: st.cardItems,
      );
    }
    return OptionalListPage(
      embedded: true,
      title: st.title.isNotEmpty ? st.title : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
      configDataManagerProvider.select((m) => m.selectedCategorySymbolGroup),
      (previous, next) {
        if (_segmentUsesCategorySocket(_mainIndex)) {
          _sendEnterForVisibleMarket();
        }
      },
    );
    ref.listen<int?>(marketTabSegmentProvider, (prev, next) {
      if (next == null || !mounted) return;
      final max = _mainSegmentPageCount();
      if (max <= 0) return;
      final idx = next.clamp(0, max - 1);
      if (idx != _mainIndex) {
        _selectMainTab(idx);
      } else if (_mainPageController.hasClients) {
        _mainPageController.jumpToPage(idx);
      }
    });

    final segs = widget.mainSegments;
    final topInset = MediaQuery.paddingOf(context).top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shellBg = isDark ? _kDarkShellBg : Colors.white;
    return Material(
      color: shellBg,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDark
                  ? Brightness.light
                  : Brightness.dark,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            ),
        child: Column(
          children: [
            ColoredBox(
              color: shellBg,
              child: Padding(
                padding: EdgeInsets.only(top: topInset),
                child: SizedBox(
                  height: 52,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20, right: 15),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (segs != null && segs.isNotEmpty)
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 0; i < segs.length; i++) ...[
                                    if (i > 0) const SizedBox(width: 30),
                                    _cmsMainTabLabel(segs[i], i),
                                  ],
                                ],
                              ),
                            ),
                          )
                        else ...[
                          _legacyMainTabLabel(
                            localizationKey: 'optional',
                            fallback: '自选',
                            index: 0,
                          ),
                          const SizedBox(width: 30),
                          _legacyMainTabLabel(
                            localizationKey: 'market',
                            fallback: '行情',
                            index: 1,
                          ),
                        ],
                        if (segs == null || segs.isEmpty) const Spacer(),
                        ..._buildTrailingWidgets(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _mainPageController,
                onPageChanged: _onMainPageChanged,
                children: _shellIndexedChildren(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _marketSubTabHasCategoryCards(SubTabItem st) {
  for (final c in st.cardItems) {
    if (c.cardStyle.toLowerCase().startsWith('category_')) return true;
  }
  return false;
}

FontWeight _marketCmsFontWeight(String? w) {
  return _marketCmsFontWeightOrDefault(w, FontWeight.w400);
}

FontWeight _marketCmsFontWeightOrDefault(String? w, FontWeight fallback) {
  switch (w?.toLowerCase()) {
    case 'bold':
      return FontWeight.w700;
    case 'medium':
      return FontWeight.w500;
    case 'semibold':
      return FontWeight.w600;
    default:
      return fallback;
  }
}

class _MarketShellNavActionButton extends StatelessWidget {
  final ActionItem action;
  final bool isDark;
  final VoidCallback onPressed;

  const _MarketShellNavActionButton({
    required this.action,
    required this.isDark,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final style = action.style ?? 0;
    if (style == 1) {
      final fs = (action.titleFont ?? 14).toDouble();
      final c =
          CardTool.parseHexColor(action.titleColor) ??
          Theme.of(context).colorScheme.onSurface;
      return TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(34, 52),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(
          action.title ?? '',
          style: TextStyle(
            fontSize: fs,
            color: c,
            fontWeight: _marketCmsFontWeight(action.titleWeight),
          ),
        ),
      );
    }
    final iconUrl = isDark && (action.iconDark?.isNotEmpty == true)
        ? action.iconDark!
        : (action.icon ?? '');
    if (iconUrl.isEmpty) {
      return const SizedBox(width: 34, height: 52);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox(
        width: 44,
        height: 52,
        child: Center(
          child: Image.network(
            iconUrl,
            width: 22,
            height: 22,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.more_horiz, size: 22),
          ),
        ),
      ),
    );
  }
}

/// GoRouter 等独立 `/market` 入口：与 [TabShell] 底栏「行情」同一套 UI（自选 + 分类列表），
/// 勿使用 [ConfiguredTabCardPage]（否则会出现卡片顶栏 + 旧版分类列表，与 iOS 不一致）。
class MarketRoutePage extends ConsumerWidget {
  const MarketRoutePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(configDataManagerProvider).tabs;
    TabBarItemData? match;
    for (final t in tabs) {
      if (t.router == '/market') {
        match = t;
        break;
      }
    }
    if (match != null) {
      return MarketTabShellPage(
        title: match.title,
        tabCards: match.cardItems,
        mainSegments: match.navInfo?.subTabs,
        navActionItems: match.navInfo?.actionItems,
      );
    }
    for (final t in tabs) {
      if (tabBarItemIsMarketSchemaCompound(t)) {
        return MarketTabShellPage(
          title: t.title,
          tabCards: mergedMarketTabCardsFromCompoundTab(t),
          mainSegments: t.navInfo?.subTabs,
          navActionItems: t.navInfo?.actionItems,
        );
      }
    }
    return MarketTabShellPage(title: null, tabCards: const []);
  }
}

/// 对齐 iOS `Cards/category_1/.../Category1CardView.m`（`categoryModel.items` → `symbolGroup`）+
/// `STConfigCardHandler` 中 `Card_Style_CategoryMarket` 请求逻辑（`selectedCategorySymbolGroup` 非法时回退 `STMarketRankTypeAll` = 0）+
/// `Categorymarket1CardView`（展示 `categoryMarketModel.items`）。
class MarketHqSection extends ConsumerStatefulWidget {
  final List<ConfigCardItemData> tabCards;
  final bool useIosFixedTabs;

  const MarketHqSection({
    super.key,
    required this.tabCards,
    this.useIosFixedTabs = true,
  });

  @override
  ConsumerState<MarketHqSection> createState() => _MarketHqSectionState();
}

class _MarketHqSectionState extends ConsumerState<MarketHqSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const Color _kMuted = Color(0xFF9A9DA2);
  static const Color _kDarkMuted = Color(0xFF6E727D);

  /// 对齐 Figma：选中主题文字 + 24px/4px 短指示条。
  static const Color _kSelected = Color(0xFF000000);
  static const Color _kDarkSelected = Color(0xFFEDF1F8);
  static const Color _kIndicator = Color(0xFF000000);
  static const Color _kDarkIndicator = Color(0xFFEDF1F8);

  /// 首帧先按当前登录态同步解析，避免先闪出与 iOS 不一致的默认分类。
  List<MarketCategoryTab> _tabs = const <MarketCategoryTab>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(Duration.zero, () async {
        if (!mounted) return;
        await _reconcileTabsFromConfigAndApi();
      });
    });
  }

  @override
  void didUpdateWidget(covariant MarketHqSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabCards != widget.tabCards) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _reconcileTabsFromConfigAndApi();
      });
    }
  }

  Future<void> _reconcileTabsFromConfigAndApi() async {
    if (!mounted) return;
    final isB = ref.read(userStateProvider).isB;
    final syncTabs = widget.useIosFixedTabs
        ? MarketTabShellConfig.iosFallbackTabs(isBUser: isB)
        : MarketTabShellConfig.resolveCategoryTabs(
            tabCards: widget.tabCards,
            isBUser: isB,
          );
    setState(() => _tabs = syncTabs);
    _syncDefaultCategory(_tabs);

    try {
      if (widget.useIosFixedTabs) return;
      final svc = ref.read(stServiceProvider);
      final asyncTabs = await MarketTabShellConfig.resolveCategoryTabsAsync(
        tabCards: widget.tabCards,
        isBUser: isB,
        service: svc,
      );
      if (!mounted) return;
      if (!_sameTabs(asyncTabs, _tabs)) {
        setState(() => _tabs = asyncTabs);
        _syncDefaultCategory(_tabs);
      }
    } catch (_) {}
  }

  bool _sameTabs(List<MarketCategoryTab> a, List<MarketCategoryTab> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].symbolGroup != b[i].symbolGroup || a[i].label != b[i].label) {
        return false;
      }
    }
    return true;
  }

  void _syncDefaultCategory(List<MarketCategoryTab> tabs) {
    if (!mounted) return;
    final mgr = ref.read(configDataManagerProvider);
    if (mgr.selectedCategorySymbolGroup < 0 && tabs.isNotEmpty) {
      mgr.applyCategorySymbolGroupSelection(tabs.first.symbolGroup);
    }
  }

  int _selectedTabIndex(int symbolGroup, List<MarketCategoryTab> tabs) {
    for (var i = 0; i < tabs.length; i++) {
      if (tabs[i].symbolGroup == symbolGroup) return i;
    }
    return -1;
  }

  int _rankTypeForList(int symbolGroup) {
    if (symbolGroup >= 0 && symbolGroup <= 8) return symbolGroup;
    return 0;
  }

  Widget _buildCategoryTabLabel(
    MarketCategoryTab tab, {
    required TextStyle style,
  }) {
    final key = tab.localizationKey;
    if (key == null || key.isEmpty) {
      return Text(tab.label, textAlign: TextAlign.center, style: style);
    }
    return STLocalizedTextByKey(
      key,
      fallback: tab.label,
      textAlign: TextAlign.center,
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen<bool>(userStateProvider.select((s) => s.isB), (previous, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _reconcileTabsFromConfigAndApi();
      });
    });

    final isB = ref.watch(userStateProvider.select((s) => s.isB));
    final tabs = _tabs.isEmpty
        ? (widget.useIosFixedTabs
              ? MarketTabShellConfig.iosFallbackTabs(isBUser: isB)
              : MarketTabShellConfig.resolveCategoryTabs(
                  tabCards: widget.tabCards,
                  isBUser: isB,
                ))
        : _tabs;

    final g = ref.watch(
      configDataManagerProvider.select((m) => m.selectedCategorySymbolGroup),
    );
    final selIdx = _selectedTabIndex(g, tabs);
    final rt = _rankTypeForList(g);

    if (selIdx < 0 && tabs.isNotEmpty) {
      final next = tabs.first.symbolGroup;
      if (g != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref
              .read(configDataManagerProvider)
              .applyCategorySymbolGroupSelection(next);
        });
      }
    }

    final listRt = selIdx < 0 && tabs.isNotEmpty
        ? _rankTypeForList(tabs.first.symbolGroup)
        : rt;

    /// 横向类目：对齐 iOS `Category1CardView`（`UIScrollView` + 横向 `UIStackView`）与
    /// `STMarketHqController`（`JXCategoryTitleView` 高 37）：用 `SingleChildScrollView` + `Row`，
    /// 避免横向 `ListView`/`shrinkWrap` 在嵌套约束下出现宽度为 0 或子项不绘制的问题。
    /// Tab 间距 34 对齐 `Category1CardView` 的 `kCategory1TabSpacing`。
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final tabSelected = isDarkTheme ? _kDarkSelected : _kSelected;
    final tabMuted = isDarkTheme ? _kDarkMuted : _kMuted;
    final tabIndicator = isDarkTheme ? _kDarkIndicator : _kIndicator;
    final shellBg = isDarkTheme ? const Color(0xFF18191A) : Colors.white;
    final borderColor = isDarkTheme
        ? const Color(0xFF2F3340)
        : const Color(0xFFECECEC);

    const categoryBarHeight = 48.0;
    const categoryBorderWidth = 0.5;
    final tabBar = SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < tabs.length; i++) ...[
              if (i > 0) const SizedBox(width: 34),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  ref
                      .read(configDataManagerProvider)
                      .applyCategorySymbolGroupSelection(tabs[i].symbolGroup);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildCategoryTabLabel(
                        tabs[i],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: selIdx == i
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: selIdx == i ? tabSelected : tabMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: selIdx == i ? 4 : 0,
                        width: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selIdx == i
                              ? tabIndicator
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: shellBg,
            border: Border(
              bottom: BorderSide(
                color: borderColor,
                width: categoryBorderWidth,
              ),
            ),
          ),
          padding: const EdgeInsets.only(left: 14, right: 12),
          constraints: const BoxConstraints(minHeight: categoryBarHeight),
          width: double.infinity,
          alignment: Alignment.bottomLeft,
          child: tabBar,
        ),
        Expanded(
          child: ColoredBox(
            color: shellBg,
            child: CategoryMarketListPage(
              // rankType 与 symbol_group 同时进 key，避免仅 rank 碰撞时列表 State 不重拉（对齐 iOS 类目切换筛数）
              key: ValueKey<String>('hq_list_${g}_$listRt'),
              embedded: true,
              rankType: listRt,
              marketSelectedSymbolGroup: g,
              title: null,
              iosStyleRows: true,
            ),
          ),
        ),
      ],
    );
  }
}
