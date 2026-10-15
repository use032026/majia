import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/card_tool.dart';
import '../../core/network/market_websocket.dart';
import '../../core/network/st_service.dart';
import '../../core/providers/event_bus.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/router/route_observer.dart';
import '../../core/services/user_preference_prefs.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../core/utils/ios_market_trade_time.dart';
import '../../core/utils/ios_date_range.dart';
import '../market/market_product_picker_sheet.dart';
import 'trade_margin_help_sheet.dart';
import '../../core/models/market_product_model.dart';
import '../../core/models/user_state.dart';
import '../../core/providers/trade_jump_navigation.dart';
import '../../shared/widgets/st_keyboard_actions.dart';
import '../../shared/widgets/st_toast.dart';
import '../../shared/widgets/trade_no_limit_sheet.dart';
import '../../shared/widgets/ios_date_picker_sheet.dart';
import 'trade_account_detail_cell_contract.dart';
import 'trade_account_switcher.dart';
import 'trade_alignment.dart';
import 'trade_action_failed_dialog.dart';
import 'trade_confirm_dialog.dart';
import 'trade_empty_state.dart';
import 'trade_ios_chrome.dart';
import 'trade_margin_display.dart';
import 'trade_order_live_update.dart';
import 'trade_position_action_sheet.dart';
import 'trade_price_mode_sheet.dart';
import 'trade_registration_mode_popup.dart';

/// 交易页色板（对齐 iOS `STTradeController` / `STTradeBuyAndSellView`）：
/// - `STRiseColor`：买入侧强调、主按钮（买方向）
/// - `STFallColor`：卖出侧强调、主按钮（卖方向）
abstract final class _TradeTheme {
  static Color get rise => CardTool.priceColor(1);
  static Color get fall => CardTool.priceColor(-1);
  static const Color labelMuted = Color(0xFF9A9DA2);
  static const Color labelDark = Color(0xFF60656D);
}

/// WebSocket `TRANSACTION_UPDATE_SYMBOL_PRICE` 推送的 bid/ask（对齐 iOS `STTradeSymbolPriceModel`）
class _LiveBidAsk {
  final String bid;
  final String ask;
  const _LiveBidAsk(this.bid, this.ask);
}

/// iOS `STTradeController -proflie` 进入 `STTradeAccountProfileController`，
/// 并固定传 `STTradeAccountProfileControllerFromType_TradeHome`。
String tradeHomeAccountProfileLocation() => '/trade/accountprofile?fromType=0';

/// 对齐 iOS `STTradeManager checkOpenKYCVerificationInCrl:`：
/// 模拟账户 `type == 1` 直接放行，非模拟账户继续走开仓权限链。
bool tradeOpenKycVerificationRequired({
  String transactionAccountType = '',
  int? currentAccountType,
}) {
  if (currentAccountType == 1) return false;
  if (transactionAccountType.trim() == '1') return false;
  return true;
}

bool tradeAccountReadyForSubmit({
  required bool isSwitching,
  required String currentAccountId,
  required String transactionAccount,
}) {
  if (isSwitching) return false;
  final current = currentAccountId.trim();
  final global = transactionAccount.trim();
  return current.isNotEmpty && global.isNotEmpty && current == global;
}

bool tradeAccountSwitchUsesBlockingReload() => false;

bool tradePageUsesFullscreenLoading({
  required bool isLoading,
  required bool isSwitchingTradeAccount,
}) {
  return false;
}

String tradeAccountSwitchToastForCurrentResult({
  required String selectedAccountId,
  required String currentAccountId,
  required bool failed,
  String successLabel = '账户切换成功',
  String failedLabel = '账户切换失败',
}) {
  if (failed) return failedLabel;
  final selected = selectedAccountId.trim();
  final current = currentAccountId.trim();
  if (selected.isNotEmpty && selected == current) return successLabel;
  return failedLabel;
}

/// 不把 Dio 原始异常文案暴露给用户（避免满屏英文栈），但保留服务端业务错误文案。
String tradeUserFacingLoadError(Object e) {
  if (e is DioException) {
    final code = e.response?.statusCode;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        return '连接超时，请检查网络后重试';
      case DioExceptionType.receiveTimeout:
        return '服务器响应超时，请稍后重试';
      case DioExceptionType.connectionError:
        return '网络异常，请检查网络连接';
      case DioExceptionType.badResponse:
        if (code == 503) return '服务暂时不可用，请稍后再试';
        if (code == 502 || code == 504) return '网关或服务异常，请稍后再试';
        if (code != null) return '请求失败（HTTP $code），请稍后再试';
        return '服务器响应异常，请稍后再试';
      default:
        break;
    }
  }
  const exceptionPrefix = 'Exception: ';
  final message = e.toString().trim();
  if (message.startsWith(exceptionPrefix)) {
    final businessMessage = message.substring(exceptionPrefix.length).trim();
    if (businessMessage.isNotEmpty) return businessMessage;
  }
  return '加载失败，请稍后重试';
}

class TradeSymbolPayloads {
  const TradeSymbolPayloads({this.symbolInfo, this.detailInfo});

  final Map<String, dynamic>? symbolInfo;
  final Map<String, dynamic>? detailInfo;
}

bool _tradeApiSuccessCode(dynamic code) {
  if (code == null) return true;
  if (code is num) return code == 0 || code == 200;
  final s = code.toString().trim();
  if (s.isEmpty) return true;
  final n = int.tryParse(s);
  if (n != null) return n == 0 || n == 200;
  return s.toLowerCase() == 'ok' || s.toLowerCase() == 'success';
}

Map<String, dynamic>? _unwrapTradeDetailMap(Map<String, dynamic>? raw) {
  if (raw == null) return null;
  Map<String, dynamic> map;
  if (raw.containsKey('code')) {
    if (!_tradeApiSuccessCode(raw['code'])) return null;
    final data = raw['data'];
    if (data is! Map) return null;
    map = Map<String, dynamic>.from(data);
  } else if (raw['data'] is Map) {
    map = Map<String, dynamic>.from(raw['data'] as Map);
  } else {
    map = Map<String, dynamic>.from(raw);
  }
  for (final key in ['symbol_info', 'symbolInfo', 'quote', 'Quote']) {
    final nested = map[key];
    if (nested is Map) {
      map.addAll(Map<String, dynamic>.from(nested));
    }
  }
  return map;
}

Future<TradeSymbolPayloads> loadTradeSymbolPayloads(
  STService stService,
  String symbol,
) async {
  final results = await Future.wait<Map<String, dynamic>?>([
    () async {
      try {
        return await stService.getSymbolInfo(symbol);
      } catch (e) {
        debugPrint('⚠️ loadTradeSymbolPayloads symbolInfo: $e');
        return null;
      }
    }(),
    () async {
      try {
        return _unwrapTradeDetailMap(await stService.getProductDetail(symbol));
      } catch (e) {
        debugPrint('⚠️ loadTradeSymbolPayloads productDetail: $e');
        return null;
      }
    }(),
  ]);
  return TradeSymbolPayloads(symbolInfo: results[0], detailInfo: results[1]);
}

void subscribeTradePageSymbol(MarketWebSocket ws, String symbol) {
  ws.connect();
  ws.sendEnterTransactionPage(symbol);
}

