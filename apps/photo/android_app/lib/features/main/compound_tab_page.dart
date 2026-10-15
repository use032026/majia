import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/card_tool.dart';
import '../../core/config/config_data_manager.dart';
import '../../core/models/market_product_model.dart';
import '../../core/models/tab_bar_item.dart';
import '../../core/models/user_state.dart';
import '../../core/network/market_websocket.dart';
import '../../core/network/st_service.dart';
import '../../core/providers/app_events.dart';
import '../../core/providers/tab_shell_navigation.dart';
import '../../core/router/st_router.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../shared/widgets/st_mini_view.dart';
import '../../shared/widgets/st_nav_action.dart';
import '../../shared/widgets/st_localized_prompt.dart';
import '../../shared/widgets/st_tab_web_pages.dart';
import '../home/card_list_page.dart';
import '../market/market_tab_shell_page.dart';
import '../market/optional_list_page.dart';
import '../news/calendar_page.dart';
import '../news/flash_list_page.dart';
import '../news/news_list_page.dart';

/// 复合 Tab 页：对齐 iOS `STTabViewController` + `STNaviTabBarView`（`Navi_Style_Tab`）。
class CompoundTabPage extends ConsumerStatefulWidget {
  final TabBarItemData tab;
  final bool isActive;

  const CompoundTabPage({super.key, required this.tab, this.isActive = true});

  static Widget buildSubTabBody(
    BuildContext context,
    TabBarItemData parentTab,
    SubTabItem st,
  ) {
    return _CompoundTabPageState._buildSubTabBody(context, parentTab, st);
  }

  @override
  ConsumerState<CompoundTabPage> createState() => _CompoundTabPageState();
}

