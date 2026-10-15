import 'package:flutter/material.dart';

import 'st_unified_webview.dart';

export 'st_unified_webview.dart' show STWebConfig, STWebMode;

/// 传统 H5 WebView 容器（薄包装层）。
///
/// 对齐 iOS `STBaseWebViewController` 的调用方式：传入 URL 和可选标题。
/// 底层由 [STUnifiedWebView] 统一实现，支持 JSBridge、深色模式通知、标题自动更新等。
///
/// [routeParams] 对齐 iOS `STWebOpenHandler.openWeb(url, params)` 中与 `link` 一并下发的字段
///（如 permission、isReplace）；最终加载 URL 会做两轮 query 合并（与 `openH5` 一致）。
///
/// 如需更细粒度控制（小程序模式等），直接使用 [STUnifiedWebView]。
class STWebView extends StatelessWidget {
  final String url;
  final String? title;
  final bool showNavigationBar;
  final Map<String, String>? headers;

  /// 宿主路由层附带参数（不含 `link` 自身；可含 permission、isReplace、isNeedNavigationBar 等）
  final Map<String, String>? routeParams;

  const STWebView({
    super.key,
    required this.url,
    this.title,
    // 对齐 iOS STBaseWebViewController：isNeedNavigationBar 默认 false
    this.showNavigationBar = false,
    this.headers,
    this.routeParams,
  });

  @override
  Widget build(BuildContext context) {
    return STUnifiedWebView(
      config: STWebConfig.h5FromRouter(
        link: url,
        routeQueryExtras: routeParams,
        explicitTitle: title,
        navigationBarFallback: showNavigationBar,
      ),
    );
  }
}
