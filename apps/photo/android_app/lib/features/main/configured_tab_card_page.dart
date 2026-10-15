import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/config_data_manager.dart';
import '../../core/models/tab_bar_item.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../home/card_list_page.dart';
import '../home/home_page.dart';

/// 根据 App 配置里 `tab_bar` 中指定 router 的 Tab，渲染卡片首页。
/// 用于独立路由（如 `/market`）与底部 Tab 行为一致：卡片化 + page_id 补全。
class ConfiguredTabCardPage extends ConsumerWidget {
  final String router;

  const ConfiguredTabCardPage({super.key, required this.router});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(configDataManagerProvider).tabs;
    TabBarItemData? match;
    for (final t in tabs) {
      if (t.router == router) {
        match = t;
        break;
      }
    }

    if (match == null) {
      return Scaffold(
        appBar: AppBar(title: Text(router)),
        body: Center(
          child: Text(
            '未在 tab_bar 中找到 $router 配置',
            style: TextStyle(color: context.adaptiveTextTertiary),
          ),
        ),
      );
    }

    if (router == '/home' || match.isHome) {
      return HomePage(
        title: match.title ?? '',
        cards: const [],
        tabBarItem: match,
      );
    }

    return CardListPage(
      title: match.title ?? '',
      cards: const [],
      tabBarItem: match,
    );
  }
}
