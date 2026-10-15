import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/config_data_manager.dart';
import '../models/user_state.dart';
import '../providers/tab_shell_navigation.dart';
import '../providers/trade_jump_navigation.dart';
import '../services/wallet_action_handler.dart';
import 'app_router.dart';
import 'card_action_handlers.dart';
import 'navigation_logger.dart';
import 'router_guard.dart';

class STRouteResolution {
  final String router;
  final Map<String, dynamic> params;
  final String location;

  const STRouteResolution({
    required this.router,
    required this.params,
    required this.location,
  });
}

/// Pure route normalization for iOS `STRouterManager+Detail`.
///
/// This keeps the Objective-C routing contract testable without pushing a
/// Flutter route: aliases, LocalMiniRouter, query params, and final locations.
class STRouteResolver {
  static const Map<String, String> _localMiniRouter = {
    '/davmu': '/mini?link=localMini://davmu',
    '/davmu/documentary/statement':
        '/mini?link=localMini://davmu&path=/documentary/statement',
    '/davmu/documentary/plan': '',
    '/davmu/documentary/detail/management':
        '/mini?link=localMini://davmu&path=/documentary/detail/management&permission=login',
    '/davmu/documentary/exam/':
        '/mini?link=localMini://davmu&path=/exam/&permission=login',
    '/davmu/exam/traderMiddlePage':
        '/mini?link=localMini://davmu&path=/exam/traderMiddlePage',
  };

  static STRouteResolution resolveCore(
    String path, {
    Map<String, dynamic>? params,
    STH5AddressModel? h5,
    bool isSignalProvider = false,
    bool isTakeExam = false,
  }) {
    var router = path.trim();
    var p = Map<String, dynamic>.from(params ?? {});

    if (router.isEmpty) {
      return const STRouteResolution(router: '', params: {}, location: '');
    }

    final shortcut = _resolveH5Shortcut(router, p, h5);
    if (shortcut != null) {
      router = shortcut.router;
      p = shortcut.params;
    }

    final lowerRouterForPolicy = router.toLowerCase();
    if (RouterGuard.pageRouterPermissionForPath(
          lowerRouterForPolicy,
        ).isNotEmpty &&
        (p['permission'] == null ||
            (p['permission'] is String &&
                (p['permission'] as String).trim().isEmpty))) {
      p['permission'] = 'login';
    }

    if (lowerRouterForPolicy == '/mine/wallet' ||
        lowerRouterForPolicy == '/mine/bank' ||
        lowerRouterForPolicy == '/mine/bankcard') {
      p['type'] = 0;
    } else if (lowerRouterForPolicy == '/mine/account' ||
        lowerRouterForPolicy == '/mine/ewallet') {
      p['type'] = 1;
    }

    final canonical = AppRouter.canonicalRedirectPath(router);
    if (canonical != null) {
      router = canonical;
    }
    if (router.toLowerCase() == '/market/productdetail') {
      router = '/market/detail';
    }

    final miniRouter = _localMiniPathFor(
      router,
      isSignalProvider: isSignalProvider,
      isTakeExam: isTakeExam,
    );
    if (miniRouter != null && miniRouter.isNotEmpty) {
      router = miniRouter;
    }

    if (router.contains('?')) {
      final uri = Uri.tryParse(router);
      if (uri != null) {
        final merged = <String, dynamic>{...uri.queryParameters, ...p};
        return resolveCore(
          uri.path,
          params: merged,
          h5: h5,
          isSignalProvider: isSignalProvider,
          isTakeExam: isTakeExam,
        );
      }
    }

    router = router.toLowerCase();

    if (router == '/web') {
      final link = (p['link'] as String? ?? '').trim();
      if (link.isNotEmpty) {
        final examMid = h5?.traderExamMiddlePageUrl ?? '';
        if (examMid.isNotEmpty && link.contains('/exam/traderMiddlePage')) {
          router = '/mini';
          p = {'link': examMid};
        } else {
          final customerUrl = h5?.customerSupportUrl ?? '';
          if (customerUrl.isNotEmpty && link == customerUrl) {
            p['isNeedNavigationBar'] = true;
          }
        }
      }
    }

    if (!p.containsKey('type')) {
      if (router == '/mine/wallet' ||
          router == '/mine/bank' ||
          router == '/mine/bankcard') {
        p['type'] = 0;
      } else if (router == '/mine/account' || router == '/mine/ewallet') {
        p['type'] = 1;
      }
    }

    p = handleValueToString(p, ['isNeedNavigationBar', 'type', 'isReplace']);

    return STRouteResolution(
      router: router,
      params: p,
      location: buildLocation(router, p),
    );
  }

