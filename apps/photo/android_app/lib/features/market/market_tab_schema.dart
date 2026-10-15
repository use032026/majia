import '../../core/models/tab_bar_item.dart';

/// 判断底栏 Tab 是否为 **行情复合页**（对齐 iOS `STMarketController` + schema：
/// `page.router == "/tab"`、`page_code == page-market`，子项在 `nav.tabs[].page.cards`）。
///
/// 服务端若未写 `page_code`，则用子 Tab 卡片启发式：`/list` + 同时存在 `selfmarket_*` 与 `category_*`。
bool tabBarItemIsMarketSchemaCompound(TabBarItemData tab) {
  if (tab.router != '/tab') return false;
  final subs = tab.navInfo?.subTabs ?? const [];
  if (subs.isEmpty) return false;

  final code = tab.tabCode.toLowerCase();
  if (code == 'page-market') {
    return true;
  }

  if (subs.length < 2) return false;
  var hasSelfMarket = false;
  var hasCategory = false;
  for (final st in subs) {
    final r = (st.router ?? '').trim();
    if (r.isNotEmpty && r != '/list') return false;
    for (final c in st.cardItems) {
      final s = c.cardStyle.toLowerCase();
      if (s.startsWith('selfmarket')) hasSelfMarket = true;
      if (s.startsWith('category_')) hasCategory = true;
    }
  }
  return hasSelfMarket && hasCategory;
}

/// 合并各子 Tab 的 `page.cards`，供 [MarketTabShellPage] / [MarketHqSection] 解析 `category_*` 等
///（[MarketTabShellConfig.parseCategoryOneTabs] 会忽略非 `category_` 前缀卡片）。
List<ConfigCardItemData> mergedMarketTabCardsFromCompoundTab(TabBarItemData tab) {
  final out = <ConfigCardItemData>[];
  for (final st in tab.navInfo?.subTabs ?? const <SubTabItem>[]) {
    out.addAll(st.cardItems);
  }
  return out;
}
