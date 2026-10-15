import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/config_data_manager.dart';
import '../../core/models/tab_bar_item.dart';
import '../../core/models/user_state.dart';
import 'mine_default_page_cards.dart';
import '../home/card_list_page.dart';

/// 对齐 iOS：访客态只使用后台下发的 Mine 卡片配置。
/// 若后台已下发 `account_3` 但 schema 标记隐藏，仍按既有访客展示规则打开；
/// 若后台未下发 `account_3`，不要从本地默认骨架自动注入。
List<ConfigCardItemData> minePageEffectiveCardsWithAccount3GuestParity({
  required List<ConfigCardItemData> raw,
  required bool isLogin,
}) {
  if (isLogin) return raw;
  final idx = raw.indexWhere((c) => c.cardStyle == 'account_3');
  if (idx >= 0) {
    final c = raw[idx];
    if (c.isShow) return raw;
    return [
      for (var i = 0; i < raw.length; i++)
        i == idx ? c.copyWith(isShow: true) : raw[i],
      ];
  }
  return raw;
}

/// 「我的」主容器：结构与首页一致，由 Tab 的 `page_id` / page 配置接口驱动，
/// 对齐 iOS `STNewMineViewController` 继承 `STProjectListViewController`。
///
/// TabBar schema 中与 `router == '/mine'` 的项同源；独立路由 `/mine` 也用同一数据源。
class ConfiguredMinePage extends ConsumerWidget {
  final bool isActive;

  const ConfiguredMinePage({super.key, this.isActive = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(configDataManagerProvider).tabs;

    TabBarItemData? mineTab;
    for (final t in tabs) {
      if (t.router == '/mine') {
        mineTab = t;
        break;
      }
    }

    if (mineTab == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: Text('未找到「我的」Tab 配置', style: TextStyle(fontSize: 15)),
        ),
      );
    }

    final baseCards = List<ConfigCardItemData>.from(
      mineTab.cardItems.isNotEmpty
          ? mineTab.cardItems
          : kDefaultMinePageCards(),
    );
    final isLogin = ref.watch(userStateProvider.select((s) => s.isLogin));
    final effectiveCards = minePageEffectiveCardsWithAccount3GuestParity(
      raw: baseCards,
      isLogin: isLogin,
    );

    return CardListPage(
      title: mineTab.title ?? '',
      cards: effectiveCards,
      tabBarItem: mineTab,
      isActive: isActive,
    );
  }
}