class _CompoundTabPageState extends ConsumerState<CompoundTabPage>
    with TickerProviderStateMixin {
  static const double _navContentHeight = 44;
  static const double _minTabWidth = 60;
  static const double _tabPadding = 14;

  late TabController _controller;
  late TabBarItemData _tab;
  StreamSubscription<MarketWSMessage>? _wsSub;
  var _disposed = false;
  var _pageInfoRequestGeneration = 0;
  var _visibleSubTabIndex = 0;

  List<SubTabItem> get _subTabs => _tab.navInfo?.subTabs ?? [];

  bool get _hasMarketSubTabs => _subTabs.any(
    (st) => st.router == '/optional' || st.router == '/tradeMarket',
  );

  @override
  void initState() {
    super.initState();
    _tab = widget.tab;
    _controller = TabController(length: _max(_subTabs.length, 1), vsync: this);
    _controller.addListener(_onTabIndexChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive) return;
      _attachMarketWebSocketIfNeeded();
      _refreshSignalProviderInfo();
    });
  }

  @override
  void didUpdateWidget(covariant CompoundTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab != widget.tab) {
      _applyTabData(widget.tab, rebuildController: false);
    }
    if (!oldWidget.isActive && widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.isActive) return;
        _attachMarketWebSocketIfNeeded();
        _refreshSignalProviderInfo();
      });
    } else if (oldWidget.isActive && !widget.isActive) {
      _wsSub?.cancel();
      _wsSub = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pageInfoRequestGeneration++;
    _controller.removeListener(_onTabIndexChanged);
    _controller.dispose();
    _wsSub?.cancel();
    _wsSub = null;
    super.dispose();
  }

  int _max(int a, int b) => a > b ? a : b;

  String _subTabsIdentifier(List<SubTabItem> tabs) {
    final buf = StringBuffer();
    for (final t in tabs) {
      buf.write('${t.pageId}${t.router ?? ''}');
    }
    return buf.toString();
  }

  void _applyTabData(TabBarItemData next, {required bool rebuildController}) {
    if (_disposed || !mounted) return;
    final preId = _subTabsIdentifier(_subTabs);
    final curTabs = next.navInfo?.subTabs ?? [];
    final curId = _subTabsIdentifier(curTabs);
    final tabsChanged = preId != curId;
    if (rebuildController ||
        tabsChanged ||
        _controller.length != _max(curTabs.length, 1)) {
      final oldIndex = _controller.index;
      _controller.removeListener(_onTabIndexChanged);
      _controller.dispose();
      final len = _max(curTabs.length, 1);
      final idx = tabsChanged ? 0 : oldIndex.clamp(0, len - 1);
      _controller = TabController(length: len, vsync: this, initialIndex: idx);
      _visibleSubTabIndex = idx;
      _controller.addListener(_onTabIndexChanged);
    }
    setState(() => _tab = next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive) return;
      _attachMarketWebSocketIfNeeded();
    });
  }

  void _onTabIndexChanged() {
    if (_disposed || !mounted) return;
    if (_visibleSubTabIndex != _controller.index) {
      setState(() => _visibleSubTabIndex = _controller.index);
    }
    if (!_controller.indexIsChanging && _hasMarketSubTabs) {
      _sendEnterForVisibleMarket();
    }
  }

  Future<void> _requestPageInfo() async {
    final pageId = _tab.pageId;
    if (pageId <= 0) return;
    final generation = ++_pageInfoRequestGeneration;
    try {
      final data = await ref
          .read(stServiceProvider)
          .fetchPageConfiguration(pageId: pageId);
      if (data == null || !_isActivePageInfoRefresh(generation, pageId)) return;

      NavInfo? navInfo = _tab.navInfo;
      final navRaw = data['nav'];
      if (navRaw is Map<String, dynamic>) {
        navInfo = NavInfo.fromJson(navRaw);
      } else if (navRaw == null) {
        navInfo = null;
      }

      final updated = _tab.copyWith(
        bgColor: data['bg_color']?.toString() ?? _tab.bgColor,
        bgIcon: data['bg_icon']?.toString() ?? _tab.bgIcon,
        bgIconDark: data['bg_icon_dark']?.toString() ?? _tab.bgIconDark,
        navInfo: navInfo,
      );

      _applyTabData(updated, rebuildController: true);
      if (!_isActivePageInfoRefresh(generation, pageId)) return;

      final mgr = ref.read(configDataManagerProvider);
      final idx = mgr.indexOfCompoundTab(
        tabId: _tab.tabId,
        pageId: _tab.pageId,
      );
      if (idx != null) {
        mgr.updateTabBarItem(idx, updated);
      }
    } catch (e) {
      debugPrint('⚠️ CompoundTabPage.requestPageInfo: $e');
      if (_disposed || !mounted || _isDisposedTabControllerError(e)) {
        return;
      }
      if (mounted) {
        showStLocalizedPrompt(context, '页面配置刷新失败', error: e);
      }
    }
  }

  bool _isActivePageInfoRefresh(int generation, int pageId) {
    return !_disposed &&
        mounted &&
        generation == _pageInfoRequestGeneration &&
        _tab.pageId == pageId;
  }

  bool _isDisposedTabControllerError(Object error) {
    final message = error.toString();
    return message.contains('TabController was used after being disposed') ||
        message.contains('called dispose() on a TabController');
  }

  Future<void> _refreshSignalProviderInfo() async {
    try {
      final raw = await ref.read(stServiceProvider).getSignalProviderInfo();
      if (!mounted) return;
      ref.read(userStateProvider.notifier).mergeSignalProviderExamFlags(raw);
    } catch (_) {}
  }

  bool _segmentUsesCategorySocket(int index) {
    if (index < 0 || index >= _subTabs.length) return false;
    return _subTabs[index].router == '/tradeMarket';
  }

  void _attachMarketWebSocketIfNeeded() {
    if (!widget.isActive || !_hasMarketSubTabs) {
      _wsSub?.cancel();
      _wsSub = null;
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

  void _sendEnterForVisibleMarket() {
    if (_disposed || !mounted || !widget.isActive || !_hasMarketSubTabs) return;
    final ws = ref.read(marketWebSocketProvider);
    if (ws.state != WSConnectionState.connected) return;
    final index = _controller.index;
    if (_segmentUsesCategorySocket(index)) {
      final g = ref.read(configDataManagerProvider).selectedCategorySymbolGroup;
      final rt = (g >= 0 && g <= 8) ? g : 0;
      ws.sendEnterMarketList(rt);
    } else if (_subTabs[index].router == '/optional') {
      ws.sendEnterMarketList(0);
    }
  }

  void _onMarketWsMessage(MarketWSMessage message) {
    if (!mounted) return;
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

  void _selectSubTab(int index) {
    if (index < 0 || index >= _subTabs.length) return;
    if (_controller.index == index) return;
    _controller.animateTo(index);
  }

  Future<void> _onNavAction(ActionItem a, {RenderBox? anchor}) async {
    late final String navAction;
    if (a.title?.trim().isNotEmpty == true) {
      navAction = a.title!.trim();
    } else {
      navAction = await STLocalizations.ofContext(
        context,
      ).text('back', fallback: 'Back');
      if (!mounted) return;
    }
    await handleStNavAction(
      context,
      a,
      anchor: anchor,
      openRoute: (path, params) => ref
          .read(stRouterProvider)
          .openPage(context, path, params: params, action: navAction),
    );
  }

  Widget _trailingActions(int index) {
    if (index < 0 || index >= _subTabs.length) {
      return const SizedBox.shrink();
    }
    final st = _subTabs[index];
    final marketActions = _marketTrailingActions(st);
    if (marketActions != null) return marketActions;

    var items = st.tabActionItems;
    if (items.isEmpty) {
      items = _tab.navInfo?.actionItems ?? const [];
    }
    if (items.isEmpty) return const SizedBox.shrink();

    final List<ActionItem> shown;
    if (items.length == 1) {
      shown = [items.last];
    } else {
      shown = [items.first, items.last];
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final a in shown)
          Builder(
            builder: (buttonContext) => _NavActionButton(
              action: a,
              isDark: isDark,
              onPressed: () {
                final anchor = buttonContext.findRenderObject() as RenderBox?;
                _onNavAction(a, anchor: anchor);
              },
            ),
          ),
      ],
    );
  }

  Widget? _marketTrailingActions(SubTabItem st) {
    if (st.router != '/optional' && st.router != '/tradeMarket') return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (st.router == '/optional') ...[
          _marketNavIcon(
            icon: Icons.edit_outlined,
            onTap: () async {
              final changed = await context.push<bool>(
                '/market/watchlist_edit',
              );
              if (changed == true && mounted) {
                ref.read(selfMarketListRefreshTickProvider.notifier).state++;
              }
            },
          ),
          const SizedBox(width: 10),
        ],
        _marketNavIcon(
          icon: Icons.search_rounded,
          onTap: () => context.push('/market/search'),
        ),
      ],
    );
  }

  Widget _marketNavIcon({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 34,
        height: _navContentHeight,
        child: Center(
          child: Icon(icon, size: 22, color: const Color(0xFF343434)),
        ),
      ),
    );
  }

  FontWeight _weight(String? w) {
    switch (w?.toLowerCase()) {
      case 'bold':
        return FontWeight.w700;
      case 'medium':
        return FontWeight.w500;
      case 'semibold':
        return FontWeight.w600;
      default:
        return FontWeight.w400;
    }
  }

  Color _tabUnselectedColor(BuildContext context, SubTabItem st) {
    return CardTool.parseAdaptiveHexColor(
          context,
          st.titleColor,
          category: CardTool.iosDarkModeTextColorKey,
        ) ??
        context.adaptiveTextSecondary;
  }

  Color _tabSelectedColor(BuildContext context, SubTabItem st) {
    return CardTool.parseAdaptiveHexColor(
          context,
          st.titleSelColor,
          category: CardTool.iosDarkModeTextColorKey,
        ) ??
        context.adaptiveTextPrimary;
  }

  double _tabWidth(BuildContext context, SubTabItem st, bool selected) {
    final style = TextStyle(
      fontSize: selected ? st.titleSelFont.toDouble() : st.titleFont.toDouble(),
      fontWeight: selected
          ? _weight(st.titleSelWeight)
          : _weight(st.titleWeight),
      height: 1.08,
    );
    final painter = TextPainter(
      text: TextSpan(text: st.title, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: double.infinity);
    return math.max(
      _minTabWidth,
      painter.width.ceilToDouble() + _tabPadding * 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(userStateProvider.select((s) => s.isLogin), (prev, next) {
      if (prev != null && prev != next) {
        _requestPageInfo();
      }
    });
    ref.listen<int?>(compoundTabSegmentProvider, (prev, next) {
      if (next == null || !mounted) return;
      final max = _subTabs.length;
      if (max <= 0) return;
      _selectSubTab(next.clamp(0, max - 1));
    });
    ref.listen<int>(
      configDataManagerProvider.select((m) => m.selectedCategorySymbolGroup),
      (previous, next) {
        if (_segmentUsesCategorySocket(_controller.index)) {
          _sendEnterForVisibleMarket();
        }
      },
    );

    final subTabs = _subTabs;
    if (subTabs.isEmpty) {
      return CardListPage(
        title: _tab.title ?? '',
        cards: const [],
        tabBarItem: _tab,
        isActive: widget.isActive,
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgHex = _tab.bgColor;
    final bgPaint =
        CardTool.parseAdaptiveHexColor(
          context,
          bgHex != null && bgHex.isNotEmpty ? bgHex : null,
          category: CardTool.iosDarkModeTotalBgColorKey,
        ) ??
        context.adaptivePageGrey;
    final navBgPaint =
        CardTool.parseAdaptiveHexColor(
          context,
          _tab.navInfo?.bgColor,
          category: CardTool.iosDarkModeTotalBgColorKey,
        ) ??
        context.adaptiveSurfacePrimary;
    final bgUrl = isDark
        ? (_tab.bgIconDark?.isNotEmpty == true ? _tab.bgIconDark : _tab.bgIcon)
        : _tab.bgIcon;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: ColoredBox(color: bgPaint)),
        if (bgUrl != null && bgUrl.isNotEmpty)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Image.network(
                bgUrl,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                width: MediaQuery.sizeOf(context).width,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: navBgPaint,
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: _navContentHeight,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final cur = _controller.index;
                        return Row(
                          children: [
                            Expanded(
                              child: TabBar(
                                controller: _controller,
                                isScrollable: true,
                                tabAlignment: TabAlignment.start,
                                padding: const EdgeInsets.only(
                                  left: 14,
                                  right: 0,
                                ),
                                labelPadding: EdgeInsets.zero,
                                splashFactory: NoSplash.splashFactory,
                                overlayColor: WidgetStateProperty.all(
                                  Colors.transparent,
                                ),
                                dividerColor: Colors.transparent,
                                dividerHeight: 0,
                                indicatorColor: Colors.transparent,
                                indicatorWeight: 0,
                                indicator: const UnderlineTabIndicator(
                                  borderSide: BorderSide(
                                    color: Colors.transparent,
                                    width: 0,
                                  ),
                                ),
                                indicatorSize: TabBarIndicatorSize.label,
                                labelColor: Colors.transparent,
                                unselectedLabelColor: Colors.transparent,
                                tabs: [
                                  for (var i = 0; i < subTabs.length; i++)
                                    Tab(
                                      height: _navContentHeight,
                                      child: SizedBox(
                                        width: _tabWidth(
                                          context,
                                          subTabs[i],
                                          cur == i,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            right: 14,
                                          ),
                                          child: Center(
                                            child: Text(
                                              subTabs[i].title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: cur == i
                                                    ? subTabs[i].titleSelFont
                                                          .toDouble()
                                                    : subTabs[i].titleFont
                                                          .toDouble(),
                                                fontWeight: cur == i
                                                    ? _weight(
                                                        subTabs[i]
                                                            .titleSelWeight,
                                                      )
                                                    : _weight(
                                                        subTabs[i].titleWeight,
                                                      ),
                                                color: cur == i
                                                    ? _tabSelectedColor(
                                                        context,
                                                        subTabs[i],
                                                      )
                                                    : _tabUnselectedColor(
                                                        context,
                                                        subTabs[i],
                                                      ),
                                                height: 1.08,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            _trailingActions(cur),
                            const SizedBox(width: 8),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _controller,
                  children: [
                    for (var i = 0; i < subTabs.length; i++)
                      _buildSubTabBody(
                        context,
                        _tab,
                        subTabs[i],
                        visible: widget.isActive && i == _visibleSubTabIndex,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _buildSubTabBody(
    BuildContext context,
    TabBarItemData parentTab,
    SubTabItem st, {
    bool visible = true,
  }) {
    if (st.router == '/list') {
      return CardListPage(
        title: st.title,
        cards: const [],
        subTabItem: st,
        isActive: visible,
      );
    }
    if (st.router == '/news') {
      return const NewsListPage(embedded: true);
    }
    if (st.router == '/web') {
      final url = st.link ?? '';
      if (url.isEmpty) {
        return _subTabPlaceholder(st.title);
      }
      return STTabWebH5Page(url: url, title: st.title, visible: visible);
    }
    if (st.router == '/mini') {
      final url = st.link ?? '';
      if (url.isEmpty) {
        return _subTabPlaceholder(st.title);
      }
      return STMiniView(link: url, path: '', title: st.title, visible: visible);
    }
    if (st.router == '/davmu') {
      return STTabWebMiniPage(link: st.link, title: st.title, visible: visible);
    }
    if (st.router == '/optional') {
      return OptionalListPage(title: st.title, embedded: true);
    }
    if (st.router == '/tradeMarket') {
      return MarketHqSection(
        tabCards: st.cardItems.isNotEmpty ? st.cardItems : parentTab.cardItems,
      );
    }
    if (st.router == '/calendar') {
      return CalendarPage(title: st.title);
    }
    if (st.router == '/flash') {
      return FlashListPage(title: st.title);
    }
    if (st.cardItems.isNotEmpty) {
      return CardListPage(
        title: st.title,
        cards: const [],
        subTabItem: st,
        isActive: visible,
      );
    }
    return _subTabPlaceholder(st.title, desc: st.router);
  }

  static Widget _subTabPlaceholder(String title, {String? desc}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          if (desc != null && desc.trim().isNotEmpty)
            Text(desc, style: TextStyle(color: Colors.grey[400]))
          else
            STLocalizedText('暂无内容', style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }
}

class _NavActionButton extends StatelessWidget {
  final ActionItem action;
  final bool isDark;
  final VoidCallback onPressed;

  const _NavActionButton({
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
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 34, minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                action.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: fs,
                  color: c,
                  fontWeight: _weightStatic(action.titleWeight),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final iconUrl = isDark && (action.iconDark?.isNotEmpty == true)
        ? action.iconDark!
        : (action.icon ?? '');
    if (iconUrl.isEmpty) {
      return const SizedBox(width: 34);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox(
        width: 34,
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Center(
            child: Image.network(
              iconUrl,
              width: 24,
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.more_horiz, size: 22),
            ),
          ),
        ),
      ),
    );
  }

  static FontWeight _weightStatic(String? w) {
    switch (w?.toLowerCase()) {
      case 'bold':
        return FontWeight.w700;
      case 'medium':
        return FontWeight.w500;
      case 'semibold':
        return FontWeight.w600;
      default:
        return FontWeight.w400;
    }
  }
}
