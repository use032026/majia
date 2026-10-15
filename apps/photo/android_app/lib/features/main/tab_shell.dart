import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';
import '../../core/config/config_data_manager.dart';
import '../../core/config/card_tool.dart';
import '../../core/models/tab_bar_item.dart';
import '../../core/models/user_state.dart';
import '../../core/providers/tab_shell_navigation.dart';
import '../../core/router/route_observer.dart';
import '../../core/router/router_guard.dart';
import '../../shared/widgets/st_localized_prompt.dart';
import '../home/card_list_page.dart';
import '../home/home_page.dart';
import '../trade/trade_page.dart';
import '../market/market_tab_schema.dart';
import '../market/market_tab_shell_page.dart';
import '../mine/mine_configured_page.dart';
import 'compound_tab_page.dart';

String tabShellDebugLine(
  TabBarItemData tab, {
  required int index,
  required bool isActive,
}) {
  final page = _tabShellPageClass(tab);
  final subTabs = tab.navInfo?.subTabs ?? const <SubTabItem>[];
  final subTabText = subTabs.isEmpty
      ? 'none'
      : subTabs
            .asMap()
            .entries
            .map((entry) {
              final i = entry.key;
              final st = entry.value;
              return '$i:title="${st.title}",'
                  'router="${st.router ?? ''}",'
                  'page=${_tabShellSubTabPageClass(st)},'
                  'cardItems=${st.cardItems.length},'
                  'cards=${_tabShellCardItemsSignature(st.cardItems)}';
            })
            .join('; ');
  return '📄 TabShell.CardListMap: '
      'index=$index '
      'active=$isActive '
      'tabId="${tab.tabId}" '
      'pageId=${tab.pageId} '
      'title="${tab.title ?? ''}" '
      'router="${tab.router}" '
      'page=$page '
      'isCardListPage=${page == 'CardListPage'} '
      'cardItems=${tab.cardItems.length} '
      'cards=${_tabShellCardItemsSignature(tab.cardItems)} '
      'subTabs=[$subTabText]';
}

String _tabShellPageClass(TabBarItemData tab) {
  if (tab.isHome) return 'HomePage';
  switch (tab.router) {
    case '/tab':
      if (tabBarItemIsMarketSchemaCompound(tab)) return 'MarketTabShellPage';
      if (tab.navInfo?.subTabs?.isNotEmpty ?? false) return 'CompoundTabPage';
      return 'CardListPage';
    case '/home':
      return 'HomePage';
    case '/mine':
      return 'ConfiguredMinePage';
    case '/market':
      return 'MarketTabShellPage';
    case '/trade':
    case '/trade1':
      return tab.cardItems.isNotEmpty ? 'CardListPage' : 'TradePage';
    default:
      if (tab.cardItems.isNotEmpty) return 'CardListPage';
      if (tab.navInfo?.subTabs?.isNotEmpty ?? false) return 'CompoundTabPage';
      return 'Fallback';
  }
}

String _tabShellSubTabPageClass(SubTabItem st) {
  switch (st.router) {
    case '/list':
      return 'CardListPage';
    case '/news':
      return 'NewsListPage';
    case '/web':
      return 'STTabWebH5Page';
    case '/mini':
      return 'STMiniView';
    case '/davmu':
      return 'STTabWebMiniPage';
    case '/optional':
      return 'OptionalListPage';
    case '/tradeMarket':
      return 'MarketHqSection';
    case '/calendar':
      return 'CalendarPage';
    case '/flash':
      return 'FlashListPage';
    default:
      return st.cardItems.isNotEmpty ? 'CardListPage' : 'Placeholder';
  }
}

String _tabShellCardItemsSignature(List<ConfigCardItemData> cardItems) {
  if (cardItems.isEmpty) return '0';
  final ids = cardItems
      .map((card) => '${card.cardId}:${card.cardStyle}')
      .toList(growable: false);
  return ids.join('|');
}

List<TabBarItemData> filterTabBarItemsForLoginState(
  List<TabBarItemData> tabs, {
  required bool isLogin,
}) {
  return tabs
      .where((tab) {
        final permission = tab.showPermission?.trim().toLowerCase() ?? '';
        if (permission == 'login' && !isLogin) return false;
        if (permission == 'unlogin' && isLogin) return false;
        return true;
      })
      .toList(growable: false);
}

