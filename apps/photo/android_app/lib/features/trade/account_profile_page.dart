import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';
import 'package:jufu/shared/widgets/st_pull_refresh.dart';

import '../../core/config/card_tool.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/models/user_state.dart';
import '../../core/models/market_product_model.dart';
import '../../core/network/market_websocket.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/network/st_service.dart';
import '../../core/providers/event_bus.dart';
import '../../core/services/wallet_action_handler.dart';
import '../../core/services/user_preference_prefs.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../core/utils/ios_date_range.dart';
import '../../shared/widgets/ios_date_picker_sheet.dart';
import '../../shared/widgets/st_toast.dart';
import 'trade_account_detail_cell_contract.dart';
import 'trade_confirm_dialog.dart';
import 'trade_empty_state.dart';
import 'trade_margin_help_sheet.dart';
import 'trade_order_live_update.dart';
import 'trade_position_action_sheet.dart';

enum _ProfileTab { position, pending, history }

enum _FieldAlignment { start, center, end }

/// 交易账户明细页面。
///
/// 对齐 iOS `STTradeAccountProfileController`：
/// 0=TradeHome, 1=Open, 2=Registration, 3=Mine, 4=Web,
/// 5=CloseSuccessTradeHome.
class AccountProfilePage extends ConsumerStatefulWidget {
  final int fromType;
  final String? accountId;
  final int? initialTab;

  const AccountProfilePage({
    super.key,
    this.fromType = 0,
    this.accountId,
    this.initialTab,
  });

  @override
  ConsumerState<AccountProfilePage> createState() => _AccountProfilePageState();
}

