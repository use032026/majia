import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Tab 配置模型
/// 对齐 iOS appConfigDic[@"tab_bar"][] 结构
class TabBarItemData {
  final String tabId;

  /// 对齐 iOS ConfigTabBarItemData.page_id → requestPageInfo 参数
  final int pageId;
  final String tabCode;
  final bool isHome;
  final String? showPermission;

  // 图标 URL（亮/暗、选中/未选中）
  final String? icon;
  final String? iconDark;
  final String? selIcon;
  final String? selIconDark;

  // 标题 && 标题样式
  final String? title;
  final Map<String, dynamic>? titleStyle;

  // 路由
  final String router;
  final String? link;

  // 背景
  final String? bgColor;
  final String? bgIcon;
  final String? bgIconDark;

  // 导航栏配置
  final NavInfo? navInfo;

  // 卡片列表（直接属于 Tab 的卡片）
  final List<ConfigCardItemData> cardItems;

  TabBarItemData({
    required this.tabId,
    this.pageId = 0,
    required this.tabCode,
    this.isHome = false,
    this.showPermission,
    this.icon,
    this.iconDark,
    this.selIcon,
    this.selIconDark,
    this.title,
    this.titleStyle,
    required this.router,
    this.link,
    this.bgColor,
    this.bgIcon,
    this.bgIconDark,
    this.navInfo,
    this.cardItems = const [],
  });