class TradeActionRefreshingHud extends StatelessWidget {
  const TradeActionRefreshingHud({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      key: ValueKey('trade-action-refreshing-hud'),
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

/// 交易主页面
/// 对齐 iOS `STTradeController`（Local/STTradeModule）布局:
///   顶部品种胶囊 | 下单板(买卖价/手数/止盈止损/提交) | 持仓/挂单分页列表
class TradePage extends ConsumerStatefulWidget {
  final bool isActive;

  const TradePage({super.key, this.isActive = true});

  @override
  ConsumerState<TradePage> createState() => _TradePageState();
}

enum _CellFieldAlignment { start, center, end }

class _TradePageText {
  const _TradePageText([this.localized = const {}]);

  final Map<String, String> localized;

  static const fallbackText = <String, String>{
    'retry': '重试',
    'chart': '图表',
    'real_account': '真实账户',
    'simulation_account': '模拟账户',
    'trader_account': '交易员账户',
    'login': '登录',
    'please_login_account': '请登录账户',
    'market_order': '市价单',
    'limit_order': '限价单',
    'stop_order': '停损单',
    'lots': '交易量 (手)',
    'hand': '手',
    'take_profit': '止盈',
    'stop_loss': '止损',
    'stop_loss_and_take_profit': '止盈/止损',
    'profile_loss_type_description':
        '(1) 止盈 (TP)：在达到指定盈利价位时自动平仓。\n(2) 止损 (SL)：在达到指定亏损价位时自动平仓。',
    'i_see': '知道了',
    'buy': '买入',
    'sell': '卖出',
    'stock_long': '买入',
    'stock_short': '卖出',
    'out_of_range': '交易手数超出范围',
    'number_out_of_range': '数量超出范围',
    'free_margin': '可用保证金',
    'margin_deposit': '保证金',
    'margin_level': '保证金水平',
    'bring_single': '带单',
    'order_tracking_sign': '跟单',
    'no_setting': '未设置',
    'select_validity_period': '选择有效期',
    'positions': '持仓',
    'pending_orders': '挂单',
    'show_current_trading_pairs': '仅显示当前品种',
    'no_holder_positions': '暂无持仓',
    'no_pending_orders': '暂无挂单',
    'open_price_title': '开仓价',
    'last_price_title': '最新价',
    'entrust_price': '委托价',
    'cancel_order': '撤单',
    'modify': '修改',
    'close_a_position': '平仓',
    'system_busy': '系统繁忙，请稍后再试',
    'market_closed': '已休市',
    'network_disconnected': '网络连接已断开',
    'price_out_of_range': '开仓价格无效',
    'profit_out_of_range': '止盈价格无效',
    'stoploss_out_of_range': '止损价格无效',
    'margin_free_not_enough': '可用保证金不足',
    'sorry_open_fail': '开仓失败',
    'order_placement_failed': '挂单失败',
    'close_fail': '平仓失败',
    'stop_loss_and_take_profit_failed': '止盈/止损设置失败',
    'modify_fail': '修改失败',
    'order_cancel_failed': '撤单失败',
    'modify_success': '修改成功',
    'order_canceled': '订单已撤销',
    'trade_temp_unable': '暂时无法开仓',
    'estimated_profit_loss': '预估盈亏',
    'network_unavailable': '网络异常，请检查网络连接',
    'request_failed': '加载失败，请稍后重试',
    'account_switch_success': '账户切换成功',
    'account_switch_failed': '账户切换失败',
    'account_switching': '账户切换处理中，请稍后再试',
    'trade_unavailable': '交易暂不可用',
    'finish_real_name_before_trade': '请先完成实名认证后再下单',
    'set_fund_password_before_trade': '请先设置资金密码后再下单',
    'deposit_to_activate_real_account': '请先入金激活真实账户',
    'invalid_entrust_price': '请输入有效委托价',
  };

  String t(String key) => localized[key] ?? fallbackText[key] ?? key;

  String get retry => t('retry');
}

class _TradePageState extends ConsumerState<TradePage>
    with WidgetsBindingObserver, RouteAware {
  static const String _depositRoute = '/mine/deposit';
  bool _isLoading = false;
  bool _isActionRefreshing = false;
  String? _errorMessage;
  String? _languageCode;
  int _languageLoadToken = 0;
  int _symbolRefreshToken = 0;
  _TradePageText _text = const _TradePageText();

  static const Map<String, String> _fallbackText = _TradePageText.fallbackText;
  TradeAccountDetailLabels get _detailLabels =>
      TradeAccountDetailLabels(_text.localized);

  // ---------- 账户数据（展示字段） ----------
  String _freeMargin = '0.00';
  String _marginLevel = '--';
  String _accountCurrency = '';
  String _accountLeverage = '1';

  // ---------- 持仓/挂单 ----------
  List<Map<String, dynamic>> _positions = [];
  List<Map<String, dynamic>> _pendingOrders = [];
  int _pendingTotalCount = 0;

  // ---------- 下单板状态 ----------
  bool _isBuy = true; // Buy / Sell
  /// 对齐 iOS `th_jumpTradeSurfaceReady`：首帧加载完成后再应用外部跳转的买卖方向。
  bool _tradeSurfaceReady = false;
  bool? _stashedJumpIsBuy;

  /// `market` | `limit` | `stop`，对齐 iOS / OrderPage
  String _boardOrderType = 'market';
  final GlobalKey _registrationModeMenuKey = GlobalKey();
  final TextEditingController _pendingPriceController = TextEditingController();
  bool _pendingPriceUserEdited = false;
  List<String> _symbolChoices = [];
  String _selectedSymbol = 'EUR/USD';
  String _selectedLot = '0.01';
  String _takeProfit = '';
  String _stopLoss = '';
  final TextEditingController _lotController = TextEditingController();
  late final TextEditingController _takeProfitController;
  late final TextEditingController _stopLossController;
  final FocusNode _pendingPriceFocus = FocusNode();
  final FocusNode _lotFocus = FocusNode();
  final FocusNode _takeProfitFocus = FocusNode();
  final FocusNode _stopLossFocus = FocusNode();

  /// 下单板挂单有效期（日历日），对齐 iOS `STTradeHomeCell` / `validityDate`
  late DateTime _boardPendingValidityDay;

  // 行情买一/卖一价（Mock 或由 API 回填后展示）
  String _bidPrice = '--';
  String _askPrice = '--';
  String _priceSpread = '';

  /// 品种展示名（对齐 iOS `currentProductModel.name` / 接口 `name`）
  String _instrumentListingName = '';

  /// 手数区间文案（对齐合约 `min_lot`～`max_lot` / `step_lot`）
  String _lotRangeHint = '';
  bool _isInTradeTime = false;
  bool _isSubmittingTrade = false;
  String _tradeMode = '4';
  double _minLot = 0.01;
  double _maxLot = 10.0;
  double _stepLot = 0.01;
  double _point = 0.0001;
  int _digits = 5;
  double _pips = 0;
  String _symbolGroup = '';
  String _contractSize = '1';
  String _profitCurrency = '';
  String _currencyMargin = '';
  String _calcMode = '';
  String _marginInitial = '0';
  String _marginInitialBuy = '1';
  String _marginInitialSell = '1';
  String _marginInitialBuyLimit = '1';
  String _marginInitialSellLimit = '1';
  String _marginInitialBuyStop = '1';
  String _marginInitialSellStop = '1';
  String _marginOccupation = '0.00';
  double _pendingMinPrice = 0;
  double _pendingMaxPrice = 0;
  double _takeProfitMinPrice = 0;
  double _takeProfitMaxPrice = 0;
  double _stopLossMinPrice = 0;
  double _stopLossMaxPrice = 0;
  String _takeProfitRange = '';
  String _stopLossRange = '';
  String _takeProfitExpected = '--';
  String _stopLossExpected = '--';
  int _takeProfitRatio = 1;
  int _stopLossRatio = 1;
  double _signalProviderMaxLot = 0;

  // ---------- 持仓/挂单 Tab ----------
  bool _showPositions = true; // true = 持仓, false = 挂单

  /// 对齐 iOS `STTradeController`：`limit = 20`，`offset = limit * page`
  static const int _kPendingPageSize = 20;
  final ScrollController _scrollController = ScrollController();
  int _pendingPageIndex = 0;
  bool _pendingHasMore = false;
  bool _pendingLoadingMore = false;
  bool _isRefreshingLedgers = false;

  StreamSubscription<MarketWSMessage>? _wsSub;
  final Map<String, _LiveBidAsk> _liveQuotesBySymbol = <String, _LiveBidAsk>{};
  final Map<String, _LiveBidAsk> _allQuotesBySymbol = <String, _LiveBidAsk>{};
  late final VoidCallback _ledgerRefreshListener;
  late final VoidCallback _accountChangedListener;

  // ---------- 合约信息 ----------
  List<String> _lotLadder = ['0.01', '0.05', '0.1', '1', '10'];
  bool _canSignalProvider = false;

  // ---------- 带单 ----------
  bool _signalProviderOn = false;

  // ---------- 品种隔离 ----------
  bool _symbolIsolationOn = false;

  /// 交易账户列表（底部切换 Sheet）
  List<Map<String, dynamic>> _tradeAccounts = [];
  String _currentAccountId = '';
  String _accountTypeLabel = '';
  int _currentAccountType = 0;
  bool _isSwitchingTradeAccount = false;
  bool _initialLoadStarted = false;

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    EventBus().off(EventBus.tradePositionListRefresh, _ledgerRefreshListener);
    EventBus().off(EventBus.accountChanged, _accountChangedListener);
    _wsSub?.cancel();
    _scrollController.removeListener(_onTradeScroll);
    _scrollController.dispose();
    _lotController.dispose();
    _pendingPriceController.dispose();
    _takeProfitController.dispose();
    _stopLossController.dispose();
    _pendingPriceFocus.dispose();
    _lotFocus.dispose();
    _takeProfitFocus.dispose();
    _stopLossFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lotController.text = _selectedLot;
    _takeProfitController = TextEditingController(text: _takeProfit);
    _stopLossController = TextEditingController(text: _stopLoss);
    _takeProfitController.addListener(() {
      _takeProfit = _takeProfitController.text;
    });
    _stopLossController.addListener(() {
      _stopLoss = _stopLossController.text;
    });
    _boardPendingValidityDay = _calendarDayOnlyTp(
      _iosDefaultValidityCalendarDayTp(),
    );
    _scrollController.addListener(_onTradeScroll);
    _wsSub = ref
        .read(marketWebSocketProvider)
        .messageStream
        .listen(_onTradeWsMessage);
    _ledgerRefreshListener = () {
      if (!mounted ||
          !widget.isActive ||
          !ref.read(userStateProvider).isLogin) {
        return;
      }
      unawaited(_refreshLedgersFromNotification());
    };
    EventBus().on(EventBus.tradePositionListRefresh, _ledgerRefreshListener);
    _accountChangedListener = () {
      if (!mounted ||
          !widget.isActive ||
          !ref.read(userStateProvider).isLogin) {
        return;
      }
      if (_isSwitchingTradeAccount) return;
      unawaited(_loadAllData(showBlockingLoading: false));
    };
    EventBus().on(EventBus.accountChanged, _accountChangedListener);
    _activateTradePageIfNeeded();
  }

  @override
  void didUpdateWidget(covariant TradePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _activateTradePageIfNeeded();
    } else if (oldWidget.isActive && !widget.isActive) {
      _deactivateTradePage();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLocalizedTextsIfNeeded();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  void _loadLocalizedTextsIfNeeded() {
    final localizations = stLocalizationsOfContext(context, ref);
    if (_languageCode == localizations.languageCode) return;
    _languageCode = localizations.languageCode;

    final token = ++_languageLoadToken;
    localizations.textMap(_fallbackText).then((value) {
      if (!mounted || token != _languageLoadToken) return;
      setState(() => _text = _TradePageText(value));
    });
  }

  @override
  void didPopNext() {
    _resetTradeSubmittingState();
    _onTradePageVisible();
  }

  @override
  void didPushNext() {
    _resetTradeSubmittingState();
  }

  void _resetTradeSubmittingState() {
    if (!mounted || !_isSubmittingTrade) return;
    setState(() => _isSubmittingTrade = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onTradePageVisible();
    }
  }

  void _activateTradePageIfNeeded() {
    if (!mounted || !widget.isActive) return;
    _resetTradeSubmittingState();
    if (!_initialLoadStarted) {
      _initialLoadStarted = true;
      unawaited(_loadAllData(showBlockingLoading: false));
      return;
    }
    _onTradePageVisible();
  }

  void _deactivateTradePage() {
    _resetTradeSubmittingState();
    try {
      ref.read(marketWebSocketProvider).sendEnterEmpty();
    } catch (e) {
      debugPrint('📡 TradePage deactivate socket: $e');
    }
  }

  /// 对齐 iOS `viewWillAppear`：从后台回前台或系统恢复后，重绑 WS 并静默刷新业务数据。
  void _onTradePageVisible() {
    if (!mounted || !widget.isActive) return;
    _resetTradeSubmittingState();
    if (!_initialLoadStarted) {
      _initialLoadStarted = true;
      unawaited(_loadAllData(showBlockingLoading: false));
      return;
    }
    _notifyWsTradeSymbol();
    if (ref.read(userStateProvider).isLogin) {
      unawaited(_loadAllData(showBlockingLoading: false));
    }
  }

  void _onTradeScroll() {
    if (!_scrollController.hasClients) return;
    if (_showPositions) return;
    if (_pendingLoadingMore || !_pendingHasMore) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= 0) return;
    if (pos.pixels < pos.maxScrollExtent - 280) return;
    _loadMorePending();
  }

  // ==================== 数据加载 ====================

  /// 安全加载 List 类型 API（避免 _Map 类型错误）
  Future<List<dynamic>> _safeLoadList(
    Future<List<dynamic>> Function() loader,
  ) async {
    try {
      return await loader();
    } catch (e) {
      debugPrint('⚠️ _safeLoadList error: $e');
      return [];
    }
  }

  /// 安全加载 Map 类型 API
  Future<Map<String, dynamic>?> _safeLoadMap(
    Future<Map<String, dynamic>> Function() loader,
  ) async {
    try {
      return await loader();
    } catch (e) {
      debugPrint('⚠️ _safeLoadMap error: $e');
      return null;
    }
  }

  Map<String, dynamic>? _mergeSymbolPayloads(
    Map<String, dynamic>? base,
    Map<String, dynamic>? overlay,
  ) {
    if (base == null) return overlay;
    if (overlay == null) return base;
    const symbolInfoQuoteKeys = {'bid', 'ask', 'buy', 'sell', 'spread'};
    final merged = Map<String, dynamic>.from(base);
    overlay.forEach((key, value) {
      if (symbolInfoQuoteKeys.contains(key) && base.containsKey(key)) return;
      if (value != null) merged[key] = value;
    });
    return merged;
  }

  String _userFacingLoadError(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return _text.t('network_unavailable');
        case DioExceptionType.badResponse:
          if (code == 503 || code == 502 || code == 504) {
            return _text.t('system_busy');
          }
          return _text.t('request_failed');
        default:
          break;
      }
    }
    const exceptionPrefix = 'Exception: ';
    final message = e.toString().trim();
    if (message.startsWith(exceptionPrefix)) {
      final businessMessage = message.substring(exceptionPrefix.length).trim();
      if (businessMessage.isNotEmpty) return businessMessage;
    }
    return _text.t('request_failed');
  }

  /// 从账户数据解析字段（兼容 `{ data: { balance... } }` 嵌套）
  void _extractAccountData(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return;
    var d = data;
    final inner = d['data'];
    if (inner is Map &&
        d['balance'] == null &&
        d['equity'] == null &&
        d['free_margin'] == null) {
      d = Map<String, dynamic>.from(inner);
    }
    _freeMargin = tradeFreeMarginDisplayFromAccountData(d);
    _marginLevel = d['margin_level']?.toString() ?? '--';
    _accountCurrency = d['currency']?.toString() ?? _accountCurrency;
    _accountLeverage =
        d['leverage']?.toString() ??
        d['account_leverage']?.toString() ??
        _accountLeverage;
    _currentAccountType = _toInt(
      d['type'] ?? d['account_type_num'] ?? d['transaction_account_type'],
      fallback: _currentAccountType,
    );
    _currentAccountId =
        (d['account_id'] ?? d['id'] ?? d['accountId'])?.toString() ?? '';
    _accountTypeLabel =
        d['account_type']?.toString() ??
        d['name']?.toString() ??
        TradeAccountEntry.fromMap(d).label;
    if (d['bid'] != null) _bidPrice = d['bid'].toString();
    if (d['ask'] != null) _askPrice = d['ask'].toString();
  }

  Future<void> _syncCurrentTradeAccountState(
    Map<String, dynamic>? accountData,
  ) async {
    if (accountData == null || accountData.isEmpty) return;
    var d = accountData;
    final inner = d['data'];
    if (inner is Map) {
      d = Map<String, dynamic>.from(inner);
    }
    final id = (d['account_id'] ?? d['id'] ?? d['accountId'])?.toString() ?? '';
    final type =
        (d['type'] ?? d['account_type_num'] ?? d['transaction_account_type'])
            ?.toString() ??
        '';
    if (id.isEmpty || type.isEmpty) return;
    await ref.read(userStateProvider.notifier).updateTransactionAccounts({
      'transaction_account': id,
      'transaction_account_type': type,
      'is_active': d['is_active']?.toString() ?? d['isActive']?.toString(),
    });
  }

  /// 加载品种信息中的 bid/ask、展示名、手数区间
  void _extractSymbolBidAsk(Map<String, dynamic>? data) {
    if (data == null) return;
    if (data['bid'] != null) _bidPrice = data['bid'].toString();
    if (data['ask'] != null) _askPrice = data['ask'].toString();
    if (data['spread'] != null) _priceSpread = data['spread'].toString();
    final name = data['name'] ?? data['title'] ?? data['listing_name'];
    _instrumentListingName = (name != null && name.toString().trim().isNotEmpty)
        ? name.toString().trim()
        : '';
    final minL = data['min_lot'] ?? data['min_volume'] ?? data['volume_min'];
    final maxL = data['max_lot'] ?? data['max_volume'] ?? data['volume_max'];
    if (minL != null || maxL != null) {
      _lotRangeHint = '${minL ?? '?'} - ${maxL ?? '?'}';
    }
    _parseContractProfile(data);
  }

