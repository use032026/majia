import 'package:flutter/foundation.dart';

/// 首页/卡片跳转日志（格式：`xx操作-地址：xxxx`）
class NavigationLogger {
  NavigationLogger._();

  static void log({
    required String action,
    required String path,
    Map<String, dynamic>? params,
    String? resolvedLocation,
  }) {
    final address = resolvedLocation != null
        ? formatResolvedLocation(path, resolvedLocation)
        : formatAddress(path, params);
    debugPrint('$action-地址：$address');
  }

  /// 将路由 + 参数格式化为可读地址（日志展示用，会自动 decode）
  static String formatAddress(String path, Map<String, dynamic>? params) {
    final p = params ?? const {};
    if (path.toLowerCase() == '/web') {
      final link = p['link']?.toString() ?? '';
      if (link.isEmpty) return '/web';
      return link;
    }
    if (path.toLowerCase() == '/mini') {
      final link = p['link']?.toString() ?? '';
      if (link.isEmpty) return '/mini';
      return link;
    }
    final scalar = <String, String>{};
    p.forEach((k, v) {
      if (v != null && v is! Map && v is! List) {
        scalar[k] = v.toString();
      }
    });
    if (scalar.isEmpty) return path;
    final q = Uri(queryParameters: scalar).query;
    return q.isEmpty ? path : '$path?$q';
  }

  /// 日志里输出最终 H5 真实地址（`/web?link=` 会 decode 成可读 URL）
  static String formatResolvedLocation(String router, String loc) {
    if (router.toLowerCase() == '/web' || router.toLowerCase() == '/mini') {
      final parsed = Uri.tryParse(loc);
      final link = parsed?.queryParameters['link'];
      if (link != null && link.isNotEmpty) return link;
    }
    return loc;
  }

  /// 根据 cardStyle 推断操作名（首页卡片未显式传 action 时使用）
  static String actionForCardStyle(String cardStyle) {
    if (cardStyle.startsWith('header_')) return 'Header用户区';
    if (cardStyle.startsWith('grid_')) return 'Grid快捷入口';
    if (cardStyle.startsWith('banner_')) return 'Banner轮播';
    if (cardStyle.startsWith('market_')) return '行情卡片';
    if (cardStyle.startsWith('selfmarket_')) return '自选行情';
    if (cardStyle.startsWith('categorymarket_')) return '分类行情';
    if (cardStyle.startsWith('category_')) return '分类Tab';
    if (cardStyle.startsWith('unlock_')) return '交易解锁';
    if (cardStyle.startsWith('vip_')) return 'VIP卡片';
    if (cardStyle.startsWith('balance_')) return '余额卡片';
    if (cardStyle.startsWith('button_')) return '按钮卡片';
    if (cardStyle.startsWith('horse_')) return '跑马灯';
    if (cardStyle.startsWith('list_')) return '列表卡片';
    if (cardStyle.startsWith('newslist_')) return '资讯卡片';
    if (cardStyle.startsWith('nav_') || cardStyle.startsWith('tabnav_')) {
      return '导航卡片';
    }
    if (cardStyle.startsWith('ad_')) return '广告卡片';
    if (cardStyle.startsWith('slip_')) return 'Slip卡片';
    return '卡片跳转($cardStyle)';
  }

  /// 根据路由推断操作名（STRouter 兜底）
  static String actionForRouter(String router, Map<String, dynamic>? params) {
    final r = router.toLowerCase();
    switch (r) {
      case '/login':
        return '登录';
      case '/register':
        return '注册';
      case '/mine/profile':
      case '/mine/editinfo':
        return '个人资料';
      case '/mine/set':
      case '/mine/setting':
        return '设置';
      case '/customer':
        return '客服';
      case '/mine/asset':
      case '/mine/wallet':
        return '钱包资产';
      case '/market/detail':
      case '/market/productdetail':
        return '行情详情';
      case '/market':
        return '行情Tab';
      case '/news':
        return '资讯Tab';
      case '/news/detail':
        return '资讯详情';
      case '/vipcenter':
        return '会员中心';
      case '/partner':
        return '合作中心';
      case '/web':
        return '网页';
      case '/mini':
        return '小程序';
      case '/home':
        return '首页Tab';
      case '/mine':
        return '我的Tab';
      case '/trade':
      case '/trade1':
        return '交易Tab';
      case '/action/popviewvipinfo':
        return 'VIP升级条件';
      case '/action/popviewmarginlevel':
        return '保证金说明';
      default:
        if (r.startsWith('/tabbar/')) return 'Tab切换';
        if (r.startsWith('/action/')) return '活动弹窗';
        return '页面跳转';
    }
  }
}
