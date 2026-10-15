import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tab_bar_item.dart';
import '../../features/market/market_tab_schema.dart';

/// 底栏 Tab 切换意图（对齐 iOS `STRouterManager popToTabbarPageWithPath` / `popToMarketpage`）
class TabShellSwitchIntent {
  final String tabCode;
  final String? innerTabCode;
  final int tick;

  const TabShellSwitchIntent({
    required this.tabCode,
    this.innerTabCode,
    required this.tick,
  });
}

class TabShellNavigationNotifier extends StateNotifier<TabShellSwitchIntent?> {
  TabShellNavigationNotifier() : super(null);
  int _tick = 0;

  void switchTo({required String tabCode, String? innerTabCode}) {
    _tick++;
    state = TabShellSwitchIntent(
      tabCode: tabCode,
      innerTabCode: innerTabCode,
      tick: _tick,
    );
  }

  void clear() => state = null;
}

final tabShellNavigationProvider =
    StateNotifierProvider<TabShellNavigationNotifier, TabShellSwitchIntent?>(
      (ref) => TabShellNavigationNotifier(),
    );

/// 当前底栏 tabCode。
///
/// 登录页是盖在当前 TabShell 上的独立路由；登录成功若没有业务挂起路由，应回到发起登录
/// 的底栏，而不是固定回首页。
final currentTabShellTabCodeProvider = StateProvider<String?>((ref) => null);

/// 行情 Tab 内主分段待切换下标（对齐 iOS `STTabViewController.selectedIndex`）
final marketTabSegmentProvider = StateProvider<int?>((ref) => null);

/// 发现/复合 Tab 内子分段待切换下标（对齐 iOS `STTabViewController.selectedIndex` + 深链 `/news`）
final compoundTabSegmentProvider = StateProvider<int?>((ref) => null);

/// 按 tabCode / router 解析底栏下标
int? resolveTabBarIndex(List<TabBarItemData> tabs, String tabCode) {
  if (tabs.isEmpty || tabCode.trim().isEmpty) return null;
  final code = tabCode.trim().toLowerCase();

  for (int i = 0; i < tabs.length; i++) {
    final t = tabs[i];
    if (t.tabCode.toLowerCase() == code || t.tabId.toLowerCase() == code) {
      return i;
    }
  }

  for (int i = 0; i < tabs.length; i++) {
    final t = tabs[i];
    final router = t.router.toLowerCase();
    if (code == 'market' &&
        (router == '/market' || tabBarItemIsMarketSchemaCompound(t))) {
      return i;
    }
    if (code == 'home' && (t.isHome || router == '/home' || router == '/tab')) {
      return i;
    }
    if (code == 'mine' && router == '/mine') return i;
    if ((code == 'trade' || code == 'trade1') &&
        (router == '/trade' || router == '/trade1')) {
      return i;
    }
    if (router == '/$code') return i;
  }

  return null;
}

/// 解析行情 Tab 内「自选 / 行情」等主分段下标
int resolveMarketMainSegmentIndex(
  TabBarItemData marketTab, {
  String? innerTabCode,
}) {
  final segs = marketTab.navInfo?.subTabs;
  if (segs != null && segs.isNotEmpty) {
    if (innerTabCode != null && innerTabCode.trim().isNotEmpty) {
      final ic = innerTabCode.trim().toLowerCase();
      for (int i = 0; i < segs.length; i++) {
        final st = segs[i];
        final r = (st.router ?? '').toLowerCase();
        final code = (st.tabCode ?? '').toLowerCase();
        final title = st.title.toLowerCase();
        if (code == ic || r == '/$ic' || r.endsWith('/$ic') || title == ic) {
          return i;
        }
        if (ic == 'optional' && (r == '/optional' || title.contains('自选'))) {
          return i;
        }
      }
    }
    for (int i = 0; i < segs.length; i++) {
      final st = segs[i];
      if ((st.router ?? '').toLowerCase() == '/optional') return i;
      if (st.cardItems.any((c) => c.cardStyle.startsWith('selfmarket_'))) {
        return i;
      }
    }
    return 0;
  }

  if (innerTabCode != null) {
    final ic = innerTabCode.toLowerCase();
    if (ic == 'market' || ic == 'hq' || ic == 'category') return 1;
  }
  return 0;
}

/// 解析复合 Tab（`router == /tab` 且非行情 schema）内子页下标
int resolveCompoundSubTabIndex(
  TabBarItemData tab, {
  String? innerTabCode,
  String? routerHint,
}) {
  final segs = tab.navInfo?.subTabs ?? [];
  if (segs.isEmpty) return 0;

  if (routerHint != null && routerHint.isNotEmpty) {
    final hint = routerHint.toLowerCase();
    for (int i = 0; i < segs.length; i++) {
      if ((segs[i].router ?? '').toLowerCase() == hint) return i;
    }
  }

  if (innerTabCode != null && innerTabCode.trim().isNotEmpty) {
    final ic = innerTabCode.trim().toLowerCase();
    for (int i = 0; i < segs.length; i++) {
      final st = segs[i];
      final r = (st.router ?? '').toLowerCase();
      final code = (st.tabCode ?? '').toLowerCase();
      final title = st.title.toLowerCase();
      if (code == ic || r == '/$ic' || r.endsWith('/$ic') || title == ic) {
        return i;
      }
      if (ic == 'news' && r == '/news') return i;
      if (ic == 'flash' && r == '/flash') return i;
      if (ic == 'calendar' && r == '/calendar') return i;
      if ((ic == 'documentary' ||
              ic == 'copytrading' ||
              ic == 'davmu' ||
              ic == 'copy') &&
          (r == '/web' || r == '/davmu' || r == '/mini')) {
        return i;
      }
      if (ic == 'optional' && (r == '/optional' || title.contains('自选'))) {
        return i;
      }
      if ((ic == 'market' || ic == 'hq' || ic == 'category') &&
          r == '/trademarket') {
        return i;
      }
    }
    for (int i = 0; i < segs.length; i++) {
      final link = (segs[i].link ?? '').toLowerCase();
      if (ic == 'documentary' && link.contains('documentary')) return i;
    }
  }

  return 0;
}

/// 发现 Tab 的 tabCode（对齐 iOS `popToSecHomepage`）
String resolveSecHomepageTabCode(List<TabBarItemData> tabs, int fallbackIndex) {
  if (tabs.isEmpty) return 'tab';
  final idx = fallbackIndex.clamp(0, tabs.length - 1);
  for (final t in tabs) {
    if (t.router == '/tab') {
      if (t.tabCode.isNotEmpty) return t.tabCode;
      if (t.tabId.isNotEmpty) return t.tabId;
    }
  }
  final tab = tabs[idx];
  if (tab.tabCode.isNotEmpty) return tab.tabCode;
  if (tab.tabId.isNotEmpty) return tab.tabId;
  return 'tab';
}