  static ({String router, Map<String, dynamic> params})? _resolveH5Shortcut(
    String router,
    Map<String, dynamic> params,
    STH5AddressModel? h5,
  ) {
    if (router == '/partner') {
      final url = h5?.partnerUrl ?? '';
      if (url.isNotEmpty) {
        return (router: '/web', params: {'link': url, 'permission': 'login'});
      }
    }
    if (router == '/taskcenter') {
      final url = h5?.taskcenterUrl ?? '';
      if (url.isNotEmpty) {
        return (router: '/web', params: {'link': url, 'permission': 'login'});
      }
    }
    if (router == '/vipcenter') {
      final url = h5?.vipCenterUrl ?? '';
      if (url.isNotEmpty) {
        return (router: '/web', params: {'link': url, 'permission': 'login'});
      }
    }
    if (router == '/customer') {
      final url = h5?.customerSupportUrl ?? '';
      if (url.isNotEmpty) return (router: '/web', params: {'link': url});
    }
    if (router == '/agreement') {
      final url = h5?.userAgreementUrl ?? '';
      if (url.isNotEmpty) return (router: '/web', params: {'link': url});
    }
    if (router == '/privacy') {
      final url = h5?.privacyPolicyUrl ?? '';
      if (url.isNotEmpty) return (router: '/web', params: {'link': url});
    }
    return null;
  }

  static String? _localMiniPathFor(
    String router, {
    required bool isSignalProvider,
    required bool isTakeExam,
  }) {
    if (!_localMiniRouter.containsKey(router)) return null;
    if (router == '/davmu/documentary/plan') {
      final target = isSignalProvider || isTakeExam
          ? '/davmu/documentary/detail/management'
          : '/davmu/documentary/exam/';
      return _localMiniRouter[target];
    }
    return _localMiniRouter[router];
  }

  static Map<String, dynamic> handleValueToString(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    final muti = Map<String, dynamic>.from(source);
    for (final key in keys) {
      final val = muti[key];
      if (val != null) {
        if (val is bool) {
          muti[key] = val ? '1' : '0';
        } else if (val is num) {
          muti[key] = val != 0 ? '1' : '0';
        }
      }
    }
    return muti;
  }

