import 'package:flutter/material.dart';
import 'package:jufu/shared/widgets/st_pull_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';
import '../../core/models/tab_bar_item.dart';
import '../../core/models/user_state.dart';
import '../../core/providers/app_events.dart';
import '../../core/router/st_router.dart';
import '../../core/router/navigation_logger.dart';
import '../../core/router/route_observer.dart';
import '../../shared/widgets/card_factory.dart';
import '../../core/config/card_tool.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../shared/widgets/st_nav_action.dart';
import '../../shared/widgets/st_localized_prompt.dart';
import 'card_list_controller.dart';
import 'card_list_page_chrome.dart';

typedef CardListControllerBuilder =
    CardListController Function({
      required WidgetRef ref,
      required List<ConfigCardItemData> cards,
      required int? pageListId,
      required bool preferPageApiOnInitialLoad,
      required bool enableMineBusinessLayer,
      required TabBarItemData? sourceTabBarItem,
    });

/// 卡片列表页
/// 对齐 iOS STProjectListViewController。
///
/// 通过 TabBarItemData 或 SubTabItem 传入卡片配置，
/// 由 CardFactory 按 cardStyle 分发数据加载和渲染。
class CardListPage extends ConsumerStatefulWidget {
  final String title;
  final List<ConfigCardItemData> cards;

  /// 方式一：通过 TabBarItem 初始化（首页、我的）
  final TabBarItemData? tabBarItem;

  /// 方式二：通过 SubTabItem 初始化（复合 Tab 的子页）
  final SubTabItem? subTabItem;

  /// 页面子类可注入专属 controller，对齐 iOS 子类重写点。
  final CardListControllerBuilder? controllerBuilder;

  /// 在底栏/复合 Tab 中，页面可能已经被 IndexedStack/TabBarView 构建但尚不可见。
  /// iOS 的非当前 VC 不会收到 viewWillAppear，因此接口刷新和轮询也应等到可见后再启动。
  final bool isActive;

  const CardListPage({
    super.key,
    required this.title,
    required this.cards,
    this.tabBarItem,
    this.subTabItem,
    this.controllerBuilder,
    this.isActive = true,
  });

  @override
  ConsumerState<CardListPage> createState() => _CardListPageState();
}

