import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/main/tab_shell.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/login_with_code_page.dart';
import '../../features/auth/register_page.dart';
import '../../features/auth/register_result_page.dart';
import '../../features/auth/register_id_info_page.dart';
import '../../features/auth/register_config.dart';
import '../../features/auth/forgot_login_password_page.dart';
import '../../shared/widgets/st_webview.dart';
import '../../shared/widgets/st_mini_view.dart';
import '../../features/mine/wallet_page.dart';
import '../../features/mine/deposit_page.dart';
import '../../features/mine/withdraw_page.dart';
import '../../features/mine/transfer_page.dart';
import '../../features/mine/wallet_finish_page.dart';
import '../../features/mine/wallet_flow_detail_page.dart';
import '../../features/mine/finance_password_page.dart';
import '../../features/mine/auth_commit_success_page.dart';
import '../../features/mine/auth_page.dart';
import '../../features/mine/bank_card_page.dart';
import '../../features/mine/add_bank_card_page.dart';
import '../../features/mine/ewallet_page.dart';
import '../../features/mine/close_account_page.dart';
import '../../features/mine/bind_email_page.dart';
import '../../features/mine/bind_phone_page.dart';
import '../../features/mine/profile_page.dart';
import '../../features/mine/profile_nickname_edit_page.dart';
import '../../features/mine/profile_signature_edit_page.dart';
import '../../features/mine/settings_page.dart';
import '../../features/mine/change_login_password_page.dart';
import '../../features/mine/mine_configured_page.dart';
import '../../features/mine/account_manager_page.dart';
import '../../features/mine/message_center_page.dart';
import '../../features/mine/setting_language_page.dart';
import '../../features/mine/setting_timezone_page.dart';
import '../../features/mine/setting_notification_page.dart';
import '../../features/mine/setting_preference_page.dart';
import '../../features/mine/setting_account_security_page.dart';
import '../../features/mine/setting_contact_page.dart';
import '../../features/mine/setting_activity_center_page.dart';
import '../../features/market/market_detail_page.dart';
import '../../features/market/chart_settings_page.dart';
import '../../features/market/contract_specifications_page.dart';
import '../../features/market/market_search_page.dart';
import '../../features/market/watchlist_edit_page.dart';
import '../../features/market/alert_setting_page.dart';
import '../../features/trade/trade_page.dart';
import '../../features/trade/order_page.dart';
import '../../features/trade/position_page.dart';
import '../../features/trade/pending_order_page.dart';
import '../../features/trade/trade_history_page.dart';
import '../../features/trade/account_profile_page.dart';
import '../../features/trade/order_detail_contract.dart';
import '../../features/trade/order_detail_page.dart';
import '../../features/trade/trade_action_result_page.dart';
import '../../features/trade/trade_one_key_closeout_result_page.dart';
import 'router_guard.dart';
import 'route_observer.dart';
import '../../features/activity/activity_popups.dart';
import '../../features/news/news_list_page.dart';
import '../../features/news/news_detail_page.dart';
import '../../features/news/flash_list_page.dart';
import '../../features/news/calendar_page.dart';
import '../../features/market/optional_list_page.dart';
import '../../features/market/category_market_list_page.dart';
import '../../features/market/market_tab_shell_page.dart';
import '../../features/mine/about_page.dart';
import '../../shared/widgets/st_toast.dart';
import '../localization/st_localizations.dart';
import '../config/config_data_manager.dart';
import '../models/bank_card_model.dart';
import '../models/h5_address_model.dart';
import '../models/user_state.dart' hide STH5AddressModel;

class _RouterTextSpec {
  const _RouterTextSpec(this.key, this.fallback);

  final String key;
  final String fallback;
}

/// 应用路由系统
/// 对齐 iOS PageRouter + STRouterManager + LocalMiniRouter
class AppRouter {
  // 路由常量
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String web = '/web';
  static const String mini = '/mini';
  static const String davmu = '/davmu';
  static const String market = '/market';
  static const String trade = '/trade';
  static const String mine = '/mine';

  static Future<String> _resolveRouterText(
    BuildContext context,
    _RouterTextSpec spec,
  ) {
    return STLocalizations.ofContext(
      context,
    ).text(spec.key, fallback: spec.fallback);
  }

  static Widget _buildLocalizedRouteText({
    required BuildContext context,
    required _RouterTextSpec spec,
    required Widget Function(String text) builder,
  }) {
    return FutureBuilder<String>(
      future: _resolveRouterText(context, spec),
      initialData: spec.fallback,
      builder: (context, snapshot) => builder(snapshot.data ?? spec.fallback),
    );
  }