  factory TabBarItemData.fromJson(Map<String, dynamic> json) {
    // 兼容两种服务端格式：
    // 1. 驼峰 + 顶层 router（旧格式）
    // 2. 蛇形 + 嵌套 page.router（当前服务端格式）
    //    tab_bar: [{ page_code, page_id, is_home, icon, sel_icon, icon_dark,
    //                title, title_color, ..., extend, page: { id, code, type, router, ... } }]

    final pageObj = json['page'] as Map<String, dynamic>?;

    /// 与 iOS `ConfigTabBarItemData` 一致：顶层 `page_id` 与嵌套 `page.id` / `page.page_id` 均可作为拉页接口 id
    final dynamic rawTabPageId =
        json['page_id'] ?? pageObj?['id'] ?? pageObj?['page_id'];
    final pageId = rawTabPageId is int
        ? rawTabPageId
        : int.tryParse('$rawTabPageId') ?? 0;

    // tabId & tabCode
    final tabId =
        json['tabId'] as String? ??
        json['page_code'] as String? ??
        pageObj?['code'] as String? ??
        (pageId > 0 ? '$pageId' : '');
    final tabCode =
        json['tabCode'] as String? ?? json['page_code'] as String? ?? '';

    // isHome
    final isHome = json['isHome'] as bool? ?? json['is_home'] as bool? ?? false;

    // router（优先从 page.router 读取）
    final router =
        pageObj?['router'] as String? ?? json['router'] as String? ?? '';

    // icon fields（兼容蛇形和驼峰）
    final icon = json['icon'] as String?;
    final iconDark =
        json['iconDark'] as String? ?? json['icon_dark'] as String?;
    final selIcon = json['selIcon'] as String? ?? json['sel_icon'] as String?;
    final selIconDark =
        json['selIconDark'] as String? ?? json['sel_icon_dark'] as String?;

    // link
    final link = json['link'] as String? ?? pageObj?['link'] as String?;

    // title style
    var titleStyle = json['titleStyle'] as Map<String, dynamic>?;
    if (titleStyle == null && json['title_color'] != null) {
      // 从蛇形字段构建 titleStyle
      titleStyle = <String, dynamic>{
        if (json['title_color'] != null) 'color': json['title_color'],
        if (json['title_sel_color'] != null)
          'selColor': json['title_sel_color'],
        if (json['title_font'] != null) 'fontSize': json['title_font'],
        if (json['title_sel_font'] != null)
          'selFontSize': json['title_sel_font'],
        if (json['title_weight'] != null) 'weight': json['title_weight'],
        if (json['title_sel_weight'] != null)
          'selWeight': json['title_sel_weight'],
      };
    }

    // cardItems（对齐 iOS: page[@"cards"] 为来源）
    List<ConfigCardItemData> cardItems = [];
    // iOS 读取顺序: page.cards → 顶层 cardItems（兼容旧格式）
    final rawCardItems =
        (pageObj?['cards'] as List<dynamic>?) ??
        (json['cardItems'] as List<dynamic>?) ??
        (pageObj?['cardItems'] as List<dynamic>?) ??
        (json['cards'] as List<dynamic>?);

    if (rawCardItems != null) {
      debugPrint(
        '📄 Tab "${json['title'] ?? router}" — ${rawCardItems.length} cardItems',
      );
      cardItems = rawCardItems
          .map((e) => ConfigCardItemData.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      debugPrint(
        '📄 Tab "${json['title'] ?? router}" — pageObjKeys=${pageObj?.keys.join(",")}',
      );
    }

    // navInfo（对齐 iOS: page[@"nav"]）
    final rawNavInfo =
        (pageObj?['nav'] as Map<String, dynamic>?) ??
        (json['navInfo'] as Map<String, dynamic>?);
    final navInfo = rawNavInfo != null ? NavInfo.fromJson(rawNavInfo) : null;

    // 对齐 iOS: show_permission → showPermission, page.bg_color → bgColor
    final showPermission =
        json['show_permission'] as String? ?? json['showPermission'] as String?;
    final bgColor =
        pageObj?['bg_color'] as String? ??
        pageObj?['bgColor'] as String? ??
        json['bgColor'] as String?;
    // 对齐 iOS: page[@"bg_image"] / page[@"bg_image_dark"]
    final bgIcon = pageObj?['bg_image'] as String? ?? json['bgIcon'] as String?;
    final bgIconDark =
        pageObj?['bg_image_dark'] as String? ?? json['bgIconDark'] as String?;

    return TabBarItemData(
      tabId: tabId,
      pageId: pageId,
      tabCode: tabCode,
      isHome: isHome,
      showPermission: showPermission,
      icon: icon,
      iconDark: iconDark,
      selIcon: selIcon,
      selIconDark: selIconDark,
      title: json['title'] as String?,
      titleStyle: titleStyle,
      router: router,
      link: link,
      bgColor: bgColor,
      bgIcon: bgIcon,
      bgIconDark: bgIconDark,
      navInfo: navInfo,
      cardItems: cardItems,
    );
  }

  Map<String, dynamic> toJson() => {
    'tabId': tabId,
    'pageId': pageId,
    'tabCode': tabCode,
    'isHome': isHome,
    'showPermission': showPermission,
    'icon': icon,
    'iconDark': iconDark,
    'selIcon': selIcon,
    'selIconDark': selIconDark,
    'title': title,
    'titleStyle': titleStyle,
    'router': router,
    'link': link,
    'bgColor': bgColor,
    'bgIcon': bgIcon,
    'bgIconDark': bgIconDark,
    'navInfo': navInfo?.toJson(),
    'cardItems': cardItems.map((e) => e.toJson()).toList(),
  };

  /// 创建副本（用于不可变更新卡片数据等场景）
  TabBarItemData copyWith({
    List<ConfigCardItemData>? cardItems,
    int? pageId,
    NavInfo? navInfo,
    String? bgColor,
    String? bgIcon,
    String? bgIconDark,
  }) {
    return TabBarItemData(
      tabId: tabId,
      pageId: pageId ?? this.pageId,
      tabCode: tabCode,
      isHome: isHome,
      showPermission: showPermission,
      icon: icon,
      iconDark: iconDark,
      selIcon: selIcon,
      selIconDark: selIconDark,
      title: title,
      titleStyle: titleStyle,
      router: router,
      link: link,
      bgColor: bgColor ?? this.bgColor,
      bgIcon: bgIcon ?? this.bgIcon,
      bgIconDark: bgIconDark ?? this.bgIconDark,
      navInfo: navInfo ?? this.navInfo,
      cardItems: cardItems ?? this.cardItems,
    );
  }
}

/// 导航栏配置
class NavInfo {
  final String? navigationStyle;
  final String? title;
  final String? icon;
  final String? iconDark;
  final String? bgColor;
  final String? titleColor;
  final int? titleFont;
  final String? titleWeight;
  final List<ActionItem>? actionItems;
  final List<SubTabItem>? subTabs;

