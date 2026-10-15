import 'package:flutter/material.dart';

import 'st_unified_webview.dart';

export 'st_unified_webview.dart' show STWebConfig, STWebMode;

/// Mini 容器（小程序 / 特殊 H5）薄包装层。
///
/// 对齐 iOS `STMini` 框架的调用方式：
/// - `localMini://name` → 本地小程序（push 导航，胶囊栏）
/// - `miniprogram://name` → 在线小程序（全屏 present，胶囊栏）
/// - `http(s)://...` → 普通 H5（AppBar）
///
/// [routeParams]：对齐 `openWeb` 时 `PageRouter` merge 的除 `link/path/title` 外的 query（permission、isReplace 等）。
///
/// 底层由 [STUnifiedWebView] 统一实现。
class STMiniView extends StatelessWidget {
  final String link;
  final String path;
  final String? title;
  final Map<String, String>? routeParams;

  /// 为 true 时不包 Scaffold/AppBar，用于卡片内嵌（对齐 iOS 内嵌 Mini 卡片）
  final bool embedded;
  final bool visible;

  const STMiniView({
    super.key,
    required this.link,
    this.path = '',
    this.title,
    this.routeParams,
    this.embedded = false,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    final extraParams = <String, String>{
      ...?routeParams,
      if (path.isNotEmpty) 'path': path,
    };
    return STUnifiedWebView(
      visible: visible,
      config: STWebConfig.fromUrl(
        link,
        title: title,
        extraParams: extraParams.isEmpty ? null : extraParams,
        embedded: embedded,
      ),
    );
  }
}