  /// 解析合约配置（对齐 iOS STTradeHomeContractProfile）
  void _parseContractProfile(Map<String, dynamic> data) {
    _minLot = _toDouble(
      data['min_lot'] ??
          data['minLot'] ??
          data['min_volume'] ??
          data['volume_min'],
      fallback: 0.01,
    );
    _maxLot = _toDouble(
      data['max_lot'] ??
          data['maxLot'] ??
          data['max_volume'] ??
          data['volume_max'],
      fallback: 10,
    );
    _stepLot = _toDouble(
      data['step_lot'] ??
          data['lotStep'] ??
          data['lot_step'] ??
          data['volume_step'],
      fallback: 0.01,
    );
    _point = _toDouble(data['point'] ?? data['tick_size'], fallback: 0.0001);
    _digits = _toInt(
      data['digits'],
      fallback: _decimalPlacesForStep(_point.toString()),
    );
    _pips = _toDouble(data['pips'] ?? data['stops_level'], fallback: _point);
    _symbolGroup = (data['symbol_group'] ?? data['symbolGroup'] ?? _symbolGroup)
        .toString();
    _contractSize =
        (data['contract_size'] ?? data['contractSize'] ?? _contractSize)
            .toString();
    _profitCurrency =
        (data['currency_profit'] ??
                data['profit_currency'] ??
                data['profitCurrency'] ??
                _profitCurrency)
            .toString();
    _currencyMargin =
        (data['currency_margin'] ??
                data['margin_currency'] ??
                data['currencyMargin'] ??
                _currencyMargin)
            .toString();
    _calcMode = (data['calc_mode'] ?? data['calcMode'] ?? _calcMode).toString();
    _marginInitial = (data['margin_initial'] ?? _marginInitial).toString();
    _marginInitialBuy = (data['margin_initial_buy'] ?? _marginInitialBuy)
        .toString();
    _marginInitialSell = (data['margin_initial_sell'] ?? _marginInitialSell)
        .toString();
    _marginInitialBuyLimit =
        (data['margin_initial_buy_limit'] ?? _marginInitialBuyLimit).toString();
    _marginInitialSellLimit =
        (data['margin_initial_sell_limit'] ?? _marginInitialSellLimit)
            .toString();
    _marginInitialBuyStop =
        (data['margin_initial_buy_stop'] ?? _marginInitialBuyStop).toString();
    _marginInitialSellStop =
        (data['margin_initial_sell_stop'] ?? _marginInitialSellStop).toString();
    _pendingMinPrice = _toDouble(
      data['pending_min_price'] ?? data['pendingMinPrice'] ?? data['min_price'],
    );
    _pendingMaxPrice = _toDouble(
      data['pending_max_price'] ?? data['pendingMaxPrice'] ?? data['max_price'],
    );
    final tradeSessions =
        data['sessions_trades_since_sunday'] ??
        data['sessionsTradesSinceSunday'];
    if (iosHasTradeSessionsSinceSunday(tradeSessions)) {
      _isInTradeTime = iosIsInTradeTimeFromSinceSunday(
        tradeSessions,
        selectedTimeZone: ref.read(userStateProvider).selectedTimeZone,
      );
    } else {
      final itt = data['is_in_trade_time'] ?? data['isInTradeTime'];
      if (itt != null) {
        _isInTradeTime = _parseApiBool(itt);
      }
    }
    _tradeMode = (data['trade_mode'] ?? data['tradeMode'] ?? _tradeMode)
        .toString()
        .trim();

    // 手数阶梯
    final rawLots = data['lots_list'] ?? data['lotsList'] ?? data['lots'];
    if (rawLots is List && rawLots.isNotEmpty) {
      _lotLadder = rawLots.map((e) => e.toString()).toList();
    } else {
      _lotLadder = ['0.01', '0.05', '0.1', '1', '10'];
    }
    if (_lotLadder.isEmpty) {
      _lotLadder = ['0.01', '0.05', '0.1', '1', '10'];
    }

    // 对齐 `STTradeProductModel`: lots_list 多于 2 个默认第二项，否则第一项。
    if (_selectedLot.trim().isEmpty || !_lotLadder.contains(_selectedLot)) {
      _selectedLot = _lotLadder.length > 1 ? _lotLadder[1] : _lotLadder.first;
    }
    if (_lotController.text != _selectedLot) {
      _lotController.text = _selectedLot;
    }

    _canSignalProvider = _parseApiBool(data['can_signal_provider']);
    final signalProviderConfig =
        data['signal_provider_take_profit_stop_loss_ratio'] ??
        data['signalProviderTakeProfitStopLossRatio'];
    if (signalProviderConfig is Map) {
      _takeProfitRatio = _toInt(
        signalProviderConfig['take_profit_ratio'],
        fallback: 1,
      );
      _stopLossRatio = _toInt(
        signalProviderConfig['stop_loss_ratio'],
        fallback: 1,
      );
      _signalProviderMaxLot = _toDouble(signalProviderConfig['max_lots']);
    }
    if (!_canSignalProvider) {
      _signalProviderOn = false;
    }
    _recalculateTradeDerivedValues();
  }