String _tabShellDisplayedTabbarEntry(TabBarItemData tab, int idx) {
  final title = tab.title ?? '';
  final tabCode = tab.tabCode;
  final router = tab.router;
  final showPermission = tab.showPermission ?? '';
  final pageClass = _tabShellPageClass(tab);
  return '{$idx title=$title code=$tabCode router=$router '
      'show=$showPermission vc=$pageClass isHome=${tab.isHome ? 1 : 0}}';
}

String tabShellDisplayedTabbarSummary(
  List<TabBarItemData> tabs, {
  required int selectedHomeIndex,
}) {
  final entries = <String>[];
  for (int i = 0; i < tabs.length; i++) {
    entries.add(_tabShellDisplayedTabbarEntry(tabs[i], i));
  }
  return 'display_count=${tabs.length} selected_home_index=$selectedHomeIndex '
      'entries=${entries.join(', ')}';
}

/// 服务端驱动 Tab 壳
/// 对齐 iOS STRootViewController + STTabBarController
///
/// Tab 由 appConfig[@"tab_bar"][] 驱动：
///   router == "/home"   → HomePage（STHomeViewController；配置化卡片 + 首页专属业务）
///   router == "/mine"   → [ConfiguredMinePage] → CardListPage（服务端卡片配置 + 我的域数据）
///   router == "/tab"    → 多为 [CompoundTabPage]；若为 schema `page-market`（子 Tab 卡片在 `nav.tabs[].page.cards`）
///                         则走 [MarketTabShellPage]（对齐 iOS `STMarketController`，与独立 `/market` 同源壳）
///   router == "/trade"  → CardListPage（有卡片配置）或 TradePage（默认）
///   router == "/trade1" → 同上变体
///   router == "/market" → MarketTabShellPage（对齐 iOS STMarketController；`tab.cardItems` 可含 category_1）
class TabShell extends ConsumerStatefulWidget {
  final String? initialTab;

  const TabShell({super.key, this.initialTab});

  @override
  ConsumerState<TabShell> createState() => _TabShellState();
}

class _TabShellState extends ConsumerState<TabShell> {
  int _currentIndex = 0;
  final Set<String> _preloadedIconUrls = {};
  bool _resolvedInitialTab = false;
  final Map<String, String> _tabBuildSignatures = {};
  String? _lastPublishedTabCode;
  String? _lastDisplayedTabbarSummary;

  /// 解析初始 Tab（支持在 config 加载后重新执行）
  int _resolveInitialTab(List<TabBarItemData> tabs, int fallbackIndex) {
    if (tabs.isEmpty) return fallbackIndex;

    if (widget.initialTab != null) {
      final idx = resolveTabBarIndex(tabs, widget.initialTab!);
      if (idx != null) return idx;
    }

    // 默认选中 isHome 的 Tab
    for (int i = 0; i < tabs.length; i++) {
      if (tabs[i].isHome) return i;
    }

    return fallbackIndex;
  }

  int _homeTabIndex(List<TabBarItemData> tabs) {
    for (int i = 0; i < tabs.length; i++) {
      if (tabs[i].isHome) return i;
    }
    return 0;
  }

  void _logDisplayedTabbarIfChanged(List<TabBarItemData> tabs) {
    final summary = tabShellDisplayedTabbarSummary(
      tabs,
      selectedHomeIndex: _homeTabIndex(tabs),
    );
    if (summary == _lastDisplayedTabbarSummary) return;
    _lastDisplayedTabbarSummary = summary;
    debugPrint('AppSatrt - DisplayedTabbar $summary');
  }

  void _applyTabShellSwitch(TabShellSwitchIntent intent) {
    final tabs = filterTabBarItemsForLoginState(
      ref.read(configDataManagerProvider).tabs,
      isLogin: ref.read(userStateProvider).isLogin,
    );
    final idx = resolveTabBarIndex(tabs, intent.tabCode);
    if (idx == null) return;

    final tab = tabs[idx];
    _publishCurrentTab(tab);
    final isMarketTab =
        intent.tabCode.toLowerCase() == 'market' ||
        tab.router == '/market' ||
        tabBarItemIsMarketSchemaCompound(tab);
    if (isMarketTab) {
      final seg = resolveMarketMainSegmentIndex(
        tab,
        innerTabCode: intent.innerTabCode ?? 'optional',
      );
      ref.read(marketTabSegmentProvider.notifier).state = seg;
    } else if (tab.router == '/tab' &&
        !tabBarItemIsMarketSchemaCompound(tab) &&
        (tab.navInfo?.subTabs?.isNotEmpty ?? false)) {
      final seg = resolveCompoundSubTabIndex(
        tab,
        innerTabCode: intent.innerTabCode,
        routerHint: intent.innerTabCode == 'news' ? '/news' : null,
      );
      ref.read(compoundTabSegmentProvider.notifier).state = seg;
    }

    if (idx != _currentIndex) {
      dismissCurrentKeyboardFocus();
      setState(() => _currentIndex = idx);
    }
  }

