/// 卡片导航回调（对齐 iOS CardRouterOpen → STRouterManager.openPageWithRouter:params:）
typedef CardNavigateCallback =
    void Function(String path, Map<String, dynamic>? params, {String? action});
