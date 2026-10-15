import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jufu/shared/widgets/st_pull_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';

import '../../core/config/card_tool.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/models/auth_status_model.dart';
import '../../core/models/user_state.dart';
import '../../core/models/wallet_model.dart';
import '../../core/network/st_service.dart';
import '../../core/router/customer_service_route.dart';
import '../../core/router/route_observer.dart';
import '../../core/services/user_preference_prefs.dart';
import '../../core/services/wallet_action_handler.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../core/utils/ios_date_range.dart';
import '../../shared/widgets/ios_date_picker_sheet.dart';
import '../../shared/widgets/st_localized_prompt.dart';

/// iOS `STWalletViewController` parity: asset header + wallet/account rows.
class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletText {
  const _WalletText._();

  static final fallbackText = {
    'wallet_assets': stLocalizedTextFromZhHans('资产'),
    'total_assets_title': stLocalizedTextFromZhHans('总资产 (USD)'),
    'my_account': stLocalizedTextFromZhHans('我的账户'),
    'my_wallet': stLocalizedTextFromZhHans('我的钱包'),
    'deposit': stLocalizedTextFromZhHans('入金'),
    'withdrawal': stLocalizedTextFromZhHans('出金'),
    'transfer': stLocalizedTextFromZhHans('资金划转'),
    'balance': stLocalizedTextFromZhHans('余额'),
    'account_equity': stLocalizedTextFromZhHans('净值'),
    'available': stLocalizedTextFromZhHans('可用余额'),
    'total_profit_and_loss': stLocalizedTextFromZhHans('总盈亏'),
    'real_account': stLocalizedTextFromZhHans('真实账户'),
    'simulation_account': stLocalizedTextFromZhHans('模拟账户'),
    'flow': stLocalizedTextFromZhHans('资金流水'),
    'filtering': stLocalizedTextFromZhHans('筛选'),
    'more': stLocalizedTextFromZhHans('更多'),
    'see_more': stLocalizedTextFromZhHans('查看更多'),
    'already_the_end': stLocalizedTextFromZhHans('没有更多了'),
    'loading': stLocalizedTextFromZhHans('加载中...'),
    'no_record': stLocalizedTextFromZhHans('暂无记录'),
    'all': stLocalizedTextFromZhHans('全部'),
    'project': stLocalizedTextFromZhHans('类型'),
    'date': stLocalizedTextFromZhHans('日期'),
    'start_date': stLocalizedTextFromZhHans('开始日期'),
    'end_date': stLocalizedTextFromZhHans('结束日期'),
    'program_today': stLocalizedTextFromZhHans('今天'),
    'last_7_days': stLocalizedTextFromZhHans('近7日'),
    'past_month': stLocalizedTextFromZhHans('近1月'),
    'manual_adjust': stLocalizedTextFromZhHans('人工调整'),
    'interest': stLocalizedTextFromZhHans('隔夜利息'),
    'transfer_enter': stLocalizedTextFromZhHans('转入'),
    'transfer_out': stLocalizedTextFromZhHans('转出'),
    'commission': stLocalizedTextFromZhHans('佣金'),
    'bonus': stLocalizedTextFromZhHans('赠金'),
    'reward_rebate': stLocalizedTextFromZhHans('赠金扣除'),
    'loss_compensation': stLocalizedTextFromZhHans('亏损赔付'),
    'wallet_flow_type_profit_loss': stLocalizedTextFromZhHans('盈亏'),
    'wallet_flow_type_balance_clear': stLocalizedTextFromZhHans('清零'),
    'wallet_flow_type_withdraw_refund': stLocalizedTextFromZhHans('出金退回'),
    'wallet_flow_type_redeem_points': stLocalizedTextFromZhHans('积分兑换'),
    'wallet_flow_type_trading_bonus': stLocalizedTextFromZhHans('交易赠金'),
    'wallet_flow_type_profit_share': stLocalizedTextFromZhHans('盈利分成'),
    'wallet_flow_type_exam_register': stLocalizedTextFromZhHans('考试报名'),
    'wallet_flow_type_system_out_refund': stLocalizedTextFromZhHans('系统出金退款'),
    'wallet_flow_type_upfront_bonus_grant': stLocalizedTextFromZhHans('前置赠金发放'),
    'wallet_flow_type_upfront_bonus_revoke': stLocalizedTextFromZhHans(
      '前置赠金撤销',
    ),
    'wallet_flow_type_post_bonus_grant': stLocalizedTextFromZhHans('后置赠金发放'),
    'wallet_flow_type_upfront_bonus_release': stLocalizedTextFromZhHans(
      '前置赠金释放',
    ),
    'wallet_flow_type_trial_grant': stLocalizedTextFromZhHans('体验金发放'),
    'wallet_flow_type_trial_reward_grant': stLocalizedTextFromZhHans('体验金奖励发放'),
    'wallet_flow_type_manual_adjust_withdrawal': stLocalizedTextFromZhHans(
      '人工调整-取款调整',
    ),
    'wallet_flow_type_manual_adjust_deposit': stLocalizedTextFromZhHans(
      '人工调整-存款调整',
    ),
    'wallet_flow_type_manual_adjust_withdrawal_reversal':
        stLocalizedTextFromZhHans('人工调整-取消取款'),
    'wallet_flow_type_manual_adjust_deposit_reversal':
        stLocalizedTextFromZhHans('人工调整-取消存款'),
    'wallet_flow_type_manual_adjust_fault': stLocalizedTextFromZhHans(
      '人工调整-故障调整',
    ),
    'wallet_flow_type_manual_adjust_bonus_issuance': stLocalizedTextFromZhHans(
      '人工调整-赠金送出',
    ),
    'wallet_flow_type_manual_adjust_bonus_deduction': stLocalizedTextFromZhHans(
      '人工调整-赠金扣除',
    ),
    'wallet_flow_type_manual_adjust_withdrawal_net_deposit':
        stLocalizedTextFromZhHans('人工调整-取款调整（纳入净入金统计）'),
    'wallet_flow_type_manual_adjust_deposit_net_deposit':
        stLocalizedTextFromZhHans('人工调整-存款调整（纳入净入金统计）'),
    'reset': stLocalizedTextFromZhHans('重置'),
    'confirm_other': stLocalizedTextFromZhHans('确认'),
    'balance_plain': stLocalizedTextFromZhHans(''),
    'no_account': stLocalizedTextFromZhHans('没有账号？'),
    'flutter_prompt_wallet_info_load_failed': stLocalizedTextFromZhHans(
      '加载钱包信息失败',
    ),
    'flutter_prompt_wallet_flow_load_failed': stLocalizedTextFromZhHans(
      '加载流水失败',
    ),
  };
}