  static Widget _buildFlashScaffold(BuildContext context, String title) {
    final theme = Theme.of(context);
    final fg = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 44,
        title: Text(title),
        titleTextStyle: TextStyle(
          color: fg,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
      ),
      body: FlashListPage(title: title),
    );
  }

  static Map<String, dynamic> _routeParams(GoRouterState state) {
    final params = <String, dynamic>{...state.uri.queryParameters};
    final extra = state.extra;
    if (extra is Map<String, dynamic>) {
      params.addAll(extra);
    } else if (extra is Map) {
      params.addAll(extra.map((key, value) => MapEntry(key.toString(), value)));
    }
    return params;
  }

  static String? _routeStringParam(
    Map<String, dynamic> params,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = params[key];
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  /// H5 虚拟路由标题映射
  static const Map<String, _RouterTextSpec> _h5RouteTitles = {
    '/partner': _RouterTextSpec('flutter_h5_partner', '合作伙伴'),
    '/taskcenter': _RouterTextSpec('task_sign_in', '任务中心'),
    '/vipcenter': _RouterTextSpec('vip_center', 'VIP中心'),
    '/customer': _RouterTextSpec('online_custom', '在线客服'),
    '/help': _RouterTextSpec('flutter_h5_help_center', '帮助中心'),
    '/about': _RouterTextSpec('about_us', '关于我们'),
    '/agreement': _RouterTextSpec('agreement_label', '用户协议'),
    '/privacy': _RouterTextSpec('privacy_label', '隐私政策'),
    '/tutorial': _RouterTextSpec('flutter_h5_tutorial', '新手教程'),
    '/faq': _RouterTextSpec('flutter_h5_faq', '常见问题'),
    '/trader': _RouterTextSpec('flutter_h5_trader', '交易员'),
    '/strategy': _RouterTextSpec('flutter_h5_strategy', '交易策略'),
  };

  /// 获取 H5 路由标题
  static _RouterTextSpec _h5RouteTitle(String path) {
    return _h5RouteTitles[path] ??
        const _RouterTextSpec('flutter_router_page', '页面');
  }

  /// iOS `PageRouter` / 历史路径别名 → Flutter 统一 path（不含 query，query 由 redirect 保留）
  static String? canonicalRedirectPath(String path) {
    switch (path.toLowerCase()) {
      case '/mine/bank':
        return '/mine/bankcard';
      case '/mine/asset':
      case '/mine/account':
        return '/mine/wallet';
      case '/mine/personalinfo':
      case '/mine/editinfo':
        return '/mine/personalinfo';
      case '/mine/set':
        return '/mine/setting';
      case '/mine/accountsafe':
        return '/mine/account_security';
      case '/market/edit':
        return '/market/watchlist_edit';
      case '/permission/login':
        return '/login';
      case '/permission/register':
        return '/register';
      case '/market/productdetail':
        return '/market/detail';
      default:
        return null;
    }
  }

  /// iOS `STStartViewController` 对 `/mine/deposit`、`/mine/draw`
  /// 会先转入 `STWalletActionHandler`，而不是普通页面 push。
  static String? walletActionForPath(String path) {
    switch (path.toLowerCase()) {
      case '/mine/deposit':
        return 'deposit';
      case '/mine/draw':
        return 'withdraw';
      default:
        return null;
    }
  }

  static final GoRouter router = GoRouter(
    navigatorKey: STToast.navigatorKey,
    initialLocation: '/',
    observers: [routeObserver],
    routes: [
      // 首页 Tab 壳
      GoRoute(
        path: '/',
        builder: (context, state) {
          // 支持从 query 参数或 extra 中获取 initialTab
          final tab =
              state.uri.queryParameters['tab'] ??
              state.uri.queryParameters['tabCode'];
          Map<String, dynamic>? extraMap;
          if (state.extra != null && state.extra is Map) {
            extraMap = state.extra as Map<String, dynamic>;
          }
          final initialTab = tab ?? extraMap?['tab'] as String?;
          return TabShell(initialTab: initialTab);
        },
      ),

      // 登录页
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),

      // 验证码登录页
      GoRoute(
        path: '/auth/login_with_code',
        builder: (context, state) => const LoginWithCodePage(),
      ),

      // 注册页
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
        routes: [
          GoRoute(
            path: 'result',
            builder: (context, state) {
              final extra = state.extra;
              RegisterOutcome outcome = RegisterOutcome.success;
              var loginMode = 1;
              Map<String, dynamic>? userInfo;
              String? registeredAccount;
              if (extra is Map) {
                final o = extra['outcome'];
                if (o is int && o >= 0 && o < RegisterOutcome.values.length) {
                  outcome = RegisterOutcome.values[o];
                }
                loginMode = extra['loginMode'] as int? ?? 1;
                final ui = extra['userInfo'];
                if (ui is Map) userInfo = Map<String, dynamic>.from(ui);
                registeredAccount = extra['registeredAccount'] as String?;
              }
              return RegisterResultPage(
                outcome: outcome,
                loginMode: loginMode,
                userInfo: userInfo,
                registeredAccount: registeredAccount,
              );
            },
          ),
          GoRoute(
            path: 'identity',
            builder: (context, state) {
              final extra = state.extra;
              var fields = <Map<String, dynamic>>[];
              var token = '';
              var loginMode = 1;
              var registeredAccount = '';
              if (extra is Map) {
                final f = extra['fields'];
                if (f is List) {
                  fields = f
                      .whereType<Map>()
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();
                }
                token = extra['registerToken'] as String? ?? '';
                loginMode = extra['loginMode'] as int? ?? 1;
                registeredAccount = extra['registeredAccount'] as String? ?? '';
              }
              return RegisterIdInfoPage(
                fields: fields,
                registerToken: token,
                loginMode: loginMode,
                registeredAccount: registeredAccount,
              );
            },
          ),
        ],
      ),

      // 找回登录密码（未登录）
      GoRoute(
        path: '/auth/forgot_password',
        builder: (context, state) => const ForgotLoginPasswordPage(),
      ),

      // WebView 容器 (/web?link=xxx&title=xxx&nav=1&permission=...)
      // nav=1 → 显示原生 AppBar（对齐 iOS isNeedNavigationBar）
      // 路由层其它 query 会透传进 STWebConfig.params，并由 STWebOpenHandler 同款逻辑合并进最终加载 URL
      GoRoute(
        path: '/web',
        builder: (context, state) {
          final qp = state.uri.queryParameters;
          final link = qp['link'] ?? '';
          final titleParam = qp['title']?.trim();
          final navRaw = qp['nav'] ?? qp['isNeedNavigationBar'];
          var showNav = navRaw == '1' || navRaw == 'true' || navRaw == 'yes';

          final routeExtras = Map<String, String>.from(qp);
          routeExtras.remove('link');
          routeExtras.remove('title');
          routeExtras.remove('nav');
          // 与 iOS STRouterManager+/web 一致：根据 nav 写回 isNeedNavigationBar 供 H5 读取
          if (navRaw != null) {
            routeExtras['isNeedNavigationBar'] = showNav ? '1' : '0';
          }

          return Consumer(
            builder: (context, ref, _) {
              var effectiveShowNav = showNav;
              var effectiveExtras = routeExtras.isEmpty
                  ? null
                  : Map<String, String>.from(routeExtras);
              if (!effectiveShowNav && link.trim().isNotEmpty) {
                final configMgr = ref.watch(configDataManagerProvider);
                final model = STH5AddressModel.fromJson(
                  configMgr.h5Config ?? {},
                );
                final cu = model.customerUrl?.trim() ?? '';
                if (cu.isNotEmpty && link.trim() == cu) {
                  effectiveShowNav = true;
                  effectiveExtras ??= {};
                  effectiveExtras['isNeedNavigationBar'] = '1';
                }
              }

              return STWebView(
                url: link.isNotEmpty ? link : 'https://www.example.com',
                title: (titleParam != null && titleParam.isNotEmpty)
                    ? titleParam
                    : null,
                showNavigationBar: effectiveShowNav,
                routeParams: effectiveExtras,
              );
            },
          );
        },
      ),

      // Mini 容器 (/mini?link=xxx&path=xxx&permission=login&...)
      GoRoute(
        path: '/mini',
        builder: (context, state) {
          final qp = state.uri.queryParameters;
          final link = qp['link'] ?? '';
          final path = qp['path'] ?? '';
          final titleParam = qp['title']?.trim();
          final extras = Map<String, String>.from(qp);
          extras.remove('link');
          extras.remove('path');
          extras.remove('title');
          extras.remove('nav');
          return STMiniView(
            link: link,
            path: path,
            title: (titleParam != null && titleParam.isNotEmpty)
                ? titleParam
                : null,
            routeParams: extras.isEmpty ? null : extras,
          );
        },
      ),

      // Davmu 跟单 Mini (/davmu?path=xxx)
      GoRoute(
        path: '/davmu',
        builder: (context, state) {
          final path = state.uri.queryParameters['path'] ?? '';
          return STMiniView(
            link: 'localMini://davmu',
            path: path,
            title: 'DAVMU',
          );
        },
      ),

      // 行情页：与底 Tab [TabShell] 中 MarketTabShellPage 一致（勿走卡片首页）
      GoRoute(
        path: '/market',
        builder: (context, state) => const MarketRoutePage(),
      ),

      // 交易页
      GoRoute(path: '/trade', builder: (context, state) => const TradePage()),

      /// iOS `router == "/trade1"`（ParentViewController 承载的交易首页变体）
      GoRoute(path: '/trade1', builder: (context, state) => const TradePage()),

      /// iOS `/home` 与 Flutter 根 Tab 壳等价（保留 query 便于 deep link）
      GoRoute(
        path: '/home',
        redirect: (context, state) =>
            state.uri.hasQuery ? '/?${state.uri.query}' : '/',
      ),

      /// Tab 分段外套之外的直达栈（对齐 STRouterManager 常用 path：`/flash`、`/calendar` 等）
      GoRoute(
        path: '/flash',
        builder: (context, state) {
          final queryTitle = state.uri.queryParameters['title'];
          if (queryTitle != null && queryTitle.isNotEmpty) {
            return _buildFlashScaffold(context, queryTitle);
          }
          return _buildLocalizedRouteText(
            context: context,
            spec: const _RouterTextSpec('flutter_router_flash', '快讯'),
            builder: (title) => _buildFlashScaffold(context, title),
          );
        },
      ),

      GoRoute(
        path: '/calendar',
        builder: (context, state) {
          final title = state.uri.queryParameters['title'];
          if (title != null && title.isNotEmpty) {
            return Scaffold(
              appBar: AppBar(title: Text(title)),
              body: CalendarPage(title: title),
            );
          }
          return _buildLocalizedRouteText(
            context: context,
            spec: const _RouterTextSpec('flutter_router_calendar', '财经日历'),
            builder: (localizedTitle) => Scaffold(
              appBar: AppBar(title: Text(localizedTitle)),
              body: CalendarPage(title: localizedTitle),
            ),
          );
        },
      ),

      GoRoute(
        path: '/optional',
        builder: (context, state) {
          final title = state.uri.queryParameters['title'] ?? '自选';
          return OptionalListPage(title: title);
        },
      ),

      GoRoute(
        path: '/tradeMarket',
        builder: (context, state) {
          final title = state.uri.queryParameters['title'] ?? '分类行情';
          final rt =
              int.tryParse(state.uri.queryParameters['rank_type'] ?? '') ??
              int.tryParse(state.uri.queryParameters['rankType'] ?? '');
          return CategoryMarketListPage(
            title: title,
            rankType: rt ?? 0,
            iosStyleRows: true,
          );
        },
      ),

      // 下单 (/trade/order, extra 含 pendingValidityYmd 等与 OrderPage 对齐)
      GoRoute(
        path: '/trade/order',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final q = state.uri.queryParameters;
          String orderType =
              (extra?['orderType'] ??
                      extra?['order_type'] ??
                      q['orderType'] ??
                      q['order_type'] ??
                      'market')
                  .toString()
                  .toLowerCase()
                  .trim();
          if (orderType != 'limit' && orderType != 'stop') {
            orderType = 'market';
          }
          return OrderPage(
            symbol: extra?['symbol'] as String? ?? q['symbol'] ?? 'EUR/USD',
            direction:
                extra?['direction'] as String? ?? q['direction'] ?? 'buy',
            lot: extra?['lot'] as String? ?? q['lot'],
            initialOrderType: orderType,
            initialPendingPrice:
                extra?['pendingPrice'] as String? ?? q['pendingPrice'],
            initialTakeProfit:
                extra?['takeProfit'] as String? ?? q['takeProfit'],
            initialStopLoss: extra?['stopLoss'] as String? ?? q['stopLoss'],
            initialPendingValidityYmd:
                extra?['pendingValidityYmd'] as String? ??
                q['pendingValidityYmd'],
          );
        },
      ),

      // 持仓列表 (/trade/positions)
      GoRoute(
        path: '/trade/positions',
        builder: (context, state) => const PositionPage(),
      ),

      // 挂单列表 (/trade/pending)
      GoRoute(
        path: '/trade/pending',
        builder: (context, state) => const PendingOrderPage(),
      ),

      // 交易历史 (/trade/history)
      GoRoute(
        path: '/trade/history',
        builder: (context, state) => const TradeHistoryPage(),
      ),

      // 我的页（与 Tab「我的」一致：schema + page 卡片，对齐 iOS STProjectListViewController）
      GoRoute(
        path: '/mine',
        builder: (context, state) => const ConfiguredMinePage(),
      ),

      // 钱包页 (/mine/wallet)
      GoRoute(
        path: '/mine/wallet',
        builder: (context, state) => const WalletPage(),
      ),

      // 钱包 / 交易账户详情（extra: { item: WalletAccountItem }）
      GoRoute(
        path: '/mine/wallet/account',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final item = extra['item'];
          if (item is WalletAccountItem) {
            return WalletAccountDetailPage(item: item);
          }
          return const WalletPage();
        },
      ),

      // 钱包 / 交易账户流水列表（extra: { item: WalletAccountItem, range: int }）
      GoRoute(
        path: '/mine/wallet/flow',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final item = extra['item'];
          if (item is WalletAccountItem) {
            return WalletFlowListPage(
              item: item,
              initialRange: extra['range'] is int ? extra['range'] as int : 0,
            );
          }
          return const WalletPage();
        },
      ),

      // 充值
      GoRoute(
        path: '/mine/deposit',
        builder: (context, state) {
          final raw = state.uri.queryParameters['depositTarget'];
          final depositTarget = int.tryParse(raw ?? '') ?? 0;
          return DepositPage(depositTarget: depositTarget);
        },
      ),

      // 提现
      GoRoute(
        path: '/mine/draw',
        builder: (context, state) {
          final raw = state.uri.queryParameters['depositTarget'];
          final depositTarget = int.tryParse(raw ?? '') ?? 0;
          return WithdrawPage(depositTarget: depositTarget);
        },
      ),

      // 资金密码（对齐 iOS `STSetFinancePwdViewController`，`?mode=set|change|forgot`）
      GoRoute(
        path: '/mine/finance_password',
        builder: (context, state) {
          final q = state.uri.queryParameters['mode'];
          return Consumer(
            builder: (ctx, ref, _) {
              final bound = ref.watch(userStateProvider).isBindFundPassword;
              FinancePwdMode mode;
              switch (q) {
                case 'change':
                  mode = bound
                      ? FinancePwdMode.change
                      : FinancePwdMode.initialSet;
                  break;
                case 'set':
                  mode = FinancePwdMode.initialSet;
                  break;
                case 'forgot':
                  mode = bound
                      ? FinancePwdMode.forgot
                      : FinancePwdMode.initialSet;
                  break;
                default:
                  mode = bound
                      ? FinancePwdMode.change
                      : FinancePwdMode.initialSet;
              }
              return FinancePasswordPage(mode: mode);
            },
          );
        },
      ),

      // 提交成功（对齐 iOS `STAuthCommitSuccessViewController`，extra: { kind }）
      GoRoute(
        path: '/mine/commit_success',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final kind = authCommitKindFromExtra(extra['kind']);
          final popCountRaw = extra['popCount'] ?? extra['pop_count'];
          return AuthCommitSuccessPage(
            kind: kind,
            returnPath: (extra['returnPath'] ?? extra['return_path'])
                ?.toString(),
            fallbackPath: (extra['fallbackPath'] ?? extra['fallback_path'])
                ?.toString(),
            popCount: popCountRaw is int
                ? popCountRaw
                : int.tryParse(popCountRaw?.toString() ?? ''),
          );
        },
      ),

      // 划转
      GoRoute(
        path: '/mine/transfer',
        builder: (context, state) => const TransferPage(),
      ),

      // 钱包操作完成（extra: { kind: transfer|deposit|withdraw, rows: Map })
      GoRoute(
        path: '/mine/wallet/finish',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final kindStr = extra['kind'] as String? ?? 'transfer';
          final kind = switch (kindStr) {
            'deposit' => WalletFinishKind.deposit,
            'withdraw' => WalletFinishKind.withdraw,
            _ => WalletFinishKind.transfer,
          };
          final rawRows = extra['rows'];
          final rows = <String, String>{};
          if (rawRows is Map) {
            for (final e in rawRows.entries) {
              rows['${e.key}'] = '${e.value}';
            }
          }
          WalletFinishDrawHeader? header;
          final dh = extra['drawHeader'];
          if (dh is Map) {
            header = WalletFinishDrawHeader(
              action: '${dh['action'] ?? ''}',
              title: '${dh['title'] ?? ''}',
              drawCurrency: '${dh['drawCurrency'] ?? ''}',
              drawNum: '${dh['drawNum'] ?? ''}',
              bankStyleIcon: dh['bankStyleIcon'] != false,
            );
          }
          return WalletFinishPage(kind: kind, drawHeader: header, rows: rows);
        },
      ),

      // 钱包流水详情（extra: { flow: Map<String, dynamic> }）
      GoRoute(
        path: '/mine/wallet/flow/detail',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final flow = extra['flow'];
          final raw = flow is Map<String, dynamic>
              ? Map<String, dynamic>.from(flow)
              : Map<String, dynamic>.from(flow as Map);
          return WalletFlowDetailPage(raw: raw);
        },
      ),

      // 实名认证
      GoRoute(
        path: '/mine/auth',
        builder: (context, state) => const AuthPage(),
      ),

      // 银行卡管理
      GoRoute(
        path: '/mine/bank',
        builder: (context, state) => const BankCardPage(),
      ),

      // 银行卡管理（兼容 iOS 入口 `/mine/bank`）
      GoRoute(
        path: '/mine/bankcard',
        builder: (context, state) => const BankCardPage(),
      ),

      GoRoute(
        path: '/mine/bankcard/add',
        builder: (context, state) {
          final extra = state.extra;
          var existingCards = <BankCardModel>[];
          if (extra is Map && extra['existingCards'] is List) {
            existingCards = (extra['existingCards'] as List)
                .whereType<BankCardModel>()
                .toList(growable: false);
          }
          return AddBankCardPage(existingCards: existingCards);
        },
      ),

      GoRoute(
        path: '/mine/bankcard/add_voucher',
        builder: (context, state) {
          final extra = state.extra;
          final draft = extra is Map
              ? Map<String, String>.fromEntries(
                  extra.entries.map(
                    (entry) => MapEntry(entry.key.toString(), '${entry.value}'),
                  ),
                )
              : <String, String>{};
          return AddBankCardVoucherPage(draft: draft);
        },
      ),

      // 电子钱包
      GoRoute(
        path: '/mine/ewallet',
        builder: (context, state) {
          final type = state.uri.queryParameters['type'];
          if (type == '1') {
            return const EWalletPage();
          }
          return const BankCardPage();
        },
      ),
      GoRoute(
        path: '/mine/ewallet/add',
        builder: (context, state) => const AddEWalletPage(),
      ),

      // 设置
      // 账户管理（对齐 iOS STAccountManagerViewController）
      GoRoute(
        path: '/mine/accountmanager',
        builder: (context, state) => const AccountManagerPage(),
      ),

      GoRoute(
        path: '/mine/setting',
        builder: (context, state) => const SettingsPage(),
      ),

      // 设置子页面
      GoRoute(
        path: '/mine/setting_language',
        builder: (context, state) => const SettingLanguagePage(),
      ),
      GoRoute(
        path: '/mine/setting_timezone',
        builder: (context, state) => const SettingTimezonePage(),
      ),
      GoRoute(
        path: '/mine/setting_notification',
        builder: (context, state) => const SettingNotificationPage(),
      ),
      GoRoute(
        path: '/mine/setting_preference',
        builder: (context, state) => const SettingPreferencePage(),
      ),
      GoRoute(
        path: '/mine/account_security',
        builder: (context, state) => const SettingAccountSecurityPage(),
      ),
      GoRoute(
        path: '/mine/bind_email',
        builder: (context, state) => const BindEmailPage(),
      ),
      GoRoute(
        path: '/mine/bind_phone',
        builder: (context, state) => const BindPhonePage(),
      ),
      GoRoute(
        path: '/mine/close_account',
        builder: (context, state) => const CloseAccountPage(),
      ),
      GoRoute(
        path: '/mine/contact',
        builder: (context, state) => const SettingContactPage(),
      ),
      GoRoute(
        path: '/mine/activity_center',
        builder: (context, state) => const SettingActivityCenterPage(),
      ),

      // 消息中心
      GoRoute(
        path: '/mine/messages',
        builder: (context, state) => const MessageCenterPage(),
      ),

      // 修改登录密码（Figma 白标 2.0：重设密码 → 验证 → 成功）
      GoRoute(
        path: '/mine/change_login_password',
        builder: (context, state) => const ChangeLoginPasswordPage(),
      ),

      // 个人资料（iOS 入口: /mine/personalinfo）
      GoRoute(
        path: '/mine/personalinfo',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/mine/profile',
        builder: (context, state) => const ProfilePage(),
      ),

      // 个人信息 — 编辑昵称（Figma 2175:77584）
      GoRoute(
        path: '/mine/profile/nickname',
        builder: (context, state) {
          final extra = state.extra;
          Map<String, dynamic>? m;
          if (extra is Map<String, dynamic>) {
            m = extra;
          } else if (extra is Map) {
            m = Map<String, dynamic>.from(extra);
          }
          final initial = m?['initial']?.toString() ?? '';
          return ProfileNicknameEditPage(initialNickname: initial);
        },
      ),

      // 个人信息 — 编辑个性签名
      GoRoute(
        path: '/mine/profile/signature',
        builder: (context, state) {
          final extra = state.extra;
          Map<String, dynamic>? m;
          if (extra is Map<String, dynamic>) {
            m = extra;
          } else if (extra is Map) {
            m = Map<String, dynamic>.from(extra);
          }
          final initial = m?['initial']?.toString() ?? '';
          return ProfileSignatureEditPage(initialSignature: initial);
        },
      ),

      // 交易账户（对齐 iOS STTradeAccountProfileController）
      // query: fromType (0=TradeHome,1=Open,2=Registration,3=Mine,4=Web,5=CloseSuccessTradeHome)
      // query: selType (0=Position,1=Registration,2=History) mirrors iOS web router params.
      GoRoute(
        path: '/trade/accountprofile',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          final fromType =
              int.tryParse(q['fromType'] ?? q['from_type'] ?? '') ?? 0;
          final selType = int.tryParse(q['selType'] ?? q['sel_type'] ?? '');
          final accountId = q['accountId'] ?? q['account_id'];
          return AccountProfilePage(
            fromType: fromType,
            accountId: accountId,
            initialTab: selType,
          );
        },
      ),

      // 订单详情
      GoRoute(
        path: '/trade/orderdetail',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          final orderId =
              q['orderId'] ?? q['order_id'] ?? q['positionId'] ?? '';
          final typeRaw =
              q['type'] ?? q['orderType'] ?? q['order_type'] ?? q['selType'];
          final extra = state.extra;
          final extraMap = extra is Map
              ? Map<String, dynamic>.from(extra)
              : <String, dynamic>{};
          final orderInfo = extraMap['orderInfo'];
          final extraLooksLikeOrder =
              extraMap.containsKey('symbol') ||
              extraMap.containsKey('order_id') ||
              extraMap.containsKey('position_id');
          final initialOrder = orderInfo is Map
              ? Map<String, dynamic>.from(orderInfo)
              : (extraLooksLikeOrder ? extraMap : null);
          final extraType = extraMap['orderType'] ?? extraMap['type'];
          final routeType = typeRaw ?? extraType?.toString();
          return OrderDetailPage(
            orderId: orderId,
            initialType: routeType == null || routeType.trim().isEmpty
                ? null
                : TradeOrderDetailContract.typeFromRoute(routeType),
            initialOrder: initialOrder,
          );
        },
      ),

      GoRoute(
        path: '/trade/action_result',
        builder: (context, state) {
          final extra = state.extra;
          final payload = extra is Map<String, dynamic>
              ? extra
              : (extra is Map
                    ? Map<String, dynamic>.from(extra)
                    : <String, dynamic>{});
          final q = state.uri.queryParameters;
          return TradeActionResultPage(
            payload: payload,
            actionType: q['type'] ?? 'open',
            isProgress: q['progress'] == '1',
          );
        },
      ),

      GoRoute(
        path: '/trade/closeout_result',
        builder: (context, state) {
          final extra = state.extra;
          final payload = extra is Map<String, dynamic>
              ? extra
              : (extra is Map
                    ? Map<String, dynamic>.from(extra)
                    : <String, dynamic>{});
          final rawItems = payload['items'];
          final items = rawItems is List
              ? rawItems
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .toList()
              : <Map<String, dynamic>>[];
          final failedRaw = payload['failedCount'];
          final failedCount = failedRaw is num
              ? failedRaw.toInt()
              : int.tryParse(failedRaw?.toString() ?? '') ?? 0;
          return TradeOneKeyCloseOutResultPage(
            items: items,
            failedCount: failedCount,
          );
        },
      ),

      // 行情详情
      GoRoute(
        path: '/market/detail',
        builder: (context, state) {
          final symbol = state.uri.queryParameters['symbol'] ?? 'EUR/USD';
          return MarketDetailPage(symbol: symbol);
        },
      ),

      /// K 线图表设置（对齐 iOS 独立设置页）
      GoRoute(
        path: '/market/chart_settings',
        builder: (context, state) => const ChartSettingsPage(),
      ),

      /// 合约规格（对齐 iOS 行情详情「合约规格」页）
      GoRoute(
        path: '/market/contract_specs',
        builder: (context, state) {
          final symbol = state.uri.queryParameters['symbol'] ?? 'EUR/USD';
          final extra = state.extra;
          final initialData = extra is Map
              ? Map<String, dynamic>.from(extra)
              : null;
          return ContractSpecificationsPage(
            symbol: symbol,
            initialData: initialData,
          );
        },
      ),

      // 行情搜索
      GoRoute(
        path: '/market/search',
        builder: (context, state) => const MarketSearchPage(),
      ),

      // 自选编辑
      GoRoute(
        path: '/market/watchlist_edit',
        builder: (context, state) => const WatchlistEditPage(),
      ),

      // 价格预警
      GoRoute(
        path: '/market/alert',
        builder: (context, state) => const AlertSettingPage(),
      ),

      // ==================== 虚拟 H5 路由（由 h5_config 驱动） ====================
      //
      // 这些路由由 h5_config 中的 URL 字段驱动，跳转到对应 H5 页面。
      // 配置缺失时 fallback 到 WebView 首页。
      // 对齐 iOS: STH5AddressModel 的虚拟路由映射。

      // 资讯页（H5 配置优先，无配置时从 getNewsList API 获取原生列表）
      GoRoute(
        path: '/news',
        builder: (context, state) {
          return Consumer(
            builder: (context, ref, _) {
              final configMgr = ref.watch(configDataManagerProvider);
              final url = configMgr.h5Url('news_url');
              if (url.isNotEmpty) {
                // iOS 资讯 H5 无原生导航栏，H5 自带 header
                return _buildLocalizedRouteText(
                  context: context,
                  spec: const _RouterTextSpec('flutter_router_news', '资讯'),
                  builder: (title) => STWebView(
                    url: url,
                    title: title,
                    showNavigationBar: false,
                  ),
                );
              }
              return const NewsListPage();
            },
          );
        },
      ),

      GoRoute(
        path: '/news/detail',
        builder: (context, state) {
          final id = state.uri.queryParameters['id'] ?? '';
          return NewsDetailPage(newsId: id);
        },
      ),

      GoRoute(
        path: '/mine/about',
        builder: (context, state) => const AboutPage(),
      ),

      // 批量注册 H5 虚拟路由（partner, taskcenter, vipcenter, customer 等）
      // 对齐 iOS：只有客服页面显式传 isNeedNavigationBar:YES，其余页面无原生导航栏
      ...h5VirtualRoutes.map(
        (path) => GoRoute(
          path: path,
          builder: (context, state) {
            return Consumer(
              builder: (context, ref, _) {
                final configMgr = ref.watch(configDataManagerProvider);
                final model = STH5AddressModel.fromJson(
                  configMgr.h5Config ?? {},
                );
                final url = model.urlForRoute(path);
                final titleSpec = _h5RouteTitle(path);
                // /customer（客服）对齐 iOS 传 isNeedNavigationBar:YES → 显示原生 AppBar
                // 其余（邀请好友 /partner、任务中心 /taskcenter 等）无原生导航栏
                final showNav = path == '/customer';
                return _buildLocalizedRouteText(
                  context: context,
                  spec: titleSpec,
                  builder: (title) => STWebView(
                    url: url?.isNotEmpty == true
                        ? url!
                        : 'https://www.example.com',
                    title: title,
                    showNavigationBar: showNav,
                  ),
                );
              },
            );
          },
        ),
      ),

      // ==================== 活动弹窗路由 ====================

      // 体验金弹窗 /action/trial (extra: {popup_image_url, activity_url, ...})
      GoRoute(
        path: '/action/trial',
        pageBuilder: (context, state) {
          final params = _routeParams(state);
          return CustomTransitionPage(
            key: state.pageKey,
            opaque: false,
            fullscreenDialog: true,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
            child: _buildLocalizedRouteText(
              context: context,
              spec: const _RouterTextSpec(
                'flutter_router_activity_detail',
                '活动详情',
              ),
              builder: (title) => BonusAlertPage(
                popupImageUrl: _routeStringParam(params, [
                  'popup_image_url',
                  'popupImageUrl',
                  'image_url',
                  'imageUrl',
                ]),
                activityUrl: _routeStringParam(params, [
                  'activity_url',
                  'activityUrl',
                  'link',
                ]),
                title: title,
              ),
            ),
          );
        },
      ),

      // 赠金弹窗 /action/bonus (extra: {popup_image_url, activity_url, ...})
      GoRoute(
        path: '/action/bonus',
        pageBuilder: (context, state) {
          final params = _routeParams(state);
          return CustomTransitionPage(
            key: state.pageKey,
            opaque: false,
            fullscreenDialog: true,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
            child: _buildLocalizedRouteText(
              context: context,
              spec: const _RouterTextSpec(
                'flutter_router_activity_detail',
                '活动详情',
              ),
              builder: (title) => BonusAlertPage(
                popupImageUrl: _routeStringParam(params, [
                  'popup_image_url',
                  'popupImageUrl',
                  'image_url',
                  'imageUrl',
                ]),
                activityUrl: _routeStringParam(params, [
                  'activity_url',
                  'activityUrl',
                  'link',
                ]),
                title: title,
              ),
            ),
          );
        },
      ),

      // 体验金状态弹窗 /action/trialStatus (extra: {sub_type, params})
      GoRoute(
        path: '/action/trialStatus',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CustomTransitionPage(
            key: state.pageKey,
            opaque: false,
            fullscreenDialog: true,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
            child: TrialBonusStatusPopPage(info: extra ?? const {}),
          );
        },
      ),

      // 交易解锁 - 全部完成弹窗 (extra: {total_reward_amount})
      GoRoute(
        path: '/action/tradeUnlockTaskCompleted',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CustomTransitionPage(
            key: state.pageKey,
            opaque: false,
            fullscreenDialog: true,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
            child: TradeUnlockCompletedPage(
              totalRewardAmount: extra?['total_reward_amount'] as String?,
            ),
          );
        },
      ),

      // 交易解锁 - 未完成弹窗 (extra: {taskInfo, isFromDeposit})
      GoRoute(
        path: '/action/tradeUnlockTaskUnCompleted',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CustomTransitionPage(
            key: state.pageKey,
            opaque: false,
            fullscreenDialog: true,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
            child: TradeUnlockUnCompletedPage(
              taskInfo: extra?['taskInfo'] as Map<String, dynamic>?,
              isFromDeposit: activityPopupIsFromDepositParam(extra),
            ),
          );
        },
      ),

      // Tab 切换路由 (/tabbar/{tabCode})
      GoRoute(
        path: '/tabbar/:tabCode',
        builder: (context, state) {
          final tabCode = state.pathParameters['tabCode'] ?? 'home';
          return TabShell(initialTab: tabCode);
        },
      ),
    ],

    // 错误页
    errorBuilder: (context, state) => _buildLocalizedRouteText(
      context: context,
      spec: const _RouterTextSpec('flutter_router_not_found', '404: 页面不存在'),
      builder: (title) => FutureBuilder<String>(
        future: _resolveRouterText(
          context,
          const _RouterTextSpec('flutter_router_back_home', '返回首页'),
        ),
        initialData: '返回首页',
        builder: (context, snapshot) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(title),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: Text(snapshot.data ?? '返回首页'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),

    // 路由重定向（权限检查）
    redirect: (context, state) async {
      final path = state.uri.path;
      final canon = AppRouter.canonicalRedirectPath(path);
      if (canon != null && canon != path) {
        final q = state.uri.query;
        return q.isEmpty ? canon : '$canon?$q';
      }

      final params = state.uri.queryParameters;

      // 检查权限
      final redirectPath = await RouterGuard.checkPermission(path, params);
      if (redirectPath != null) {
        return redirectPath;
      }

      return null;
    },

    // navigatorObservers 已移至 MaterialApp.router 配置（go_router 14.x 兼容）
  );
}