  static String buildLocation(String router, Map<String, dynamic> params) {
    final lower = router.toLowerCase();

    if (lower == '/web') {
      final link = params['link'] as String? ?? '';
      if (link.isEmpty) return '/web';
      final query = <String, String>{'link': link};
      final navVal = params['isNeedNavigationBar'];
      if (_truthy(navVal)) query['nav'] = '1';
      final title = params['title'] as String? ?? '';
      if (title.isNotEmpty) query['title'] = title;
      _appendScalarExtras(query, params, {
        'link',
        'isNeedNavigationBar',
        'title',
        'permission',
      });
      return '/web?${Uri(queryParameters: query).query}';
    }

    if (lower == '/mini') {
      final link = params['link'] as String? ?? '';
      if (link.isEmpty) return '/mini';
      final query = <String, String>{'link': link};
      final path = params['path'] as String? ?? '';
      if (path.isNotEmpty) query['path'] = path;
      final title = params['title'] as String? ?? '';
      if (title.isNotEmpty) query['title'] = title;
      _appendScalarExtras(query, params, {'link', 'path', 'title'});
      return '/mini?${Uri(queryParameters: query).query}';
    }

    if (lower == '/market/detail') {
      final symbol =
          params['symbol'] as String? ?? params['link'] as String? ?? '';
      if (symbol.isEmpty) return '/market/detail';
      return '/market/detail?symbol=${Uri.encodeComponent(symbol)}';
    }

    if (lower == '/trade/orderdetail') {
      final orderId = params['orderId'] as String? ?? '';
      final q = <String, String>{};
      if (orderId.isNotEmpty) q['orderId'] = orderId;
      final type = params['type'] ?? params['orderType'] ?? params['selType'];
      if (type != null && type.toString().isNotEmpty) {
        q['type'] = type.toString();
      }
      if (q.isEmpty) return '/trade/orderdetail';
      return '/trade/orderdetail?${Uri(queryParameters: q).query}';
    }

    if (lower == '/trade/order') {
      final q = <String, String>{};
      params.forEach((k, v) {
        if (v != null && v.toString().isNotEmpty) {
          q[k] = v.toString();
        }
      });
      if (q.isEmpty) return '/trade/order';
      return '/trade/order?${Uri(queryParameters: q).query}';
    }

    if (lower == '/trade/accountprofile') {
      final q = <String, String>{};
      if (params['fromType'] != null) {
        q['fromType'] = params['fromType'].toString();
      }
      if (params['selType'] != null) {
        q['selType'] = params['selType'].toString();
      }
      if (params['accountId'] != null) {
        q['accountId'] = params['accountId'].toString();
      }
      if (q.isEmpty) return '/trade/accountprofile';
      return '/trade/accountprofile?${Uri(queryParameters: q).query}';
    }

    if (lower == '/market/contract_specs') {
      final symbol = params['symbol'] as String? ?? '';
      if (symbol.isEmpty) return '/market/contract_specs';
      return '/market/contract_specs?symbol=${Uri.encodeComponent(symbol)}';
    }

    if (lower == '/mine/finance_password') {
      final mode = params['mode'] as String? ?? '';
      if (mode.isEmpty) return '/mine/finance_password';
      return '/mine/finance_password?mode=${Uri.encodeComponent(mode)}';
    }

    if (lower == '/mine/profile/nickname' ||
        lower == '/mine/profile/signature') {
      return router;
    }

    if (lower == '/mine/wallet/flow/detail') {
      return '/mine/wallet/flow/detail';
    }

    if (lower == '/mine/commit_success') {
      return '/mine/commit_success';
    }

    if (lower == '/mine/wallet/finish') {
      return '/mine/wallet/finish';
    }

    final scalarParams = <String, String>{};
    _appendScalarExtras(scalarParams, params, {'permission'});
    if (scalarParams.isEmpty) return router;
    return '$router?${Uri(queryParameters: scalarParams).query}';
  }

  static void _appendScalarExtras(
    Map<String, String> query,
    Map<String, dynamic> params,
    Set<String> excluded,
  ) {
    for (final entry in params.entries) {
      final key = entry.key;
      final value = entry.value;
      if (excluded.contains(key) ||
          key == 'isOnce' ||
          key == 'isReplace' ||
          value == null ||
          value is Map ||
          value is List ||
          value.toString().isEmpty) {
        continue;
      }
      query[key] = value.toString();
    }
  }

  static bool _truthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value.toString().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }
}

/// 统一路由导航工具
/// 对齐 iOS STRouterManager.openPageWithRouter:params:
///
/// 职责：
/// 1. 特殊网页路由转换（/partner /taskcenter /vipcenter /customer）
/// 2. Tab 切换路由（/tabbar/:tabCode）
/// 3. 本地小程序路由映射（LocalMiniRouter）
/// 4. router 含 ? 时的拆分重调用
/// 5. /web 内嵌特殊处理（客服导航栏、交易员考试中间页）
/// 6. /mine/wallet|bank → type=0；/mine/account|ewallet → type=1
/// 7. 权限检查 + 登录失败后挂起路由，登录成功后重试
/// 8. 最终调用 GoRouter 进行页面跳转
class STRouter {
  final Ref ref;

  STRouter._(this.ref);

  /// 从 ref 创建实例
  static STRouter of(Ref ref) => STRouter._(ref);