  NavInfo({
    this.navigationStyle,
    this.title,
    this.icon,
    this.iconDark,
    this.bgColor,
    this.titleColor,
    this.titleFont,
    this.titleWeight,
    this.actionItems,
    this.subTabs,
  });

  factory NavInfo.fromJson(Map<String, dynamic> json) {
    // iOS ConfigNaviBarItemData: nav_style、buttons/action_items、tabs/tab_items（无 subTabs）
    final rawTabs =
        json['tabs'] ??
        json['tab_items'] ??
        json['subTabs'] ??
        json['sub_tabs'];
    List<SubTabItem>? subTabs;
    if (rawTabs is List<dynamic>) {
      subTabs = rawTabs
          .map((e) => SubTabItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final rawButtons =
        json['actionItems'] as List<dynamic>? ??
        json['buttons'] as List<dynamic>? ??
        json['action_items'] as List<dynamic>?;

    return NavInfo(
      navigationStyle:
          json['navigationStyle'] as String? ?? json['nav_style'] as String?,
      title: json['title'] as String?,
      icon: json['icon'] as String?,
      iconDark: json['icon_dark'] as String? ?? json['iconDark'] as String?,
      bgColor: json['bg_color'] as String? ?? json['bgColor'] as String?,
      titleColor:
          json['title_color'] as String? ?? json['titleColor'] as String?,
      titleFont: json['title_font'] is int
          ? json['title_font'] as int
          : int.tryParse('${json['title_font'] ?? json['titleFont']}'),
      titleWeight:
          json['title_weight'] as String? ?? json['titleWeight'] as String?,
      actionItems: rawButtons
          ?.map((e) => ActionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      subTabs: subTabs,
    );
  }

  Map<String, dynamic> toJson() => {
    'navigationStyle': navigationStyle,
    'title': title,
    'icon': icon,
    'iconDark': iconDark,
    'bgColor': bgColor,
    'titleColor': titleColor,
    'titleFont': titleFont,
    'titleWeight': titleWeight,
    'actionItems': actionItems?.map((e) => e.toJson()).toList(),
    'subTabs': subTabs?.map((e) => e.toJson()).toList(),
  };
}

/// 导航栏操作按钮（对齐 iOS `ConfigActionItemData`：`style` 1 为文字，否则为图标）
class ActionItem {
  final String? title;
  final String? icon;
  final String? iconDark;

  /// 1 = 文字按钮，其它 = 图片按钮（见 `STNaviTabBarView`）
  final int? style;
  final String? titleColor;
  final int? titleFont;
  final String? titleWeight;
  final String? router;
  final String? routerPermission;
  final String? link;
  final Map<String, dynamic>? params;

  /// 对齐 iOS `ConfigActionItemData.items`（JSON 字段 `buttons` / `items`）
  final List<ActionItem> menuItems;

  ActionItem({
    this.title,
    this.icon,
    this.iconDark,
    this.style,
    this.titleColor,
    this.titleFont,
    this.titleWeight,
    this.router,
    this.routerPermission,
    this.link,
    this.params,
    this.menuItems = const [],
  });

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    final rawChildren =
        json['buttons'] as List<dynamic>? ?? json['items'] as List<dynamic>?;
    final children =
        rawChildren
            ?.map((e) => ActionItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <ActionItem>[];

    return ActionItem(
      title: json['title'] as String?,
      icon: json['icon'] as String?,
      iconDark: json['icon_dark'] as String?,
      style: json['style'] is int
          ? json['style'] as int
          : int.tryParse('${json['style']}'),
      titleColor: json['title_color'] as String?,
      titleFont: json['title_font'] is int
          ? json['title_font'] as int
          : int.tryParse('${json['title_font']}'),
      titleWeight: json['title_weight'] as String?,
      router: json['router'] as String?,
      routerPermission: json['router_permission'] as String?,
      link: json['link'] as String?,
      params: json['params'] as Map<String, dynamic>?,
      menuItems: children,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'icon': icon,
    'icon_dark': iconDark,
    'style': style,
    'title_color': titleColor,
    'title_font': titleFont,
    'title_weight': titleWeight,
    'router': router,
    'router_permission': routerPermission,
    'link': link,
    'params': params,
    if (menuItems.isNotEmpty)
      'buttons': menuItems.map((e) => e.toJson()).toList(),
  };
}

/// 子 Tab 项（对应 iOS `ConfigNaviBarTabItemData` + `page`）
class SubTabItem {
  final String title;

  /// 对齐 iOS ConfigNaviBarTabItemData.page_id
  final int pageId;
  final String? tabCode;
  final String? router;
  final String? link;
  final String? permission;
  final String? bgColor;
  final String? bgIcon;
  final String? bgIconDark;

  /// 对齐 iOS `title_color` / `title_sel_color` 等（`STNaviTabBarView`）
  final String? titleColor;
  final String? titleSelColor;
  final int titleFont;
  final int titleSelFont;
  final String? titleWeight;
  final String? titleSelWeight;

  /// 对齐 iOS `items`（子 Tab 自带操作区，优先于 `NavInfo.actionItems`）
  final List<ActionItem> tabActionItems;
  final List<ConfigCardItemData> cardItems;

  SubTabItem({
    required this.title,
    this.pageId = 0,
    this.tabCode,
    this.router,
    this.link,
    this.permission,
    this.bgColor,
    this.bgIcon,
    this.bgIconDark,
    this.titleColor,
    this.titleSelColor,
    this.titleFont = 16,
    this.titleSelFont = 18,
    this.titleWeight = 'regular',
    this.titleSelWeight = 'bold',
    this.tabActionItems = const [],
    this.cardItems = const [],
  });

  factory SubTabItem.fromJson(Map<String, dynamic> json) {
    final pageObj = json['page'] as Map<String, dynamic>?;
    final dynamic rawPid =
        json['page_id'] ??
        json['tab_id'] ??
        pageObj?['id'] ??
        pageObj?['page_id'];
    final pageId = rawPid is int ? rawPid : int.tryParse('$rawPid') ?? 0;

    // 对齐 iOS ConfigNaviBarTabItemData: page.router / page.cards / bg_image
    final rawCards =
        (pageObj?['cards'] as List<dynamic>?) ??
        (json['cards'] as List<dynamic>?) ??
        (json['cardItems'] as List<dynamic>?);

    int parseFont(dynamic v, int fallback) {
      if (v is int) return v;
      return int.tryParse('$v') ?? fallback;
    }

    final rawTabItems =
        json['buttons'] as List<dynamic>? ??
        json['action_items'] as List<dynamic>? ??
        json['items'] as List<dynamic>?;
    final tabActionItems =
        rawTabItems
            ?.map((e) => ActionItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return SubTabItem(
      title: json['title'] as String? ?? '',
      pageId: pageId,
      tabCode:
          json['page_code'] as String? ??
          json['tab_code'] as String? ??
          pageObj?['code'] as String?,
      router: pageObj?['router'] as String? ?? json['router'] as String?,
      link: pageObj?['link'] as String? ?? json['link'] as String?,
      permission:
          json['permission'] as String? ?? json['show_permission'] as String?,
      bgColor:
          pageObj?['bg_color'] as String? ??
          pageObj?['bgColor'] as String? ??
          json['bgColor'] as String?,
      bgIcon:
          pageObj?['bg_image'] as String? ??
          pageObj?['bgIcon'] as String? ??
          json['bgIcon'] as String?,
      bgIconDark:
          pageObj?['bg_image_dark'] as String? ??
          pageObj?['bgIconDark'] as String? ??
          json['bgIconDark'] as String?,
      titleColor:
          json['title_color'] as String? ?? pageObj?['title_color'] as String?,
      titleSelColor:
          json['title_sel_color'] as String? ??
          pageObj?['title_sel_color'] as String?,
      titleFont: parseFont(json['title_font'] ?? pageObj?['title_font'], 16),
      titleSelFont: parseFont(
        json['title_sel_font'] ?? pageObj?['title_sel_font'],
        18,
      ),
      titleWeight:
          json['title_weight'] as String? ??
          pageObj?['title_weight'] as String?,
      titleSelWeight:
          json['title_sel_weight'] as String? ??
          pageObj?['title_sel_weight'] as String?,
      tabActionItems: tabActionItems,
      cardItems:
          rawCards
              ?.map(
                (e) => ConfigCardItemData.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'pageId': pageId,
    'tabCode': tabCode,
    'router': router,
    'link': link,
    'permission': permission,
    'bgColor': bgColor,
    'bgIcon': bgIcon,
    'bgIconDark': bgIconDark,
    'titleColor': titleColor,
    'titleSelColor': titleSelColor,
    'titleFont': titleFont,
    'titleSelFont': titleSelFont,
    'titleWeight': titleWeight,
    'titleSelWeight': titleSelWeight,
    'tabActionItems': tabActionItems.map((e) => e.toJson()).toList(),
    'cardItems': cardItems.map((e) => e.toJson()).toList(),
  };
}

/// 配置卡片数据模型
/// 对齐 iOS ConfigCardItemData（增强版）
class ConfigCardItemData {
  final String cardId;
  final String cardStyle;

  /// 是否显示（对齐 iOS isShow）
  /// unlock 卡片初始为 false，API 加载确认有活动后置为 true
  bool isShow;
  final String? title;
  final String? bgColor;
  final String? cardType; // native / web / mini
  final String? cardTypedef;
  final double? aspectRatio;
  final String? showPermission;
  final String? link;
  final Map<String, dynamic>? cardDetail;

  ConfigCardItemData({
    required this.cardId,
    required this.cardStyle,
    this.isShow = true,
    this.title,
    this.bgColor,
    this.cardType,
    this.cardTypedef,
    this.aspectRatio,
    this.showPermission,
    this.link,
    this.cardDetail,
  });

  factory ConfigCardItemData.fromJson(Map<String, dynamic> json) {
    // 对齐 iOS ConfigCardItemData.initWithDic:
    //   code → cardId, style → cardStyle, payload → cardDetail (JSON String → Map)
    //   bg_color → bgColor, show_permission → showPermission, aspect_ratio → aspectRatio
    final cardId = json['code'] as String? ?? json['cardId'] as String? ?? '';
    final rawCardStyle =
        (json['style'] as String? ??
                json['card_style'] as String? ??
                json['cardStyle'] as String? ??
                json['header_style'] as String? ??
                json['balance_style'] as String? ??
                json['account_style'] as String? ??
                json['list_style'] as String? ??
                json['unlock_style'] as String? ??
                json['unlockStyle'] as String? ??
                json['slip_style'] as String? ??
                json['category_style'] as String? ??
                json['categoryStyle'] as String? ??
                json['categorymarket_style'] as String? ??
                json['categorymarketStyle'] as String? ??
                json['ad_style'] as String? ??
                '')
            .trim();
    final cardStyle = _normalizeBackendCardStyle(rawCardStyle);
    final cardType = json['type'] as String? ?? json['cardType'] as String?;
    final bgColor = json['bg_color'] as String? ?? json['bgColor'] as String?;
    final showPermission =
        json['show_permission'] as String? ?? json['showPermission'] as String?;
    // iOS 可能传字符串（如 "3:4"），需要安全转换
    // 对齐 iOS ConfigCardItemData.m 行 276-283
    double? aspectRatio;
    final rawAspect = json['aspect_ratio'] ?? json['aspectRatio'];
    if (rawAspect is num) {
      aspectRatio = rawAspect.toDouble();
    } else if (rawAspect is String && rawAspect.contains(':')) {
      // 处理 "16:9" 或 "3:4" 格式字符串比值
      final parts = rawAspect.split(':');
      if (parts.length == 2) {
        final w = double.tryParse(parts[0]);
        final h = double.tryParse(parts[1]);
        if (w != null && h != null && h > 0) {
          aspectRatio = w / h;
        }
      }
    }

    // payload 可能是 JSON 字符串或 Map（iOS 存为 String，Dart 可能直接解析为 Map）
    Map<String, dynamic>? cardDetail;
    final payload = json['payload'] ?? json['cardDetail'];
    if (payload is Map<String, dynamic>) {
      cardDetail = payload;
    } else if (payload is String && payload.isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          cardDetail = decoded;
        }
      } catch (_) {}
    }

    // 对齐 iOS: unlock 卡片默认不显示（在卡片数据加载并验证通过后置为 true）
    bool isShow = json['isShow'] as bool? ?? true;
    if (cardStyle.startsWith('unlock_')) {
      isShow = false;
    }

    // 对齐 iOS: cardType 字符串映射到 cardTypedef 枚举值
    //   native → native, web → web, online → mini
    String? cardTypedef;
    if (cardType == 'native') {
      cardTypedef = 'native';
    } else if (cardType == 'web') {
      cardTypedef = 'web';
    } else if (cardType == 'online') {
      cardTypedef = 'mini';
    } else if (cardType != null) {
      cardTypedef = cardType; // fallback: 保留原始值
    }

    return ConfigCardItemData(
      cardId: cardId,
      cardStyle: cardStyle,
      isShow: isShow,
      title: json['title'] as String?,
      bgColor: bgColor,
      cardType: cardType,
      cardTypedef: cardTypedef,
      aspectRatio: aspectRatio,
      showPermission: showPermission,
      link: json['link'] as String?,
      cardDetail: cardDetail,
    );
  }

  Map<String, dynamic> toJson() => {
    'cardId': cardId,
    'cardStyle': cardStyle,
    'isShow': isShow,
    'title': title,
    'bgColor': bgColor,
    'cardType': cardType,
    'cardTypedef': cardTypedef,
    'aspectRatio': aspectRatio,
    'showPermission': showPermission,
    'link': link,
    'cardDetail': cardDetail,
  };

  static String _normalizeBackendCardStyle(String style) {
    if (style.startsWith('header_')) return 'header_4';
    if (style.startsWith('balance_')) return 'balance_3';
    if (style.startsWith('account_')) return 'account_3';
    if (style.startsWith('list_')) return 'list_2';
    if (style.startsWith('unlock_')) return 'unlock_2';
    if (style.startsWith('slip_')) return 'slip_1';
    if (style.startsWith('categorymarket_')) return 'categorymarket_2';
    if (style.startsWith('category_') ||
        RegExp(r'^category\d').hasMatch(style)) {
      return 'category_1';
    }
    if (style.startsWith('ad_')) return 'ad_1';
    return style;
  }

  /// 创建副本（用于更新 cardDetail / isShow 等）
  ConfigCardItemData copyWith({
    Map<String, dynamic>? cardDetail,
    bool? isShow,
  }) {
    return ConfigCardItemData(
      cardId: cardId,
      cardStyle: cardStyle,
      isShow: isShow ?? this.isShow,
      title: title,
      bgColor: bgColor,
      cardType: cardType,
      cardTypedef: cardTypedef,
      aspectRatio: aspectRatio,
      showPermission: showPermission,
      link: link,
      cardDetail: cardDetail ?? this.cardDetail,
    );
  }
}
