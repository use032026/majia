import 'package:flutter/material.dart';

import 'mine_configured_page.dart';

/// 「我的」页面入口。
///
/// iOS `STNewMineViewController` 继承 `STProjectListViewController`，页面结构由
/// app/page 配置接口下发的 cards、背景和导航栏驱动。Flutter 端不再保留旧的
/// Figma 静态拼页，统一交给 [ConfiguredMinePage] 复用配置化卡片列表实现。
class MinePage extends StatelessWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ConfiguredMinePage();
  }
}