  /// 打开页面（主入口）
  ///
  /// [path]  路由路径（如 /mine/wallet）
  /// [params] 附加参数（可为 null）
  /// [context] 用于 Navigator
  /// [useGo] 是否使用 context.go（默认 push）
  Future<void> openPage(
    BuildContext context,
    String path, {
    Map<String, dynamic>? params,
    bool useGo = false,
    String? action,
  }) async {
    var router = path.trim();
    var p = Map<String, dynamic>.from(params ?? {});

    if (router.isEmpty) return;

    final userState = ref.read(userStateProvider);
    final h5 = userState.h5AddressModel;
    final resolved = STRouteResolver.resolveCore(
      router,
      params: p,
      h5: h5,
      isSignalProvider: userState.isSignalProvider,
      isTakeExam: userState.isTakeExam,
    );
    router = resolved.router;
    p = resolved.params;

    // iOS PageRouter / STRouterManager 路径别名
    final canonical = AppRouter.canonicalRedirectPath(router);
    if (canonical != null) {
      router = canonical;
    }
    if (router.toLowerCase() == '/market/productdetail') {
      router = '/market/detail';
    }

    // ================================================================
    // 1. 特殊网页路由转换（对齐 iOS STRouterManager+Detail.m）
    // ================================================================
    if (router == '/partner') {
      final url = h5?.partnerUrl ?? '';
      if (url.isNotEmpty) {
        router = '/web';
        p = {'link': url, 'permission': 'login'};
      }
    } else if (router == '/taskcenter') {
      final url = h5?.taskcenterUrl ?? '';
      if (url.isNotEmpty) {
        router = '/web';
        p = {'link': url, 'permission': 'login'};
      }
    } else if (router == '/vipcenter') {
      final url = h5?.vipCenterUrl ?? '';
      if (url.isNotEmpty) {
        router = '/web';
        p = {'link': url, 'permission': 'login'};
      }
    } else if (router == '/customer') {
      final url = h5?.customerSupportUrl ?? '';
      if (url.isNotEmpty) {
        router = '/web';
        p = {'link': url, 'isNeedNavigationBar': '1'};
      }
    }

    // ================================================================
    // 2. Tab 切换路由（对齐 iOS popToTabbarPageWithPath / popToMarketpage）
    // ================================================================
    if (router.toLowerCase() == '/home') {
      NavigationLogger.log(
        action: action ?? '首页Tab',
        path: router,
        resolvedLocation: '/',
      );
      _switchBottomTab(context, tabCode: 'home');
      return;
    }

    if (router.toLowerCase() == '/mine') {
      NavigationLogger.log(
        action: action ?? '我的Tab',
        path: router,
        resolvedLocation: '/',
      );
      _switchBottomTab(context, tabCode: 'mine');
      return;
    }

    if (router.toLowerCase() == '/trade' || router.toLowerCase() == '/trade1') {
      await jumpToTradePage(
        context,
        symbol: (p['symbol'] as String?)?.trim(),
        isBuy: _tradeDirectionIsBuy(p),
        action: action ?? '交易Tab',
        params: p,
      );
      return;
    }

    if (router.toLowerCase() == '/tab') {
      NavigationLogger.log(
        action: action ?? '发现Tab',
        path: router,
        resolvedLocation: '/',
      );
      _switchBottomTab(context, tabCode: _secHomeTabCode());
      return;
    }

    if (router.toLowerCase() == '/news') {
      NavigationLogger.log(
        action: action ?? '资讯Tab',
        path: router,
        params: p,
        resolvedLocation: '/',
      );
      _switchBottomTab(
        context,
        tabCode: _secHomeTabCode(),
        innerTabCode: 'news',
      );
      return;
    }

    if (router.toLowerCase() == '/action/documentaryhome') {
      NavigationLogger.log(
        action: action ?? '跟单Tab',
        path: router,
        resolvedLocation: '/',
      );
      _switchBottomTab(
        context,
        tabCode: _secHomeTabCode(),
        innerTabCode: 'documentary',
      );
      return;
    }

    if (router.toLowerCase() == '/market') {
      NavigationLogger.log(
        action: action ?? '行情Tab',
        path: router,
        params: p,
        resolvedLocation: '/',
      );
      _switchBottomTab(
        context,
        tabCode: 'market',
        innerTabCode: (p['segment'] as String?) ?? 'optional',
      );
      return;
    }

    if (router.startsWith('/tabbar/')) {
      NavigationLogger.log(
        action: action ?? 'Tab切换',
        path: router,
        params: p,
        resolvedLocation: '/',
      );
      final rest = router.substring('/tabbar/'.length);
      final parts = rest.split('/').where((e) => e.trim().isNotEmpty).toList();
      if (parts.isNotEmpty) {
        _switchBottomTab(
          context,
          tabCode: parts.first,
          innerTabCode: parts.length > 1 ? parts.last : null,
        );
      }
      return;
    }

    // ================================================================
    // 3. router 含 ? 时拆分为 path + params 重新调用（对齐 iOS）
    // ================================================================
    if (router.contains('?')) {
      final uri = Uri.tryParse(router);
      if (uri != null) {
        final newPath = uri.path;
        final queryParams = Map<String, String>.from(uri.queryParameters);
        // query 参数覆盖外部 params 的同名键
        final merged = Map<String, dynamic>.from(p);
        merged.addAll(queryParams);
        // 递归调用，但避免再次进入含 ? 分支（已拆分）
        await openPage(
          context,
          newPath,
          params: merged,
          useGo: useGo,
          action: action,
        );
        return;
      }
    }

    // ================================================================
    // 4. /web 内嵌特殊处理
    // ================================================================
    if (router.toLowerCase() == '/web') {
      var link = (p['link'] as String? ?? '').trim();
      if (link.isNotEmpty) {
        // 交易员考试中间页 → /mini
        final examMid = h5?.traderExamMiddlePageUrl ?? '';
        if (examMid.isNotEmpty && link.contains('/exam/traderMiddlePage')) {
          router = '/mini';
          p = {'link': examMid};
        }
        // 客服链接强制显示导航栏
        final customerUrl = h5?.customerSupportUrl ?? '';
        if (customerUrl.isNotEmpty && link == customerUrl) {
          p['isNeedNavigationBar'] = '1';
        }
      }
    }

    // ================================================================
    // 5. 钱包/银行卡/账户/电子钱包 type 注入（对齐 iOS）
    // ================================================================
    final lowerRouter = router.toLowerCase();
    if (!p.containsKey('type')) {
      if (lowerRouter == '/mine/wallet' ||
          lowerRouter == '/mine/bank' ||
          lowerRouter == '/mine/bankcard') {
        p['type'] = '0';
      } else if (lowerRouter == '/mine/account' ||
          lowerRouter == '/mine/ewallet') {
        p['type'] = '1';
      }
    }

    // ================================================================
    // 6. 布尔值统一转字符串（对齐 iOS handleValueToString）
    // ================================================================
    p = _handleValueToString(p, ['isNeedNavigationBar', 'type', 'isReplace']);

    // ================================================================
    // 6b. `/action/popview*` 弹窗（对齐 iOS STStartViewController + STConfigCardHandler）
    // ================================================================
    if (router.toLowerCase().startsWith('/action/popview')) {
      NavigationLogger.log(
        action: action ?? NavigationLogger.actionForRouter(router, p),
        path: router,
        params: p,
      );
      final handled = await CardActionHandlers.handlePopViewRoute(
        context,
        ref,
        router,
        p,
      );
      if (handled) return;
    }

    // ================================================================
    // 7. 权限检查（对齐 iOS PageRouter.permissionCheck）
    // ================================================================
    final permissionStr = p['permission'] as String? ?? '';
    final permissionAry = permissionStr.isNotEmpty
        ? permissionStr
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];