  static double _toDouble(dynamic v, {double fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '').trim()) ?? fallback;
  }

  static int _toInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim()) ?? fallback;
  }

  double get _effectiveMaxLot => _signalProviderOn && _signalProviderMaxLot > 0
      ? _signalProviderMaxLot
      : _maxLot;

  bool get _hasLotProfile =>
      _lotLadder.isNotEmpty && _minLot > 0 && _effectiveMaxLot > 0;

  static int _decimalPlacesForStep(String literal) {
    final s = literal.trim();
    final dot = s.indexOf('.');
    if (dot < 0) return 0;
    return s.length - dot - 1;
  }

  static String _formatDownToStep(dynamic raw, double step) {
    final n = _toDouble(raw);
    final places = math.max(0, _decimalPlacesForStep(step.toString()));
    final scale = math.pow(10, places).toDouble();
    final down = (n * scale).floorToDouble() / scale;
    return down.toStringAsFixed(places);
  }

  String _formatPriceByPoint(double value) {
    final places = math.max(0, _decimalPlacesForStep(_point.toString()));
    return value.toStringAsFixed(places);
  }

  double _maxFinitePrice() {
    final places = math.max(0, _digits);
    return 99999999 + ((math.pow(10, places) - 1) / math.pow(10, places));
  }

  void _recalculateTradeDerivedValues() {
    _recalculatePendingPriceRange();
    _syncDefaultPendingPriceIfNeeded();
    _recalculateTpslRangeAndDefaults();
    _recalculateExpectedProfit();
    _recalculateMarginOccupation();
  }

  void _recalculatePendingPriceRange() {
    if (_boardOrderType == 'market') return;
    final buy = _toDouble(_askPrice);
    final sell = _toDouble(_bidPrice);
    final pips = _pips > 0 ? _pips : _point;
    final maxFinite = _maxFinitePrice();

    if (_boardOrderType == 'limit') {
      if (_isBuy) {
        _pendingMinPrice = _point;
        _pendingMaxPrice = math.max(_point, buy - pips);
      } else {
        _pendingMinPrice = sell + pips;
        _pendingMaxPrice = maxFinite;
      }
    } else {
      if (_isBuy) {
        _pendingMinPrice = buy + pips;
        _pendingMaxPrice = maxFinite;
      } else {
        _pendingMinPrice = _point;
        _pendingMaxPrice = math.max(_point, sell - pips);
      }
    }
  }

  void _resetPendingPriceToNativeDefault() {
    _pendingPriceUserEdited = false;
    _pendingPriceController.clear();
  }

  void _syncDefaultPendingPriceIfNeeded() {
    if (_boardOrderType == 'market') return;
    if (_pendingPriceUserEdited) return;
    if (_pendingPriceController.text.trim().isNotEmpty) return;
    final fallback = _defaultPendingPrice();
    if (fallback.isNotEmpty) {
      _pendingPriceController.text = fallback;
    }
  }

  void _recalculateTpslRangeAndDefaults() {
    final buy = _toDouble(_askPrice);
    final sell = _toDouble(_bidPrice);
    final pending = _toDouble(
      _pendingPriceController.text.trim().isEmpty
          ? _defaultPendingPrice()
          : _pendingPriceController.text,
    );
    final pips = _pips > 0 ? _pips : _point;
    final maxFinite = _maxFinitePrice();
    final profitCap = _signalProviderOn ? _point * _takeProfitRatio : 0.0;
    final lossCap = _signalProviderOn ? _point * _stopLossRatio : 0.0;

    double profitMin;
    double profitMax;
    double lossMin;
    double lossMax;

    if (_boardOrderType != 'market') {
      final open = pending > 0 ? pending : (_isBuy ? buy : sell);
      if (_isBuy) {
        profitMin = open + pips;
        profitMax = _signalProviderOn ? open + pips + profitCap : maxFinite;
        lossMin = _signalProviderOn
            ? math.max(_point, open - pips - lossCap)
            : _point;
        lossMax = math.max(_point, open - pips);
      } else {
        profitMin = _signalProviderOn
            ? math.max(_point, open - pips - profitCap)
            : _point;
        profitMax = math.max(_point, open - pips);
        lossMin = open + pips;
        lossMax = _signalProviderOn ? open + pips + lossCap : maxFinite;
      }
    } else if (_isBuy) {
      profitMin = sell + pips;
      profitMax = _signalProviderOn ? buy + pips + profitCap : maxFinite;
      lossMin = _signalProviderOn
          ? math.max(_point, sell - pips - lossCap)
          : _point;
      lossMax = math.max(_point, sell - pips);
    } else {
      profitMin = _signalProviderOn
          ? math.max(_point, sell - pips - profitCap)
          : _point;
      profitMax = math.max(_point, buy - pips);
      lossMin = buy + pips;
      lossMax = _signalProviderOn ? buy + pips + lossCap : maxFinite;
    }

    _takeProfitMinPrice = math.max(0, profitMin);
    _takeProfitMaxPrice = math.max(0, profitMax);
    _stopLossMinPrice = math.max(0, lossMin);
    _stopLossMaxPrice = math.max(0, lossMax);

    if (_signalProviderOn) {
      _takeProfitRange =
          '${_formatPriceByPoint(_takeProfitMinPrice)} - ${_formatPriceByPoint(_takeProfitMaxPrice)}';
      _stopLossRange =
          '${_formatPriceByPoint(_stopLossMinPrice)} - ${_formatPriceByPoint(_stopLossMaxPrice)}';
    } else if (_isBuy) {
      _takeProfitRange = '>= ${_formatPriceByPoint(_takeProfitMinPrice)}';
      _stopLossRange = '<= ${_formatPriceByPoint(_stopLossMaxPrice)}';
    } else {
      _takeProfitRange = '<= ${_formatPriceByPoint(_takeProfitMaxPrice)}';
      _stopLossRange = '>= ${_formatPriceByPoint(_stopLossMinPrice)}';
    }

    if (_takeProfitController.text.trim().isEmpty && _takeProfitMinPrice > 0) {
      _takeProfitController.text = _formatPriceByPoint(
        _isBuy ? _takeProfitMinPrice : _takeProfitMaxPrice,
      );
    }
    if (_stopLossController.text.trim().isEmpty && _stopLossMaxPrice > 0) {
      _stopLossController.text = _formatPriceByPoint(
        _isBuy ? _stopLossMaxPrice : _stopLossMinPrice,
      );
    }
  }

  void _recalculateExpectedProfit() {
    final openPrice = _boardOrderType == 'market'
        ? (_isBuy ? _askPrice : _bidPrice)
        : _pendingPriceForSubmit();
    final conversionRate =
        _quoteRate(_profitCurrency, 'USD', isBuy: _isBuy) *
        _quoteRate('USD', _accountCurrency, isBuy: _isBuy);

    String expectedFor(String raw) {
      return TradeExpectedProfit.calculate(
        isBuy: _isBuy,
        openPrice: openPrice,
        closePrice: raw,
        lotText: _normalizedLot(),
        contractSize: _contractSize,
        conversionRate: conversionRate,
      );
    }

    _takeProfitExpected = _takeProfitController.text.trim().isEmpty
        ? '--'
        : expectedFor(_takeProfitController.text);
    _stopLossExpected = _stopLossController.text.trim().isEmpty
        ? '--'
        : expectedFor(_stopLossController.text);
  }

  void _recalculateMarginOccupation() {
    final lot = _toDouble(_normalizedLot(), fallback: _minLot);
    final marginInitial = _toDouble(_marginInitial);
    final marginLevel = _marginRateForCurrentMode();
    final leverage = math.max(1, _toDouble(_accountLeverage, fallback: 1));
    final price = _isBuy ? _toDouble(_askPrice) : _toDouble(_bidPrice);
    final currencyRate = _quoteRate(_currencyMargin, 'USD', isBuy: _isBuy);
    double value;
    if (marginInitial == 0) {
      value = _toDouble(_contractSize);
    } else if (_calcMode == '0') {
      value = lot * marginInitial * marginLevel * currencyRate / leverage;
    } else if (_calcMode == '2') {
      value = lot * marginInitial * price * marginLevel * currencyRate;
    } else if (_calcMode == '4') {
      value =
          lot * marginInitial * price * marginLevel * currencyRate / leverage;
    } else if (_calcMode == '5') {
      value = lot * marginInitial * marginLevel * currencyRate;
    } else {
      value = lot * marginInitial * marginLevel;
    }
    if (value.isFinite && value >= 0) {
      _marginOccupation = value.toStringAsFixed(2);
    }
  }

  double _marginRateForCurrentMode() {
    if (_boardOrderType == 'market') {
      return _toDouble(
        _isBuy ? _marginInitialBuy : _marginInitialSell,
        fallback: 1,
      );
    }
    if (_boardOrderType == 'limit') {
      return _toDouble(
        _isBuy ? _marginInitialBuyLimit : _marginInitialSellLimit,
        fallback: 1,
      );
    }
    return _toDouble(
      _isBuy ? _marginInitialBuyStop : _marginInitialSellStop,
      fallback: 1,
    );
  }

  double _quoteRate(String from, String to, {required bool isBuy}) {
    final f = from.trim().toUpperCase();
    final t = to.trim().toUpperCase();
    if (f.isEmpty || t.isEmpty || f == t) return 1;
    final direct = _allQuotesBySymbol['$f$t'];
    if (direct != null) {
      final v = _toDouble(isBuy ? direct.ask : direct.bid, fallback: 1);
      return v <= 0 ? 1 : v;
    }
    final inverse = _allQuotesBySymbol['$t$f'];
    if (inverse != null) {
      final v = _toDouble(isBuy ? inverse.bid : inverse.ask, fallback: 1);
      return v <= 0 ? 1 : 1 / v;
    }
    return 1;
  }

  static bool _parseApiBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }

  /// 对齐 iOS `sendEnterTradeMainMessageWithSymbol:`：页内切品种直接切房间，不先清空。
  void _notifyWsTradeSymbol() {
    subscribeTradePageSymbol(
      ref.read(marketWebSocketProvider),
      _selectedSymbol,
    );
  }

  /// 对齐 iOS `TRANSACTION_UPDATE_SYMBOL_PRICE` / 买卖价推送刷新下单板与持仓参考价
  void _onTradeWsMessage(MarketWSMessage msg) {
    if (!mounted || !widget.isActive) return;
    switch (msg.type) {
      case 'TRANSACTION_UPDATE_SYMBOL_PRICE':
        final d = msg.data;
        final sym = d['symbol']?.toString() ?? '';
        if (sym.isEmpty) return;
        final bid = d['bid']?.toString() ?? '';
        final ask = d['ask']?.toString() ?? '';
        final spread = d['spread']?.toString() ?? '';
        setState(() {
          _liveQuotesBySymbol[sym] = _LiveBidAsk(bid, ask);
          _allQuotesBySymbol[sym.replaceAll('/', '').toUpperCase()] =
              _LiveBidAsk(bid, ask);
          _applyLiveOrderQuoteToLedgers(msg);
          if (sym == _selectedSymbol) {
            if (bid.isNotEmpty) _bidPrice = bid;
            if (ask.isNotEmpty) _askPrice = ask;
            if (spread.isNotEmpty) _priceSpread = spread;
            _recalculateTradeDerivedValues();
          }
        });
        break;
      case 'UPDATE_SELL_AND_BUY':
        // iOS trade home ignores the market-detail quote event; its spread
        // can use a different unit/direction than transaction quotes.
        break;
      case 'ORDER_DEAL':
        if (ref.read(userStateProvider).isLogin) {
          unawaited(_refreshTradeLedgers());
        }
        break;
      default:
        break;
    }
  }

  void _applyLiveOrderQuoteToLedgers(MarketWSMessage msg) {
    void update(Map<String, dynamic> order, {required bool pending}) {
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
    }

    for (final order in _positions) {
      update(order, pending: false);
    }
    for (final order in _pendingOrders) {
      update(order, pending: true);
    }
  }

  Future<void> _loadAllData({bool showBlockingLoading = true}) async {
    if (showBlockingLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else if (mounted) {
      setState(() => _errorMessage = null);
    }

    try {
      final stService = ref.read(stServiceProvider);
      final loggedIn = ref.read(userStateProvider).isLogin;

      /// 对齐 iOS `STTradeController getTotalInfo:`：未登录清空账户展示，
      /// 仍拉持仓/挂单、全量行情与品种合约，接口失败只 toast 不阻断整页。
      if (!loggedIn) {
        _positions = [];
        _pendingOrders = [];
        _pendingTotalCount = 0;
        _pendingPageIndex = 0;
        _pendingHasMore = false;
        _freeMargin = '0.00';
        _marginLevel = '--';
        _tradeAccounts = [];
        _currentAccountId = '';
        _accountTypeLabel = '';
        _currentAccountType = 0;
      } else {
        await _refreshLoggedInTradeDependencies(stService);

        // 1. 交易账户
        final accountsRaw = await _safeLoadList(
          () => stService.getTradeAccounts(),
        );
        _tradeAccounts = accountsRaw.whereType<Map<String, dynamic>>().toList(
          growable: false,
        );
        final rememberedId = ref.read(userStateProvider).transactionAccount;
        final currentAccountData = await _loadCurrentTradeAccount(stService);
        final accountData = resolveTradeAccountDisplayData(
          currentAccount: currentAccountData,
          accounts: _tradeAccounts,
          rememberedAccountId: rememberedId,
        );
        _extractAccountData(accountData);
        await _syncCurrentTradeAccountState(accountData);

        // 2. 持仓
        final positionsRaw = await _safeLoadList(
          () => stService.getPositions(),
        );
        _positions = positionsRaw.whereType<Map<String, dynamic>>().toList();

        // 3. 挂单
        await _reloadPendingFirstPage(stService);
      }

      // 4. 可交易品种
      final symbolsRaw = await _safeLoadList(() => stService.getTradeSymbols());
      _symbolChoices = symbolsRaw
          .whereType<Map<String, dynamic>>()
          .map((m) => (m['symbol'] as String?) ?? (m['name'] as String?) ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (_symbolChoices.isEmpty) {
        _symbolChoices = [
          'EUR/USD',
          'GBP/USD',
          'USD/JPY',
          'AUD/USD',
          'XAU/USD',
          'BTC/USD',
        ];
      }

      final allPricesRaw = await _safeLoadList(
        () => stService.getAllSymbolPrices(),
      );
      _allQuotesBySymbol.clear();
      for (final item in allPricesRaw.whereType<Map>()) {
        final m = Map<String, dynamic>.from(item);
        final symbol = (m['symbol'] ?? m['name'] ?? '').toString();
        if (symbol.isEmpty) continue;
        final bid = (m['bid'] ?? m['sell'] ?? '').toString();
        final ask = (m['ask'] ?? m['buy'] ?? '').toString();
        _allQuotesBySymbol[symbol.replaceAll('/', '').toUpperCase()] =
            _LiveBidAsk(bid, ask);
      }

      // 5. 用户记忆的品种/手数
      final userState = ref.read(userStateProvider);
      if (userState.currentTradeSymbol.isNotEmpty &&
          _symbolChoices.contains(userState.currentTradeSymbol)) {
        _selectedSymbol = userState.currentTradeSymbol;
      } else if (!_symbolChoices.contains(_selectedSymbol)) {
        _selectedSymbol = _symbolChoices.first;
      }
      if (userState.currentTradeSetLot.isNotEmpty) {
        _selectedLot = userState.currentTradeSetLot;
        _lotController.text = _selectedLot;
      }

      final payload = await loadTradeSymbolPayloads(stService, _selectedSymbol);
      _extractSymbolBidAsk(
        _mergeSymbolPayloads(payload.symbolInfo, payload.detailInfo),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (widget.isActive) {
          _notifyWsTradeSymbol();
        }
        _markTradeSurfaceReady();
      }
    } catch (e) {
      debugPrint('⚠️ _loadAllData fatal: $e');
      if (mounted) {
        setState(() {
          if (showBlockingLoading) {
            _errorMessage = _userFacingLoadError(e);
          }
          _isLoading = false;
        });
        _markTradeSurfaceReady();
      }
    }
  }

  Future<void> _runWithActionRefreshing(Future<void> Function() action) async {
    if (mounted) {
      setState(() => _isActionRefreshing = true);
    }
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _isActionRefreshing = false);
      }
    }
  }

  /// 对齐 iOS `STTradeController viewWillAppear/getTotalInfo/updateOrders`：
  /// 页面每次进入都同步实名/KYC/钱包/等级变更与交易组保证金阈值，供交易权限、
  /// 保证金帮助弹层和账户相关入口使用。
  Future<void> _refreshLoggedInTradeDependencies(STService stService) async {
    final notifier = ref.read(userStateProvider.notifier);
    await Future.wait([
      notifier.bootstrapLoggedInSession(stService),
      _refreshTransactionGroupRatios(stService, notifier),
    ]);
  }

  Future<Map<String, dynamic>?> _loadCurrentTradeAccount(
    STService stService,
  ) async {
    final currentRaw = await _safeLoadMap(
      () => stService.getCurrentTransAccount(),
    );
    if (currentRaw == null) return null;
    final innerData = currentRaw['data'];
    final currentAccount = innerData is Map
        ? Map<String, dynamic>.from(innerData)
        : currentRaw;
    logTradeAccountSwitchDebug(
      'current_response',
      tradeAccountCurrentDebugSnapshot(currentAccount),
    );
    return currentAccount;
  }

  Future<void> _refreshTransactionGroupRatios(
    STService stService,
    UserStateNotifier notifier,
  ) async {
    try {
      final raw = await stService.getTransactionGroupDetail();
      final data = raw['data'] is Map
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : raw;
      final ratios = data['margin_ratio_list'];
      if (ratios is List && ratios.isNotEmpty && ratios.first is Map) {
        final first = Map<String, dynamic>.from(ratios.first as Map);
        await notifier.updateTransactionAccounts({
          'margin_call_ratio': first['margin_call_ratio'],
          'margin_stop_out_ratio': first['margin_stop_out_ratio'],
        });
      }
    } catch (e) {
      debugPrint('⚠️ getTransactionGroupDetail failed: $e');
    }
  }

  void _markTradeSurfaceReady() {
    if (_tradeSurfaceReady) return;
    _tradeSurfaceReady = true;
    if (_stashedJumpIsBuy != null) {
      _isBuy = _stashedJumpIsBuy!;
      _stashedJumpIsBuy = null;
    }
    final pending = ref.read(tradeJumpNavigationProvider);
    if (pending != null) {
      unawaited(_applyTradeJumpIntent(pending));
    }
  }

  void _onTradeJumpIntent(TradeJumpIntent intent) {
    if (!_tradeSurfaceReady || _isLoading) {
      if (intent.isBuy != null) {
        _stashedJumpIsBuy = intent.isBuy;
      }
      final sym = intent.symbol;
      if (sym != null &&
          sym.isNotEmpty &&
          (_symbolChoices.isEmpty || _symbolChoices.contains(sym))) {
        _selectedSymbol = sym;
      }
      return;
    }
    unawaited(_applyTradeJumpIntent(intent));
  }

  Future<void> _applyTradeJumpIntent(TradeJumpIntent intent) async {
    var needsQuoteRefresh = false;
    var needsSetState = false;

    final sym = intent.symbol;
    if (sym != null &&
        sym.isNotEmpty &&
        (_symbolChoices.isEmpty || _symbolChoices.contains(sym)) &&
        _selectedSymbol != sym) {
      _selectedSymbol = sym;
      needsQuoteRefresh = true;
      needsSetState = true;
    }

    if (intent.isBuy != null && _isBuy != intent.isBuy) {
      _isBuy = intent.isBuy!;
      needsSetState = true;
    }

    if (needsSetState && mounted) {
      setState(() {});
    }
    if (needsQuoteRefresh) {
      await _refreshSymbolQuotes(symbol: sym);
    } else if (needsSetState) {
      _notifyWsTradeSymbol();
    }

    ref.read(tradeJumpNavigationProvider.notifier).clear();
  }

  Future<void> _reloadPendingFirstPage(STService stService) async {
    try {
      final pendingPage = await stService.getPendingOrdersWithTotal(
        offset: 0,
        limit: _kPendingPageSize,
      );
      _pendingOrders = pendingPage.orders
          .whereType<Map<String, dynamic>>()
          .toList();
      _pendingTotalCount = pendingPage.total;
      _pendingPageIndex = 0;
      _pendingHasMore =
          _pendingTotalCount > 0 && _pendingOrders.length < _pendingTotalCount;
      if (_pendingTotalCount <= 0 && _pendingOrders.isNotEmpty) {
        _pendingHasMore = _pendingOrders.length >= _kPendingPageSize;
      }
    } catch (e) {
      debugPrint('⚠️ _reloadPendingFirstPage: $e');
      _pendingOrders = [];
      _pendingTotalCount = 0;
      _pendingPageIndex = 0;
      _pendingHasMore = false;
    }
  }

  Future<void> _refreshTradeLedgers() async {
    if (_isRefreshingLedgers) return;
    _isRefreshingLedgers = true;
    try {
      final stService = ref.read(stServiceProvider);
      final positionsFuture = _safeLoadList(() => stService.getPositions());
      final pendingFuture = stService
          .getPendingOrdersWithTotal(offset: 0, limit: _kPendingPageSize)
          .then((page) => page)
          .catchError((e) {
            debugPrint('⚠️ _refreshTradeLedgers pending: $e');
            return (orders: <dynamic>[], total: 0);
          });
      final positionsRaw = await positionsFuture;
      final pendingPage = await pendingFuture;
      if (!mounted) return;
      setState(() {
        _positions = positionsRaw.whereType<Map<String, dynamic>>().toList();
        _pendingOrders = pendingPage.orders
            .whereType<Map<String, dynamic>>()
            .toList();
        _pendingTotalCount = pendingPage.total;
        _pendingPageIndex = 0;
        _pendingHasMore =
            _pendingTotalCount > 0 &&
            _pendingOrders.length < _pendingTotalCount;
        if (_pendingTotalCount <= 0 && _pendingOrders.isNotEmpty) {
          _pendingHasMore = _pendingOrders.length >= _kPendingPageSize;
        }
        _recalculateTradeDerivedValues();
      });
    } finally {
      _isRefreshingLedgers = false;
    }
  }

  Future<void> _refreshLedgersFromNotification() => _refreshTradeLedgers();

  Future<void> _loadMorePending() async {
    if (_pendingLoadingMore || !_pendingHasMore || _showPositions) return;
    _pendingLoadingMore = true;
    if (mounted) setState(() {});

    try {
      final stService = ref.read(stServiceProvider);
      final nextPage = _pendingPageIndex + 1;
      final pendingPage = await stService.getPendingOrdersWithTotal(
        offset: nextPage * _kPendingPageSize,
        limit: _kPendingPageSize,
      );
      final batch = pendingPage.orders
          .whereType<Map<String, dynamic>>()
          .toList();
      if (batch.isEmpty) {
        _pendingHasMore = false;
      } else {
        _pendingPageIndex = nextPage;
        _pendingOrders.addAll(batch);
        if (pendingPage.total > 0) {
          _pendingTotalCount = pendingPage.total;
        }
        _pendingHasMore = _pendingTotalCount > 0
            ? _pendingOrders.length < _pendingTotalCount
            : batch.length >= _kPendingPageSize;
      }
    } catch (e) {
      debugPrint('⚠️ _loadMorePending: $e');
    } finally {
      _pendingLoadingMore = false;
      if (mounted) setState(() {});
    }
  }

  DateTime _calendarDayOnlyTp(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _iosDefaultValidityCalendarDayTp() {
    final n = DateTime.now();
    return _calendarDayOnlyTp(n).add(const Duration(days: 6));
  }

  int _endOfDayUnixSecondsTp(DateTime calendarDay) {
    final end = DateTime(
      calendarDay.year,
      calendarDay.month,
      calendarDay.day,
      23,
      59,
      59,
    );
    return end.millisecondsSinceEpoch ~/ 1000;
  }

  // ==================== 辅助方法 ====================

  String _fmtMoney(dynamic v) {
    if (v == null || v == '--') return '--';
    final n = (v is num) ? v : double.tryParse(v.toString()) ?? 0;
    return n.toStringAsFixed(2);
  }

  Color _pnlColor(dynamic v) {
    if (v == null) return Colors.grey;
    final n = (v is num) ? v : double.tryParse(v.toString()) ?? 0;
    return n > 0 ? _TradeTheme.rise : (n < 0 ? _TradeTheme.fall : Colors.grey);
  }

  String _moneyWithSign(dynamic v) {
    if (v == null || v.toString() == '--' || v.toString().isEmpty) {
      return '--';
    }
    final n = (v is num) ? v.toDouble() : double.tryParse(v.toString());
    if (n == null) return '--';
    return '${n >= 0 ? '+' : ''}${n.toStringAsFixed(2)}';
  }

  String _volStr(Map<String, dynamic> pos) =>
      pos['volume']?.toString() ?? pos['lots']?.toString() ?? '--';

  /// 与品种切换后刷新 bid/ask
  Future<void> _refreshSymbolQuotes({String? symbol}) async {
    final targetSymbol = (symbol ?? _selectedSymbol).trim();
    if (targetSymbol.isEmpty) return;
    final requestToken = ++_symbolRefreshToken;
    final stService = ref.read(stServiceProvider);
    final payload = await loadTradeSymbolPayloads(stService, targetSymbol);
    if (!mounted ||
        requestToken != _symbolRefreshToken ||
        _selectedSymbol != targetSymbol) {
      return;
    }
    setState(() {
      _extractSymbolBidAsk(
        _mergeSymbolPayloads(payload.symbolInfo, payload.detailInfo),
      );
      _recalculateTradeDerivedValues();
    });
    _notifyWsTradeSymbol();
  }

  int _directionApiIntFromDynamic(dynamic d) {
    if (d == null) return 0;
    if (d is int) return d;
    if (d is num) return d.toInt();
    final s = d.toString().toLowerCase();
    if (s == '1' || s == 'sell') return 1;
    return int.tryParse(s) ?? 0;
  }

  String _dirStr(Map<String, dynamic> pos) {
    final d = pos['direction'];
    if (d == 1 || d == '1' || (d is String && d.toLowerCase() == 'sell')) {
      return 'SELL';
    }
    return 'BUY';
  }

  Color _dirColor(Map<String, dynamic> pos) =>
      _dirStr(pos) == 'BUY' ? _TradeTheme.rise : _TradeTheme.fall;

  List<Map<String, dynamic>> get _visiblePositions {
    return TradeSymbolFilter.visiblePositions(
      _positions,
      isolateCurrentSymbol: _symbolIsolationOn,
      selectedSymbol: _selectedSymbol,
      selectedAlias: _instrumentListingName,
      rememberedTradeSymbol: ref.read(userStateProvider).currentTradeSymbol,
    );
  }

  List<Map<String, dynamic>> get _visiblePending {
    return TradeSymbolFilter.visiblePending(
      _pendingOrders,
      isolateCurrentSymbol: _symbolIsolationOn,
      selectedSymbol: _selectedSymbol,
      selectedAlias: _instrumentListingName,
      rememberedTradeSymbol: ref.read(userStateProvider).currentTradeSymbol,
    );
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    final riseFall = ref.watch(
      userStateProvider.select((s) => s.riseAndFallType),
    );
    CardTool.setRiseAndFallType(riseFall);
    ref.listen<UserState>(userStateProvider, (prev, next) {
      if (prev?.isLogin != next.isLogin && mounted) {
        unawaited(_loadAllData());
      }
    });
    ref.listen<TradeJumpIntent?>(tradeJumpNavigationProvider, (prev, next) {
      if (next == null || next.tick == prev?.tick) return;
      _onTradeJumpIntent(next);
    });

    /// 对齐 iOS/Figma：交易首页是单列全宽下单表单；交互状态仍由原交易页状态机驱动。
    final body = _errorMessage != null && !_isSwitchingTradeAccount
        ? _buildErrorView()
        : _buildContent();
    final showCenteredLoadingHud =
        _isLoading ||
        _isActionRefreshing ||
        tradePageUsesFullscreenLoading(
          isLoading: _isLoading,
          isSwitchingTradeAccount: _isSwitchingTradeAccount,
        );

    final userState = ref.watch(userStateProvider);
    final keyboardFocusNodes = [
      if (_boardOrderType != 'market') _pendingPriceFocus,
      _lotFocus,
      if (userState.profitOn) _takeProfitFocus,
      if (userState.stopLossOn) _stopLossFocus,
    ];

    return STKeyboardActions(
      focusNodes: keyboardFocusNodes,
      child: Scaffold(
        backgroundColor: context.adaptiveSurfacePrimary,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(child: body),
              if (showCenteredLoadingHud) const TradeActionRefreshingHud(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.error_outline, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton.icon(
            onPressed: _loadAllData,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(_text.retry),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      children: [
        _buildInstrumentRibbon(),
        _buildOrderBoard(),
        _buildLedgerSection(),
      ],
    );
  }

  // ==================== ① 品种胶囊 ====================

  /// 顶栏品种名（Figma：保留 `BTC/USDT` 斜杠；无展示名时用 `_selectedSymbol`）。
  String _ribbonSymbolTitle() {
    final raw = _instrumentListingName.isNotEmpty
        ? _instrumentListingName
        : _selectedSymbol;
    return raw.trim();
  }

  Widget _buildInstrumentRibbon() {
    final loggedIn = ref.watch(
      userStateProvider.select((s) => s.isExplicitlyLoggedIn),
    );
    final title = _ribbonSymbolTitle();
    final accountLabel = loggedIn
        ? tradeAccountDisplayLabel(
            type: _currentAccountType,
            rawLabel: _accountTypeLabel,
            text: _text.t,
          )
        : _text.t('please_login_account');

    return TradeIosInstrumentHeader(
      title: title,
      accountLabel: accountLabel,
      isBuy: _isBuy,
      loggedIn: loggedIn,
      onTapSymbol: _showSymbolPicker,
      onTapDetail: () => _pushMarketDetail(_selectedSymbol),
      onTapAccount: () {
        if (!loggedIn) {
          context.push('/login');
          return;
        }
        _showAccountSwitcherSheet();
      },
      detailTooltip: _text.t('chart'),
    );
  }

  /// iOS `tradeHome:presentAccountSwitcherFrom:` — 底部 Sheet + 「管理」入口。
  Future<void> _showAccountSwitcherSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return TradeAccountSwitcherSheet(
          accounts: _tradeAccounts,
          currentAccountId: _currentAccountId,
          onManage: () {
            Navigator.pop(ctx);
            context.push('/mine/accountmanager');
          },
          onSelect: (account) async {
            Navigator.pop(ctx);
            await _switchTradeAccount(account);
          },
        );
      },
    );
  }

  Future<void> _switchTradeAccount(Map<String, dynamic> account) async {
    final entry = TradeAccountEntry.fromMap(account);
    try {
      final accountId = entry.id;
      if (accountId.isEmpty) return;
      logTradeAccountSwitchDebug(
        'trade_page_select',
        tradeAccountSwitchDebugSnapshot(account, entry),
      );
      if (mounted) {
        setState(() {
          _isSwitchingTradeAccount = true;
          _isLoading = false;
          _errorMessage = null;
        });
      }
      await _runWithActionRefreshing(() async {
        final stService = ref.read(stServiceProvider);
        final switchResponse = await stService.switchTradeAccount(
          entry.switchPayload,
        );
        logTradeAccountSwitchDebug(
          'trade_page_switch_response',
          tradeAccountSwitchResponseDebugSnapshot(switchResponse),
        );
        final userNotifier = ref.read(userStateProvider.notifier);
        await userNotifier.applyChangeAccountSuccessPayload(
          stService,
          switchResponse,
        );
        await userNotifier.refreshProfileAfterLogin(stService);
        EventBus().emit(EventBus.accountChanged);
        await _loadAllData(showBlockingLoading: false);
      });
      if (!mounted) return;
      logTradeAccountSwitchDebug('trade_page_current_confirm', {
        'selected_id': entry.id,
        'current_id': _currentAccountId,
        'current_type': _currentAccountType,
        'current_label': _accountTypeLabel,
        'global_transaction_account': ref
            .read(userStateProvider)
            .transactionAccount,
        'success': _currentAccountId == entry.id,
      });
      _toast(
        tradeAccountSwitchToastForCurrentResult(
          selectedAccountId: entry.id,
          currentAccountId: _currentAccountId,
          failed: false,
          successLabel: _text.t('account_switch_success'),
          failedLabel: _text.t('account_switch_failed'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      logTradeAccountSwitchDebug('trade_page_error', {
        'selected_id': entry.id,
        'current_id': _currentAccountId,
        'error': e.toString(),
      });
      setState(() => _isLoading = false);
      _toast(
        tradeAccountSwitchToastForCurrentResult(
          selectedAccountId: account['id']?.toString() ?? '',
          currentAccountId: _currentAccountId,
          failed: true,
          successLabel: _text.t('account_switch_success'),
          failedLabel: _text.t('account_switch_failed'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSwitchingTradeAccount = false);
    }
  }

  bool get _isCryptoSymbol =>
      _symbolGroup.toLowerCase() == 'crypto' ||
      _selectedSymbol.toUpperCase().contains('USDT');

  /// 品种选择（对齐 iOS `STMarketDetailProductsController`：搜索 + 分类 Tab）
  void _showSymbolPicker() {
    MarketProductPickerSheet.show(
      context,
      ref,
      selectedSymbol: _selectedSymbol,
      onPick: (symbol) async {
        if (!mounted) return;
        setState(() {
          _selectedSymbol = symbol;
          _selectedLot = '';
          _takeProfitExpected = '--';
          _stopLossExpected = '--';
          _lotController.clear();
          _resetPendingPriceToNativeDefault();
          _takeProfitController.clear();
          _stopLossController.clear();
        });
        ref
            .read(userStateProvider.notifier)
            .rememberTradeSelection(symbol: symbol, lot: '');
        await _refreshSymbolQuotes(symbol: symbol);
      },
    );
  }

  // ==================== ② 下单板（Order Board） ====================
  /// 对齐 iOS STTHBoardTableCell boardRows 顺序与结构

  Widget _buildOrderBoard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOrderSideToggle(),
        const SizedBox(height: 14),
        _buildOrderTypeDropdownRow(),
        const SizedBox(height: 14),
        if (_boardOrderType != 'market') ...[
          _buildPendingPriceStepper(),
          const SizedBox(height: 14),
        ],
        _buildVolumeLadderBlock(),
        if (_canSignalProvider) ...[
          const SizedBox(height: 5),
          _buildSignalProviderSwitch(),
        ],
        const SizedBox(height: 14),
        _buildTPSLCheckboxSection(),
        if (_boardOrderType != 'market') ...[
          const SizedBox(height: 20),
          _buildBoardValidityRow(),
        ],
        const SizedBox(height: 32),
        _buildSubmitBanner(),
      ],
    );
  }

  /// 2a. Buy / Sell（对齐 `STTHBidAskModeView`：白外壳胶囊 + 中间点差徽章）
  Widget _buildOrderSideToggle() {
    void selectSide(bool buy) {
      setState(() {
        _isBuy = buy;
        _resetPendingPriceToNativeDefault();
        _takeProfitController.clear();
        _stopLossController.clear();
        _recalculateTradeDerivedValues();
      });
    }

    return TradeIosBidAskToggle(
      isBuy: _isBuy,
      askPrice: _askPrice,
      bidPrice: _bidPrice,
      spread: _priceSpread,
      onSelectBuy: () => selectSide(true),
      onSelectSell: () => selectSide(false),
      buyLabel: _text.t('buy'),
      sellLabel: _text.t('sell'),
    );
  }

  /// 2b. 订单类型（对齐 `STTradeHomeCell` 市价单下拉宽按钮）
  Widget _buildOrderTypeDropdownRow() {
    String label;
    switch (_boardOrderType) {
      case 'limit':
        label = _text.t('limit_order');
      case 'stop':
        label = _text.t('stop_order');
      default:
        label = _text.t('market_order');
    }
    return TradeIosOrderTypeButton(
      label: label,
      onTap: () => _showOrderTypePicker(),
    );
  }

  Future<void> _showOrderTypePicker() async {
    final idx = switch (_boardOrderType) {
      'limit' => 1,
      'stop' => 2,
      _ => 0,
    };
    final selected = await showTradePriceModeSheet(
      context: context,
      selectedIndex: idx,
    );
    if (selected == null || !mounted) return;
    setState(() {
      final wasMarket = _boardOrderType == 'market';
      _boardOrderType = switch (selected) {
        1 => 'limit',
        2 => 'stop',
        _ => 'market',
      };
      if (wasMarket && _boardOrderType != 'market') {
        _boardPendingValidityDay = _calendarDayOnlyTp(
          _iosDefaultValidityCalendarDayTp(),
        );
      }
      _resetPendingPriceToNativeDefault();
      _takeProfitController.clear();
      _stopLossController.clear();
      _recalculateTradeDerivedValues();
    });
  }

  Future<void> _showRegistrationModePicker() async {
    final keyContext = _registrationModeMenuKey.currentContext;
    final renderObject = keyContext?.findRenderObject();
    if (renderObject is! RenderBox) return;

    final topLeft = renderObject.localToGlobal(Offset.zero);
    final anchorRect = Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy + renderObject.size.height + 4,
      math.max(renderObject.size.width, 96),
      68,
    );
    final selected = await showTradeRegistrationModePopup(
      context: context,
      anchorRect: anchorRect,
      currentMode: _boardOrderType == 'stop'
          ? TradeRegistrationMode.stop
          : TradeRegistrationMode.limit,
    );
    if (selected == null || !mounted) return;

    setState(() {
      _boardOrderType = selected == TradeRegistrationMode.stop
          ? 'stop'
          : 'limit';
      _resetPendingPriceToNativeDefault();
      _takeProfitController.clear();
      _stopLossController.clear();
      _recalculateTradeDerivedValues();
    });
  }

  /// 手数（对齐 `STTradeLotsView`：stepper + 快捷手数 chips + 保证金行）
  Widget _buildVolumeLadderBlock() {
    final loggedIn = ref.watch(userStateProvider.select((s) => s.isLogin));
    final lotOutOfRange = _isLotOutOfRange();
    final lotTitle = _isCryptoSymbol
        ? '${_text.t('lots').replaceAll(RegExp(r'\s*\([^)]*\)'), '')}(${_cryptoUnit()})'
        : _text.t('lots');
    final marginText = loggedIn ? _marginOccupation : '0';
    final freeMarginText = loggedIn ? _fmtMoney(_freeMargin) : '0.00';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TradeIosStepperField(
          title: lotTitle,
          range: _lotRangeHint,
          controller: _lotController,
          focusNode: _lotFocus,
          buttonChrome: TradeIosStepperButtonChrome.circleOutline,
          valueColor: lotOutOfRange
              ? _TradeTheme.fall
              : context.adaptiveTextPrimary,
          onMinus: () => _nudgeLot(-1),
          onPlus: () => _nudgeLot(1),
          onChanged: (v) {
            setState(() {
              _selectedLot = v.trim();
              _recalculateTradeDerivedValues();
            });
          },
          onSubmitted: (v) {
            final next = _formatDownToStep(
              v,
              _stepLot > _minLot ? _minLot : _stepLot,
            );
            setState(() {
              _selectedLot = next;
              _lotController.text = next;
              _recalculateTradeDerivedValues();
            });
          },
          hintText: _text.t('no_setting'),
        ),
        const SizedBox(height: 8),
        if (_lotLadder.isNotEmpty) ...[
          TradeIosLotQuickButtons(
            lots: _lotLadder,
            selectedLot: _selectedLot,
            onSelect: (lot) => setState(() {
              _selectedLot = lot;
              _lotController.text = lot;
              _recalculateTradeDerivedValues();
            }),
          ),
        ],
        TradeIosMarginSummaryRow(
          margin: marginText,
          marginUnit: _currencyMargin,
          freeMargin: freeMarginText,
          freeMarginUnit: _accountCurrency,
          freeMarginLabel: _text.t('free_margin'),
          marginLabel: _text.t('margin_deposit'),
          onAddFunds: () {
            unawaited(_openDepositWithPreflight());
          },
        ),
      ],
    );
  }

  String _cryptoUnit() {
    final s = _selectedSymbol.trim();
    final i = s.indexOf('/');
    if (i <= 0 || i >= s.length - 1) return _text.t('hand');
    return s.substring(0, i).toUpperCase();
  }

  void _nudgeLot(int direction) {
    final current = _toDouble(_selectedLot, fallback: _minLot);
    final step = _stepLot > 0 ? _stepLot : _minLot;
    final next = (current + direction * step).clamp(_minLot, _maxLot);
    final text = _formatDownToStep(next, step);
    setState(() {
      _selectedLot = text;
      _lotController.text = text;
      _recalculateTradeDerivedValues();
    });
  }

  Widget _stepperButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final strokeColor = enabled
        ? (context.adaptiveIsDark
              ? TradeIosChromeColors.darkControlText
              : TradeIosChromeColors.labelDark)
        : context.adaptiveTextHint;
    return SizedBox(
      width: 44,
      height: 40,
      child: Center(
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          behavior: HitTestBehavior.opaque,
          child: Container(
            key: ValueKey(
              icon == Icons.remove
                  ? 'trade-ios-stepper-circle-button-minus'
                  : 'trade-ios-stepper-circle-button-plus',
            ),
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: strokeColor),
            ),
            child: Icon(icon, size: 14, color: strokeColor),
          ),
        ),
      ),
    );
  }

  /// 止盈止损
  Widget _buildTPSLCheckboxSection() {
    final profitOn = ref.watch(userStateProvider.select((s) => s.profitOn));
    final stopLossOn = ref.watch(userStateProvider.select((s) => s.stopLossOn));
    final profitOutOfRange = _isTpslOutOfRange(
      _takeProfitController.text,
      _takeProfitMinPrice,
      _takeProfitMaxPrice,
    );
    final stopLossOutOfRange = _isTpslOutOfRange(
      _stopLossController.text,
      _stopLossMinPrice,
      _stopLossMaxPrice,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TradeIosTpslRow(
          label: _text.t('take_profit'),
          range: _takeProfitRange,
          enabled: profitOn,
          checkboxKey: const ValueKey('trade-ios-tpsl-checkbox-take-profit'),
          controller: _takeProfitController,
          focusNode: _takeProfitFocus,
          valueColor: profitOutOfRange
              ? _TradeTheme.fall
              : context.adaptiveTextPrimary,
          expectedProfit: _moneyWithSign(_takeProfitExpected),
          onToggle: (v) {
            if (_signalProviderOn) {
              ref.read(userStateProvider.notifier).updateProfitOn(true);
            } else {
              ref.read(userStateProvider.notifier).updateProfitOn(v);
            }
            setState(() {});
          },
          onHelp: () => _showTradeHelpSheet(
            _text.t('stop_loss_and_take_profit'),
            _text.t('profile_loss_type_description'),
          ),
          onMinus: () => _nudgeTpslPrice(_takeProfitController, -1),
          onPlus: () => _nudgeTpslPrice(_takeProfitController, 1),
          onChanged: (_) {
            _recalculateExpectedProfit();
            setState(() {});
          },
          hintText: _text.t('no_setting'),
          expectedProfitLabel: _text.t('estimated_profit_loss'),
        ),
        const SizedBox(height: 15),
        TradeIosTpslRow(
          label: _text.t('stop_loss'),
          range: _stopLossRange,
          enabled: stopLossOn,
          checkboxKey: const ValueKey('trade-ios-tpsl-checkbox-stop-loss'),
          controller: _stopLossController,
          focusNode: _stopLossFocus,
          valueColor: stopLossOutOfRange
              ? _TradeTheme.fall
              : context.adaptiveTextPrimary,
          expectedProfit: _moneyWithSign(_stopLossExpected),
          onToggle: (v) {
            if (_signalProviderOn) {
              ref.read(userStateProvider.notifier).updateStopLossOn(true);
            } else {
              ref.read(userStateProvider.notifier).updateStopLossOn(v);
            }
            setState(() {});
          },
          onHelp: () => _showTradeHelpSheet(
            _text.t('stop_loss_and_take_profit'),
            _text.t('profile_loss_type_description'),
          ),
          onMinus: () => _nudgeTpslPrice(_stopLossController, -1),
          onPlus: () => _nudgeTpslPrice(_stopLossController, 1),
          onChanged: (_) {
            _recalculateExpectedProfit();
            setState(() {});
          },
          hintText: _text.t('no_setting'),
          expectedProfitLabel: _text.t('estimated_profit_loss'),
        ),
      ],
    );
  }

  bool _isTpslOutOfRange(String current, double minPrice, double maxPrice) {
    final trimmed = current.trim();
    if (trimmed.isEmpty || minPrice <= 0 || maxPrice <= 0) return false;
    final currentValue = _toDouble(trimmed);
    return currentValue < minPrice || currentValue > maxPrice;
  }

  void _showTradeHelpSheet(String title, String message) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.adaptiveCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.adaptiveTextPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: context.adaptiveTextTertiary,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B57A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: Text(_text.t('i_see')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _nudgeTpslPrice(TextEditingController c, int dir) {
    final raw = c.text.trim();
    final v = double.tryParse(raw.replaceAll(',', '')) ?? 0;
    const step = 0.1;
    final next = (v + dir * step).clamp(0, 1e12);
    final s = raw.contains('.')
        ? next.toStringAsFixed(5).replaceFirst(RegExp(r'\.?0+$'), '')
        : next.toStringAsFixed(0);
    c.text = s;
    setState(() => _recalculateExpectedProfit());
  }

  /// 提交条 + 保证金水平（`STTHOrderSubmitSummaryView`）
  Widget _buildSubmitBanner() {
    final loggedIn = ref.watch(userStateProvider.select((s) => s.isLogin));
    final primary = _isBuy ? _TradeTheme.rise : _TradeTheme.fall;
    final overLots = _isLotOutOfRange();
    final disabled =
        _isSubmittingTrade ||
        _isSwitchingTradeAccount ||
        _isTradeBlockedByMode() ||
        overLots ||
        (loggedIn && _currentAccountId.isEmpty);
    final visualDim = disabled || !_isInTradeTime;

    return TradeIosSubmitArea(
      marginLevel: _marginLevel == '--' ? '--' : _marginLevel,
      actionLabel: _isBuy ? _text.t('buy') : _text.t('sell'),
      color: primary,
      enabled: !disabled,
      dimmed: visualDim,
      isLoading: _isSubmittingTrade,
      warning: overLots ? _text.t('out_of_range') : null,
      marginLevelLabel: _text.t('margin_level'),
      onHelp: () => TradeMarginHelpSheet.showHelp(
        context,
        ref,
        marginLevelDisplay: _marginLevel,
      ),
      onSubmit: disabled ? null : _confirmTrade,
    );
  }

  /// 2d. 带单开关（信号源）
  Widget _buildSignalProviderSwitch() {
    return SizedBox(
      height: 31,
      child: Row(
        children: [
          TradeIosSwitchSlot(
            value: _signalProviderOn,
            onChanged: (v) {
              if (v) {
                ref.read(userStateProvider.notifier).updateProfitOn(true);
                ref.read(userStateProvider.notifier).updateStopLossOn(true);
              }
              setState(() {
                _signalProviderOn = v;
                _recalculateTradeDerivedValues();
              });
            },
          ),
          Text(
            _text.t('bring_single'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.adaptiveTextTertiary,
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            icon: const Icon(
              Icons.info_outline,
              size: 16,
              color: _TradeTheme.labelMuted,
            ),
            onPressed: () => _showTradeHelpSheet(
              _text.t('bring_single'),
              _text.t('bring_single'),
            ),
          ),
        ],
      ),
    );
  }

  /// 挂单价步进输入（对齐 `STTradePriceView` / `STTradeStepperView`）
  Widget _buildPendingPriceStepper() {
    final label = _boardOrderType == 'limit'
        ? _text.t('limit_order')
        : _text.t('stop_order');
    final range = _pendingPriceRangeText();
    final current = _pendingPriceController.text.trim();
    final currentPrice = _toDouble(current);
    final outOfRange =
        current.isNotEmpty &&
        _pendingMinPrice > 0 &&
        _pendingMaxPrice > 0 &&
        (currentPrice < _pendingMinPrice || currentPrice > _pendingMaxPrice);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            children: [
              GestureDetector(
                key: _registrationModeMenuKey,
                behavior: HitTestBehavior.opaque,
                onTap: _showRegistrationModePicker,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.adaptiveTextTertiary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: context.adaptiveTextSecondary,
                    ),
                  ],
                ),
              ),
              if (range.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  range,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.adaptiveTextSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Container(
            key: const ValueKey('trade-pending-price-bg'),
            height: 44,
            decoration: BoxDecoration(
              color: context.adaptiveMutedBlock,
              borderRadius: tradeCapsuleBorderRadius(44),
            ),
            child: Row(
              children: [
                _stepperButton(
                  icon: Icons.remove,
                  enabled: true,
                  onTap: () => _nudgePendingPrice(-1),
                ),
                Expanded(
                  child: TextField(
                    key: const ValueKey('trade-pending-price-input'),
                    controller: _pendingPriceController,
                    focusNode: _pendingPriceFocus,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: outOfRange
                          ? _TradeTheme.fall
                          : context.adaptiveTextPrimary,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: _text.t('no_setting'),
                      hintStyle: TextStyle(
                        fontSize: 16,
                        color: context.adaptiveTextSecondary,
                      ),
                    ),
                    onChanged: (_) {
                      setState(() {
                        _pendingPriceUserEdited = true;
                        _recalculateTradeDerivedValues();
                      });
                    },
                  ),
                ),
                _stepperButton(
                  icon: Icons.add,
                  enabled: true,
                  onTap: () => _nudgePendingPrice(1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _nudgePendingPrice(int direction) {
    final fallback = _defaultPendingPrice();
    final current = _toDouble(
      _pendingPriceController.text.trim().isEmpty
          ? fallback
          : _pendingPriceController.text,
    );
    final next = math.max(
      0,
      current + direction * (_point > 0 ? _point : 0.0001),
    );
    setState(() {
      _pendingPriceController.text = _formatDownToStep(next, _point);
      _recalculateTradeDerivedValues();
    });
  }

  String _pendingPriceRangeText() {
    if (_pendingMinPrice <= 0 || _pendingMaxPrice <= 0) return '';
    if (_boardOrderType == 'limit') {
      return _isBuy
          ? '<= ${_formatPriceByPoint(_pendingMaxPrice)}'
          : '>= ${_formatPriceByPoint(_pendingMinPrice)}';
    }
    return _isBuy
        ? '>= ${_formatPriceByPoint(_pendingMinPrice)}'
        : '<= ${_formatPriceByPoint(_pendingMaxPrice)}';
  }

  Future<void> _pickBoardValidityDate() async {
    final today = _calendarDayOnlyTp(DateTime.now());
    final initial = _boardPendingValidityDay.isBefore(today)
        ? today
        : _boardPendingValidityDay;
    final picked = await showIosDatePickerSheet(
      context: context,
      initialDate: initial,
      minimumDate: today,
      maximumDate: DateTime(2050, 12, 30),
    );
    if (picked != null) {
      setState(() => _boardPendingValidityDay = _calendarDayOnlyTp(picked));
    }
  }

  /// 挂单模式：有效期（对齐 iOS 下单板）
  Widget _buildBoardValidityRow() {
    return InkWell(
      onTap: _pickBoardValidityDate,
      child: SizedBox(
        height: 49,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 0, 13, 0),
          child: Row(
            children: [
              Text(
                _text.t('select_validity_period'),
                style: TextStyle(
                  fontSize: 13,
                  color: context.adaptiveTextPrimary,
                ),
              ),
              const Spacer(),
              Text(
                formatIosYmd(
                  _boardPendingValidityDay,
                  languageCode: languageCodeFromLocale(
                    Localizations.localeOf(context),
                  ),
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.adaptiveTextPrimary,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_right_rounded,
                size: 20,
                color: context.adaptiveTextSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== ③ 持仓/挂单分页 ====================

  Widget _buildLedgerSection() {
    final loggedIn = ref.watch(userStateProvider.select((s) => s.isLogin));
    final posCount = !loggedIn
        ? 0
        : (_symbolIsolationOn ? _visiblePositions.length : _positions.length);
    final pendCount = !loggedIn ? 0 : _pendingTotalCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TradeIosLedgerTabs(
          positionLabel: '${_text.t('positions')} ($posCount)',
          pendingLabel: '${_text.t('pending_orders')} ($pendCount)',
          positionsSelected: _showPositions,
          onSelectPositions: () => setState(() => _showPositions = true),
          onSelectPending: () => setState(() => _showPositions = false),
          onOpenManager: () {
            if (!ref.read(userStateProvider).isLogin) {
              context.push('/login');
              return;
            }
            context.push(tradeHomeAccountProfileLocation());
          },
          managerTooltip:
              '${_text.t('positions')} / ${_text.t('pending_orders')}',
        ),
        _buildShowCurrentRow(),
        if (_showPositions) _buildPositionList() else _buildPendingList(),
      ],
    );
  }

  Widget _buildShowCurrentRow() {
    return InkWell(
      onTap: () => setState(() => _symbolIsolationOn = !_symbolIsolationOn),
      child: Padding(
        padding: const EdgeInsets.only(top: 7),
        child: SizedBox(
          height: 32,
          child: Row(
            children: [
              TradeIosSwitchSlot(
                value: _symbolIsolationOn,
                onChanged: (v) => setState(() => _symbolIsolationOn = v),
              ),
              Text(
                _text.t('show_current_trading_pairs'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF656B78),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- 持仓列表 ----

  Widget _buildPositionList() {
    final loggedIn = ref.watch(userStateProvider.select((s) => s.isLogin));
    if (!loggedIn) {
      return _ledgerLoginEmpty(positions: true);
    }
    if (_visiblePositions.isEmpty) {
      return _emptyLedger(_text.t('no_holder_positions'));
    }
    return Column(
      children: [
        ..._visiblePositions.map(
          (pos) => _buildTradeAccountDetailRow(pos, isPosition: true),
        ),
      ],
    );
  }

  // ---- 挂单列表 ----

  Widget _buildPendingList() {
    final loggedIn = ref.watch(userStateProvider.select((s) => s.isLogin));
    if (!loggedIn) {
      return _ledgerLoginEmpty(positions: false);
    }
    if (_visiblePending.isEmpty) {
      return _emptyLedger(_text.t('no_pending_orders'));
    }
    return Column(
      children: [
        ..._visiblePending.map(
          (order) => _buildTradeAccountDetailRow(order, isPosition: false),
        ),
        if (_pendingLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTradeAccountDetailRow(
    Map<String, dynamic> order, {
    required bool isPosition,
  }) {
    final cellType = isPosition
        ? TradeAccountDetailCellType.position
        : TradeAccountDetailCellType.pending;
    final title = tradeAccountDetailTitle(order, cellType);
    final alias = tradeAccountDetailAlias(order);
    final dirColor = _dirColor(order);
    final profit = order['profit'] ?? order['pnl'] ?? 0;
    final created = tradeAccountPendingTrailingTimeText(order);
    final sign = tradeAccountDetailSign(order);

    final metrics = isPosition
        ? [
            MapEntry(
              _text.t('open_price_title'),
              tradeAccountPositionOpenPriceText(order),
            ),
            MapEntry(
              _text.t('last_price_title'),
              tradeAccountCurrentPriceText(order),
            ),
            MapEntry(_text.t('take_profit'), tradeAccountTakeProfitText(order)),
            MapEntry(_text.t('stop_loss'), tradeAccountStopLossText(order)),
          ]
        : [
            MapEntry(
              _text.t('entrust_price'),
              tradeAccountPendingPriceText(order),
            ),
            MapEntry(
              _text.t('last_price_title'),
              tradeAccountCurrentPriceText(order),
            ),
            MapEntry(_text.t('take_profit'), tradeAccountTakeProfitText(order)),
            MapEntry(_text.t('stop_loss'), tradeAccountStopLossText(order)),
          ];

    final metricWidgets = <Widget>[
      for (var i = 0; i < metrics.length; i++)
        Expanded(
          child: _metricColumn(
            label: metrics[i].key,
            value: metrics[i].value,
            alignment: switch (i) {
              0 => _CellFieldAlignment.start,
              3 => _CellFieldAlignment.end,
              _ => _CellFieldAlignment.center,
            },
          ),
        ),
    ];

    final actionButtons = isPosition
        ? [
            _ledgerTextButton(
              _text.t('chart'),
              () => _chartForPosition(order),
              key: const ValueKey('trade-ledger-position-chart'),
            ),
            const SizedBox(width: 10),
            _ledgerTextButton(
              _text.t('stop_loss_and_take_profit'),
              () => _editTPSL(order),
              key: const ValueKey('trade-ledger-position-tpsl'),
            ),
            const SizedBox(width: 10),
            _ledgerTextButton(
              _text.t('close_a_position'),
              () => _closePosition(order),
              key: const ValueKey('trade-ledger-position-close'),
            ),
          ]
        : [
            _ledgerTextButton(
              _text.t('cancel_order'),
              () => _cancelPending(order),
              key: const ValueKey('trade-ledger-pending-cancel'),
            ),
            const SizedBox(width: 10),
            _ledgerTextButton(
              _text.t('modify'),
              () => _modifyPending(order),
              key: const ValueKey('trade-ledger-pending-modify'),
            ),
          ];

    return GestureDetector(
      onTap: () => _openOrderDetail(order, isPosition: isPosition),
      child: ColoredBox(
        color: context.adaptiveSurfacePrimary,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: context.adaptiveTextPrimary,
                                ),
                              ),
                            ),
                            if (alias.isNotEmpty) ...[
                              const SizedBox(width: 5),
                              Text(
                                alias,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.adaptiveTextSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isPosition)
                        Text(
                          tradeAccountDetailProfitText(profit),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _pnlColor(profit),
                          ),
                        )
                      else
                        Text(
                          created,
                          style: TextStyle(
                            fontSize: 10,
                            color: context.adaptiveTextSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _directionBadge(
                        tradeAccountDetailDirectionText(
                          order,
                          labels: _detailLabels,
                        ),
                        dirColor,
                      ),
                      const SizedBox(width: 5),
                      _lotsBadge(order),
                      if (sign != null) ...[
                        const SizedBox(width: 5),
                        _tradeSignChip(sign),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(children: metricWidgets),
                  const SizedBox(height: 14),
                  Row(children: actionButtons),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              indent: 15,
              endIndent: 15,
              color: context.adaptiveDivider,
            ),
          ],
        ),
      ),
    );
  }

  Widget _directionBadge(String text, Color color) {
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }

  Widget _lotsBadge(Map<String, dynamic> order) {
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.adaptiveMutedBlock,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        tradeAccountDetailLotText(order, labels: _detailLabels),
        style: TextStyle(fontSize: 12, color: context.adaptiveTextTertiary),
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

  Widget _metricColumn({
    required String label,
    required String value,
    _CellFieldAlignment alignment = _CellFieldAlignment.start,
  }) {
    final crossAxisAlignment = switch (alignment) {
      _CellFieldAlignment.start => CrossAxisAlignment.start,
      _CellFieldAlignment.center => CrossAxisAlignment.center,
      _CellFieldAlignment.end => CrossAxisAlignment.end,
    };
    final textAlign = switch (alignment) {
      _CellFieldAlignment.start => TextAlign.left,
      _CellFieldAlignment.center => TextAlign.center,
      _CellFieldAlignment.end => TextAlign.right,
    };
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          label,
          textAlign: textAlign,
          style: TextStyle(fontSize: 12, color: context.adaptiveTextSecondary),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.adaptiveTextTertiary,
          ),
        ),
      ],
    );
  }

  Widget _ledgerTextButton(String label, VoidCallback onTap, {Key? key}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          key: key,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.adaptiveMutedBlock,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _TradeTheme.labelDark,
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyLedger(String msg) {
    return ColoredBox(
      color: context.adaptiveCard,
      child: TradeNoRecordsEmpty(message: msg),
    );
  }

  /// 未登录占位（对齐产品稿「登录查看持仓/挂单」）
  Widget _ledgerLoginEmpty({required bool positions}) {
    return _emptyLedger(
      positions ? _text.t('no_holder_positions') : _text.t('no_pending_orders'),
    );
  }

  // ==================== 登录守卫 ====================

  /// 检查登录态，未登录则跳转登录页
  bool _requireLogin() {
    if (!ref.read(userStateProvider).isLogin) {
      context.push('/login');
      return false;
    }
    return true;
  }

  Future<void> _openDepositWithPreflight() async {
    if (!_requireLogin()) return;
    context.push(_depositRoute);
  }

  // ==================== 操作 ====================

  void _toast(String message) {
    if (!mounted) return;
    STToast.show(context, message);
  }

  Future<void> _showActionFailedSheet({
    required String title,
    required String reason,
  }) {
    return showTradeActionFailedDialog(
      context: context,
      title: title,
      reason: reason,
    );
  }

  bool _isSystemBusyCode(Map<String, dynamic> response) {
    final code = response['code'];
    return code == 200162 ||
        (code is num && code.toInt() == 200162) ||
        code?.toString() == '200162';
  }

  void _pushTradeActionResult({
    required Map<String, dynamic> response,
    required String actionType,
    required bool isProgress,
    required int direction,
    required String lots,
    String? price,
    int? expireTime,
  }) {
    final payload = <String, dynamic>{...response};
    payload['symbol'] = payload['symbol'] ?? _selectedSymbol;
    payload['symbol_alias'] = payload['symbol_alias'] ?? _instrumentListingName;
    payload['lots'] = payload['lots'] ?? lots;
    payload['direction'] = payload['direction'] ?? direction;
    payload['symbol_group'] = payload['symbol_group'] ?? _symbolGroup;
    if (price != null) {
      payload['price'] = payload['price'] ?? price;
    }
    if (expireTime != null) {
      payload['expire_time'] = payload['expire_time'] ?? expireTime;
    }
    context.push(
      '/trade/action_result?type=$actionType&progress=${isProgress ? 1 : 0}',
      extra: payload,
    );
  }

  String _normalizedLot() {
    final editing = _lotController.text.trim();
    final raw = editing.isNotEmpty
        ? editing
        : (_selectedLot.trim().isEmpty ? _minLot.toString() : _selectedLot);
    final lotStep = _stepLot > _minLot ? _minLot : _stepLot;
    return _formatDownToStep(raw, lotStep <= 0 ? 0.01 : lotStep);
  }

  bool _isLotOutOfRange() {
    if (!_hasLotProfile) return false;
    final raw = _lotController.text.trim().isNotEmpty
        ? _lotController.text.trim()
        : _selectedLot.trim();
    if (raw.isEmpty) return false;
    final lot = _toDouble(raw, fallback: double.nan);
    if (lot.isNaN) return false;
    return lot > _effectiveMaxLot || lot < _minLot;
  }

  bool _isTradeBlockedByMode() {
    switch (_tradeMode) {
      case '0':
      case '3':
        return true;
      case '1':
        return !_isBuy;
      case '2':
        return _isBuy;
      case '4':
      default:
        return false;
    }
  }

  String _defaultPendingPrice() {
    if (_pendingMinPrice > 0 && _pendingMaxPrice > 0) {
      if (_boardOrderType == 'limit') {
        return (_isBuy ? _pendingMaxPrice : _pendingMinPrice).toStringAsFixed(
          _decimalPlacesForStep(_point.toString()),
        );
      }
      return (_isBuy ? _pendingMinPrice : _pendingMaxPrice).toStringAsFixed(
        _decimalPlacesForStep(_point.toString()),
      );
    }
    final quote = _isBuy ? _askPrice : _bidPrice;
    return quote == '--' ? '' : _formatDownToStep(quote, _point);
  }

  String _pendingPriceForSubmit() {
    final typed = _pendingPriceController.text.trim();
    if (typed.isNotEmpty) return _formatDownToStep(typed, _point);
    if (_pendingPriceUserEdited) return '';
    final fallback = _defaultPendingPrice();
    return fallback;
  }

  bool _validateTradeBeforeSubmit() {
    final user = ref.read(userStateProvider);
    if (!user.isLogin) {
      context.push('/login');
      return false;
    }
    if (!tradeAccountReadyForSubmit(
      isSwitching: _isSwitchingTradeAccount,
      currentAccountId: _currentAccountId,
      transactionAccount: user.transactionAccount,
    )) {
      _toast(_text.t('account_switching'));
      unawaited(_loadAllData(showBlockingLoading: false));
      return false;
    }
    if (!_isInTradeTime) {
      _toast(_text.t('market_closed'));
      return false;
    }
    if (_isTradeBlockedByMode()) {
      _toast(_text.t('trade_unavailable'));
      return false;
    }
    final requiresOpenVerification = tradeOpenKycVerificationRequired(
      transactionAccountType: user.transactionAccountType,
      currentAccountType: _currentAccountType,
    );
    if (requiresOpenVerification && !user.isAuthed) {
      _toast(_text.t('finish_real_name_before_trade'));
      return false;
    }
    if (requiresOpenVerification && !user.isBindFundPassword) {
      _toast(_text.t('set_fund_password_before_trade'));
      return false;
    }
    if (user.transactionAccountType == '0' &&
        user.transactionAccountIsActive == '0') {
      _toast(_text.t('deposit_to_activate_real_account'));
      return false;
    }
    if (requiresOpenVerification && _isLevelChangeTradeOpenBlocked(user)) {
      unawaited(showTradeNoLimitSheet(context: context));
      return false;
    }
    if (ref.read(marketWebSocketProvider).state !=
        WSConnectionState.connected) {
      _toast(_text.t('network_disconnected'));
      return false;
    }

    if (_isLotOutOfRange()) {
      _toast(_text.t(_isCryptoSymbol ? 'number_out_of_range' : 'out_of_range'));
      return false;
    }

    if (_boardOrderType != 'market') {
      final price = _toDouble(_pendingPriceForSubmit());
      if (price <= 0) {
        _toast(_text.t('price_out_of_range'));
        return false;
      }
      if (_pendingMinPrice > 0 &&
          _pendingMaxPrice > 0 &&
          (price < _pendingMinPrice || price > _pendingMaxPrice)) {
        _toast(_text.t('price_out_of_range'));
        return false;
      }
    }
    if (user.profitOn && _takeProfit.trim().isNotEmpty) {
      final price = _toDouble(_takeProfit.trim());
      if (_takeProfitMinPrice > 0 &&
          _takeProfitMaxPrice > 0 &&
          (price < _takeProfitMinPrice || price > _takeProfitMaxPrice)) {
        _toast(_text.t('profit_out_of_range'));
        return false;
      }
    }
    if (user.stopLossOn && _stopLoss.trim().isNotEmpty) {
      final price = _toDouble(_stopLoss.trim());
      if (_stopLossMinPrice > 0 &&
          _stopLossMaxPrice > 0 &&
          (price < _stopLossMinPrice || price > _stopLossMaxPrice)) {
        _toast(_text.t('stoploss_out_of_range'));
        return false;
      }
    }
    final free = _toDouble(_freeMargin);
    final occupation = _toDouble(_marginOccupation);
    if (free > 0 && occupation > free) {
      _toast(_text.t('margin_free_not_enough'));
      return false;
    }
    return true;
  }

  bool _isLevelChangeTradeOpenBlocked(UserState user) {
    if (user.pendingChangeLevelId == 0) return false;
    final direction = user.pendingChangeLevelDirection.toUpperCase();
    final permission = switch (direction) {
      'UP' => 'level_up_before_open',
      'DOWN' => 'level_down_before_open',
      _ => '',
    };
    if (permission.isEmpty) return false;
    for (final model in user.verificationConfig) {
      if (model.permission == permission) {
        return !model.allowed;
      }
    }
    return false;
  }

  Future<void> _refreshTradeSubmitAuthStateIfNeeded() async {
    final user = ref.read(userStateProvider);
    if (!user.isLogin) return;
    final requiresOpenVerification = tradeOpenKycVerificationRequired(
      transactionAccountType: user.transactionAccountType,
      currentAccountType: _currentAccountType,
    );
    if (!requiresOpenVerification) return;
    if (user.isAuthed && user.isBindFundPassword) return;
    await ref
        .read(userStateProvider.notifier)
        .refreshAuthStatus(ref.read(stServiceProvider));
  }

  Future<void> _confirmTrade() async {
    if (_isSubmittingTrade) return;
    await _refreshTradeSubmitAuthStateIfNeeded();
    if (!_validateTradeBeforeSubmit()) return;

    final profitOn = ref.read(userStateProvider).profitOn;
    final stopLossOn = ref.read(userStateProvider).stopLossOn;
    final takeProfit = profitOn && _takeProfit.trim().isNotEmpty
        ? _takeProfit.trim()
        : '0';
    final stopLoss = stopLossOn && _stopLoss.trim().isNotEmpty
        ? _stopLoss.trim()
        : '0';
    final lot = _normalizedLot();
    final direction = _isBuy ? 0 : 1;

    setState(() => _isSubmittingTrade = true);
    try {
      final st = ref.read(stServiceProvider);
      final Map<String, dynamic> response;
      if (_boardOrderType == 'market') {
        response = await st.submitOrder({
          'symbol': _selectedSymbol,
          'direction': direction,
          'lots': lot,
          'take_profit': takeProfit,
          'stop_loss': stopLoss,
          if (_signalProviderOn) 'is_signal_provider': 1,
        });
      } else {
        response = await st.submitPendingOrder({
          'pending_type': _boardOrderType == 'limit' ? 0 : 1,
          'symbol': _selectedSymbol,
          'direction': direction,
          'lots': lot,
          'price': _pendingPriceForSubmit(),
          'expire_time': _endOfDayUnixSecondsTp(_boardPendingValidityDay),
          'take_profit': takeProfit,
          'stop_loss': stopLoss,
          if (_signalProviderOn) 'is_signal_provider': 1,
        });
      }

      if (_isSystemBusyCode(response)) {
        _toast(_text.t('system_busy'));
        return;
      }

      ref
          .read(userStateProvider.notifier)
          .rememberTradeSelection(symbol: _selectedSymbol, lot: lot);
      _selectedLot = lot;
      _lotController.text = lot;
      final pendingExpire = _boardOrderType == 'market'
          ? null
          : _endOfDayUnixSecondsTp(_boardPendingValidityDay);
      _pushTradeActionResult(
        response: response,
        actionType: _boardOrderType == 'market' ? 'open' : 'pending',
        isProgress: _boardOrderType == 'market'
            ? true
            : (_toInt(response['status']) != 1),
        direction: direction,
        lots: lot,
        price: _boardOrderType == 'market' ? null : _pendingPriceForSubmit(),
        expireTime: pendingExpire,
      );
      _resetTradeSubmittingState();
    } catch (e) {
      await _showActionFailedSheet(
        title: _boardOrderType == 'market'
            ? _text.t('sorry_open_fail')
            : _text.t('order_placement_failed'),
        reason: _userFacingLoadError(e),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingTrade = false);
    }
  }

  /// 原生行情详情（与持仓列表「图表」一致；symbol 含 `/` 必须编码）
  void _pushMarketDetail(String symbol) {
    if (symbol.isEmpty) return;
    context.push('/market/detail?symbol=${Uri.encodeComponent(symbol)}');
  }

  void _openOrderDetail(
    Map<String, dynamic> order, {
    required bool isPosition,
  }) {
    if (!_requireLogin()) return;
    final orderId =
        order['order_id']?.toString() ?? order['position_id']?.toString() ?? '';
    if (orderId.isNotEmpty) {
      final type = isPosition ? 0 : 1;
      context.push(
        '/trade/orderdetail?orderId=${Uri.encodeComponent(orderId)}&type=$type',
        extra: <String, dynamic>{'orderInfo': order, 'orderType': type},
      );
    }
  }

  void _chartForPosition(Map<String, dynamic> pos) {
    if (!_requireLogin()) return;
    final sym = pos['symbol'] as String? ?? _selectedSymbol;
    _pushMarketDetail(sym);
  }

  Future<void> _editTPSL(Map<String, dynamic> pos) async {
    if (!_requireLogin()) return;
    final pidRaw = pos['position_id'] ?? pos['order_id'] ?? pos['id'];
    final pid = pidRaw?.toString() ?? '';
    if (pid.isEmpty) return;

    final result = await showTradePositionStopLossPayloadSheet(
      context: context,
      order: pos,
    );

    if (result == null) return;

    try {
      await _runWithActionRefreshing(() async {
        final stService = ref.read(stServiceProvider);
        final response = await stService.editPosition(result);
        if (_isSystemBusyCode(response)) {
          _toast(_text.t('system_busy'));
          return;
        }
        await _loadAllData(showBlockingLoading: false);
        if (mounted) {
          _toast(_text.t('modify_success'));
        }
      });
    } catch (e) {
      if (mounted) {
        await _showActionFailedSheet(
          title: _text.t('stop_loss_and_take_profit_failed'),
          reason: _userFacingLoadError(e),
        );
      }
    }
  }

  Future<void> _closePosition(Map<String, dynamic> pos) async {
    if (!_requireLogin()) return;
    final pidRaw = pos['position_id'] ?? pos['order_id'] ?? pos['id'];
    final pid = pidRaw?.toString() ?? '';
    if (pid.isEmpty) return;

    final sym = pos['symbol']?.toString() ?? '';
    final lots = pos['lots']?.toString() ?? pos['volume']?.toString() ?? '0.01';

    final ok = await showTradeClosePositionDialog(
      context: context,
      symbol: sym,
      lots: _volStr(pos),
    );
    if (ok != true) return;

    try {
      await _runWithActionRefreshing(() async {
        final stService = ref.read(stServiceProvider);
        final body = <String, dynamic>{
          'symbol': sym,
          'direction': _directionApiIntFromDynamic(pos['direction']),
          'lots': lots,
        };
        final asInt = int.tryParse(pid);
        if (asInt != null) {
          body['position_id'] = asInt;
        } else {
          body['position_id'] = pid;
        }
        final response = await stService.closePosition(body);
        if (_isSystemBusyCode(response)) {
          _toast(_text.t('system_busy'));
          return;
        }
        await _loadAllData(showBlockingLoading: false);
        if (mounted) {
          _pushTradeActionResult(
            response: response,
            actionType: 'close',
            isProgress: true,
            direction: _directionApiIntFromDynamic(pos['direction']),
            lots: lots,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        await _showActionFailedSheet(
          title: _text.t('close_fail'),
          reason: _userFacingLoadError(e),
        );
      }
    }
  }

  Future<void> _modifyPending(Map<String, dynamic> order) async {
    if (!_requireLogin()) return;
    final oidRaw = order['order_id'] ?? order['id'];
    final oid = oidRaw?.toString() ?? '';
    if (oid.isEmpty) return;

    final result = await showTradePendingEditPayloadSheet(
      context: context,
      order: order,
    );

    if (result == null) return;

    try {
      final px = double.tryParse(result['price']?.toString() ?? '') ?? 0;
      if (px <= 0) {
        if (mounted) {
          _toast(_text.t('invalid_entrust_price'));
        }
        return;
      }
      await _runWithActionRefreshing(() async {
        final stService = ref.read(stServiceProvider);
        final body = <String, dynamic>{
          'symbol': result['symbol'],
          'price': result['price'],
          'take_profit': result['take_profit'],
          'stop_loss': result['stop_loss'],
          'expire_time': result['expire_time'],
        };
        final asInt = int.tryParse(oid);
        if (asInt != null) {
          body['order_id'] = asInt;
        } else {
          body['order_id'] = oid;
        }
        final response = await stService.editPendingOrder(body);
        if (_isSystemBusyCode(response)) {
          _toast(_text.t('system_busy'));
          return;
        }
        await _loadAllData(showBlockingLoading: false);
        if (mounted) {
          _toast(_text.t('modify_success'));
        }
      });
    } catch (e) {
      if (mounted) {
        await _showActionFailedSheet(
          title: _text.t('modify_fail'),
          reason: _userFacingLoadError(e),
        );
      }
    }
  }

  Future<void> _cancelPending(Map<String, dynamic> order) async {
    if (!_requireLogin()) return;
    final oidRaw = order['order_id'] ?? order['id'];
    final oid = oidRaw?.toString() ?? '';
    if (oid.isEmpty) return;
    final sym = order['symbol']?.toString() ?? '';

    final ok = await showTradeCancelOrderDialog(context: context, orderId: oid);
    if (ok != true) return;

    try {
      await _runWithActionRefreshing(() async {
        final stService = ref.read(stServiceProvider);
        final body = <String, dynamic>{'symbol': sym};
        final asInt = int.tryParse(oid);
        if (asInt != null) {
          body['order_id'] = asInt;
        } else {
          body['order_id'] = oid;
        }
        final response = await stService.deleteOrder(body);
        if (_isSystemBusyCode(response)) {
          _toast(_text.t('system_busy'));
          return;
        }
        await _loadAllData(showBlockingLoading: false);
        if (mounted) {
          _toast(_text.t('order_canceled'));
        }
      });
    } catch (e) {
      if (mounted) {
        await _showActionFailedSheet(
          title: _text.t('order_cancel_failed'),
          reason: _userFacingLoadError(e),
        );
      }
    }
  }
}