  @override
  void didUpdateWidget(covariant TabShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != null &&
        widget.initialTab != oldWidget.initialTab) {
      final tabs = ref.read(configDataManagerProvider).tabs;
      final idx = resolveTabBarIndex(
        filterTabBarItemsForLoginState(
          tabs,
          isLogin: ref.read(userStateProvider).isLogin,
        ),
        widget.initialTab!,
      );
      if (idx != null && idx != _currentIndex) {
        dismissCurrentKeyboardFocus();
        setState(() => _currentIndex = idx);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TabShellSwitchIntent?>(tabShellNavigationProvider, (prev, next) {
      if (next == null) return;
      _applyTabShellSwitch(next);
    });

    final configMgr = ref.watch(configDataManagerProvider);
    final isLogin = ref.watch(userStateProvider.select((s) => s.isLogin));
    final tabs = filterTabBarItemsForLoginState(
      configMgr.tabs,
      isLogin: isLogin,
    );

    if (tabs.isEmpty) {
      return const Scaffold(body: Center(child: STLoadAnimationView()));
    }
    _preloadIcons(tabs, context);

    // 解析初始 Tab（仅首次或索引越界时）
    if (!_resolvedInitialTab || _currentIndex >= tabs.length) {
      _currentIndex = _resolveInitialTab(tabs, _currentIndex);
      _resolvedInitialTab = true;
    }

    // 确保索引有效
    final safeIndex = _currentIndex.clamp(0, tabs.length - 1);
    _publishCurrentTab(tabs[safeIndex], defer: true);
    _logDisplayedTabbarIfChanged(tabs);

    // 构建 Tab 页面（IndexedStack 保持各 Tab 状态，对齐 iOS UITabBarController 缓存 VC）
    _cleanupTabBuildSignatures(tabs);
    final body = IndexedStack(
      index: safeIndex,
      children: List.generate(
        tabs.length,
        (i) =>
            _buildPageForTab(tabs[i], isActive: i == safeIndex, debugIndex: i),
      ),
    );

    return Scaffold(
      body: body,
      bottomNavigationBar: _buildBottomTabBar(
        context,
        tabs: tabs,
        configMgr: configMgr,
        safeIndex: safeIndex,
      ),
    );
  }

  Widget _buildBottomTabBar(
    BuildContext context, {
    required List<TabBarItemData> tabs,
    required ConfigDataManager configMgr,
    required int safeIndex,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF18191A)
        : const Color(0xFFFFFFFF);
    final lineColor = isDark
        ? const Color(0xFF212229)
        : const Color(0xFFF7F7F7);
    final hasCenterLargeItem =
        tabs.length.isOdd && configMgr.tabBarStyle != 'default';
    final centerIndex = hasCenterLargeItem ? tabs.length ~/ 2 : -1;

    return Material(
      color: backgroundColor,
      child: SafeArea(
        top: false,
        child: Container(
          height: 49,
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: lineColor, width: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(tabs.length, (i) {
              final tab = tabs[i];
              final selected = i == safeIndex;
              return Expanded(
                child: _TabShellBarItem(
                  key: ValueKey('${tab.tabId}-$i'),
                  label: tab.title ?? '',
                  selected: selected,
                  iconUrl: _tabIconUrl(tab, selected: selected, isDark: isDark),
                  placeholderIconUrl: selected
                      ? _tabIconUrl(tab, selected: false, isDark: isDark)
                      : null,
                  fallbackIcon: _defaultIconForRouter(tab.router),
                  imageSize: i == centerIndex ? 36 : 24,
                  textStyle: _tabTitleStyle(tab, selected: selected),
                  fallbackIconColor: _tabTitleColor(tab, selected: selected),
                  onTap: () => _handleTabTap(context, tabs, i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTabTap(
    BuildContext context,
    List<TabBarItemData> tabs,
    int index,
  ) async {
    final tab = tabs[index];
    if (tab.showPermission != null && tab.showPermission!.isNotEmpty) {
      final params = <String, String>{'permission': tab.showPermission!};
      final redirect = await RouterGuard.checkPermission(tab.router, params);
      if (redirect != null) {
        if (context.mounted) {
          context.push(redirect);
        }
        return;
      }
    }

    await HapticFeedback.lightImpact();
    if (!mounted) return;
    _publishCurrentTab(tab);
    if (index != _currentIndex) {
      dismissCurrentKeyboardFocus();
    }
    setState(() => _currentIndex = index);
  }

  void _publishCurrentTab(TabBarItemData tab, {bool defer = false}) {
    final code = _returnCodeForTab(tab);
    if (code == null || code == _lastPublishedTabCode) return;
    _lastPublishedTabCode = code;
    if (defer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(currentTabShellTabCodeProvider.notifier).state = code;
      });
      return;
    }
    ref.read(currentTabShellTabCodeProvider.notifier).state = code;
  }

  String? _returnCodeForTab(TabBarItemData tab) {
    final tabCode = tab.tabCode.trim();
    if (tabCode.isNotEmpty) return tabCode;
    final tabId = tab.tabId.trim();
    if (tabId.isNotEmpty) return tabId;
    final router = tab.router.trim();
    if (router.startsWith('/') && router.length > 1) {
      return router.substring(1).split('/').first;
    }
    return null;
  }

  /// 预下载 Tab 图标（对齐 iOS 预下载逻辑）
  void _preloadIcons(List<TabBarItemData> tabs, BuildContext context) {
    for (int i = 0; i < tabs.length; i++) {
      final tab = tabs[i];
      // 预缓存 icon / iconDark / selIcon / selIconDark
      final urls = [
        tab.icon,
        tab.iconDark,
        tab.selIcon,
        tab.selIconDark,
      ].whereType<String>().where((u) => u.isNotEmpty).toList();
      for (final url in urls) {
        _preloadImage(url, context);
      }
    }
  }

  void _preloadImage(String url, BuildContext context) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      if (!_preloadedIconUrls.add(url)) return;
      final provider = NetworkImage(url);
      precacheImage(provider, context).catchError((Object error) {
        _preloadedIconUrls.remove(url);
      });
    }
  }

  /// 空页面占位（当 Tab 既无原生页也无卡片配置时显示）
  Widget _buildPageFallback(TabBarItemData tab) {
    debugPrint(
      '📄 TabShell: rendering fallback for router="${tab.router}" title="${tab.title}"',
    );
    final fallbackTitle = tab.title?.trim().isNotEmpty == true
        ? tab.title!.trim()
        : (tab.router.isNotEmpty ? tab.router : null);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.web_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          if (fallbackTitle != null)
            Text(
              fallbackTitle,
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            )
          else
            STLocalizedText(
              '暂无内容',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }

  String? _tabIconUrl(
    TabBarItemData tab, {
    required bool selected,
    required bool isDark,
  }) {
    if (selected) {
      if (isDark && _isValidUrl(tab.selIconDark)) return tab.selIconDark;
      if (_isValidUrl(tab.selIcon)) return tab.selIcon;
      if (isDark && _isValidUrl(tab.iconDark)) return tab.iconDark;
      return tab.icon;
    }
    if (isDark && _isValidUrl(tab.iconDark)) return tab.iconDark;
    return tab.icon;
  }

  TextStyle _tabTitleStyle(TabBarItemData tab, {required bool selected}) {
    final style = tab.titleStyle ?? const <String, dynamic>{};
    final fontSize = _doubleFromStyle(
      style[selected ? 'selFontSize' : 'fontSize'],
      fallback: 11,
    );
    return TextStyle(
      color: _tabTitleColor(tab, selected: selected),
      fontSize: fontSize,
      fontWeight: _fontWeightFromString(
        style[selected ? 'selWeight' : 'weight']?.toString(),
      ),
      height: 1,
      letterSpacing: 0,
    );
  }

  Color _tabTitleColor(TabBarItemData tab, {required bool selected}) {
    final style = tab.titleStyle ?? const <String, dynamic>{};
    final color = CardTool.parseHexColor(
      style[selected ? 'selColor' : 'color']?.toString(),
    );
    if (color != null) return color;
    return selected ? const Color(0xFF00B57A) : const Color(0xFF9A9DA2);
  }

  double _doubleFromStyle(dynamic value, {required double fallback}) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }

  FontWeight _fontWeightFromString(String? weight) {
    switch (weight?.toLowerCase()) {
      case 'bold':
      case 'heavy':
        return FontWeight.w700;
      case 'medium':
        return FontWeight.w500;
      case 'semibold':
      case 'demibold':
        return FontWeight.w600;
      case 'regular':
      case 'normal':
      default:
        return FontWeight.w400;
    }
  }

  bool _isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  IconData _defaultIconForRouter(String router) {
    switch (router) {
      case '/home':
      case '/tab':
        return Icons.dashboard;
      case '/market':
        return Icons.show_chart;
      case '/trade':
      case '/trade1':
        return Icons.swap_horiz;
      case '/mine':
        return Icons.person;
      default:
        return Icons.circle;
    }
  }

  /// 根据 Tab router 构建页面
  Widget _buildPageForTab(
    TabBarItemData tab, {
    required bool isActive,
    required int debugIndex,
  }) {
    _debugBuildTabPageIfChanged(tab, isActive: isActive, index: debugIndex);

    if (tab.isHome) {
      return HomePage(
        title: tab.title ?? '',
        cards: const [],
        tabBarItem: tab,
        isActive: isActive,
      );
    }

    switch (tab.router) {
      case '/tab':
        // 对齐 iOS STTabViewController：nav.tab_items → NavInfo.subTabs
        {
          if (tabBarItemIsMarketSchemaCompound(tab)) {
            return MarketTabShellPage(
              title: tab.title,
              tabCards: mergedMarketTabCardsFromCompoundTab(tab),
              mainSegments: tab.navInfo?.subTabs,
              navActionItems: tab.navInfo?.actionItems,
              isActive: isActive,
            );
          }
          final subTabs = tab.navInfo?.subTabs ?? [];
          if (subTabs.isNotEmpty) {
            return CompoundTabPage(tab: tab, isActive: isActive);
          }
          return CardListPage(
            title: tab.title ?? '',
            cards: [],
            tabBarItem: tab,
            isActive: isActive,
          );
        }

      case '/home':
        return HomePage(
          title: tab.title ?? '',
          cards: const [],
          tabBarItem: tab,
          isActive: isActive,
        );

      case '/mine':
        return ConfiguredMinePage(isActive: isActive);

      case '/market':
        return MarketTabShellPage(
          title: tab.title,
          tabCards: tab.cardItems,
          mainSegments: tab.navInfo?.subTabs,
          navActionItems: tab.navInfo?.actionItems,
          isActive: isActive,
        );

      case '/trade':
      case '/trade1':
        if (tab.cardItems.isNotEmpty) {
          return CardListPage(
            title: tab.title ?? '',
            cards: const [],
            tabBarItem: tab,
            isActive: isActive,
          );
        }
        return TradePage(isActive: isActive);

      default:
        // 未知路由 → 先尝试卡片列表，再尝试复合子 Tab
        _debugBuildTabEvent(
          tab,
          index: debugIndex,
          event: 'unknown_router',
          message:
              '📄 TabShell: unknown router="${tab.router}" title="${tab.title}" cardItems=${tab.cardItems.length} subTabs=${tab.navInfo?.subTabs?.length ?? 0}',
        );
        if (tab.cardItems.isNotEmpty) {
          return CardListPage(
            title: tab.title ?? '',
            cards: [],
            tabBarItem: tab,
            isActive: isActive,
          );
        }
        // 对齐 iOS: 有子 Tab 的未知路由 → 渲染复合 Tab（分段式 TabBar + 子页列表）
        if (tab.navInfo?.subTabs != null && tab.navInfo!.subTabs!.isNotEmpty) {
          _debugBuildTabEvent(
            tab,
            index: debugIndex,
            event: 'unknown_router_compound',
            message:
                '📄 TabShell: unknown router="${tab.router}" has ${tab.navInfo!.subTabs!.length} subTabs — rendering compound tab',
          );
          return CompoundTabPage(tab: tab, isActive: isActive);
        }
        return _buildPageFallback(tab);
    }
  }

  String _tabBuildSignature(TabBarItemData tab, {required bool isActive}) {
    return '${tab.tabId}|${tab.router}|${tab.title}|${tab.isHome}|'
        '${_tabCardItemsSignature(tab.cardItems)}|$isActive|'
        '${_tabSubTabsSignature(tab.navInfo?.subTabs ?? const [])}';
  }

  String _tabCardItemsSignature(List<ConfigCardItemData> cardItems) {
    return '${cardItems.length}:${_tabShellCardItemsSignature(cardItems)}';
  }

  String _tabSubTabsSignature(List<SubTabItem> subTabs) {
    if (subTabs.isEmpty) return '0';
    final ids = subTabs
        .map((st) {
          return '${st.pageId}:${st.router}:${st.title}:'
              '${_tabShellCardItemsSignature(st.cardItems)}';
        })
        .toList(growable: false);
    return '${ids.length}:${ids.join('|')}';
  }

  String _tabBuildDebugKey(TabBarItemData tab, {required int index}) {
    return tab.tabId.isNotEmpty ? tab.tabId : '$index-${tab.router}';
  }

  void _debugBuildTabPageIfChanged(
    TabBarItemData tab, {
    required bool isActive,
    required int index,
  }) {
    final key = _tabBuildDebugKey(tab, index: index);
    final sig = _tabBuildSignature(tab, isActive: isActive);
    final lastSig = _tabBuildSignatures[key];
    if (lastSig != null && lastSig == sig) return;

    _tabBuildSignatures[key] = sig;
    debugPrint(tabShellDebugLine(tab, index: index, isActive: isActive));
  }

  void _debugBuildTabEvent(
    TabBarItemData tab, {
    required int index,
    required String event,
    required String message,
  }) {
    final key = '${_tabBuildDebugKey(tab, index: index)}:$event';
    final sig = _tabBuildSignature(tab, isActive: false);
    final lastSig = _tabBuildSignatures[key];
    if (lastSig != null && lastSig == sig) return;

    _tabBuildSignatures[key] = sig;
    debugPrint(message);
  }

  void _cleanupTabBuildSignatures(List<TabBarItemData> tabs) {
    if (_tabBuildSignatures.isEmpty) return;
    final validKeys = <String>{
      for (var i = 0; i < tabs.length; i++) ...{
        _tabBuildDebugKey(tabs[i], index: i),
        '${_tabBuildDebugKey(tabs[i], index: i)}:unknown_router',
        '${_tabBuildDebugKey(tabs[i], index: i)}:unknown_router_compound',
      },
    };
    _tabBuildSignatures.removeWhere((k, _) => !validKeys.contains(k));
  }
}

class _TabShellBarItem extends StatelessWidget {
  final String label;
  final bool selected;
  final String? iconUrl;
  final String? placeholderIconUrl;
  final IconData fallbackIcon;
  final double imageSize;
  final TextStyle textStyle;
  final Color fallbackIconColor;
  final VoidCallback onTap;

  const _TabShellBarItem({
    super.key,
    required this.label,
    required this.selected,
    required this.iconUrl,
    this.placeholderIconUrl,
    required this.fallbackIcon,
    required this.imageSize,
    required this.textStyle,
    required this.fallbackIconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconTop = 49 - 13 - 1 - 4 - imageSize;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 49,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                top: iconTop,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: imageSize,
                    height: imageSize,
                    child: _buildIcon(),
                  ),
                ),
              ),
              Positioned(
                left: 2,
                right: 2,
                bottom: 1,
                height: 13,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label, maxLines: 1, style: textStyle),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final url = iconUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: imageSize,
        height: imageSize,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return _placeholderIcon(url);
        },
        errorBuilder: (_, __, ___) => _fallbackIcon(),
      );
    }
    return _fallbackIcon();
  }

  Widget _placeholderIcon(String currentUrl) {
    final placeholder = placeholderIconUrl;
    if (placeholder == null ||
        placeholder.isEmpty ||
        placeholder == currentUrl) {
      return _fallbackIcon();
    }
    return Image.network(
      placeholder,
      width: imageSize,
      height: imageSize,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return _fallbackIcon();
      },
      errorBuilder: (_, __, ___) => _fallbackIcon(),
    );
  }

  Widget _fallbackIcon() {
    return Icon(fallbackIcon, size: imageSize, color: fallbackIconColor);
  }
}