    if (permissionAry.isNotEmpty) {
      final isLoggedIn = ref.read(userStateProvider).isLogin;
      final canLoginRoute = await RouterGuard.shouldAllowByLogin(
        isLoginState: isLoggedIn,
      );
      if (permissionAry.contains('login') && !canLoginRoute) {
        // 挂起路由，登录成功后重试
        final isOnce =
            p['isOnce'] == '1' || p['isOnce'] == 1 || p['isOnce'] == true;
        if (!isOnce) {
          await RouterGuard.saveFailedRouter(
            router,
            Map<String, String>.from(
              p.map((k, v) => MapEntry(k, v?.toString() ?? '')),
            ),
          );
        }
        if (context.mounted) {
          NavigationLogger.log(
            action: action ?? '登录',
            path: '/login',
            resolvedLocation: '/login',
          );
          context.push('/login');
        }
        return;
      }
      if (permissionAry.contains('register') && !canLoginRoute) {
        final isOnce =
            p['isOnce'] == '1' || p['isOnce'] == 1 || p['isOnce'] == true;
        if (!isOnce) {
          await RouterGuard.saveFailedRouter(
            router,
            Map<String, String>.from(
              p.map((k, v) => MapEntry(k, v?.toString() ?? '')),
            ),
          );
        }
        if (context.mounted) {
          NavigationLogger.log(
            action: action ?? '注册',
            path: '/register',
            resolvedLocation: '/register',
          );
          context.push('/register');
        }
        return;
      }
    }

    // ================================================================
    // 7b. 钱包动作路由（对齐 iOS STStartViewController 特判）
    // ================================================================
    final walletAction = AppRouter.walletActionForPath(router);
    if (walletAction != null) {
      if (!context.mounted) return;
      final targetLocation = _buildLocation(router, p);
      await ref
          .read(walletActionHandlerProvider)
          .handleWalletAction(
            context: context,
            action: walletAction,
            onPassed: () {
              if (context.mounted) {
                context.push(targetLocation);
              }
            },
          );
      return;
    }

