import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;

import '../../core/models/tab_bar_item.dart';
import 'card_list_controller.dart';
import 'card_list_page.dart';
import 'home_card_list_controller.dart';

/// 首页配置化页面。
///
/// 对齐 iOS `STHomeViewController`：页面主体复用 `STProjectListViewController`
/// 对应的 [CardListPage]，首页专属业务由 [HomeCardListController] 承载。
class HomePage extends StatelessWidget {
  final String title;
  final List<ConfigCardItemData> cards;
  final TabBarItemData tabBarItem;
  final bool isActive;

  const HomePage({
    super.key,
    required this.title,
    required this.cards,
    required this.tabBarItem,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    return CardListPage(
      title: title,
      cards: cards,
      tabBarItem: tabBarItem,
      controllerBuilder: _buildController,
      isActive: isActive,
    );
  }

  CardListController _buildController({
    required WidgetRef ref,
    required List<ConfigCardItemData> cards,
    required int? pageListId,
    required bool preferPageApiOnInitialLoad,
    required bool enableMineBusinessLayer,
    required TabBarItemData? sourceTabBarItem,
  }) {
    return HomeCardListController(
      ref: ref,
      cards: cards,
      pageListId: pageListId,
      sourceTabBarItem: sourceTabBarItem ?? tabBarItem,
    );
  }
}
