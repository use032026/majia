import 'h5_address_payload.dart';

/// H5 地址模型
/// 对齐 iOS STH5AddressModel，从 appConfig 的 h5_config 字段解析
///
/// 提供各 H5 页面的 URL 映射，用于虚拟路由跳转：
///   /partner    → partnerUrl
///   /taskcenter → taskcenterUrl
///   /vipcenter  → vipcenterUrl
///   /customer   → customerUrl
///   /help       → helpUrl
///   /about      → aboutUrl
///   /agreement  → agreementUrl
///   /privacy    → privacyUrl
///   /tutorial   → tutorialUrl
///   /faq        → faqUrl
class STH5AddressModel {
  /// API 密钥（用于 H5 页面鉴权）
  final String? apiKey;

  // ==================== 业务 H5 页面 ====================
  final String? partnerUrl; // 合作中心
  final String? taskcenterUrl; // 任务中心
  final String? vipcenterUrl; // 会员中心
  final String? customerUrl; // 客服
  final String? helpUrl; // 帮助中心
  final String? aboutUrl; // 关于我们
  final String? agreementUrl; // 用户协议
  final String? privacyUrl; // 隐私政策
  final String? tutorialUrl; // 教程
  final String? faqUrl; // 常见问题
  final String? traderUrl; // 交易员
  final String? newsUrl; // 资讯
  final String? calendarUrl; // 财经日历

  // ==================== 关于页 ====================
  final String? officialWebsiteAUrl; // 官网 A 面
  final String? officialWebsiteBUrl; // 官网 B 面
  final String? customerSupportUrl; // 客服支持页

  // ==================== 交易相关 ====================
  final String? strategyUrl; // 策略
  final String? activityUrl; // 活动中心

  STH5AddressModel({
    this.apiKey,
    this.partnerUrl,
    this.taskcenterUrl,
    this.vipcenterUrl,
    this.customerUrl,
    this.helpUrl,
    this.aboutUrl,
    this.agreementUrl,
    this.privacyUrl,
    this.tutorialUrl,
    this.faqUrl,
    this.traderUrl,
    this.newsUrl,
    this.calendarUrl,
    this.officialWebsiteAUrl,
    this.officialWebsiteBUrl,
    this.customerSupportUrl,
    this.strategyUrl,
    this.activityUrl,
  });

  /// 从原始 h5_config 字典解析
  factory STH5AddressModel.fromJson(Map<String, dynamic> json) {
    final data = normalizeH5AddressPayload(json);
    return STH5AddressModel(
      apiKey: data['api_key'] as String?,
      partnerUrl: data['partner_url'] as String?,
      taskcenterUrl: data['taskcenter_url'] as String?,
      vipcenterUrl: data['vipcenter_url'] as String?,
      // 对齐 iOS：customer_support_url（STMineViewController 用法）和 customer_url 均支持
      customerUrl:
          (data['customer_support_url'] ?? data['customer_url']) as String?,
      helpUrl: data['help_url'] as String?,
      aboutUrl: data['about_url'] as String?,
      agreementUrl:
          (data['agreement_url'] ?? data['user_agreement_url']) as String?,
      privacyUrl:
          (data['privacy_url'] ?? data['privacy_policy_url']) as String?,
      tutorialUrl: data['tutorial_url'] as String?,
      faqUrl: data['faq_url'] as String?,
      traderUrl: data['trader_url'] as String?,
      newsUrl: data['news_url'] as String?,
      calendarUrl: data['calendar_url'] as String?,
      officialWebsiteAUrl: data['official_website_a_url'] as String?,
      officialWebsiteBUrl: data['official_website_b_url'] as String?,
      customerSupportUrl: data['customer_support_url'] as String?,
      strategyUrl: data['strategy_url'] as String?,
      activityUrl: data['activity_url'] as String?,
    );
  }

  /// 获取指定路由对应的 H5 URL
  String? urlForRoute(String route) {
    switch (route) {
      case '/partner':
        return partnerUrl;
      case '/taskcenter':
        return taskcenterUrl;
      case '/vipcenter':
        return vipcenterUrl;
      case '/customer':
        return customerUrl;
      case '/help':
        return helpUrl;
      case '/about':
        return aboutUrl;
      case '/agreement':
        return agreementUrl;
      case '/privacy':
        return privacyUrl;
      case '/tutorial':
        return tutorialUrl;
      case '/faq':
        return faqUrl;
      case '/trader':
        return traderUrl;
      case '/news':
        return newsUrl;
      case '/calendar':
        return calendarUrl;
      case '/strategy':
        return strategyUrl;
      case '/activity':
        return activityUrl;
      default:
        return null;
    }
  }

  /// 获取所有已配置的 H5 路由映射
  Map<String, String> get configuredRoutes {
    final routes = <String, String>{};
    for (final entry in _routeKeyMap.entries) {
      final url = urlForRoute(entry.key);
      if (url != null && url.isNotEmpty) {
        routes[entry.key] = url;
      }
    }
    return routes;
  }

  static const Map<String, String> _routeKeyMap = {
    '/partner': 'partnerUrl',
    '/taskcenter': 'taskcenterUrl',
    '/vipcenter': 'vipcenterUrl',
    '/customer': 'customerUrl',
    '/help': 'helpUrl',
    '/about': 'aboutUrl',
    '/agreement': 'agreementUrl',
    '/privacy': 'privacyUrl',
    '/tutorial': 'tutorialUrl',
    '/faq': 'faqUrl',
    '/trader': 'traderUrl',
    '/news': 'newsUrl',
    '/calendar': 'calendarUrl',
    '/strategy': 'strategyUrl',
    '/activity': 'activityUrl',
  };
}

/// 所有虚拟 H5 路由路径列表（用于在路由表中注册）
const List<String> h5VirtualRoutes = [
  '/partner',
  '/taskcenter',
  '/vipcenter',
  '/customer',
  '/help',
  '/about',
  '/agreement',
  '/privacy',
  '/tutorial',
  '/faq',
  '/trader',
  '/strategy',
];