class _CardListPageState extends ConsumerState<CardListPage>
    with WidgetsBindingObserver, RouteAware {
  late CardListController _controller;
  TabBarItemData? _chromeTab;

  /// Web 卡 appear/disappear（对齐 iOS STWebCardView pageWillAppear/pageWillDisAppear）
  late final ValueNotifier<bool> _pageVisibleNotifier;
  bool _routeSubscribed = false;
  bool _initialLoadStarted = false;
  bool _reportedPageVisible = false;

  /// 从 TabBarItem 或 SubTabItem 获取卡片列表
  List<ConfigCardItemData> get _effectiveCards {
    if (widget.cards.isNotEmpty) {
      return widget.cards;
    }
    if (widget.tabBarItem != null) {
      return widget.tabBarItem!.cardItems;
    }
    if (widget.subTabItem != null) {
      return widget.subTabItem!.cardItems;
    }
    return [];
  }

  bool get _usesHomeChrome {
    final tab = widget.tabBarItem;
    if (tab == null) return false;
    return tab.router == '/home' || tab.isHome;
  }

  bool get _useMineChrome => widget.tabBarItem?.router == '/mine';

  bool get _useCmsChrome =>
      widget.tabBarItem != null && widget.subTabItem == null;

  bool get _isCurrentRoute {
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageVisibleNotifier = ValueNotifier(widget.isActive);
    _chromeTab = widget.tabBarItem;

    final int? pageListId =
        widget.subTabItem != null && widget.subTabItem!.pageId > 0
        ? widget.subTabItem!.pageId
        : (widget.tabBarItem != null && widget.tabBarItem!.pageId > 0
              ? widget.tabBarItem!.pageId
              : null);

    final isMineTab = widget.tabBarItem?.router == '/mine';

    _controller = (widget.controllerBuilder ?? _defaultControllerBuilder)(
      ref: ref,
      cards: _effectiveCards,
      pageListId: pageListId,
      preferPageApiOnInitialLoad: isMineTab,
      enableMineBusinessLayer: isMineTab,
      sourceTabBarItem: widget.tabBarItem,
    );
    _controller.setRouteOpener((path, params) {
      if (context.mounted) {
        ref.read(stRouterProvider).openPage(context, path, params: params);
      }
    });
    _startInitialLoadIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_routeSubscribed) {
      final route = ModalRoute.of(context);
      if (route != null) {
        routeObserver.subscribe(this, route);
        _routeSubscribed = true;
      }
    }
    _activatePageIfNeeded();
  }

  @override
  void didUpdateWidget(covariant CardListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newCards = _effectiveCards;
    final oldCards =
        oldWidget.tabBarItem?.cardItems ??
        oldWidget.subTabItem?.cardItems ??
        oldWidget.cards;
    if (newCards != oldCards) {
      _controller.initialize(newCards);
    }
    if (widget.tabBarItem != oldWidget.tabBarItem) {
      _chromeTab = widget.tabBarItem;
    }
    if (!oldWidget.isActive && widget.isActive) {
      _scheduleActivatePageIfNeeded();
    } else if (oldWidget.isActive && !widget.isActive) {
      _deactivatePageIfNeeded();
    }
  }

  @override
  void dispose() {
    if (_routeSubscribed) {
      routeObserver.unsubscribe(this);
    }
    WidgetsBinding.instance.removeObserver(this);
    _deactivatePageIfNeeded();
    _pageVisibleNotifier.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _startInitialLoadIfNeeded() {
    if (_initialLoadStarted || !widget.isActive) return;
    _initialLoadStarted = true;
    _controller.onViewDidLoad();
  }

  void _activatePageIfNeeded() {
    if (!widget.isActive || !_isCurrentRoute) {
      _setPageVisible(false);
      return;
    }
    _startInitialLoadIfNeeded();
    if (_reportedPageVisible) {
      _setPageVisible(true);
      return;
    }
    _controller.onWillAppear();
    _controller.onDidAppear();
    _reportedPageVisible = true;
    _setPageVisible(true);
  }

  void _scheduleActivatePageIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _activatePageIfNeeded();
    });
  }

  void _deactivatePageIfNeeded() {
    if (!_reportedPageVisible && !_pageVisibleNotifier.value) return;
    if (_reportedPageVisible) {
      _controller.onWillDisappear();
    }
    _reportedPageVisible = false;
    _setPageVisible(false);
  }

  void _setPageVisible(bool visible) {
    if (_pageVisibleNotifier.value != visible) {
      _pageVisibleNotifier.value = visible;
    }
  }

  @override
  void didPopNext() {
    _activatePageIfNeeded();
  }

  @override
  void didPushNext() {
    _deactivatePageIfNeeded();
  }

  @override
  void didPop() {
    _deactivatePageIfNeeded();
  }

  Widget _wrapMineChrome(
    BuildContext context, {
    required bool useMineChrome,
    required Widget child,
  }) {
    if (!useMineChrome || Theme.of(context).brightness == Brightness.dark) {
      return child;
    }
    final h = MediaQuery.sizeOf(context).height;
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: h * 0.55,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFD8E9FF), Color(0xFFF7F7F7)],
                stops: [0, 0.58],
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Image.asset(
            'assets/images/st_mine_back.png',
            fit: BoxFit.fitWidth,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dashboard_customize_outlined,
              size: 64,
              color: context.adaptiveTextHint,
            ),
            const SizedBox(height: 16),
            STLocalizedText(
              '暂无内容',
              style: TextStyle(
                fontSize: 16,
                color: context.adaptiveTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateCard(
    BuildContext context,
    String path,
    Map<String, dynamic>? params, {
    String? action,
  }) {
    if (!context.mounted || path.isEmpty) return;
    ref
        .read(stRouterProvider)
        .openPage(context, path, params: params, action: action);
  }

  Future<void> _onNavAction(ActionItem action, {RenderBox? anchor}) async {
    final navAction = action.title?.trim().isNotEmpty == true
        ? action.title!.trim()
        : widget.title;
    await handleStNavAction(
      context,
      action,
      anchor: anchor,
      openRoute: (path, params) => ref
          .read(stRouterProvider)
          .openPage(context, path, params: params, action: navAction),
    );
  }

  TabBarItemData? get _effectiveChromeTab =>
      _controller.pageChrome ?? _chromeTab ?? widget.tabBarItem;

  Widget _buildScrollBody(
    BuildContext context,
    bool useMineChrome, {
    required bool pinFirstCardBelowNav,
  }) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final cards = _controller.filteredCards;
        final loading = _controller.isLoading;

        if (loading && cards.isEmpty) {
          return const Center(child: STLoadAnimationView());
        }

        if (cards.isEmpty) {
          return STPullRefresh(
            onRefresh: () => _controller.refreshPage(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: _buildEmptyState(context),
            ),
          );
        }

        return STPullRefresh(
          onRefresh: () => _controller.refreshPage(),
          child: CustomScrollView(
            slivers: [
              if (loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final card = cards[index];
                  final compactTop = pinFirstCardBelowNav && index == 0;
                  return CardFactory.createCard(
                    context,
                    card,
                    onNavigate: (path, params, {action}) {
                      _navigateCard(
                        context,
                        path,
                        params,
                        action:
                            action ??
                            NavigationLogger.actionForCardStyle(card.cardStyle),
                      );
                    },
                    dataCache: _controller.cardDataCache,
                    onReloadCategoryMarket: () =>
                        _controller.reloadCategoryMarketCards(),
                    onLoadMoreCategoryMarket: (c) =>
                        _controller.loadMoreCategoryMarket(c),
                    useMinePageVariants: useMineChrome,
                    pageVisibleListenable: _pageVisibleNotifier,
                    compactTop: compactTop,
                  );
                }, childCount: cards.length),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(userStateProvider.select((s) => s.isLogin), (prev, next) {
      if (prev != null && prev != next) {
        _controller.onLoginStateChanged();
      }
    });
    ref.listen(selfMarketListRefreshTickProvider, (prev, next) {
      if (prev != next) {
        _controller.refreshSelfMarketCards();
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final useMineChrome = _useMineChrome;
    final chromeTab = _effectiveChromeTab;
    final useCmsChrome = _useCmsChrome && chromeTab != null;
    final hasCmsNav =
        useCmsChrome && CardListPageChrome.hasNavBar(chromeTab.navInfo);

    final homeLightGray = !isDark
        ? CardTool.iosPageBackgroundGrey
        : context.adaptivePageGrey;

    final pageBg = _usesHomeChrome
        ? homeLightGray
        : (useCmsChrome
              ? Colors.transparent
              : (useMineChrome && !isDark
                    ? const Color(0xFFF7F7F7)
                    : (isDark
                          ? context.adaptivePageGrey
                          : CardTool.iosPageBackgroundGrey)));

    // CMS 顶栏已含 SafeArea；有顶栏时滚动区不再加 top inset，banner 才能紧贴导航栏下方
    Widget scrollBody = _buildScrollBody(
      context,
      useMineChrome,
      pinFirstCardBelowNav: hasCmsNav,
    );

    Widget bodyContent = scrollBody;
    if (useMineChrome && !useCmsChrome) {
      bodyContent = _wrapMineChrome(
        context,
        useMineChrome: true,
        child: bodyContent,
      );
    }

    if (useCmsChrome) {
      if (!hasCmsNav) {
        bodyContent = SafeArea(bottom: false, child: bodyContent);
      }
      bodyContent = CardListPageChrome(
        tab: chromeTab,
        backgroundColor: _usesHomeChrome && !isDark
            ? CardTool.iosPageBackgroundGrey
            : null,
        onNavAction: (action, anchor) => _onNavAction(action, anchor: anchor),
        child: bodyContent,
      );
    } else {
      bodyContent = SafeArea(bottom: false, child: bodyContent);
    }

    return Scaffold(backgroundColor: pageBg, body: bodyContent);
  }

  CardListController _defaultControllerBuilder({
    required WidgetRef ref,
    required List<ConfigCardItemData> cards,
    required int? pageListId,
    required bool preferPageApiOnInitialLoad,
    required bool enableMineBusinessLayer,
    required TabBarItemData? sourceTabBarItem,
  }) {
    return CardListController(
      ref: ref,
      cards: cards,
      pageListId: pageListId,
      preferPageApiOnInitialLoad: preferPageApiOnInitialLoad,
      enableMineBusinessLayer: enableMineBusinessLayer,
      sourceTabBarItem: sourceTabBarItem,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _activatePageIfNeeded();
    } else if (state == AppLifecycleState.paused) {
      _deactivatePageIfNeeded();
    }
  }
}