    // ================================================================
    // 8. 构建最终 location 并跳转
    // ================================================================
    if (!context.mounted) return;

    final loc = _buildLocation(router, p);
    NavigationLogger.log(
      action: action ?? NavigationLogger.actionForRouter(router, p),
      path: router,
      params: p,
      resolvedLocation: loc,
    );

    // isReplace 处理
    final isReplace = _truthy(p['isReplace']);

    if (useGo) {
      context.go(loc);
    } else if (isReplace) {
      context.pushReplacement(loc);
    } else {
      context.push(loc);
    }

    // 登录成功后若之前有挂起路由，本次跳转成功后清除对应记录
    if (permissionStr.isNotEmpty) {
      final failed = await RouterGuard.getFailedRouter();
      if (failed != null && failed.key == router) {
        await RouterGuard.clearFailedRouter();
      }
    }
  }

  /// 构建 GoRouter 可用的 location 字符串
  /// 对已知路由做 query/extra 适配，其余直接透传
  String _buildLocation(String router, Map<String, dynamic> params) {
    return STRouteResolver.buildLocation(router, params);
  }

  /// 布尔值统一转 "1"/"0" 字符串（对齐 iOS handleValueToString）
  Map<String, dynamic> _handleValueToString(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    final muti = Map<String, dynamic>.from(source);
    for (final key in keys) {
      final val = muti[key];
      if (val != null) {
        if (val is bool) {
          muti[key] = val ? '1' : '0';
        } else if (val is num) {
          muti[key] = val != 0 ? '1' : '0';
        }
        // String 保持原样
      }
    }
    return muti;
  }

  bool _truthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value.toString().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }

  /// 跳转交易 Tab 并切换品种/买卖方向（对齐 iOS `popToTradepage` + `STJumpToTradeNotification`）
  Future<void> jumpToTradePage(
    BuildContext context, {
    String? symbol,
    bool? isBuy,
    String? action,
    Map<String, dynamic>? params,
  }) async {
    final sym = symbol?.trim();
    if (sym != null && sym.isNotEmpty) {
      ref
          .read(userStateProvider.notifier)
          .rememberTradeSelection(symbol: sym, lot: '');
    }

    ref
        .read(tradeJumpNavigationProvider.notifier)
        .jumpToTrade(symbol: sym, isBuy: isBuy);

    NavigationLogger.log(
      action: action ?? (isBuy == false ? '跳转交易-卖出' : '跳转交易-买入'),
      path: '/trade',
      params: {
        if (params != null) ...params,
        if (sym != null && sym.isNotEmpty) 'symbol': sym,
        if (isBuy != null) 'direction': isBuy ? 'buy' : 'sell',
      },
      resolvedLocation: '/',
    );
    _switchBottomTab(context, tabCode: 'trade');
  }

  bool? _tradeDirectionIsBuy(Map<String, dynamic> params) {
    final raw = params['direction'] ?? params['type'];
    if (raw == null) {
      final symbol = (params['symbol'] as String?)?.trim();
      return symbol != null && symbol.isNotEmpty ? true : null;
    }
    if (raw is bool) return raw;
    if (raw is num) return raw == 0;
    final s = raw.toString().trim().toLowerCase();
    if (s == 'sell' || s == '1') return false;
    if (s == 'buy' || s == '0') return true;
    return true;
  }

  /// 切换底栏 Tab 并回到根壳（对齐 iOS popToRoot + selectedIndex）
  void _switchBottomTab(
    BuildContext context, {
    required String tabCode,
    String? innerTabCode,
  }) {
    ref
        .read(tabShellNavigationProvider.notifier)
        .switchTo(tabCode: tabCode, innerTabCode: innerTabCode);
    if (context.mounted) {
      context.go('/');
    }
  }

  String _secHomeTabCode() {
    final mgr = ref.read(configDataManagerProvider);
    return resolveSecHomepageTabCode(mgr.tabs, mgr.currentSecHomepageIndex);
  }
}

/// Riverpod Provider（全局单例，按 ref 创建）
final stRouterProvider = Provider<STRouter>((ref) {
  return STRouter.of(ref);
});