mixin _WalletLocalizedState<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  String? _localizedLanguageCode;
  Map<String, String> _localized = _WalletText.fallbackText;

  void _ensureLocalizedText() {
    final localizations = ref.read(stLocalizationsProvider);
    final languageCode = localizations.languageCode;
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    localizations.textMap(_WalletText.fallbackText).then((entries) {
      if (!mounted || _localizedLanguageCode != languageCode) return;
      setState(() => _localized = entries);
    });
  }

  String _t(String key) =>
      _localized[key] ?? _WalletText.fallbackText[key] ?? key;

  String _walletItemTitle(WalletAccountItem item) {
    if (item.isWallet) return _t('my_wallet');
    switch (item.account!.type) {
      case '0':
      case '4':
        return _t('real_account');
      case '1':
        return _t('simulation_account');
      default:
        return item.account!.accountType.isEmpty
            ? _t('my_account')
            : item.account!.accountType;
    }
  }
}

class _WalletPageState extends ConsumerState<WalletPage>
    with RouteAware, _WalletLocalizedState<WalletPage> {
  static const Duration _walletPollingInterval = Duration(seconds: 5);

  bool _hidden = false;
  bool _loading = false;
  bool _showRefreshHud = false;
  bool _pollingWalletInfo = false;
  bool _routeSubscribed = false;
  Timer? _walletPollingTimer;

  @override
  void initState() {
    super.initState();
    _startWalletPolling();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _refreshWalletInfo(showRefreshHud: true),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeSubscribed) return;
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
      _routeSubscribed = true;
    }
  }

  @override
  void didPopNext() {
    _startWalletPolling();
  }

  @override
  void didPushNext() {
    _stopWalletPolling();
  }

  @override
  void dispose() {
    _stopWalletPolling();
    if (_routeSubscribed) {
      routeObserver.unsubscribe(this);
    }
    super.dispose();
  }

  void _startWalletPolling() {
    if (_walletPollingTimer != null) return;
    _walletPollingTimer = Timer.periodic(
      _walletPollingInterval,
      (_) => _pollWalletInfo(),
    );
  }

  void _stopWalletPolling() {
    _walletPollingTimer?.cancel();
    _walletPollingTimer = null;
  }

  Future<void> _pollWalletInfo() async {
    if (!mounted || _loading || _pollingWalletInfo) return;
    if (!ref.read(userStateProvider).isLogin) return;
    _pollingWalletInfo = true;
    try {
      final info = await ref.read(stServiceProvider).getWalletInfo();
      if (mounted) {
        ref.read(userStateProvider.notifier).updateWalletInfo(info);
      }
    } catch (e) {
      debugPrint('Wallet polling getWalletInfo failed: $e');
    } finally {
      _pollingWalletInfo = false;
    }
  }

  Future<void> _refreshWalletInfo({bool showRefreshHud = false}) async {
    if (!mounted || _loading) return;
    setState(() {
      _loading = true;
      _showRefreshHud = showRefreshHud;
    });
    final service = ref.read(stServiceProvider);
    Object? lastError;

    try {
      final info = await service.getWalletInfo();
      ref.read(userStateProvider.notifier).updateWalletInfo(info);
    } catch (e) {
      lastError = e;
    }

    try {
      final configs = await service.getVerificationConfig();
      ref
          .read(userStateProvider.notifier)
          .updateVerificationConfig(
            configs
                .whereType<Map>()
                .map(
                  (e) => STVerificationModel.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList(),
          );
    } catch (e) {
      lastError = e;
    }

    try {
      final auth = await service.getAuthStatus();
      final data = auth['data'];
      ref
          .read(userStateProvider.notifier)
          .updateAuthStatus(
            AuthStatusModel.fromJson(
              data is Map<String, dynamic>
                  ? data
                  : data is Map
                  ? Map<String, dynamic>.from(data)
                  : auth,
            ),
          );
    } catch (e) {
      lastError = e;
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _showRefreshHud = false;
    });
    if (lastError != null) {
      showStLocalizedToastByKey(
        context,
        'flutter_prompt_wallet_info_load_failed',
        fallback: _t('flutter_prompt_wallet_info_load_failed'),
      );
    }
  }

  void _openCustomerService(UserState user) {
    CustomerServiceRoute.open(context, ref);
  }

  Future<void> _walletAction(String action, String route) async {
    await ref
        .read(walletActionHandlerProvider)
        .handleWalletAction(
          context: context,
          action: action,
          onPassed: () => context.push(route),
        );
  }

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText();
    final user = ref.watch(userStateProvider);
    final items = <WalletAccountItem>[
      ...user.walletAry.map(WalletAccountItem.wallet),
      ...user.accountAry
          .where((account) => account.type == '0' || account.type == '4')
          .map(WalletAccountItem.trade),
    ];

    return Scaffold(
      backgroundColor: context.adaptivePageGrey,
      body: Stack(
        children: [
          STPullRefresh(
            onRefresh: _refreshWalletInfo,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _WalletAssetHeader(
                    user: user,
                    hidden: _hidden,
                    onToggleHidden: () => setState(() => _hidden = !_hidden),
                    onCustomerService: () => _openCustomerService(user),
                    onDeposit: () => _walletAction('deposit', '/mine/deposit'),
                    onWithdraw: () => _walletAction('withdraw', '/mine/draw'),
                    onTransfer: () =>
                        _walletAction('internal_transfer', '/mine/transfer'),
                    text: _localized,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.adaptivePageGrey,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(19, 17, 19, 1),
                    child: Text(
                      _t('my_account'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: context.adaptiveTextPrimary,
                      ),
                    ),
                  ),
                ),
                if (items.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(15, 6, 15, 24),
                      child: _WalletEmptyCard(text: _t('no_account')),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(0, 1, 0, 24),
                    sliver: SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _WalletAccountListCard(
                          item: item,
                          title: _walletItemTitle(item),
                          text: _localized,
                          onTap: () => context.push(
                            '/mine/wallet/account',
                            extra: {'item': item},
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (_showRefreshHud) const _WalletActionRefreshingHud(),
        ],
      ),
    );
  }
}

class _WalletActionRefreshingHud extends StatelessWidget {
  const _WalletActionRefreshingHud();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      key: ValueKey('wallet-action-refreshing-hud'),
      child: AbsorbPointer(
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xCC17171A),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: SizedBox(
              width: 72,
              height: 72,
              child: Center(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Color(0xFFE6E6EA),
                    backgroundColor: Color(0xFF3A3A40),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WalletAccountDetailPage extends ConsumerStatefulWidget {
  final WalletAccountItem item;

  const WalletAccountDetailPage({super.key, required this.item});

  @override
  ConsumerState<WalletAccountDetailPage> createState() =>
      _WalletAccountDetailPageState();
}

class _WalletAccountDetailPageState
    extends ConsumerState<WalletAccountDetailPage>
    with _WalletLocalizedState<WalletAccountDetailPage> {
  static const int _limit = 6;

  int _range = 0;
  bool _loading = true;
  bool _showMore = false;
  List<Map<String, dynamic>> _flows = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFlows());
  }

  Future<void> _loadFlows() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final service = ref.read(stServiceProvider);
      final range = _resolveRange(
        _range,
        timezone: ref.read(userStateProvider).selectedTimeZone,
      );
      final flowTypeLookupFuture = _loadWalletFlowTypeDescLookup(service);
      if (widget.item.isWallet) {
        final result = await service.getWalletTransactionsWithTotal(
          offset: 0,
          limit: _limit,
          walletId: widget.item.wallet!.walletId,
          createTimeStart: range.start,
          createTimeEnd: range.end,
        );
        final flowTypeLookup = await flowTypeLookupFuture;
        _flows = result.items
            .whereType<Map>()
            .map(
              (e) => _enrichWalletFlowRecord(
                Map<String, dynamic>.from(e),
                flowTypeLookup,
              ),
            )
            .toList();
        _showMore = _flows.length < result.total;
      } else {
        final result = await service.getTransAccountFlow({
          'offset': 0,
          'limit': _limit,
          'account_id': widget.item.account!.accountId,
          'account_type': widget.item.account!.type,
          if (range.start != null) 'create_time_start': range.start,
          if (range.end != null) 'create_time_end': range.end,
        });
        final flowTypeLookup = await flowTypeLookupFuture;
        _flows = result
            .whereType<Map>()
            .map(
              (e) => _enrichWalletFlowRecord(
                Map<String, dynamic>.from(e),
                flowTypeLookup,
              ),
            )
            .toList();
        _showMore = _flows.length >= _limit;
      }
    } catch (e) {
      if (mounted) _toast(_t('flutter_prompt_wallet_flow_load_failed'));
      _flows = [];
      _showMore = false;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _moreCondition() {
    context.push(
      '/mine/wallet/flow',
      extra: {'item': widget.item, 'range': _range},
    );
  }

  Future<void> _walletAction(String action, String route) async {
    final targetRoute =
        widget.item.isWallet &&
            (route == '/mine/deposit' || route == '/mine/draw')
        ? '$route?depositTarget=1'
        : route;
    await ref
        .read(walletActionHandlerProvider)
        .handleWalletAction(
          context: context,
          action: action,
          onPassed: () => context.push(targetRoute),
        );
  }

  void _toast(String message) {
    if (mounted) showStLocalizedToast(context, message);
  }

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText();
    final item = widget.item;
    return Scaffold(
      backgroundColor: context.adaptivePageGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.adaptiveSurfacePrimary,
        foregroundColor: context.adaptiveTextPrimary,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.adaptiveTextPrimary),
        title: Text(
          _walletItemTitle(item),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: context.adaptiveTextPrimary,
          ),
        ),
      ),
      body: STPullRefresh(
        onRefresh: _loadFlows,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(15, 20, 15, 24),
          children: [
            _WalletAccountSummaryCard(
              item: item,
              title: _walletItemTitle(item),
              text: _localized,
              detail: true,
              onDeposit: () => _walletAction('deposit', '/mine/deposit'),
              onWithdraw: () => _walletAction('withdraw', '/mine/draw'),
              onTransfer: () =>
                  _walletAction('internal_transfer', '/mine/transfer'),
            ),
            const SizedBox(height: 21),
            Row(
              children: [
                _RangeChips(
                  value: _range,
                  text: _localized,
                  onChanged: (value) {
                    setState(() => _range = value);
                    _loadFlows();
                  },
                ),
                const Spacer(),
                TextButton(
                  onPressed: _moreCondition,
                  child: Text(
                    _t('more'),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.adaptiveTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            if (_loading)
              const _WalletLoadingCard()
            else if (_flows.isEmpty)
              _WalletNoRecordsCard(text: _t('no_record'))
            else
              _FlowPreviewList(
                flows: _flows,
                showMore: _showMore,
                onMore: _moreCondition,
                text: _localized,
              ),
          ],
        ),
      ),
    );
  }
}

class WalletFlowListPage extends ConsumerStatefulWidget {
  final WalletAccountItem item;
  final int initialRange;

  const WalletFlowListPage({
    super.key,
    required this.item,
    this.initialRange = 0,
  });

  @override
  ConsumerState<WalletFlowListPage> createState() => _WalletFlowListPageState();
}

class _WalletFlowListPageState extends ConsumerState<WalletFlowListPage> {
  String? _localizedLanguageCode;
  Map<String, String> _localized = _WalletText.fallbackText;

  static const int _pageSize = 20;

  int _range = 0;
  dynamic _filterType;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _openingFlowFilter = false;
  int _offset = 0;
  List<Map<String, dynamic>> _flows = [];

  void _ensureLocalizedText() {
    final localizations = ref.read(stLocalizationsProvider);
    final languageCode = localizations.languageCode;
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    localizations.textMap(_WalletText.fallbackText).then((entries) {
      if (!mounted || _localizedLanguageCode != languageCode) return;
      setState(() => _localized = entries);
    });
  }

  String _t(String key) =>
      _localized[key] ?? _WalletText.fallbackText[key] ?? key;

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  Future<void> _load({required bool reset}) async {
    if (_loadingMore) return;
    if (reset) {
      setState(() {
        _loading = true;
        _offset = 0;
        _hasMore = true;
      });
    } else if (!_hasMore) {
      return;
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final service = ref.read(stServiceProvider);
      final range = _resolveRange(
        _range,
        timezone: ref.read(userStateProvider).selectedTimeZone,
        customStart: _customStartDate,
        customEnd: _customEndDate,
      );
      final flowTypeLookupFuture = _loadWalletFlowTypeDescLookup(service);
      List<Map<String, dynamic>> next;
      int total;
      if (widget.item.isWallet) {
        final result = await service.getWalletTransactionsWithTotal(
          offset: _offset,
          limit: _pageSize,
          walletId: widget.item.wallet!.walletId,
          createTimeStart: range.start,
          createTimeEnd: range.end,
          method: _filterType,
        );
        final flowTypeLookup = await flowTypeLookupFuture;
        next = result.items
            .whereType<Map>()
            .map(
              (e) => _enrichWalletFlowRecord(
                Map<String, dynamic>.from(e),
                flowTypeLookup,
              ),
            )
            .toList();
        total = result.total;
      } else {
        final result = await service.getTransAccountFlow({
          'offset': _offset,
          'limit': _pageSize,
          'account_id': widget.item.account!.accountId,
          'account_type': widget.item.account!.type,
          if (range.start != null) 'create_time_start': range.start,
          if (range.end != null) 'create_time_end': range.end,
          if (_filterType != null) 'type': _filterType,
        });
        final flowTypeLookup = await flowTypeLookupFuture;
        next = result
            .whereType<Map>()
            .map(
              (e) => _enrichWalletFlowRecord(
                Map<String, dynamic>.from(e),
                flowTypeLookup,
              ),
            )
            .toList();
        total = _offset + next.length + (next.length >= _pageSize ? 1 : 0);
      }

      if (mounted) {
        setState(() {
          if (reset) {
            _flows = next;
          } else {
            _flows.addAll(next);
          }
          _offset = _flows.length;
          _hasMore = _flows.length < total && next.isNotEmpty;
        });
      }
    } catch (e) {
      if (mounted) {
        showStLocalizedToast(
          context,
          _t('flutter_prompt_wallet_flow_load_failed'),
        );
      }
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _openFlowFilter() async {
    if (_openingFlowFilter) return;
    _openingFlowFilter = true;
    final result =
        await showWalletFlowFilterSheet(
          context: context,
          service: ref.read(stServiceProvider),
          text: _localized,
          range: _range,
          filterType: _filterType,
          startDate: _customStartDate,
          endDate: _customEndDate,
        ).whenComplete(() {
          _openingFlowFilter = false;
        });
    if (result == null || !mounted) return;
    setState(() {
      _range = result.range;
      _filterType = result.filterType;
      _customStartDate = result.startDate;
      _customEndDate = result.endDate;
    });
    await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText();
    return Scaffold(
      backgroundColor: context.adaptivePageGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.adaptiveSurfacePrimary,
        foregroundColor: context.adaptiveTextPrimary,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.adaptiveTextPrimary),
        title: Text(
          _t('flow'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: context.adaptiveTextPrimary,
          ),
        ),
      ),
      body: STPullRefresh(
        onRefresh: () => _load(reset: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: _RangeChips(
                    value: _range,
                    text: _localized,
                    onChanged: (value) {
                      setState(() => _range = value);
                      _load(reset: true);
                    },
                  ),
                ),
                TextButton(
                  onPressed: _openFlowFilter,
                  child: Text(
                    _t('filtering'),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.adaptiveTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            if (_loading)
              const _WalletLoadingCard()
            else if (_flows.isEmpty)
              _WalletNoRecordsCard(text: _t('no_record'))
            else
              _FlowPreviewList(
                flows: _flows,
                showMore: false,
                text: _localized,
              ),
            if (_flows.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Center(
                  child: TextButton(
                    onPressed: _hasMore ? () => _load(reset: false) : null,
                    child: Text(
                      _loadingMore
                          ? _t('loading')
                          : _hasMore
                          ? _t('see_more')
                          : _t('already_the_end'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WalletAssetHeader extends StatelessWidget {
  final UserState user;
  final bool hidden;
  final VoidCallback onToggleHidden;
  final VoidCallback onCustomerService;
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;
  final VoidCallback onTransfer;
  final Map<String, String> text;

  const _WalletAssetHeader({
    required this.user,
    required this.hidden,
    required this.onToggleHidden,
    required this.onCustomerService,
    required this.onDeposit,
    required this.onWithdraw,
    required this.onTransfer,
    required this.text,
  });

  String _t(String key) => text[key] ?? _WalletText.fallbackText[key] ?? key;

  @override
  Widget build(BuildContext context) {
    final usd = user.totalAmountUSD.trim().isNotEmpty
        ? _formatMoney(user.totalAmountUSD)
        : '';
    final local = user.totalAmountLocalCurrency.trim();
    final currency = user.localCurrency.trim();

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/st_mine_balance_bg.png'),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Image.asset(
                      'assets/images/st_mine_back_white.png',
                      width: 24,
                      height: 24,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _t('wallet_assets'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onCustomerService,
                    icon: Image.asset(
                      'assets/images/st_mine_customer.png',
                      width: 24,
                      height: 24,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(34, 15, 34, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _t('total_assets_title').replaceAll(' (USD)', ''),
                        style: TextStyle(
                          color: Color(0x80FFFFFF),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 24,
                          height: 24,
                        ),
                        onPressed: onToggleHidden,
                        icon: Image.asset(
                          hidden
                              ? 'assets/images/st_mine_see_un.png'
                              : 'assets/images/st_mine_see.png',
                          width: 24,
                          height: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        hidden ? '****' : (usd.isEmpty ? '0.00' : usd),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!hidden &&
                          local.isNotEmpty &&
                          currency.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '≈ ${_formatMoney(local)}($currency)',
                            style: const TextStyle(
                              color: Color(0x80FFFFFF),
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _AssetActionButton(
                        label: _t('deposit'),
                        assetName: 'st_mine_deposit_sec',
                        onTap: onDeposit,
                      ),
                      _AssetActionButton(
                        label: _t('withdrawal'),
                        assetName: 'st_mine_draw_sec',
                        onTap: onWithdraw,
                      ),
                      _AssetActionButton(
                        label: _t('transfer'),
                        assetName: 'st_mine_transfer',
                        onTap: onTransfer,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetActionButton extends StatelessWidget {
  final String label;
  final String assetName;
  final VoidCallback onTap;

  const _AssetActionButton({
    required this.label,
    required this.assetName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Column(
        children: [
          Image.asset(
            'assets/images/$assetName.png',
            width: 48,
            height: 48,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(color: Color(0x80FFFFFF), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _WalletAccountListCard extends StatelessWidget {
  final WalletAccountItem item;
  final String title;
  final Map<String, String> text;
  final VoidCallback onTap;

  const _WalletAccountListCard({
    required this.item,
    required this.title,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: _WalletAccountSummaryCard(
          item: item,
          title: title,
          text: text,
          detail: false,
        ),
      ),
    );
  }
}

class _WalletAccountSummaryCard extends StatelessWidget {
  final WalletAccountItem item;
  final String title;
  final Map<String, String> text;
  final bool detail;
  final VoidCallback? onDeposit;
  final VoidCallback? onWithdraw;
  final VoidCallback? onTransfer;

  const _WalletAccountSummaryCard({
    required this.item,
    required this.title,
    required this.text,
    required this.detail,
    this.onDeposit,
    this.onWithdraw,
    this.onTransfer,
  });

  String _t(String key) => text[key] ?? _WalletText.fallbackText[key] ?? key;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 14),
      decoration: BoxDecoration(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.adaptiveTextPrimary,
                ),
              ),
              if (!detail) ...[
                const SizedBox(width: 2),
                Image.asset(
                  'assets/images/st_mine_arrow_more.png',
                  width: 14,
                  height: 14,
                ),
              ],
              const Spacer(),
              Text(
                item.id,
                style: TextStyle(
                  fontSize: 12,
                  color: context.adaptiveTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AccountIcon(isWallet: item.isWallet, accountType: item.type),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _t('balance'),
                    style: TextStyle(
                      fontSize: 10,
                      color: context.adaptiveTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _formatMoney(item.balance),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.adaptiveTextPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (!item.isWallet) ...[
            const SizedBox(height: 11),
            Row(
              children: [
                _MetricColumn(
                  label: _t('account_equity'),
                  value: item.equity,
                  alignment: TextAlign.left,
                ),
                const _VerticalMetricLine(),
                _MetricColumn(
                  label: _t('available'),
                  value: detail ? item.canDraw : item.marginFree,
                  alignment: TextAlign.center,
                ),
                const _VerticalMetricLine(),
                _MetricColumn(
                  label: _t('total_profit_and_loss'),
                  value: item.profit,
                  color: _moneyColor(context, item.profit),
                  alignment: TextAlign.right,
                ),
              ],
            ),
          ],
          if (detail) ...[
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _DetailAction(
                  label: _t('deposit'),
                  icon: Icons.south_west_rounded,
                  onTap: onDeposit,
                ),
                _DetailAction(
                  label: _t('withdrawal'),
                  icon: Icons.north_east_rounded,
                  onTap: onWithdraw,
                ),
                _DetailAction(
                  label: _t('transfer'),
                  icon: Icons.compare_arrows_rounded,
                  onTap: onTransfer,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _DetailAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.adaptiveIconPillBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: context.adaptiveTextPrimary, size: 24),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: context.adaptiveTextSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final TextAlign alignment;

  const _MetricColumn({
    required this.label,
    required this.value,
    this.color,
    this.alignment = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: _crossAxisAlignment,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignment,
            style: TextStyle(
              fontSize: 12,
              color: context.adaptiveTextSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatMoney(value),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: alignment,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color ?? context.adaptiveTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  CrossAxisAlignment get _crossAxisAlignment {
    switch (alignment) {
      case TextAlign.center:
        return CrossAxisAlignment.center;
      case TextAlign.right:
      case TextAlign.end:
        return CrossAxisAlignment.end;
      default:
        return CrossAxisAlignment.start;
    }
  }
}

class _VerticalMetricLine extends StatelessWidget {
  const _VerticalMetricLine();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: 1,
        height: 32,
        child: DecoratedBox(
          decoration: BoxDecoration(color: context.adaptiveDivider),
        ),
      ),
    );
  }
}

class _AccountIcon extends StatelessWidget {
  final bool isWallet;
  final String accountType;

  const _AccountIcon({required this.isWallet, required this.accountType});

  @override
  Widget build(BuildContext context) {
    final assetName = isWallet
        ? 'st_mine_wallet_sec'
        : accountType == '1'
        ? 'st_mine_simulate'
        : accountType == '2' || accountType == '3'
        ? 'st_mine_trans'
        : 'st_mine_firm';
    return Image.asset(
      'assets/images/$assetName.png',
      width: 32,
      height: 32,
      fit: BoxFit.contain,
    );
  }
}

class _RangeChips extends StatelessWidget {
  final int value;
  final Map<String, String> text;
  final ValueChanged<int> onChanged;

  const _RangeChips({
    required this.value,
    required this.text,
    required this.onChanged,
  });

  String _t(String key) => text[key] ?? _WalletText.fallbackText[key] ?? key;

  @override
  Widget build(BuildContext context) {
    final labels = [
      _t('all'),
      _t('program_today'),
      _t('last_7_days'),
      _t('past_month'),
    ];
    return Wrap(
      spacing: 5,
      children: [
        for (var i = 0; i < labels.length; i++)
          ChoiceChip(
            label: Text(labels[i]),
            selected: value == i,
            onSelected: (_) => onChanged(i),
            showCheckmark: false,
            labelStyle: TextStyle(
              fontSize: 12,
              color: value == i ? Colors.white : context.adaptiveTextPrimary,
            ),
            selectedColor: Colors.black,
            backgroundColor: context.adaptiveCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
              side: BorderSide(
                color: value == i ? Colors.black : context.adaptiveDivider,
              ),
            ),
          ),
      ],
    );
  }
}

class WalletFlowFilterResult {
  const WalletFlowFilterResult({
    required this.range,
    this.filterType,
    this.startDate,
    this.endDate,
  });

  final int range;
  final dynamic filterType;
  final DateTime? startDate;
  final DateTime? endDate;
}

class _WalletFlowTypeItem {
  const _WalletFlowTypeItem({required this.title, this.type});

  final String title;
  final dynamic type;
}

Future<WalletFlowFilterResult?> showWalletFlowFilterSheet({
  required BuildContext context,
  required STService service,
  required Map<String, String> text,
  required int range,
  dynamic filterType,
  DateTime? startDate,
  DateTime? endDate,
}) async {
  final raw = await service.getOrderTypes();
  if (!context.mounted) return null;
  final types = _parseWalletFlowTypes(raw, text);
  return showModalBottomSheet<WalletFlowFilterResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
    ),
    builder: (ctx) => _WalletFlowFilterSheet(
      types: types,
      text: text,
      initialRange: range,
      initialFilterType: filterType,
      initialStartDate: startDate,
      initialEndDate: endDate,
    ),
  );
}

String _normalizeWalletFlowTypeToken(String raw) {
  return raw
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_\-()/]'), '')
      .replaceAll('（', '')
      .replaceAll('）', '')
      .replaceAll(':', '');
}

String? _walletFlowTypeLocalizationKey(String rawTitle) {
  switch (_normalizeWalletFlowTypeToken(rawTitle)) {
    case 'profitloss':
    case '盈亏':
      return 'wallet_flow_type_profit_loss';
    case 'balanceclear':
    case '清零':
      return 'wallet_flow_type_balance_clear';
    case 'overnightinterest':
    case 'nightinterest':
    case '夜间利息':
    case '隔夜利息':
      return 'interest';
    case 'manualadjustment':
    case '人工调整':
      return 'manual_adjust';
    case 'manualadjustmentwithdrawaladjustment':
    case '人工调整取款调整':
      return 'wallet_flow_type_manual_adjust_withdrawal';
    case 'manualadjustmentdepositadjustment':
    case '人工调整存款调整':
      return 'wallet_flow_type_manual_adjust_deposit';
    case 'manualadjustmentwithdrawalreversal':
    case '人工调整取消取款':
      return 'wallet_flow_type_manual_adjust_withdrawal_reversal';
    case 'manualadjustmentdepositreversal':
    case '人工调整取消存款':
      return 'wallet_flow_type_manual_adjust_deposit_reversal';
    case 'manualadjustmentfaultadjustment':
    case '人工调整故障调整':
      return 'wallet_flow_type_manual_adjust_fault';
    case 'manualadjustmentbonusissuance':
    case '人工调整赠金送出':
      return 'wallet_flow_type_manual_adjust_bonus_issuance';
    case 'manualadjustmentbonusdeduction':
    case '人工调整赠金扣除':
      return 'wallet_flow_type_manual_adjust_bonus_deduction';
    case 'manualadjustmentwithdrawalincludedinnetdepositstatistics':
    case '人工调整取款调整纳入净入金统计':
      return 'wallet_flow_type_manual_adjust_withdrawal_net_deposit';
    case 'manualadjustmentdepositincludedinnetdepositstatistics':
    case '人工调整存款调整纳入净入金统计':
      return 'wallet_flow_type_manual_adjust_deposit_net_deposit';
    case 'deposit':
    case '入金':
      return 'deposit';
    case 'withdrawal':
    case '出金':
      return 'withdrawal';
    case 'withdrawrefund':
    case '出金退回':
      return 'wallet_flow_type_withdraw_refund';
    case 'transferin':
    case '转入':
      return 'transfer_enter';
    case 'transferout':
    case '转出':
      return 'transfer_out';
    case 'commission':
    case '佣金':
      return 'commission';
    case 'bonus':
    case '赠金':
      return 'bonus';
    case 'rewarddeduct':
    case '赠金扣除':
      return 'reward_rebate';
    case 'redeempoints':
    case '积分兑换':
      return 'wallet_flow_type_redeem_points';
    case 'tradingbonus':
    case '交易赠金':
      return 'wallet_flow_type_trading_bonus';
    case 'profitshare':
    case '盈利分成':
      return 'wallet_flow_type_profit_share';
    case 'losscompensate':
    case '亏损赔付':
      return 'loss_compensation';
    case 'examregister':
    case '考试报名':
      return 'wallet_flow_type_exam_register';
    case 'systemoutrefund':
    case '系统出金退款':
      return 'wallet_flow_type_system_out_refund';
    case 'upfrontbonusgrant':
    case '前置赠金发放':
      return 'wallet_flow_type_upfront_bonus_grant';
    case 'upfrontbonusrevoke':
    case '前置赠金撤销':
      return 'wallet_flow_type_upfront_bonus_revoke';
    case 'postbonusgrant':
    case '后置赠金发放':
      return 'wallet_flow_type_post_bonus_grant';
    case 'upfrontbonusrelease':
    case '前置赠金释放':
      return 'wallet_flow_type_upfront_bonus_release';
    case 'trialgrant':
    case '体验金发放':
      return 'wallet_flow_type_trial_grant';
    case 'trialrewardgrant':
    case '体验金奖励发放':
      return 'wallet_flow_type_trial_reward_grant';
  }
  return null;
}

String _localizedWalletFlowTypeTitle(
  String rawTitle,
  Map<String, String> text,
) {
  final key = _walletFlowTypeLocalizationKey(rawTitle);
  if (key == null) return rawTitle;
  return text[key] ?? _WalletText.fallbackText[key] ?? rawTitle;
}

List<_WalletFlowTypeItem> _parseWalletFlowTypes(
  Map<String, dynamic> raw,
  Map<String, String> text,
) {
  final dynamic source =
      raw['types'] ??
      (raw['data'] is Map ? (raw['data'] as Map)['types'] : null) ??
      (raw['data'] is Map ? (raw['data'] as Map)['order_types'] : null) ??
      raw['order_types'];
  final items = <_WalletFlowTypeItem>[
    _WalletFlowTypeItem(
      title: text['all'] ?? _WalletText.fallbackText['all']!,
      type: null,
    ),
  ];
  if (source is List) {
    for (final item in source.whereType<Map>()) {
      final rawTitle =
          item['desc']?.toString() ??
          item['name']?.toString() ??
          item['title']?.toString() ??
          '';
      if (rawTitle.isEmpty || item['type'] == -1) {
        continue;
      }
      final title = _localizedWalletFlowTypeTitle(rawTitle, text);
      if (title == (text['all'] ?? _WalletText.fallbackText['all']!)) continue;
      items.add(_WalletFlowTypeItem(title: title, type: item['type']));
    }
  }
  return items;
}

class _WalletFlowFilterSheet extends StatefulWidget {
  const _WalletFlowFilterSheet({
    required this.types,
    required this.text,
    required this.initialRange,
    this.initialFilterType,
    this.initialStartDate,
    this.initialEndDate,
  });

  final List<_WalletFlowTypeItem> types;
  final Map<String, String> text;
  final int initialRange;
  final dynamic initialFilterType;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  @override
  State<_WalletFlowFilterSheet> createState() => _WalletFlowFilterSheetState();
}

class _WalletFlowFilterSheetState extends State<_WalletFlowFilterSheet> {
  late int _range = widget.initialRange;
  late dynamic _filterType = widget.initialFilterType;
  late DateTime? _startDate = widget.initialStartDate;
  late DateTime? _endDate = widget.initialEndDate;

  String _t(String key) =>
      widget.text[key] ?? _WalletText.fallbackText[key] ?? key;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: _walletFlowFilterMaxHeight(context),
      ),
      child: Container(
        key: const ValueKey('wallet-flow-filter-sheet'),
        decoration: BoxDecoration(
          color: context.adaptiveSurfacePrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
        ),
        padding: EdgeInsets.fromLTRB(15, 28, 15, 24 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                key: const ValueKey('wallet-flow-filter-handle'),
                width: 80,
                height: 5,
                decoration: BoxDecoration(
                  color: _walletFlowFilterOptionBg(context),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 26),
            Center(
              child: Text(
                _t('filtering'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.adaptiveTextPrimary,
                ),
              ),
            ),
            const SizedBox(height: 34),
            Text(
              _t('project'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.adaptiveTextTertiary,
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                key: const ValueKey('wallet-flow-filter-type-scroll'),
                physics: const BouncingScrollPhysics(),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in widget.types)
                        _WalletFlowFilterPill(
                          label: item.title,
                          selected:
                              '${item.type ?? ''}' == '${_filterType ?? ''}',
                          onTap: () => setState(() => _filterType = item.type),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            _WalletFlowFilterFooter(
              key: const ValueKey('wallet-flow-filter-fixed-footer'),
              dateLabel: _t('date'),
              startLabel: _dateButtonText(_startDate, _t('start_date')),
              endLabel: _dateButtonText(_endDate, _t('end_date')),
              startSelected: _startDate != null,
              endSelected: _endDate != null,
              resetLabel: _t('reset'),
              confirmLabel: _t('confirm_other'),
              onStartTap: () => _pickDate(isStart: true),
              onEndTap: () => _pickDate(isStart: false),
              onReset: () => setState(() {
                _range = 0;
                _filterType = null;
                _startDate = null;
                _endDate = null;
              }),
              onConfirm: () => Navigator.of(context).pop(
                WalletFlowFilterResult(
                  range: _range,
                  filterType: _filterType,
                  startDate: _startDate,
                  endDate: _endDate,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _walletFlowFilterMaxHeight(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final view = View.of(context);
    final fallbackHeight = view.physicalSize.height / view.devicePixelRatio;
    final height = mediaSize.height > 0 ? mediaSize.height : fallbackHeight;
    return height * 0.8;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showIosDatePickerSheet(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      minimumDate: isStart ? DateTime(2000) : (_startDate ?? DateTime(2000)),
      maximumDate: isStart
          ? (_endDate ?? DateTime(2050, 12, 30))
          : DateTime(2050, 12, 30),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
        if (_startDate != null && _startDate!.isAfter(picked)) {
          _startDate = picked;
        }
      }
      _range = 0;
    });
  }

  String _dateButtonText(DateTime? date, String fallback) {
    if (date == null) return fallback;
    return formatIosYmd(
      date,
      languageCode: languageCodeFromLocale(Localizations.localeOf(context)),
    );
  }
}

class _WalletFlowFilterFooter extends StatelessWidget {
  const _WalletFlowFilterFooter({
    super.key,
    required this.dateLabel,
    required this.startLabel,
    required this.endLabel,
    required this.startSelected,
    required this.endSelected,
    required this.resetLabel,
    required this.confirmLabel,
    required this.onStartTap,
    required this.onEndTap,
    required this.onReset,
    required this.onConfirm,
  });

  final String dateLabel;
  final String startLabel;
  final String endLabel;
  final bool startSelected;
  final bool endSelected;
  final String resetLabel;
  final String confirmLabel;
  final VoidCallback onStartTap;
  final VoidCallback onEndTap;
  final VoidCallback onReset;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 34),
        Text(
          dateLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: context.adaptiveTextTertiary,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _DateFilterButton(
                label: startLabel,
                selected: startSelected,
                onTap: onStartTap,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                width: 8,
                height: 1,
                color: const Color(0xFFD9D9D9),
              ),
            ),
            Expanded(
              child: _DateFilterButton(
                label: endLabel,
                selected: endSelected,
                onTap: onEndTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),
        Row(
          children: [
            Expanded(
              child: _WalletFlowFilterActionButton(
                label: resetLabel,
                backgroundColor: context.adaptiveDivider,
                foregroundColor: context.adaptiveTextPrimary,
                onPressed: onReset,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _WalletFlowFilterActionButton(
                label: confirmLabel,
                backgroundColor: const Color(0xFF397BD8),
                foregroundColor: Colors.white,
                onPressed: onConfirm,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WalletFlowFilterActionButton extends StatelessWidget {
  const _WalletFlowFilterActionButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}

class _DateFilterButton extends StatelessWidget {
  static const Color _selectedLineColor = Color(0xFF00B57A);
  static const Color _unselectedLineColor = Color(0xFFECECEC);

  const _DateFilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 26,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: selected
                          ? context.adaptiveTextPrimary
                          : const Color(0xFFCCCCCC),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: context.adaptiveTextPrimary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          Container(
            height: 1,
            color: selected ? _selectedLineColor : _unselectedLineColor,
          ),
        ],
      ),
    );
  }
}

class _WalletFlowFilterPill extends StatelessWidget {
  const _WalletFlowFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('wallet-flow-filter-$label'),
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _walletFlowFilterOptionBg(context),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 26),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: selected
                      ? const Color(0xFF00B57A)
                      : context.adaptiveTextSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _walletFlowFilterOptionBg(BuildContext context) =>
    context.adaptiveIsDark ? context.adaptiveCard : const Color(0xFFF7F7F7);

class _FlowPreviewList extends StatelessWidget {
  final List<Map<String, dynamic>> flows;
  final bool showMore;
  final Map<String, String> text;
  final VoidCallback? onMore;

  const _FlowPreviewList({
    required this.flows,
    required this.showMore,
    required this.text,
    this.onMore,
  });

  String _t(String key) => text[key] ?? _WalletText.fallbackText[key] ?? key;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < flows.length; i++)
            _FlowRow(
              raw: flows[i],
              isLast: i == flows.length - 1 && !showMore,
              text: text,
            ),
          if (showMore)
            TextButton(
              onPressed: onMore,
              child: Text(
                _t('see_more'),
                style: TextStyle(
                  fontSize: 12,
                  color: context.adaptiveTextPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FlowRow extends StatelessWidget {
  final Map<String, dynamic> raw;
  final bool isLast;
  final Map<String, String> text;

  const _FlowRow({required this.raw, required this.isLast, required this.text});

  String _t(String key) => text[key] ?? _WalletText.fallbackText[key] ?? key;

  @override
  Widget build(BuildContext context) {
    final title = _flowTitle(raw, text);
    final time = _flowTime(raw);
    final amount = _flowAmount(raw);
    final balance = _flowBalance(raw);
    return InkWell(
      onTap: () =>
          context.push('/mine/wallet/flow/detail', extra: {'flow': raw}),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 13, 12, 0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.adaptiveTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        time,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.adaptiveTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amount,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: amount.startsWith('-')
                            ? const Color(0xFFFF4D4F)
                            : const Color(0xFF1BCC83),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_t('balance_plain')} ${_formatMoney(balance)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.adaptiveTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (!isLast)
              Padding(
                padding: const EdgeInsets.only(top: 13),
                child: Divider(height: 1, color: context.adaptiveDivider),
              )
            else
              const SizedBox(height: 13),
          ],
        ),
      ),
    );
  }
}

class _WalletEmptyCard extends StatelessWidget {
  final String text;

  const _WalletEmptyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      decoration: BoxDecoration(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: context.adaptiveTextSecondary),
        ),
      ),
    );
  }
}

class _WalletNoRecordsCard extends StatelessWidget {
  final String text;

  const _WalletNoRecordsCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 49),
      decoration: BoxDecoration(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 46,
            color: context.adaptiveTextHint,
          ),
          const SizedBox(height: 11),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: context.adaptiveTextPrimary),
          ),
        ],
      ),
    );
  }
}

class _WalletLoadingCard extends StatelessWidget {
  const _WalletLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      decoration: BoxDecoration(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Center(child: STLoadAnimationView()),
    );
  }
}

class WalletAccountItem {
  final WalletModel? wallet;
  final STAccountModel? account;

  const WalletAccountItem.wallet(WalletModel value)
    : wallet = value,
      account = null;

  const WalletAccountItem.trade(STAccountModel value)
    : wallet = null,
      account = value;

  bool get isWallet => wallet != null;
  String get title => isWallet ? wallet!.walletId : account!.accountType;
  String get id => isWallet ? wallet!.walletId : account!.accountId;
  String get type => isWallet ? '' : account!.type;
  String get balance => isWallet ? '${wallet!.balance}' : account!.balance;
  String get equity => isWallet ? wallet!.equity : account!.equity;
  String get marginFree => isWallet ? wallet!.marginFree : account!.marginFree;
  String get canDraw => isWallet ? wallet!.canDraw : account!.canDraw;
  String get profit => isWallet ? '' : account!.profit;
}

({int? start, int? end}) _resolveRange(
  int value, {
  String? timezone,
  DateTime? customStart,
  DateTime? customEnd,
}) {
  if (customStart != null && customEnd != null) {
    return (
      start: iosStartOfDaySeconds(customStart, timezone: timezone),
      end: iosEndOfDaySeconds(customEnd, timezone: timezone),
    );
  }
  final range = iosQuickRange(value, timezone: timezone);
  return (start: range.start, end: range.end);
}

String _formatMoney(dynamic value) {
  if (value == null) return '0.00';
  final text = value.toString().trim();
  if (text.isEmpty) return '0.00';
  final parsed = double.tryParse(text.replaceAll(',', ''));
  if (parsed == null) return text;
  final formatter = NumberFormat('#,##0.00', 'en_US');
  return formatter.format(parsed);
}

Color _moneyColor(BuildContext context, String value) {
  final parsed = double.tryParse(value.replaceAll(',', '')) ?? 0;
  if (parsed > 0) return CardTool.priceColor(1);
  if (parsed < 0) return CardTool.priceColor(-1);
  return context.adaptiveTextPrimary;
}

String _flowTitle(Map<String, dynamic> raw, [Map<String, String>? text]) {
  final title =
      raw['chang_method_str']?.toString() ??
      raw['changMethodStr']?.toString() ??
      raw['fund_flow_type_str']?.toString() ??
      raw['fundFlowTypeStr']?.toString() ??
      raw['desc']?.toString() ??
      raw['name']?.toString() ??
      raw['title']?.toString() ??
      raw['type']?.toString();
  if (_isBlankFlowText(title)) return '--';
  if (text == null) return title!;
  return _localizedWalletFlowTypeTitle(title!, text);
}

String _flowAmount(Map<String, dynamic> raw) {
  final value = raw['change_amount'] ?? raw['changeAmount'] ?? raw['amount'];
  final n = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  final sign = n < 0 ? '-' : '+';
  return '$sign${_formatMoney(n.abs())}';
}

String _flowBalance(Map<String, dynamic> raw) {
  return '${raw['after_balance'] ?? raw['afterBalance'] ?? raw['balance_after'] ?? raw['balanceAfter'] ?? raw['balance'] ?? '0'}';
}

bool _isBlankFlowText(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty || text == '--' || text == '—';
}

Future<Map<String, String>> _loadWalletFlowTypeDescLookup(
  STService service,
) async {
  try {
    return _buildWalletFlowTypeDescLookup(await service.getOrderTypes());
  } catch (_) {
    return const <String, String>{};
  }
}

Map<String, String> _buildWalletFlowTypeDescLookup(Map<String, dynamic> raw) {
  final dynamic source =
      raw['types'] ??
      (raw['data'] is Map ? (raw['data'] as Map)['types'] : null) ??
      (raw['data'] is Map ? (raw['data'] as Map)['order_types'] : null) ??
      raw['order_types'];
  final lookup = <String, String>{};
  if (source is! List) return lookup;
  for (final item in source.whereType<Map>()) {
    final typeKey = item['type']?.toString();
    final desc =
        item['desc']?.toString() ??
        item['name']?.toString() ??
        item['title']?.toString();
    if (_isBlankFlowText(typeKey) ||
        typeKey == '-1' ||
        _isBlankFlowText(desc)) {
      continue;
    }
    lookup[typeKey!] = desc!;
  }
  return lookup;
}

Map<String, dynamic> _enrichWalletFlowRecord(
  Map<String, dynamic> raw,
  Map<String, String> flowTypeLookup,
) {
  if (flowTypeLookup.isEmpty) return raw;
  final enriched = Map<String, dynamic>.from(raw);
  final existingTitle = _flowTitle(enriched);
  if (!_isBlankFlowText(existingTitle)) {
    if (enriched['order_num'] == null && enriched['order_no'] != null) {
      enriched['order_num'] = enriched['order_no'];
    }
    return enriched;
  }

  final flowType =
      enriched['chang_method'] ??
      enriched['changMethod'] ??
      enriched['fund_flow_type'] ??
      enriched['fundFlowType'];
  final flowTypeKey = flowType?.toString();
  final resolvedTitle = flowTypeKey == null
      ? null
      : flowTypeLookup[flowTypeKey];
  if (!_isBlankFlowText(resolvedTitle)) {
    if (enriched.containsKey('fund_flow_type') ||
        enriched.containsKey('fundFlowType')) {
      enriched['fund_flow_type_str'] = resolvedTitle;
    } else {
      enriched['chang_method_str'] = resolvedTitle;
    }
  }
  if (enriched['order_num'] == null && enriched['order_no'] != null) {
    enriched['order_num'] = enriched['order_no'];
  }
  return enriched;
}

String _flowTime(Map<String, dynamic> raw) {
  final value =
      raw['order_time'] ??
      raw['orderTime'] ??
      raw['created_at'] ??
      raw['transaction_time'] ??
      raw['transactionTime'];
  if (value == null) return '--';
  if (value is String) {
    final parsedDate = DateTime.tryParse(value);
    if (parsedDate != null) {
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(parsedDate);
    }
    final parsedInt = int.tryParse(value);
    if (parsedInt == null) return value;
    return _flowTime({'order_time': parsedInt});
  }
  final n = value is num ? value.toInt() : 0;
  if (n <= 0) return '$value';
  final sec = n > 2000000000 ? n ~/ 1000 : n;
  return DateFormat(
    'yyyy-MM-dd HH:mm:ss',
  ).format(DateTime.fromMillisecondsSinceEpoch(sec * 1000));
}