class _AccountProfilePageState extends ConsumerState<AccountProfilePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const int _pageSize = 20;
  static const Color _lineColor = Color(0xFFECECEC);
  static const Color _mutedText = Color(0xFF9A9DA2);
  static const Color _figmaMutedText = Color(0xFF949494);
  static const Color _tabIndicatorGreen = Color(0xFF4DCB73);
  static const double _oneKeyCloseBottomOffset = 62;
  static const String _depositRoute = '/mine/deposit';

  Color _profileBgOf(BuildContext context) => context.adaptivePageGrey;
  Color _surfaceOf(BuildContext context) => context.adaptiveSurfacePrimary;
  Color _mutedBlockOf(BuildContext context) => context.adaptiveMutedBlock;
  Color _primaryTextOf(BuildContext context) => context.adaptiveTextPrimary;
  Color _secondaryTextOf(BuildContext context) => context.adaptiveTextSecondary;
  Color _dividerOf(BuildContext context) => context.adaptiveDivider;
  Color _ledgerUnselectedTextOf(BuildContext context) =>
      context.adaptiveIsDark ? _secondaryTextOf(context) : _figmaMutedText;

  late final TabController _tabController;
  Timer? _accountTimer;
  StreamSubscription<MarketWSMessage>? _wsSub;
  VoidCallback? _accountChangedListener;
  String? _localizedLanguageCode;
  int _languageLoadToken = 0;
  Map<String, String> _localized = _fallbackText;

  static const Map<String, String> _fallbackText = {
    'switch_account': '切换',
    'account_equity': '净值',
    'profit_and_loss': '盈亏',
    'free_margin': '可用保证金',
    'occupied_security_deposit': '已用保证金',
    'balance': '余额',
    'margin_level': '保证金水平',
    'top_up_pay': '入金',
    'new_order': '新订单',
    'positions': '持仓',
    'pending_orders': '挂单',
    'history': '历史',
    'no_holder_positions': '暂无持仓',
    'no_pending_orders': '暂无挂单',
    'no_history_yet': '暂无历史记录',
    'open_price_title': '开仓价',
    'last_price_title': '最新价',
    'take_profit': '止盈',
    'stop_loss': '止损',
    'chart': '图表',
    'stop_loss_and_take_profit': '止盈/止损',
    'close_a_position': '平仓',
    'order_price': '委托价',
    'cancel_order': '撤单',
    'modify_order': '修改',
    'closing_price': '平仓价',
    'one_click_closing_position': '一键平仓',
    'cancel': '取消',
    'confirm_close_position': '确认平仓',
    'pull_up_to_load_more': '上拉加载更多',
    'dkplayer_retry': '重试',
    'order_canceled': '已撤单',
    'order_cancel_failed': '撤单失败',
    'modify_success': '修改成功',
    'stop_loss_and_take_profit_failed': '修改失败',
    'system_busy': '系统繁忙，请稍后再试',
    'close_fail': '平仓失败',
    'all': '全部',
    'last_three_day': '近3天',
    'in_the_three_days': '近3天',
    'seven_days': '最近7天',
    'past_month': '近30天',
    'in_the_past_one_months': '近30天',
    'in_the_past_three_months': '近3月',
    'date': '日期',
    'filtering': '筛选',
    'start_date': '开始日期',
    'end_date': '结束日期',
    'status': '状态',
    'order_status': '订单状态',
    'finished': '已成交',
    'already_transacted': '已成交',
    'reversed': '已撤销',
    'revoked': '已撤销',
    'direction': '方向',
    'buy': '买入',
    'sell': '卖出',
    'stock_long': '买入',
    'stock_short': '卖出',
    'product': '品种',
    'reset': '重置',
    'confirm': '确定',
    'confirm_other': '确认',
    'trade_account': '交易账户',
    'hand': '手',
    'order_tracking_sign': '跟单',
    'bring_single': '带单',
    'real_account': '真实账户',
    'simulation_account': '模拟账户',
    'binary_options_account': '期权账户',
    'trader_account': '交易员账户',
    'account_load_failed': '账户数据加载失败',
    'positions_load_failed': '持仓加载失败',
    'pending_load_failed': '挂单加载失败',
    'history_load_failed': '历史加载失败',
    'batch_close_failed': '批量平仓失败',
  };

  bool _isLoading = true;
  bool _isAccountExpanded = false;
  bool _batchMode = false;
  bool _batchClosing = false;
  bool _pendingLoadingMore = false;
  bool _historyLoadingMore = false;

  String? _accountError;
  String? _positionError;
  String? _pendingError;
  String? _historyError;

  Map<String, dynamic>? _accountData;
  List<Map<String, dynamic>> _positions = [];
  List<Map<String, dynamic>> _pendingOrders = [];
  List<Map<String, dynamic>> _historyOrders = [];
  final Set<String> _selectedPositionIds = {};

  int _positionTotal = -1;
  int _pendingTotal = -1;
  int _pendingPage = 0;
  int _historyPage = 0;
  bool _pendingHasMore = false;
  bool _historyHasMore = false;
  TradeAccountDetailLabels get _detailLabels =>
      TradeAccountDetailLabels(_localized);

  DateTime? _historyStartDate;
  DateTime? _historyEndDate;
  int _historyState = 0;
  int _historyDirection = 0;
  Set<String> _historySelectedSymbols = {};
  List<String> _historySymbols = [];

  String _balance = '--';
  String _equity = '--';
  String _positionProfit = '--';
  String _freeMargin = '--';
  String _usedMargin = '--';
  String _marginLevel = '--';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _resolveInitialIndex(),
    );
    _tabController.addListener(_onTabChanged);

    if (!ref.read(userStateProvider).isLogin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.push('/login');
      });
      return;
    }

    _wsSub = ref
        .read(marketWebSocketProvider)
        .messageStream
        .listen(_onWsMessage);
    _accountChangedListener = () {
      if (!mounted || !ref.read(userStateProvider).isLogin) return;
      unawaited(_loadAccount(showError: false));
      unawaited(_reloadVisibleTab(showBlocking: false));
    };
    EventBus().on(EventBus.accountChanged, _accountChangedListener!);
    _loadData();
    unawaited(_loadHistorySymbols());
    _accountTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _loadAccount(showError: false),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode = stLanguageCodeOfContext(context);
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    final token = ++_languageLoadToken;
    loadStLocalizedTextMap(context, ref, _fallbackText).then((entries) {
      if (!mounted || token != _languageLoadToken) return;
      setState(() => _localized = entries);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!mounted || !ref.read(userStateProvider).isLogin) return;
    _loadAccount(showError: false);
    _reloadVisibleTab(showBlocking: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final accountChangedListener = _accountChangedListener;
    if (accountChangedListener != null) {
      EventBus().off(EventBus.accountChanged, accountChangedListener);
    }
    _accountTimer?.cancel();
    _wsSub?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  int _resolveInitialIndex() {
    final explicit = widget.initialTab;
    if (explicit != null && explicit >= 0 && explicit <= 2) return explicit;
    if (widget.fromType == 2) return _ProfileTab.pending.index;
    return _ProfileTab.position.index;
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (mounted) setState(() {});
    _reloadVisibleTab(showBlocking: false);
  }

  Future<void> _reloadVisibleTab({required bool showBlocking}) async {
    switch (_ProfileTab.values[_tabController.index]) {
      case _ProfileTab.position:
        await _loadPositions(showBlocking: showBlocking);
      case _ProfileTab.pending:
        await _loadPending(reset: true, showBlocking: showBlocking);
      case _ProfileTab.history:
        await _loadHistory(reset: true, showBlocking: showBlocking);
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadAccount(showError: true),
      _loadPositions(showBlocking: false),
      _loadPending(reset: true, showBlocking: false),
    ]);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (_tabController.index == _ProfileTab.history.index) {
      unawaited(_loadHistory(reset: true, showBlocking: false));
    }
  }

  Future<void> _loadAccount({required bool showError}) async {
    try {
      final stService = ref.read(stServiceProvider);
      final current = await stService.getCurrentTransAccount();
      final data = _mapFromEnvelope(current);
      final group = await stService.getTransactionGroupDetail();
      final groupData = _mapFromEnvelope(group);
      final ratios = groupData['margin_ratio_list'];
      if (ratios is List && ratios.isNotEmpty && ratios.first is Map) {
        ref
            .read(userStateProvider.notifier)
            .updateTransactionAccounts(Map<String, dynamic>.from(ratios.first));
      }
      if (!mounted) return;
      setState(() {
        _accountData = data;
        _balance = _pickString(data, const ['balance']) ?? '--';
        _equity =
            _pickString(data, const ['equity', 'account_equity']) ?? _balance;
        _positionProfit =
            _pickString(data, const ['profit', 'pnl']) ?? _positionProfit;
        _freeMargin =
            _pickString(data, const ['margin_free', 'free_margin']) ?? '--';
        _usedMargin =
            _pickString(data, const ['margin_used', 'used_margin', 'margin']) ??
            '--';
        _marginLevel =
            _pickString(data, const ['margin_level', 'marginLevel']) ?? '--';
        _accountError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _accountError = null);
      if (showError) _showSnack(_t('account_load_failed'), isError: true);
    }
  }

  Future<void> _loadPositions({required bool showBlocking}) async {
    try {
      final raw = await ref.read(stServiceProvider).getPositions();
      final list = raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
      var totalProfit = 0.0;
      var totalNight = 0.0;
      for (final item in list) {
        totalProfit += _toDouble(item['profit'] ?? item['pnl']);
        totalNight += _toDouble(item['overnight_interest']);
      }
      if (!mounted) return;
      setState(() {
        _positions = list;
        _positionTotal = list.length;
        _positionProfit = totalProfit.toStringAsFixed(2);
        final balanceValue = _toNullableDouble(_balance);
        final used = _toNullableDouble(_usedMargin);
        if (balanceValue != null) {
          final equity = balanceValue + totalProfit + totalNight;
          _equity = equity.toStringAsFixed(2);
          if (used != null) {
            _freeMargin = (equity - used).toStringAsFixed(2);
            _marginLevel = used > 0
                ? '${(equity / used * 100).toStringAsFixed(1)}%'
                : '--';
          }
        }
        _positionError = null;
        _selectedPositionIds.removeWhere(
          (id) => !list.any((item) => _orderId(item) == id),
        );
      });
      final ws = ref.read(marketWebSocketProvider);
      for (final symbol
          in list.map(_symbol).where((s) => s.isNotEmpty).toSet()) {
        ws.sendEnterTransactionPage(symbol);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _positions = [];
        _positionTotal = 0;
        _positionError = null;
        _selectedPositionIds.clear();
      });
      if (showBlocking) _showSnack(_t('positions_load_failed'), isError: true);
    }
  }

  Future<void> _loadPending({
    required bool reset,
    required bool showBlocking,
  }) async {
    if (!reset && (_pendingLoadingMore || !_pendingHasMore)) return;
    if (!reset) setState(() => _pendingLoadingMore = true);
    try {
      final page = reset ? 0 : _pendingPage + 1;
      final result = await ref
          .read(stServiceProvider)
          .getPendingOrdersWithTotal(
            offset: page * _pageSize,
            limit: _pageSize,
          );
      final batch = result.orders
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
      if (!mounted) return;
      setState(() {
        if (reset) {
          _pendingOrders = batch;
        } else {
          _pendingOrders.addAll(batch);
        }
        _pendingPage = page;
        _pendingTotal = result.total;
        _pendingHasMore = _pendingOrders.length < result.total;
        _pendingLoadingMore = false;
        _pendingError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (reset) {
          _pendingOrders = [];
          _pendingTotal = 0;
          _pendingPage = 0;
          _pendingHasMore = false;
        }
        _pendingLoadingMore = false;
        _pendingError = null;
      });
      if (showBlocking) _showSnack(_t('pending_load_failed'), isError: true);
    }
  }

  Future<void> _loadHistory({
    required bool reset,
    required bool showBlocking,
  }) async {
    if (!reset && (_historyLoadingMore || !_historyHasMore)) return;
    if (!reset) setState(() => _historyLoadingMore = true);
    try {
      final page = reset ? 0 : _historyPage + 1;
      final timezone = ref.read(userStateProvider).selectedTimeZone;
      final start = _historyStartDate == null
          ? null
          : iosStartOfDaySeconds(_historyStartDate!, timezone: timezone);
      final end = _historyEndDate == null
          ? null
          : iosEndExclusiveSeconds(_historyEndDate!, timezone: timezone);
      final status = _historyState == 0 ? null : '$_historyState';
      final direction = _historyDirection == 0
          ? null
          : '${_historyDirection - 1}';
      final raw = await ref
          .read(stServiceProvider)
          .getHistoryOrders(
            symbols: _historySelectedSymbols.toList(),
            offset: page * _pageSize,
            limit: _pageSize,
            startTime: start,
            endTime: end,
            status: status,
            direction: direction,
          );
      final batch = raw
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
      if (!mounted) return;
      setState(() {
        if (reset) {
          _historyOrders = batch;
        } else {
          _historyOrders.addAll(batch);
        }
        _historyPage = page;
        _historyHasMore = batch.length >= _pageSize;
        _historyLoadingMore = false;
        _historyError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (reset) {
          _historyOrders = [];
          _historyPage = 0;
          _historyHasMore = false;
        }
        _historyLoadingMore = false;
        _historyError = null;
      });
      if (showBlocking) _showSnack(_t('history_load_failed'), isError: true);
    }
  }

  Future<void> _loadHistorySymbols() async {
    try {
      final raw = await ref.read(stServiceProvider).getTradeSymbols(type: 2);
      final symbols = raw
          .whereType<Map>()
          .map(
            (item) =>
                item['symbol']?.toString() ??
                item['title']?.toString() ??
                item['name']?.toString() ??
                '',
          )
          .where((item) => item.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() => _historySymbols = symbols);
    } catch (_) {
      if (!mounted) return;
      setState(() => _historySymbols = const []);
    }
  }

  void _onWsMessage(MarketWSMessage msg) {
    if (msg.type != 'TRANSACTION_UPDATE_SYMBOL_PRICE' &&
        msg.type != 'UPDATE_SELL_AND_BUY') {
      if (msg.type == 'ORDER_DEAL') {
        unawaited(_loadPositions(showBlocking: false));
        unawaited(_loadPending(reset: true, showBlocking: false));
      }
      return;
    }
    final symbol = msg.data['symbol']?.toString() ?? '';
    if (symbol.isEmpty) return;
    var touched = false;
    void update(Map<String, dynamic> order, bool pending) {
      if (_symbol(order) != symbol) return;
      final liveUpdate = TradeOrderLiveUpdate.fromMarketMessage(
        order: order,
        message: msg,
        pending: pending,
      );
      if (liveUpdate == null) return;
      order.addAll(liveUpdate);
      EventBus().emitData(
        EventBus.tradeActionViewRefresh,
        Map<String, dynamic>.from(order),
      );
      touched = true;
    }

    for (final order in _positions) {
      update(order, false);
    }
    for (final order in _pendingOrders) {
      update(order, true);
    }
    if (touched && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final riseFall = ref.watch(
      userStateProvider.select((s) => s.riseAndFallType),
    );
    CardTool.setRiseAndFallType(riseFall);
    final content = Scaffold(
      backgroundColor: _profileBgOf(context),
      appBar: _buildProfileAppBar(),
      body: _isLoading
          ? const Center(child: STLoadAnimationView())
          : Column(
              children: [
                _buildAccountHeader(),
                _buildLedgerTabs(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPositionTab(),
                      _buildPendingTab(),
                      _buildHistoryTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
    if (!_returnsToTradeHomeOnBack) return content;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: content,
    );
  }

  bool get _returnsToTradeHomeOnBack =>
      widget.fromType == 1 || widget.fromType == 2 || widget.fromType == 5;

  void _handleBack() {
    if (_returnsToTradeHomeOnBack) {
      try {
        context.go('/?tab=trade');
      } catch (_) {
        Navigator.of(context).maybePop();
      }
      return;
    }
    Navigator.of(context).maybePop();
  }

  PreferredSizeWidget _buildProfileAppBar() {
    return AppBar(
      backgroundColor: _surfaceOf(context),
      foregroundColor: _primaryTextOf(context),
      surfaceTintColor: _surfaceOf(context),
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 44,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 24),
        onPressed: _handleBack,
      ),
      title: _buildAccountTitle(),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Center(child: _buildSwitchAccountPill()),
        ),
      ],
    );
  }

  Widget _buildAccountTitle() {
    return RichText(
      key: const ValueKey('trade_account_profile_title'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      text: TextSpan(
        text: _accountTitle,
        style: TextStyle(
          color: _primaryTextOf(context),
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 19 / 18,
        ),
        children: [
          if (_accountTail.isNotEmpty)
            TextSpan(
              text: '(**$_accountTail)',
              style: TextStyle(
                color: _primaryTextOf(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 19 / 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSwitchAccountPill() {
    return InkWell(
      key: const ValueKey('trade_account_switch_pill'),
      borderRadius: BorderRadius.circular(27),
      onTap: () {
        if (!_requireLogin()) return;
        context.push('/mine/accountmanager');
      },
      child: Container(
        width: 63,
        height: 24,
        decoration: BoxDecoration(
          color: _profileBgOf(context),
          borderRadius: BorderRadius.circular(27),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _t('switch_account'),
              style: TextStyle(
                fontSize: 12,
                height: 14 / 12,
                color: _primaryTextOf(context),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.swap_vert_rounded,
              size: 14,
              color: _primaryTextOf(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountHeader() {
    final currency = _pickString(_accountData, const ['currency']) ?? 'USD';
    return Container(
      width: double.infinity,
      color: _profileBgOf(context),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Column(
        children: [
          if (_accountError != null) _errorText(_accountError!),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_t('account_equity')}($currency)',
                style: const TextStyle(fontSize: 12, color: _mutedText),
              ),
              Container(
                width: 1,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: _lineColor,
              ),
              Text(
                '${_t('profit_and_loss')}($currency)',
                style: const TextStyle(fontSize: 12, color: _mutedText),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _formatMoney(_equity),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                width: 1,
                height: 24,
                margin: const EdgeInsets.symmetric(horizontal: 18),
                color: _lineColor,
              ),
              Text(
                _formatProfit(_positionProfit),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _moneyColor(_positionProfit),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _isAccountExpanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _miniInfo(
                              _t('free_margin'),
                              _formatMoney(_freeMargin),
                            ),
                            _miniInfo(
                              _t('occupied_security_deposit'),
                              _formatMoney(_usedMargin),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _miniInfo(_t('balance'), _formatMoney(_balance)),
                            _miniInfo(
                              _t('margin_level'),
                              _formatMarginLevel(_marginLevel),
                              trailing: IconButton(
                                key: const ValueKey(
                                  'trade_account_margin_help',
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 24,
                                  height: 24,
                                ),
                                icon: const Icon(
                                  Icons.help_outline,
                                  size: 18,
                                  color: _mutedText,
                                ),
                                onPressed: () => TradeMarginHelpSheet.showHelp(
                                  context,
                                  ref,
                                  marginLevelDisplay: _formatMarginLevel(
                                    _marginLevel,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _headerAction(_t('top_up_pay'), () {
                              if (_requireLogin()) {
                                _openDepositWithPreflight();
                              }
                            }),
                            const SizedBox(width: 18),
                            _headerAction(
                              _t('new_order'),
                              _newOrder,
                              primary: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : const SizedBox(height: 20),
          ),
          GestureDetector(
            key: const ValueKey('trade_account_expand'),
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                setState(() => _isAccountExpanded = !_isAccountExpanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                _isAccountExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: _mutedText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniInfo(String label, String value, {Widget? trailing}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: _secondaryTextOf(context),
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: _primaryTextOf(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerAction(
    String label,
    VoidCallback onTap, {
    bool primary = false,
  }) {
    return SizedBox(
      width: 83,
      height: 26,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: primary
              ? const Color(0xFF00B57A)
              : _mutedBlockOf(context),
          foregroundColor: primary ? Colors.white : _primaryTextOf(context),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildLedgerTabs() {
    return Container(
      key: const ValueKey('trade_account_profile_tabs'),
      height: 44.5,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surfaceOf(context),
        border: Border(
          bottom: BorderSide(color: _dividerOf(context), width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 15),
          _ledgerTab(0, _tabTitle(_t('positions'), _positionTotal)),
          const SizedBox(width: 24),
          _ledgerTab(1, _tabTitle(_t('pending_orders'), _pendingTotal)),
          const SizedBox(width: 24),
          _ledgerTab(2, _t('history')),
        ],
      ),
    );
  }

  Widget _ledgerTab(int index, String label) {
    final selected = _tabController.index == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_tabController.index == index) return;
        _tabController.animateTo(index);
        setState(() {});
        unawaited(_reloadVisibleTab(showBlocking: false));
      },
      child: SizedBox(
        height: 44,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                height: 18 / 16,
                color: selected
                    ? _primaryTextOf(context)
                    : _ledgerUnselectedTextOf(context),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 4),
            DecoratedBox(
              key: ValueKey('trade_account_profile_tab_indicator_$index'),
              decoration: BoxDecoration(
                color: selected ? _tabIndicatorGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const SizedBox(width: 13, height: 3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionTab() {
    if (_positionError != null && _positions.isEmpty) {
      return _errorView(
        _positionError!,
        () => _loadPositions(showBlocking: true),
      );
    }
    if (_positions.isEmpty) {
      return STPullRefresh(
        onRefresh: () => _loadPositions(showBlocking: false),
        child: TradeNoRecordsEmpty(
          message: _t('no_holder_positions'),
          height: 271,
          scrollable: true,
        ),
      );
    }
    final showOneKeyClose =
        !_batchMode && ref.watch(userStateProvider).oneKeyClose;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              STPullRefresh(
                onRefresh: () => _loadPositions(showBlocking: false),
                child: ListView.separated(
                  padding: EdgeInsets.only(bottom: safeBottom),
                  itemCount: _positions.length,
                  separatorBuilder: (_, __) => _accountDetailSeparator(),
                  itemBuilder: (context, index) {
                    final item = _positions[index];
                    final id = _orderId(item);
                    return _orderCard(
                      order: item,
                      type: TradeAccountDetailCellType.position,
                      leading: _batchMode
                          ? Checkbox(
                              value: _selectedPositionIds.contains(id),
                              onChanged: (_) => _toggleSelectedPosition(id),
                            )
                          : null,
                      fields: [
                        _field(
                          _t('open_price_title'),
                          tradeAccountPositionOpenPriceText(item),
                          alignment: _FieldAlignment.start,
                        ),
                        _field(
                          _t('last_price_title'),
                          tradeAccountCurrentPriceText(item),
                          alignment: _FieldAlignment.center,
                        ),
                        _field(
                          _t('take_profit'),
                          tradeAccountTakeProfitText(item),
                          alignment: _FieldAlignment.center,
                        ),
                        _field(
                          _t('stop_loss'),
                          tradeAccountStopLossText(item),
                          alignment: _FieldAlignment.end,
                        ),
                      ],
                      trailing: Text(
                        tradeAccountDetailProfitText(
                          item['profit'] ?? item['pnl'],
                        ),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _moneyColor(item['profit'] ?? item['pnl']),
                        ),
                      ),
                      actions: _batchMode
                          ? const SizedBox.shrink()
                          : _actionRow([
                              _actionButton(
                                _t('chart'),
                                () => _openChart(item),
                              ),
                              _actionButton(
                                _t('stop_loss_and_take_profit'),
                                () => _editPosition(item),
                              ),
                              _actionButton(
                                _t('close_a_position'),
                                () => _closePosition(item),
                              ),
                            ]),
                      onTap: _batchMode
                          ? () => _toggleSelectedPosition(id)
                          : () => _openDetail(item, _ProfileTab.position),
                    );
                  },
                ),
              ),
              if (showOneKeyClose)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: _oneKeyCloseBottomOffset + safeBottom,
                  child: Center(child: _oneKeyCloseButton()),
                ),
            ],
          ),
        ),
        if (_batchMode) SafeArea(top: false, child: _buildBatchBar()),
      ],
    );
  }

  Widget _buildPendingTab() {
    if (_pendingError != null && _pendingOrders.isEmpty) {
      return _errorView(_pendingError!, () {
        return _loadPending(reset: true, showBlocking: true);
      });
    }
    if (_pendingOrders.isEmpty) {
      return STPullRefresh(
        onRefresh: () => _loadPending(reset: true, showBlocking: false),
        child: TradeNoRecordsEmpty(
          message: _t('no_pending_orders'),
          height: 271,
          scrollable: true,
        ),
      );
    }
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 120) {
          _loadPending(reset: false, showBlocking: false);
        }
        return false;
      },
      child: STPullRefresh(
        onRefresh: () => _loadPending(reset: true, showBlocking: false),
        child: ListView.separated(
          padding: EdgeInsets.only(bottom: safeBottom),
          itemCount: _pendingOrders.length + 1,
          separatorBuilder: (_, __) => _accountDetailSeparator(),
          itemBuilder: (context, index) {
            if (index == _pendingOrders.length) {
              return _listFooter(_pendingLoadingMore, _pendingHasMore);
            }
            final item = _pendingOrders[index];
            return _orderCard(
              order: item,
              type: TradeAccountDetailCellType.pending,
              fields: [
                _field(
                  _t('order_price'),
                  tradeAccountPendingPriceText(item),
                  alignment: _FieldAlignment.start,
                ),
                _field(
                  _t('last_price_title'),
                  tradeAccountCurrentPriceText(item),
                  alignment: _FieldAlignment.center,
                ),
                _field(
                  _t('take_profit'),
                  tradeAccountTakeProfitText(item),
                  alignment: _FieldAlignment.center,
                ),
                _field(
                  _t('stop_loss'),
                  tradeAccountStopLossText(item),
                  alignment: _FieldAlignment.end,
                ),
              ],
              trailing: Text(
                tradeAccountPendingTrailingTimeText(item),
                style: const TextStyle(fontSize: 10, color: Color(0xFF9A9DA2)),
              ),
              actions: _actionRow([
                _actionButton(
                  _t('cancel_order'),
                  () => _cancelPendingOrder(item),
                ),
                _actionButton(
                  _t('modify_order'),
                  () => _editPendingOrder(item),
                ),
              ]),
              onTap: () => _openDetail(item, _ProfileTab.pending),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Column(
      children: [
        Container(
          key: const ValueKey('trade_account_history_filter_bar'),
          height: 33,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: _surfaceOf(context),
            border: Border(bottom: BorderSide(color: _dividerOf(context))),
          ),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: _showHistoryQuickDateFilter,
                style: TextButton.styleFrom(
                  foregroundColor: _primaryTextOf(context),
                ),
                icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                label: Text(_historyDateTitle),
              ),
              const Spacer(),
              IconButton(
                color: _primaryTextOf(context),
                icon: const Icon(Icons.filter_list, size: 20),
                onPressed: _showHistoryAllFilter,
              ),
            ],
          ),
        ),
        Expanded(child: _buildHistoryBody()),
      ],
    );
  }

  Widget _buildHistoryBody() {
    if (_historyError != null && _historyOrders.isEmpty) {
      return _errorView(_historyError!, () {
        return _loadHistory(reset: true, showBlocking: true);
      });
    }
    if (_historyOrders.isEmpty) {
      return STPullRefresh(
        onRefresh: () => _loadHistory(reset: true, showBlocking: false),
        child: TradeNoRecordsEmpty(
          message: _t('no_history_yet'),
          height: 271,
          scrollable: true,
        ),
      );
    }
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 120) {
          _loadHistory(reset: false, showBlocking: false);
        }
        return false;
      },
      child: STPullRefresh(
        onRefresh: () => _loadHistory(reset: true, showBlocking: false),
        child: ListView.separated(
          padding: EdgeInsets.only(bottom: safeBottom),
          itemCount: _historyOrders.length + 1,
          separatorBuilder: (_, __) => _accountDetailSeparator(),
          itemBuilder: (context, index) {
            if (index == _historyOrders.length) {
              return _listFooter(_historyLoadingMore, _historyHasMore);
            }
            final item = _historyOrders[index];
            return _orderCard(
              order: item,
              type: TradeAccountDetailCellType.position,
              fields: [
                _field(
                  _t('open_price_title'),
                  _formatPrice(item['open_price'] ?? item['price']),
                ),
                _field(
                  _t('closing_price'),
                  _formatPrice(item['close_price'] ?? item['current_price']),
                ),
                _field(
                  _t('take_profit'),
                  _dashIfMinusOne(item['target_profit'] ?? item['take_profit']),
                ),
                _field(
                  _t('stop_loss'),
                  _dashIfMinusOne(item['stop_loss'] ?? item['stopLosss']),
                ),
              ],
              trailing: Text(
                _formatProfit(item['profit'] ?? item['pnl']),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _moneyColor(item['profit'] ?? item['pnl']),
                ),
              ),
              onTap: () => _openDetail(item, _ProfileTab.history),
            );
          },
        ),
      ),
    );
  }

  Widget _orderCard({
    required Map<String, dynamic> order,
    required TradeAccountDetailCellType type,
    required List<Widget> fields,
    required Widget trailing,
    Widget? leading,
    Widget? actions,
    VoidCallback? onTap,
  }) {
    final isBuy = _isBuy(order);
    final directionColor = isBuy
        ? CardTool.priceColor(1)
        : CardTool.priceColor(-1);
    final sign = tradeAccountDetailSign(order);
    final alias = tradeAccountDetailAlias(order);
    return InkWell(
      onTap: onTap,
      child: Container(
        color: _surfaceOf(context),
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (leading != null) ...[leading, const SizedBox(width: 8)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              tradeAccountDetailTitle(order, type),
                              style: TextStyle(
                                color: _primaryTextOf(context),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (alias.isNotEmpty) ...[
                            const SizedBox(width: 5),
                            Text(
                              alias,
                              style: TextStyle(
                                fontSize: 10,
                                color: _secondaryTextOf(context),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            height: 16,
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: directionColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              tradeAccountDetailDirectionText(
                                order,
                                labels: _detailLabels,
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                color: directionColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            height: 17,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _mutedBlockOf(context),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              tradeAccountDetailLotText(
                                order,
                                labels: _detailLabels,
                              ),
                              style: TextStyle(
                                color: _secondaryTextOf(context),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (sign != null) ...[
                            const SizedBox(width: 5),
                            _tradeSignChip(sign),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
            const SizedBox(height: 12),
            Row(children: fields),
            if (actions != null) ...[const SizedBox(height: 14), actions],
          ],
        ),
      ),
    );
  }

  Widget _oneKeyCloseButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _batchMode = true),
      child: Container(
        key: const ValueKey('trade_account_one_key_close'),
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.playlist_add_check, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              _t('one_click_closing_position'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tradeSignChip(TradeAccountDetailSign sign) {
    final isOrigin = sign == TradeAccountDetailSign.origin;
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isOrigin ? Colors.black : const Color(0xFF00B57A),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        tradeAccountDetailSignText(sign, labels: _detailLabels),
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
    );
  }

  Widget _field(
    String label,
    String value, {
    _FieldAlignment alignment = _FieldAlignment.start,
  }) {
    final crossAxisAlignment = switch (alignment) {
      _FieldAlignment.start => CrossAxisAlignment.start,
      _FieldAlignment.center => CrossAxisAlignment.center,
      _FieldAlignment.end => CrossAxisAlignment.end,
    };
    final textAlign = switch (alignment) {
      _FieldAlignment.start => TextAlign.left,
      _FieldAlignment.center => TextAlign.center,
      _FieldAlignment.end => TextAlign.right,
    };
    return Expanded(
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Text(
            label,
            textAlign: textAlign,
            style: TextStyle(fontSize: 12, color: _secondaryTextOf(context)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _primaryTextOf(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow(List<Widget> buttons) {
    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          Expanded(child: buttons[i]),
          if (i != buttons.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }

  Widget _actionButton(String label, VoidCallback onTap) {
    return SizedBox(
      height: 28,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: _mutedBlockOf(context),
          foregroundColor: _primaryTextOf(context),
          side: BorderSide.none,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _accountDetailSeparator() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 15,
      endIndent: 15,
      color: _profileBgOf(context),
    );
  }

  Widget _buildBatchBar() {
    return Container(
      key: const ValueKey('trade_account_batch_bar'),
      color: _profileBgOf(context),
      padding: const EdgeInsets.fromLTRB(16, 7, 17, 7),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: _toggleAllPositions,
            icon: Icon(
              _selectedPositionIds.length == _positions.length
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
            ),
            label: Text(
              '${_t('all')}${_selectedPositionIds.length}/${_positions.length}',
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 90,
            height: 42,
            child: ElevatedButton(
              onPressed: _cancelBatchMode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFECECEC),
                foregroundColor: Colors.black,
                elevation: 0,
              ),
              child: Text(_t('cancel')),
            ),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: 163,
            height: 42,
            child: ElevatedButton(
              onPressed: _selectedPositionIds.isEmpty || _batchClosing
                  ? null
                  : _confirmBatchClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B57A),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(
                  0xFF00B57A,
                ).withValues(alpha: 0.2),
                elevation: 0,
              ),
              child: _batchClosing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_t('confirm_close_position')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listFooter(bool loading, bool hasMore) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!hasMore) {
      return const SizedBox(height: 16);
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(child: Text(_t('pull_up_to_load_more'))),
    );
  }

  Widget _errorView(String message, Future<void> Function() retry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: const TextStyle(color: Color(0xFFF95959))),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: retry, child: Text(_t('dkplayer_retry'))),
        ],
      ),
    );
  }

  Widget _errorText(String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(message, style: const TextStyle(color: Color(0xFFF95959))),
    );
  }

  Future<void> _cancelPendingOrder(Map<String, dynamic> order) async {
    if (!_requireLogin()) return;
    final orderId = _orderId(order);
    final confirmed = await showTradeCancelOrderDialog(
      context: context,
      orderId: orderId,
    );
    if (confirmed != true || !mounted) return;
    try {
      final oid = int.tryParse(orderId);
      await ref.read(stServiceProvider).deleteOrder({
        'symbol': _symbol(order),
        'order_id': oid ?? orderId,
      });
      _showSnack(_t('order_canceled'));
      await _loadPending(reset: true, showBlocking: false);
      await _loadAccount(showError: false);
    } catch (e) {
      if (mounted) {
        _showSnack(
          '${_t('order_cancel_failed')}：${stUserVisibleErrorMessage(e)}',
          isError: true,
        );
      }
    }
  }

  Future<void> _editPendingOrder(Map<String, dynamic> order) async {
    if (!_requireLogin()) return;
    final result = await _showPendingEditDialog(order);
    if (result == null || !mounted) return;
    try {
      await ref.read(stServiceProvider).editPendingOrder(result);
      _showSnack(_t('modify_success'));
      await _loadPending(reset: true, showBlocking: false);
    } catch (e) {
      if (mounted) {
        _showSnack(
          '${_t('stop_loss_and_take_profit_failed')}：${stUserVisibleErrorMessage(e)}',
          isError: true,
        );
      }
    }
  }

  Future<void> _editPosition(Map<String, dynamic> order) async {
    if (!_requireLogin()) return;
    final result = await _showPositionEditDialog(order);
    if (result == null || !mounted) return;
    try {
      await ref.read(stServiceProvider).editPosition(result);
      _showSnack(_t('modify_success'));
      await _loadPositions(showBlocking: false);
      await _loadAccount(showError: false);
    } catch (e) {
      if (mounted) {
        _showSnack(
          '${_t('stop_loss_and_take_profit_failed')}：${stUserVisibleErrorMessage(e)}',
          isError: true,
        );
      }
    }
  }

  Future<void> _closePosition(Map<String, dynamic> order) async {
    if (!_requireLogin()) return;
    final confirmed = await showTradeClosePositionDialog(
      context: context,
      symbol: _symbol(order),
      lots: _lots(order),
    );
    if (confirmed != true || !mounted) return;
    try {
      final response = await ref.read(stServiceProvider).closePosition({
        'symbol': _symbol(order),
        'direction': _directionInt(order),
        'lots': _lots(order),
        'position_id': int.tryParse(_orderId(order)) ?? _orderId(order),
      });
      if (response['code'] == 200162) {
        _showSnack(_t('system_busy'), isError: true);
      } else {
        EventBus().emit(EventBus.tradePositionListRefresh);
        if (mounted) {
          context.push(
            '/trade/action_result?type=close&progress=1',
            extra: _tradeActionResultPayload(response, order),
          );
        }
        await _loadPositions(showBlocking: false);
        await _loadAccount(showError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
          '${_t('close_fail')}：${stUserVisibleErrorMessage(e)}',
          isError: true,
        );
      }
    }
  }

  Future<void> _confirmBatchClose() async {
    final selected = _positions
        .where((item) => _selectedPositionIds.contains(_orderId(item)))
        .toList();
    final payloadPositions = selected
        .map(
          (item) => <String, dynamic>{
            'symbol': _symbol(item),
            'direction': _directionInt(item),
            'lots': _lots(item),
            'position_id': int.tryParse(_orderId(item)) ?? _orderId(item),
          },
        )
        .toList();
    if (payloadPositions.isEmpty || _batchClosing) return;
    setState(() => _batchClosing = true);
    try {
      final response = await ref.read(stServiceProvider).batchClosePositions({
        'positions': payloadPositions,
      });
      final closeOut = _parseBatchCloseOutResponse(response, selected);
      if (closeOut.items.isEmpty || closeOut.items.length == closeOut.failed) {
        if (mounted) {
          setState(() => _batchClosing = false);
          _showSnack(_t('system_busy'), isError: true);
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _batchClosing = false;
        _batchMode = false;
        _selectedPositionIds.clear();
      });
      EventBus().emit(EventBus.tradePositionListRefresh);
      context.push(
        '/trade/closeout_result',
        extra: <String, dynamic>{
          'items': closeOut.items,
          'failedCount': closeOut.failed,
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _batchClosing = false);
        _showSnack(
          '${_t('batch_close_failed')}：${stUserVisibleErrorMessage(e)}',
          isError: true,
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _showPositionEditDialog(
    Map<String, dynamic> order,
  ) async {
    return showTradePositionStopLossPayloadSheet(
      context: context,
      order: order,
    );
  }

  Future<Map<String, dynamic>?> _showPendingEditDialog(
    Map<String, dynamic> order,
  ) async {
    return showTradePendingEditPayloadSheet(context: context, order: order);
  }

  Future<void> _showHistoryQuickDateFilter() async {
    final now = DateTime.now();
    final selectedIndex = _historyDatePresetIndex(
      _historyStartDate,
      _historyEndDate,
      now,
    );
    final picked = await showModalBottomSheet<DateTimeRange?>(
      context: context,
      backgroundColor: _surfaceOf(context),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 72,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFECECEC),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 27),
            Text(
              _t('date'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _primaryTextOf(context),
              ),
            ),
            const SizedBox(height: 22),
            for (var i = 0; i < _historyDatePresets.length; i++)
              _historyDateOptionTile(
                ctx,
                _t(_historyDatePresets[i].labelKey),
                selected: selectedIndex == i,
                range: _historyDatePresets[i].range(now),
              ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _historyStartDate = picked?.start;
      _historyEndDate = picked?.end;
    });
    await _loadHistory(reset: true, showBlocking: false);
  }

  Widget _historyDateOptionTile(
    BuildContext sheetContext,
    String label, {
    required bool selected,
    required DateTimeRange? range,
  }) {
    return InkWell(
      onTap: () => Navigator.of(sheetContext).pop(range),
      child: Container(
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 29),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: _dividerOf(context), width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 15, color: _primaryTextOf(context)),
              ),
            ),
            if (selected)
              const Icon(Icons.check, size: 18, color: Color(0xFF4DCB73)),
          ],
        ),
      ),
    );
  }

  Future<void> _showHistoryAllFilter() async {
    final now = DateTime.now();
    final picked = await showModalBottomSheet<_HistoryFilterResult>(
      context: context,
      backgroundColor: _surfaceOf(context),
      isScrollControlled: true,
      builder: (ctx) => _ProfileHistoryFilterSheet(
        now: now,
        languageCode: _languageCode,
        text: _localized,
        initialStartDate: _historyStartDate,
        initialEndDate: _historyEndDate,
        initialState: _historyState,
        initialDirection: _historyDirection,
        initialSymbols: _historySelectedSymbols,
        symbols: _historySymbols,
      ),
    );
    if (!mounted) return;
    if (picked == null) return;
    setState(() {
      _historyStartDate = picked.startDate;
      _historyEndDate = picked.endDate;
      _historyState = picked.state;
      _historyDirection = picked.direction;
      _historySelectedSymbols = picked.symbols;
    });
    await _loadHistory(reset: true, showBlocking: false);
  }

  void _toggleSelectedPosition(String id) {
    if (id.isEmpty) return;
    setState(() {
      if (_selectedPositionIds.contains(id)) {
        _selectedPositionIds.remove(id);
      } else {
        _selectedPositionIds.add(id);
      }
    });
  }

  void _toggleAllPositions() {
    setState(() {
      if (_selectedPositionIds.length == _positions.length) {
        _selectedPositionIds.clear();
      } else {
        _selectedPositionIds
          ..clear()
          ..addAll(_positions.map(_orderId).where((id) => id.isNotEmpty));
      }
    });
  }

  void _cancelBatchMode() {
    setState(() {
      _batchMode = false;
      _batchClosing = false;
      _selectedPositionIds.clear();
    });
  }

  void _openChart(Map<String, dynamic> order) {
    if (!_requireLogin()) return;
    context.push(
      '/market/detail?symbol=${Uri.encodeComponent(_symbol(order))}',
    );
  }

  void _openDetail(Map<String, dynamic> order, _ProfileTab tab) {
    if (!_requireLogin()) return;
    final id = _orderId(order);
    if (id.isEmpty) return;
    final type = switch (tab) {
      _ProfileTab.position => 0,
      _ProfileTab.pending => 1,
      _ProfileTab.history => 2,
    };
    context.push(
      '/trade/orderdetail?orderId=${Uri.encodeComponent(id)}&type=$type',
      extra: <String, dynamic>{'orderInfo': order, 'orderType': type},
    );
  }

  Map<String, dynamic> _tradeActionResultPayload(
    Map<String, dynamic> response,
    Map<String, dynamic> order,
  ) {
    final payload = <String, dynamic>{...response};
    payload['symbol'] = payload['symbol'] ?? _symbol(order);
    payload['symbol_alias'] = payload['symbol_alias'] ?? _symbolAlias(order);
    payload['lots'] = payload['lots'] ?? _lots(order);
    payload['direction'] = payload['direction'] ?? _directionInt(order);
    payload['symbol_group'] =
        payload['symbol_group'] ??
        order['symbol_group'] ??
        order['symbolGroup'];
    return payload;
  }

  ({List<Map<String, dynamic>> items, int failed}) _parseBatchCloseOutResponse(
    Map<String, dynamic> response,
    List<Map<String, dynamic>> selected,
  ) {
    final rawPositions = response['positions'];
    final positions = rawPositions is List ? rawPositions : const <dynamic>[];
    final selectedById = {for (final item in selected) _orderId(item): item};
    var failed = 0;
    final items = <Map<String, dynamic>>[];
    for (final raw in positions) {
      if (raw is! Map) continue;
      final result = Map<String, dynamic>.from(raw);
      final positionId = _pickString(result, const [
        'position_id',
        'positionId',
        'id',
      ]);
      final source = selectedById[positionId] ?? const <String, dynamic>{};
      result['position_id'] = positionId ?? _orderId(source);
      result['symbol'] = result['symbol'] ?? _symbol(source);
      result['symbol_alias'] = result['symbol_alias'] ?? _symbolAlias(source);
      result['lots'] = result['lots'] ?? _lots(source);
      result['direction'] = result['direction'] ?? _directionInt(source);
      final status = result['status'];
      final statusMap = status is Map
          ? Map<String, dynamic>.from(status)
          : null;
      final code = _intValue(statusMap?['code'] ?? result['code']);
      if (code != 0) {
        failed++;
        result['trade_close_result'] = 'failed';
        result['message'] =
            _pickString(statusMap, const ['message']) ??
            _pickString(result, const ['message']) ??
            _t('system_busy');
      }
      items.add(result);
    }
    return (items: items, failed: failed);
  }

  void _newOrder() {
    if (!_requireLogin()) return;
    if (widget.fromType == 3) {
      ref.read(userStateProvider.notifier).updateNeedJumpToTrade(true);
      context.go('/trade');
    } else {
      context.pop();
    }
  }

  Future<void> _openDepositWithPreflight() async {
    await ref
        .read(walletActionHandlerProvider)
        .handleWalletAction(
          context: context,
          action: 'deposit',
          onPassed: () {
            if (mounted) context.push(_depositRoute);
          },
        );
  }

  bool _requireLogin() {
    if (ref.read(userStateProvider).isLogin) return true;
    context.push('/login');
    return false;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    STToast.show(context, message);
  }

  String get _accountTitle {
    final accountType = _nativeAccountTypeTitle(
      _pickString(_accountData, const [
        'account_type',
        'accountType',
        'transaction_account_type',
        'transactionAccountType',
        'type',
        'type_name',
      ]),
    );
    if (accountType != null) return accountType;
    final userType = _nativeAccountTypeTitle(
      ref.read(userStateProvider).transactionAccountType,
    );
    return userType ?? _t('trade_account');
  }

  String? _nativeAccountTypeTitle(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    switch (raw) {
      case '0':
      case '4':
        return _t('real_account');
      case '1':
        return _t('simulation_account');
      case '2':
        return _t('binary_options_account');
      case '3':
        return _t('trader_account');
    }
    if (raw.contains('真实')) return _t('real_account');
    if (raw.contains('模拟')) return _t('simulation_account');
    return raw;
  }

  String get _accountTail {
    final raw =
        _pickString(_accountData, const ['account_id', 'accountId', 'id']) ??
        widget.accountId ??
        '';
    final trimmed = raw.trim();
    if (trimmed.length < 2) return '';
    return trimmed.substring(trimmed.length - 2);
  }

  String get _historyDateTitle {
    if (_historyStartDate == null || _historyEndDate == null) return _t('date');
    final presetIndex = _historyDatePresetIndex(
      _historyStartDate,
      _historyEndDate,
      DateTime.now(),
    );
    if (presetIndex > 0) return _t(_historyDatePresets[presetIndex].labelKey);
    return '${formatIosYmd(_historyStartDate!, languageCode: _languageCode)}-${formatIosYmd(_historyEndDate!, languageCode: _languageCode)}';
  }

  String get _languageCode =>
      languageCodeFromLocale(Localizations.localeOf(context));

  String _tabTitle(String title, int count) =>
      count >= 0 ? '$title($count)' : title;

  String _t(String key) => _localized[key] ?? _fallbackText[key] ?? key;

  Map<String, dynamic> _mapFromEnvelope(Map<String, dynamic> root) {
    final data = root['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return Map<String, dynamic>.from(root);
  }

  String? _pickString(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return null;
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  String _symbol(Map<String, dynamic> order) =>
      _pickString(order, const ['symbol', 'name']) ?? '---';

  String _symbolAlias(Map<String, dynamic> order) =>
      _pickString(order, const ['symbol_alias', 'symbolAlias']) ?? '';

  String _lots(Map<String, dynamic> order) =>
      _pickString(order, const ['set_lot', 'setLot', 'lots', 'volume']) ?? '--';

  String _orderId(Map<String, dynamic> order) =>
      _pickString(order, const ['order_id', 'position_id', 'id']) ?? '';

  int _directionInt(Map<String, dynamic> order) {
    final raw = order['direction'];
    if (raw is num) return raw.toInt();
    final s = raw?.toString().toLowerCase() ?? '';
    if (s == '1' || s == 'sell' || s == 'short') return 1;
    return 0;
  }

  int _intValue(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _isBuy(Map<String, dynamic> order) => _directionInt(order) == 0;

  double _toDouble(dynamic value) => _toNullableDouble(value) ?? 0;

  double? _toNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final cleaned = value.toString().replaceAll(',', '').replaceAll('%', '');
    return double.tryParse(cleaned);
  }

  String _formatMoney(dynamic value) {
    final number = _toNullableDouble(value);
    if (number == null) return '--';
    final fixed = number.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts.first;
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      final remaining = whole.length - i;
      buffer.write(whole[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
    }
    return '${buffer.toString()}.${parts.last}';
  }

  String _formatProfit(dynamic value) {
    final number = _toNullableDouble(value);
    if (number == null) return '--';
    final formatted = _formatMoney(number.abs());
    if (number > 0) return '+$formatted';
    if (number < 0) return '-$formatted';
    return formatted;
  }

  String _formatPrice(dynamic value) {
    final number = _toNullableDouble(value);
    if (number == null) return '--';
    return number.toStringAsFixed(5);
  }

  String _formatMarginLevel(dynamic value) {
    if (value == null || value.toString().isEmpty) return '--';
    final raw = value.toString();
    if (raw == '--') return raw;
    return raw.contains('%') ? raw : '$raw%';
  }

  String _dashIfMinusOne(dynamic value) {
    if (value == null) return '--';
    final s = value.toString();
    if (s == '-1' || s.isEmpty) return '--';
    final number = _toNullableDouble(s);
    if (number != null && number == 0) return '--';
    return s;
  }

  Color _moneyColor(dynamic value) {
    final number = _toDouble(value);
    if (number > 0) return CardTool.priceColor(1);
    if (number < 0) return CardTool.priceColor(-1);
    return const Color(0xFF9A9DA2);
  }
}

class _HistoryDatePreset {
  const _HistoryDatePreset(this.labelKey, this.days);

  final String labelKey;
  final int? days;

  DateTimeRange? range(DateTime now) {
    final d = days;
    if (d == null) return null;
    return DateTimeRange(
      start: iosInclusiveStartDay(d, now: now),
      end: now,
    );
  }
}

const _historyDatePresets = <_HistoryDatePreset>[
  _HistoryDatePreset('all', null),
  _HistoryDatePreset('in_the_three_days', 3),
  _HistoryDatePreset('seven_days', 7),
  _HistoryDatePreset('in_the_past_one_months', 30),
  _HistoryDatePreset('in_the_past_three_months', 90),
];

int _historyDatePresetIndex(DateTime? start, DateTime? end, DateTime now) {
  if (start == null || end == null) return 0;
  final endDay = iosCalendarDay(end);
  if (endDay != iosCalendarDay(now)) return -1;
  for (var i = 1; i < _historyDatePresets.length; i++) {
    final range = _historyDatePresets[i].range(now);
    if (range == null) continue;
    if (iosCalendarDay(start) == iosCalendarDay(range.start)) return i;
  }
  return -1;
}

class _HistoryFilterResult {
  const _HistoryFilterResult({
    this.startDate,
    this.endDate,
    required this.state,
    required this.direction,
    required this.symbols,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final int state;
  final int direction;
  final Set<String> symbols;
}

class _ProfileHistoryFilterSheet extends StatefulWidget {
  const _ProfileHistoryFilterSheet({
    required this.now,
    required this.languageCode,
    required this.text,
    required this.initialState,
    required this.initialDirection,
    required this.initialSymbols,
    required this.symbols,
    this.initialStartDate,
    this.initialEndDate,
  });

  final DateTime now;
  final String languageCode;
  final Map<String, String> text;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final int initialState;
  final int initialDirection;
  final Set<String> initialSymbols;
  final List<String> symbols;

  @override
  State<_ProfileHistoryFilterSheet> createState() =>
      _ProfileHistoryFilterSheetState();
}

class _ProfileHistoryFilterSheetState
    extends State<_ProfileHistoryFilterSheet> {
  late DateTime? _startDate = widget.initialStartDate;
  late DateTime? _endDate = widget.initialEndDate;
  late int _state = widget.initialState;
  late int _direction = widget.initialDirection;
  late Set<String> _symbols = {...widget.initialSymbols};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 15,
          right: 15,
          top: 27,
          bottom: MediaQuery.of(context).padding.bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  _t('filtering'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _sectionTitle(context, _t('date')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _dateButton(
                      context,
                      _startDate,
                      _t('start_date'),
                      () => _pickDate(isStart: true),
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    color: const Color(0xFFD9D9D9),
                  ),
                  Expanded(
                    child: _dateButton(
                      context,
                      _endDate,
                      _t('end_date'),
                      () => _pickDate(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _historyDatePresets.length; i++)
                    _datePresetChip(context, i),
                ],
              ),
              const SizedBox(height: 18),
              _sectionTitle(context, _t('order_status')),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(
                    context,
                    _t('all'),
                    _state == 0,
                    () => setState(() => _state = 0),
                  ),
                  _chip(
                    context,
                    _t('already_transacted'),
                    _state == 1,
                    () => setState(() => _state = 1),
                  ),
                  _chip(
                    context,
                    _t('revoked'),
                    _state == 2,
                    () => setState(() => _state = 2),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _sectionTitle(context, _t('direction')),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(
                    context,
                    _t('all'),
                    _direction == 0,
                    () => setState(() => _direction = 0),
                  ),
                  _chip(
                    context,
                    _t('buy'),
                    _direction == 1,
                    () => setState(() => _direction = 1),
                  ),
                  _chip(
                    context,
                    _t('sell'),
                    _direction == 2,
                    () => setState(() => _direction = 2),
                  ),
                ],
              ),
              if (widget.symbols.isNotEmpty) ...[
                const SizedBox(height: 18),
                _sectionTitle(context, _t('product')),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final symbol in widget.symbols)
                      _chip(context, symbol, _symbols.contains(symbol), () {
                        setState(() {
                          if (!_symbols.add(symbol)) _symbols.remove(symbol);
                        });
                      }, product: true),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                          _state = 0;
                          _direction = 0;
                          _symbols = {};
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: const Color(0xFFECECEC),
                        side: BorderSide.none,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(_t('reset')),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(
                        _HistoryFilterResult(
                          startDate: _startDate,
                          endDate: _endDate,
                          state: _state,
                          direction: _direction,
                          symbols: _symbols,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00B57A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(_t('confirm_other')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: context.adaptiveTextTertiary,
      ),
    );
  }

  Widget _datePresetChip(BuildContext context, int index) {
    final preset = _historyDatePresets[index];
    final selected = switch (preset.days) {
      null => _startDate == null && _endDate == null,
      final days =>
        _startDate != null &&
            _endDate != null &&
            iosCalendarDay(_startDate!) ==
                iosCalendarDay(iosInclusiveStartDay(days, now: widget.now)) &&
            iosCalendarDay(_endDate!) == iosCalendarDay(widget.now),
    };
    return _chip(context, _t(preset.labelKey), selected, () {
      setState(() {
        final range = preset.range(widget.now);
        _startDate = range?.start;
        _endDate = range?.end;
      });
    });
  }

  Widget _chip(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap, {
    bool product = false,
  }) {
    final foreground = selected
        ? const Color(0xFF00B57A)
        : context.adaptiveTextTertiary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: EdgeInsets.only(
          left: product ? 10 : 16,
          right: product ? 14 : 16,
        ),
        decoration: BoxDecoration(
          color: context.adaptiveCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (product) ...[
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF00B57A)
                        : context.adaptiveDivider,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF00B57A),
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
            ],
            Text(label, style: TextStyle(fontSize: 14, color: foreground)),
          ],
        ),
      ),
    );
  }

  Widget _dateButton(
    BuildContext context,
    DateTime? date,
    String placeholder,
    VoidCallback onTap,
  ) {
    final selected = date != null;
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            selected
                ? formatIosYmd(date, languageCode: widget.languageCode)
                : placeholder,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: selected
                  ? context.adaptiveTextPrimary
                  : const Color(0xFFCCCCCC),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            color: selected ? const Color(0xFF00B57A) : const Color(0xFFECECEC),
          ),
        ],
      ),
    );
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
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
      } else {
        _endDate = picked;
        if (_startDate != null && _startDate!.isAfter(picked)) {
          _startDate = picked;
        }
      }
    });
  }

  String _t(String key) =>
      widget.text[key] ?? _AccountProfilePageState._fallbackText[key] ?? key;
}
