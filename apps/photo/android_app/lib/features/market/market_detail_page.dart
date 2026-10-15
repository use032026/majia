import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers/app_events.dart';
import '../../core/network/st_service.dart';
import '../../core/network/market_websocket.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/models/market_product_model.dart';
import '../../core/models/user_state.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/router/route_observer.dart';
import '../../core/router/st_router.dart';
import '../../core/config/card_tool.dart';
import '../../core/config/config_data_manager.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../core/utils/ios_market_trade_time.dart';
import '../../shared/widgets/kline_candle_chart.dart';
import '../../shared/widgets/st_load_animation_view.dart';
import '../../shared/widgets/st_toast.dart';
import 'chart_indicator_prefs.dart';
import 'chart_prefs_keys.dart';
import 'market_detail_header_config.dart';
import 'market_product_picker_sheet.dart';

/// 与 iOS `STMarketManager klineTypes` 顺序、文案一致；`key` 传入 [STService.chartParam]
class _PeriodItem {
  final String key;
  final String labelKey;
  final String fallback;
  const _PeriodItem(this.key, this.labelKey, this.fallback);
}

class _TradeDetailTick {
  final int timeSec;
  final String price;
  final int riseStatus;

  const _TradeDetailTick({
    required this.timeSec,
    required this.price,
    required this.riseStatus,
  });
}

abstract final class _MarketDetailIconAssets {
  static const String list = 'assets/images/market_detail_list.png';
  static const String listDark = 'assets/images/market_detail_list_dark.png';
  static const String collect = 'assets/images/market_detail_collect.png';
  static const String collectSelected =
      'assets/images/market_detail_collect_selected.png';
  static const String collectDark =
      'assets/images/market_detail_collect_dark.png';
  static const String collectEmptyDark =
      'assets/images/market_detail_collect_empty_dark.png';
  static const String contractSpec = 'assets/images/market_detail_fz.png';
  static const String contractSpecDark =
      'assets/images/market_detail_fz_dark.png';
  static const String chartStyle = 'assets/images/market_detail_style.png';
  static const String chartStyleDark =
      'assets/images/market_detail_style_dark.png';
  static const String chartSetting = 'assets/images/market_detail_setting.png';
  static const String chartSettingDark =
      'assets/images/market_detail_setting_dark.png';
  static const String more = 'assets/images/market_kline_more.png';
  static const String moreDark = 'assets/images/market_kline_more_dark.png';
}

/// 行情详情 + K 线页面
/// 对齐 iOS STMarketDetailController
class MarketDetailPage extends ConsumerStatefulWidget {
  final String symbol;

  const MarketDetailPage({super.key, required this.symbol});

  @override
  ConsumerState<MarketDetailPage> createState() => _MarketDetailPageState();
}

class _MarketDetailPageState extends ConsumerState<MarketDetailPage>
    with RouteAware {
  /// 主图切换条前 5 项（iOS `STChartView` 分段 +「更多」）
  static const List<_PeriodItem> _primaryPeriods = [
    _PeriodItem('FS', 'time_sharing_chart', '分时'),
    _PeriodItem('1m', 'kline_1Min', '1分'),
    _PeriodItem('30m', 'kline_30Min', '30分'),
    _PeriodItem('1H', 'kline_1Hr', '1时'),
    _PeriodItem('1D', 'kline_1D', '1天'),
  ];

  static const List<_PeriodItem> _morePeriods = [
    _PeriodItem('5m', 'kline_5Min', '5分'),
    _PeriodItem('2H', 'kline_2Hr', '2时'),
    _PeriodItem('4H', 'kline_4Hr', '4时'),
    _PeriodItem('2D', 'kline_2D', '2天'),
    _PeriodItem('1W', 'kline_Week', '1周'),
    _PeriodItem('1M', 'kline_Month', '1月'),
  ];

  static const Map<String, String> _fallbackText = {
    'time_sharing_chart': '分时',
    'kline_1Min': '1分',
    'kline_30Min': '30分',
    'kline_1Hr': '1时',
    'kline_1D': '1天',
    'kline_5Min': '5分',
    'kline_2Hr': '2时',
    'kline_4Hr': '4时',
    'kline_2D': '2天',
    'kline_Week': '1周',
    'kline_Month': '1月',
    'kline_More': '更多',
    'kline_settings': '图表设置',
    'chart': '图表样式',
    'candles': 'K线图',
    'hollow_candles': '空心K线图',
    'candle_up_stroke': 'K线涨空心',
    'candle_down_stroke': 'K线跌空心',
    'bars': '美国线',
    'area': '面积图',
    'requestfail': '数据加载失败',
    'no_data': '暂无数据',
    'dkplayer_retry': '重试',
    'open_now': '今开',
    'received_yesterday': '昨收',
    '24hour_minimum': '最低',
    '24hour_maximum': '最高',
    'update_time': '更新时间',
    'time': '成交时间',
    'price_usd': '价格 (USD)',
    'sell': '卖出',
    'buy': '买入',
    'market_closed': '市场已休市',
    'optional': '自选',
    'contract_attributes': '合约规格',
  };

  /// iOS 默认 `STKlineType1MIN`
  late String _symbol;
  String _selectedPeriod = '1m';
  List<Map<String, dynamic>> _klineData = [];
  bool _isLoading = true;
  String? _klineErrorMessage;

  /// 整表刷新后递增，驱动 K 线图滚到最新（prepend 历史不递增）
  int _klineScrollNonce = 0;

  /// 对齐 iOS `noMoreKline` / `klineViewDidMoveToLeftBorder`
  bool _noMoreKlineOlder = false;
  bool _loadingOlderKline = false;
  int _lastChartNearLeftMs = 0;

  // 实时价格数据（对齐 iOS `STMarketDetailBasicView` + 推送）
  double _currentPrice = 0;
  double _change = 0;
  double _changePercent = 0;
  double _high24h = 0;
  double _low24h = 0;
  double _openToday = 0;
  double _preClose = 0;
  int _updateTimeSec = 0;
  int _precision = 2;
  String _productName = '';
  String _detailSymbol = '';
  Map<String, dynamic>? _productDetailMap;
  bool _isInTradeTime = false;

  /// iOS `trade_mode`："0"禁用 "1"仅买入 "2"仅卖出 "3"仅平仓 "4"完全
  String _tradeMode = '4';
  String _bidStr = '--';
  String _askStr = '--';
  String _spreadStr = '--';
  List<_TradeDetailTick> _tradeDetailTicks = const [];
  final ValueNotifier<List<_TradeDetailTick>> _tradeDetailTicksNotifier =
      ValueNotifier<List<_TradeDetailTick>>(const []);

  /// 是否在自选（对齐 `STMarketDetailHeaderView` 收藏）
  bool _inWatchlist = false;

  /// 主图指标（MA / EMA / BOLL / SAR）
  String _mainIndicator = 'MA';

  /// 副图指标（VOL / MACD / …）
  String _subIndicator = 'MACD';

  List<int> _maPeriods = const [5, 10, 20];
  List<int> _emaPeriods = const [12, 26];

  int _macdFast = 12;
  int _macdSlow = 26;
  int _macdSignal = 9;
  int _kdjPeriod = 9;
  int _kdjKSmooth = 3;
  int _kdjDSmooth = 3;
  int _rsiPeriod = 14;
  int _dmiPeriod = 14;

  KlineMainChartStyle _chartStyle = KlineMainChartStyle.candle;
  bool _showGrid = false;
  bool _enableCrosshair = true;
  Map<String, String> _localizedText = _fallbackText;
  String? _localizedLanguageCode;

  /// `get_symbol_detail` 等下发的合约规格入口覆盖（`null` = 未配置，遵循全局 app_config）
  bool? _contractSpecSymbolOverride;

  // WebSocket 订阅
  StreamSubscription<MarketWSMessage>? _wsSubscription;
  StreamSubscription<WSConnectionState>? _wsStateSubscription;
  MarketWebSocket? _marketWebSocket;
  bool _routeVisible = true;
  bool _routeSubscribed = false;
  bool _detailSocketActive = false;
  int _localOverlayRouteDepth = 0;
  int _ignoredLocalOverlayPopCount = 0;
  Timer? _quoteFlushTimer;
  Timer? _klineFlushTimer;
  Map<String, dynamic>? _pendingBidAskUpdate;
  Map<String, dynamic>? _pendingRealtimeUpdate;
  Map<String, dynamic>? _pendingPriceUpdate;
  Map<String, dynamic>? _pendingTickStatUpdate;
  List<Map<String, dynamic>>? _pendingKlineRowsUpdate;

  static const Color _kIosAccentBlue = Color(0xFF00B57A);

  /// 图表样式选中描边/文字（对齐 iOS 行情页青绿色选中态）
  static const Color _kChartStyleSelectedTeal = Color(0xFF15C3B8);

  @override
  void initState() {
    super.initState();
    _symbol = widget.symbol.trim().isEmpty ? 'EUR/USD' : widget.symbol.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rememberTradeSymbolForDetail();
    });
    _bootstrap();
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
  void didPush() {
    _routeVisible = true;
  }

  @override
  void didPushNext() {
    if (_localOverlayRouteDepth > 0) {
      _ignoredLocalOverlayPopCount++;
      return;
    }
    _deactivateDetailSocket(clearRoom: true);
  }

  @override
  void didPopNext() {
    if (_ignoredLocalOverlayPopCount > 0) {
      _ignoredLocalOverlayPopCount--;
      _routeVisible = true;
      return;
    }
    _routeVisible = true;
    _connectWebSocket();
  }

  @override
  void didPop() {
    _deactivateDetailSocket(clearRoom: false);
  }

  bool get _canUseDetailSocket {
    if (!mounted || !_routeVisible) return false;
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }

  @override
  void didUpdateWidget(covariant MarketDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.symbol.trim();
    if (next.isNotEmpty && next != _symbol) {
      unawaited(_changeProduct(next));
    }
  }

  /// 对齐 iOS `STMarketDetailController viewDidLoad`：进入详情即记忆当前交易品种。
  void _rememberTradeSymbolForDetail() {
    if (!mounted) return;
    final sym = _symbol.trim();
    if (sym.isEmpty) return;
    ref
        .read(userStateProvider.notifier)
        .rememberTradeSelection(symbol: sym, lot: '');
  }

  Future<void> _changeProduct(String symbol) async {
    final next = symbol.trim();
    if (next.isEmpty) return;

    if (_morePeriods.any((e) => e.key == _selectedPeriod)) {
      _selectedPeriod = '1m';
      final sp = await SharedPreferences.getInstance();
      await sp.setString(MarketChartPrefKeys.klinePeriod, _selectedPeriod);
    }

    if (!mounted) return;
    _clearPendingSocketUpdates();
    setState(() {
      _symbol = next;
      _productName = '';
      _detailSymbol = '';
      _productDetailMap = null;
      _currentPrice = 0;
      _change = 0;
      _changePercent = 0;
      _high24h = 0;
      _low24h = 0;
      _openToday = 0;
      _preClose = 0;
      _updateTimeSec = 0;
      _precision = 2;
      _isInTradeTime = false;
      _tradeMode = '4';
      _bidStr = '--';
      _askStr = '--';
      _spreadStr = '--';
      _inWatchlist = false;
      _isLoading = true;
      _klineErrorMessage = null;
      _klineData = [];
      _setTradeDetailTicks(const []);
      _contractSpecSymbolOverride = null;
      _noMoreKlineOlder = false;
    });

    _rememberTradeSymbolForDetail();
    await _hydrateFromRest();
    await _loadKlineData();
    if (!mounted) return;
    ref
        .read(marketWebSocketProvider)
        .sendSwitchKlineChart(_symbol, STService.chartParam(_selectedPeriod));
  }

  Future<void> _bootstrap() async {
    final sp = await SharedPreferences.getInstance();
    final saved = sp.getString(MarketChartPrefKeys.klinePeriod);
    final validPrimary = _primaryPeriods.map((e) => e.key).toSet();
    if (saved != null && validPrimary.contains(saved)) {
      _selectedPeriod = saved;
    }

    _applyChartPrefs(sp);

    if (!mounted) return;
    setState(() {});
    await _hydrateFromRest();
    if (!_canUseDetailSocket) return;
    _loadKlineData();
    _connectWebSocket();
  }

  void _applyChartPrefs(SharedPreferences sp) {
    final pair = ChartIndicatorPrefs.readMainSub(sp);
    _chartStyle = _parseChartStyle(
      sp.getString(MarketChartPrefKeys.chartStyle),
    );
    _showGrid = sp.getBool(MarketChartPrefKeys.showGrid) ?? false;
    _enableCrosshair = sp.getBool(MarketChartPrefKeys.crosshair) ?? true;
    _mainIndicator = pair.$1;
    _subIndicator = pair.$2;
    _maPeriods = ChartIndicatorPrefs.parsePeriodList(
      sp.getString(MarketChartPrefKeys.maPeriods),
      const [5, 10, 20],
    );
    _emaPeriods = ChartIndicatorPrefs.parsePeriodList(
      sp.getString(MarketChartPrefKeys.emaPeriods),
      const [12, 26],
    );
    final macdT = ChartIndicatorPrefs.parseTriple(
      sp.getString(MarketChartPrefKeys.macdParams),
      (12, 26, 9),
    );
    _macdFast = macdT.$1;
    _macdSlow = macdT.$2;
    _macdSignal = macdT.$3;
    final kdjT = ChartIndicatorPrefs.parseTriple(
      sp.getString(MarketChartPrefKeys.kdjParams),
      (9, 3, 3),
    );
    _kdjPeriod = kdjT.$1;
    _kdjKSmooth = kdjT.$2;
    _kdjDSmooth = kdjT.$3;
    _rsiPeriod = ChartIndicatorPrefs.parseSinglePeriod(
      sp.getString(MarketChartPrefKeys.rsiParams),
      14,
    );
    _dmiPeriod = ChartIndicatorPrefs.parseSinglePeriod(
      sp.getString(MarketChartPrefKeys.dmiParams),
      14,
    );
  }

  Future<void> _reloadChartPrefs() async {
    final sp = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _applyChartPrefs(sp));
  }

  static KlineMainChartStyle _parseChartStyle(String? raw) {
    switch (raw) {
      case 'hollow':
      case 'hollow_rise':
        return KlineMainChartStyle.candleHollowRise;
      case 'hollow_all':
        return KlineMainChartStyle.candleHollowAll;
      case 'hollow_fall':
        return KlineMainChartStyle.candleHollowFall;
      case 'us':
        return KlineMainChartStyle.usLine;
      case 'area':
        return KlineMainChartStyle.area;
      default:
        return KlineMainChartStyle.candle;
    }
  }

  static String _chartStylePrefValue(KlineMainChartStyle s) {
    switch (s) {
      case KlineMainChartStyle.candle:
        return 'candle';
      case KlineMainChartStyle.candleHollowAll:
        return 'hollow_all';
      case KlineMainChartStyle.candleHollowRise:
        return 'hollow_rise';
      case KlineMainChartStyle.candleHollowFall:
        return 'hollow_fall';
      case KlineMainChartStyle.usLine:
        return 'us';
      case KlineMainChartStyle.area:
        return 'area';
    }
  }

  static KlineMainOverlay _overlayForIndicator(String id) {
    switch (id) {
      case 'MA':
        return KlineMainOverlay.ma;
      case 'EMA':
        return KlineMainOverlay.ema;
      case 'BOLL':
        return KlineMainOverlay.boll;
      default:
        return KlineMainOverlay.none;
    }
  }

  static KlineSubChartType _subChartForIndicator(String id) {
    switch (id) {
      case 'MA':
      case 'EMA':
      case 'BOLL':
      case 'SAR':
      case 'VOL':
        return KlineSubChartType.volume;
      case 'MACD':
        return KlineSubChartType.macd;
      case 'KDJ':
        return KlineSubChartType.kdj;
      case 'RSI':
        return KlineSubChartType.rsi;
      case 'DMI':
        return KlineSubChartType.dmi;
      default:
        return KlineSubChartType.volume;
    }
  }

  Future<void> _persistChartStyle(KlineMainChartStyle style) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      MarketChartPrefKeys.chartStyle,
      _chartStylePrefValue(style),
    );
  }

  Future<void> _hydrateFromRest() async {
    final service = ref.read(stServiceProvider);
    Map<String, dynamic>? productDetailMap;
    Map<String, dynamic>? basicQuoteMap;

    try {
      final raw = await service.getProductDetail(_symbol);
      final m = _unwrapDetailMap(raw);
      productDetailMap = m == null ? null : Map<String, dynamic>.from(m);
    } catch (e) {
      debugPrint('MarketDetail product detail: $e');
      _showIosErrorToast(_t('requestfail'), e);
    }

    try {
      final raw = await service.getBasicQuote(_symbol);
      final m = _unwrapDetailMap(raw);
      basicQuoteMap = m == null ? null : Map<String, dynamic>.from(m);
    } catch (e) {
      debugPrint('MarketDetail basic quote: $e');
      _showIosErrorToast(_t('requestfail'), e);
    }

    Map<String, dynamic>? m = productDetailMap == null
        ? null
        : Map<String, dynamic>.from(productDetailMap);
    if (basicQuoteMap != null) {
      m = m == null
          ? Map<String, dynamic>.from(basicQuoteMap)
          : {...basicQuoteMap, ...m};
    }

    if (m != null && mounted) {
      final watchlistFlag = _watchlistFlagFromMap(m);
      setState(() {
        _productDetailMap = productDetailMap;
        _applyProductDetailFields(m!);
        _applyQuoteMap(m);
        if (watchlistFlag != null) {
          _inWatchlist = watchlistFlag;
        }
      });
      if (watchlistFlag != null) return;
    }
    await _syncWatchlistFlag();
  }

  bool? _watchlistFlagFromMap(Map<String, dynamic> m) {
    for (final key in const [
      'is_watch_list',
      'isWatchList',
      'in_optional',
      'inOptional',
    ]) {
      if (!m.containsKey(key)) continue;
      final value = m[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == '1' || normalized == 'true' || normalized == 'yes') {
          return true;
        }
        if (normalized == '0' || normalized == 'false' || normalized == 'no') {
          return false;
        }
      }
    }
    return null;
  }

  String _readableError(Object error) {
    return stSanitizeUserVisibleText(error.toString());
  }

  void _showIosErrorToast(String title, Object error) {
    if (!mounted) return;
    STToast.show(context, '$title：${_readableError(error)}');
  }

  void _ensureLocalizedText(STLocalizations localizations) {
    final languageCode = localizations.languageCode;
    if (_isLocalizedTextReady(languageCode)) return;
    _localizedLanguageCode = languageCode;
    _localizedText = _fallbackText;
    localizations.textMap(_fallbackText).then((text) {
      if (!mounted || _localizedLanguageCode != languageCode) return;
      setState(() {
        _localizedText = text;
      });
    });
  }

  bool _isLocalizedTextReady(String languageCode) {
    if (_localizedLanguageCode != languageCode) return false;
    if (languageCode == 'zh-Hans' || languageCode == 'zh') return true;
    return _localizedText['time_sharing_chart'] !=
        _fallbackText['time_sharing_chart'];
  }

  String _t(String key) => _localizedText[key] ?? _fallbackText[key] ?? key;

  String _periodLabel(_PeriodItem item) {
    final value = _localizedText[item.labelKey];
    if (value == null || value == item.labelKey) return item.fallback;
    return value;
  }

  Future<void> _syncWatchlistFlag() async {
    if (!ref.read(userStateProvider).isLogin) {
      if (mounted) setState(() => _inWatchlist = false);
      return;
    }
    try {
      final list = await ref
          .read(stServiceProvider)
          .getOptionList(needPoints: false);
      final syms = <String>{};
      for (final e in list) {
        if (e is Map) {
          final s = e['symbol'] ?? e['Symbol'] ?? e['title'];
          if (s != null) syms.add(s.toString());
        }
      }
      if (!mounted) return;
      setState(() => _inWatchlist = syms.contains(_symbol));
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    if (!ref.read(userStateProvider).isLogin) {
      context.push('/login');
      return;
    }
    final svc = ref.read(stServiceProvider);
    try {
      if (_inWatchlist) {
        await svc.removeFromWatchlist([_symbol]);
      } else {
        await svc.addToWatchlist([_symbol]);
      }
      notifyWatchlistChanged(ref);
      if (mounted) setState(() => _inWatchlist = !_inWatchlist);
    } catch (e) {
      if (!mounted) return;
      STToast.show(
        context,
        '${_t('requestfail')}: ${stUserVisibleErrorMessage(e)}',
      );
    }
  }

  /// 对齐 iOS `STMarketProductDetailModel`（footer 校验交易时间、trade_mode）
  void _applyProductDetailFields(Map<String, dynamic> m) {
    final sym = m['symbol']?.toString();
    if (sym != null && sym.isNotEmpty) {
      _detailSymbol = sym;
    }
    final tm = m['trade_mode'] ?? m['tradeMode'];
    if (tm != null) {
      _tradeMode = tm.toString();
    }
    final tradeSessions =
        m['sessions_trades_since_sunday'] ?? m['sessionsTradesSinceSunday'];
    if (iosHasTradeSessionsSinceSunday(tradeSessions)) {
      _isInTradeTime = iosIsInTradeTimeFromSinceSunday(
        tradeSessions,
        selectedTimeZone: ref.read(userStateProvider).selectedTimeZone,
      );
    } else {
      final itt = m['is_in_trade_time'] ?? m['isInTradeTime'];
      if (itt is bool) {
        _isInTradeTime = itt;
      } else if (itt is num) {
        _isInTradeTime = itt != 0;
      } else if (itt is String) {
        _isInTradeTime = itt == '1' || itt.toLowerCase() == 'true';
      }
    }
  }

  bool _isDetailSymbol(String? sym) {
    if (sym == null || sym.isEmpty) return false;
    return sym == _symbol || (_detailSymbol.isNotEmpty && sym == _detailSymbol);
  }

  double? _parsePercentLike(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final s = v.trim().replaceAll('%', '').replaceAll('+', '');
      return double.tryParse(s);
    }
    return null;
  }

  /// 对齐 iOS `UPDATE_SYMBOL_REAL_TIME_PRICE` → `STMarketDetailBasicView`
  void _applyRealtimePriceMap(Map<String, dynamic> data) {
    _prependTradeDetailTickFromRealtime(
      data,
      initialPreviousPrice: _currentPrice,
    );
    final p = _pickDouble(data, ['price', 'last_price', 'lastPrice']);
    if (p != null) _currentPrice = p;

    final pc = _pickDouble(data, [
      'pre_close',
      'preClose',
      'yesterday_close',
      'yesterdayClose',
    ]);
    if (pc != null) _preClose = pc;

    final o = _pickDouble(data, ['open', 'Open']);
    if (o != null) _openToday = o;

    final hi = _pickDouble(data, ['high', 'day_high', 'high24']);
    if (hi != null) _high24h = hi;

    final lo = _pickDouble(data, ['low', 'day_low', 'low24']);
    if (lo != null) _low24h = lo;

    final ut = data['update_time'] ?? data['updateTime'];
    if (ut is int) {
      _updateTimeSec = ut;
    } else if (ut is num) {
      _updateTimeSec = ut.toInt();
    } else if (ut is String) {
      _updateTimeSec = int.tryParse(ut) ?? _updateTimeSec;
    }

    final cr = _parsePercentLike(data['change_rate'] ?? data['changeRate']);
    if (cr != null) {
      _changePercent = cr;
    }

    if (p != null && pc != null) {
      _change = p - pc;
      if (cr == null && pc.abs() > 1e-12) {
        _changePercent = (_change / pc) * 100.0;
      }
    }
  }

  void _prependTradeDetailTickFromRealtime(
    Map<String, dynamic> data, {
    required double initialPreviousPrice,
  }) {
    if (!_isCurrentRealtimeDetailSymbol(data)) return;
    final priceText = data['price']?.toString().trim();
    if (priceText == null || priceText.isEmpty) return;
    final updateTime = _parseExactRealtimeUpdateTime(data['update_time']);
    if (updateTime == null || updateTime <= 0) return;

    final previousPrice = _tradeDetailTicks.isNotEmpty
        ? double.tryParse(_tradeDetailTicks.first.price) ?? initialPreviousPrice
        : initialPreviousPrice;
    final nextPrice = double.tryParse(priceText) ?? 0;
    final status = nextPrice > previousPrice
        ? 1
        : nextPrice < previousPrice
        ? -1
        : 0;

    _setTradeDetailTicks([
      _TradeDetailTick(
        timeSec: updateTime,
        price: priceText,
        riseStatus: status,
      ),
      ..._tradeDetailTicks,
    ]);
  }

  int? _parseExactRealtimeUpdateTime(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  void _setTradeDetailTicks(List<_TradeDetailTick> rows) {
    _tradeDetailTicks = List<_TradeDetailTick>.unmodifiable(rows);
    _tradeDetailTicksNotifier.value = _tradeDetailTicks;
  }

  void _beginLocalOverlayRoute() {
    _localOverlayRouteDepth++;
  }

  void _endLocalOverlayRoute() {
    if (_localOverlayRouteDepth > 0) {
      _localOverlayRouteDepth--;
    }
  }

  Future<T?> _showLocalModalBottomSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    Color? backgroundColor,
    ShapeBorder? shape,
  }) {
    _beginLocalOverlayRoute();
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: backgroundColor,
      shape: shape,
      builder: builder,
    ).whenComplete(_endLocalOverlayRoute);
  }

  Future<T> _runWithLocalOverlayRouteGuard<T>(Future<T> Function() action) {
    _beginLocalOverlayRoute();
    return action().whenComplete(_endLocalOverlayRoute);
  }

  /// `get_symbol_detail` / `get_symbol_kline_data` 返回形态不一，统一取出可用 Map
  ///
  /// iOS [STMarketDetailController requestBasicData]：`dict = response.data[@"symbol_info"]`
  /// 再转 `STMarketBasicModel`，故盘口价、涨跌幅等在 **`data.symbol_info`** 内，需拍平到一层供 [_applyQuoteMap]。
  Map<String, dynamic>? _unwrapDetailMap(Map<String, dynamic> raw) {
    if (!_isApiSuccessCode(raw['code'])) return null;
    final d = raw['data'];
    if (d is! Map) return null;
    final map = Map<String, dynamic>.from(d);
    return _flattenSymbolInfo(map);
  }

  bool _isApiSuccessCode(dynamic code) {
    if (code == null) return true;
    if (code is num) return code == 0 || code == 200;
    if (code is String) {
      final s = code.trim();
      if (s.isEmpty) return true;
      final n = int.tryParse(s);
      if (n != null) return n == 0 || n == 200;
      return s.toLowerCase() == 'ok' || s.toLowerCase() == 'success';
    }
    return true;
  }

  /// 合并 `symbol_info`（及可选 `quote`）到顶层，键与 iOS `STMarketBasicModel` 一致
  Map<String, dynamic> _flattenSymbolInfo(Map<String, dynamic> data) {
    final out = Map<String, dynamic>.from(data);
    for (final key in ['symbol_info', 'symbolInfo', 'quote', 'Quote']) {
      final nested = data[key];
      if (nested is Map) {
        out.addAll(Map<String, dynamic>.from(nested));
      }
    }
    return out;
  }

  double? _pickDouble(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    }
    return null;
  }

  int? _parsePrecision(dynamic raw) {
    int? value;
    if (raw is num) {
      value = raw.toInt();
    } else if (raw is String) {
      final text = raw.trim();
      if (text.isNotEmpty) {
        value = int.tryParse(text) ?? double.tryParse(text)?.toInt();
      }
    }
    if (value == null || value < 0) return null;
    return value.clamp(0, 8);
  }

  void _applyQuoteMap(Map<String, dynamic> m) {
    _productName =
        m['name']?.toString() ?? m['title']?.toString() ?? _productName;
    final prec = m['precision'] ?? m['digits'];
    _precision = _parsePrecision(prec) ?? _precision;

    _currentPrice =
        _pickDouble(m, ['last_price', 'lastPrice', 'price', 'close', 'last']) ??
        _currentPrice;
    _change = _pickDouble(m, ['change', 'price_change', 'diff']) ?? _change;
    _changePercent =
        _pickDouble(m, [
          'change_percent',
          'changePercent',
          'chg_pct',
          'change_rate',
          'changeRate',
        ]) ??
        _changePercent;
    _high24h = _pickDouble(m, ['high', 'high24', 'day_high']) ?? _high24h;
    _low24h = _pickDouble(m, ['low', 'low24', 'day_low']) ?? _low24h;

    _openToday = _pickDouble(m, ['open', 'Open', 'today_open']) ?? _openToday;
    _preClose =
        _pickDouble(m, [
          'pre_close',
          'preClose',
          'yesterday_close',
          'yesterdayClose',
          'prev_close',
        ]) ??
        _preClose;

    final ut = m['update_time'] ?? m['updateTime'];
    if (ut is int && ut > 0) {
      _updateTimeSec = ut;
    } else if (ut is num && ut.toInt() > 0) {
      _updateTimeSec = ut.toInt();
    } else if (ut is String) {
      final n = int.tryParse(ut);
      if (n != null && n > 0) _updateTimeSec = n;
    }

    final bid = m['bid'] ?? m['Bid'];
    final ask = m['ask'] ?? m['Ask'];
    if (bid != null) _bidStr = bid.toString();
    if (ask != null) _askStr = ask.toString();
    final sp = m['spread'] ?? m['Spread'];
    if (sp != null) _spreadStr = sp.toString();

    _contractSpecSymbolOverride =
        MarketDetailHeaderConfig.parseSymbolContractSpecOverride(m);

    if (_currentPrice.abs() > 1e-12 && _preClose.abs() > 1e-12) {
      _change = _currentPrice - _preClose;
      _changePercent = (_change / _preClose) * 100.0;
    }
  }

  /// 与 iOS `STYYKlineRootModel` 一致：`timestamp` 为 Unix 秒；内部 `time` 为毫秒便于排序
  int _parseKlineTimestampMs(dynamic v) {
    if (v == null) return 0;
    int? n;
    if (v is int) {
      n = v;
    } else if (v is num) {
      n = v.toInt();
    } else if (v is String) {
      n = int.tryParse(v);
    }
    if (n == null || n == 0) return 0;
    if (n < 100000000000) return n * 1000;
    return n;
  }

  Map<String, dynamic> _normalizeKlineRow(dynamic e) {
    if (e is! Map) return {};
    final src = Map<String, dynamic>.from(e);
    num? pick(List<String> keys) {
      for (final k in keys) {
        final v = src[k];
        if (v is num) return v;
        if (v is String) return num.tryParse(v);
      }
      return null;
    }

    final open = pick(['open', 'Open', 'o']);
    final high = pick(['high', 'High', 'h']);
    final low = pick(['low', 'Low', 'l']);
    final close = pick(['close', 'Close', 'c', 'last', 'Last']);
    final vol = pick(['volume', 'Volume', 'vol', 'tick_volume', 'tickVolume']);
    if (open == null && high == null && low == null && close == null) {
      return {};
    }
    var t = 0;
    for (final k in ['timestamp', 'time', 'Time', 't', 'date', 'datetime']) {
      if (src[k] != null) {
        t = _parseKlineTimestampMs(src[k]);
        if (t != 0) break;
      }
    }
    return {
      'open': open?.toDouble() ?? 0.0,
      'high': high?.toDouble() ?? 0.0,
      'low': low?.toDouble() ?? 0.0,
      'close': close?.toDouble() ?? 0.0,
      'volume': vol?.toInt() ?? 0,
      'time': t,
    };
  }

  List<Map<String, dynamic>> _sortKlineByTime(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return rows;
    if (!rows.any((e) => (e['time'] as int? ?? 0) != 0)) return rows;
    final sorted = List<Map<String, dynamic>>.from(rows);
    sorted.sort((a, b) {
      final ta = a['time'] as int? ?? 0;
      final tb = b['time'] as int? ?? 0;
      return ta.compareTo(tb);
    });
    return sorted;
  }

  @override
  void dispose() {
    if (_routeSubscribed) {
      routeObserver.unsubscribe(this);
    }
    _clearPendingSocketUpdates();
    _deactivateDetailSocket(clearRoom: _routeVisible);
    _tradeDetailTicksNotifier.dispose();
    super.dispose();
  }

  /// 对齐 iOS `sendEnterSymbolDetailWithSymbol:chart:`：进入详情后订阅当前所选周期（REST [getKlineData] 使用同一 `chartParam`）
  void _subscribeDetailWebSocket() {
    if (!_canUseDetailSocket) return;
    final MarketWebSocket ws =
        _marketWebSocket ?? ref.read(marketWebSocketProvider);
    _marketWebSocket ??= ws;
    ws.sendEnterSymbolDetail(
      _symbol,
      chart: STService.chartParam(_selectedPeriod),
    );
    _detailSocketActive = true;
  }

  void _connectWebSocket() {
    if (!_canUseDetailSocket) return;
    final ws = ref.read(marketWebSocketProvider);
    _marketWebSocket = ws;
    ws.connect();

    _wsStateSubscription?.cancel();
    _wsStateSubscription = ws.stateStream.listen((state) {
      if (state == WSConnectionState.connected && _canUseDetailSocket) {
        _subscribeDetailWebSocket();
      }
    });

    if (ws.state == WSConnectionState.connected && _canUseDetailSocket) {
      _subscribeDetailWebSocket();
    }

    _wsSubscription?.cancel();
    _wsSubscription = ws.messageStream.listen(_onWSMessage);
  }

  void _deactivateDetailSocket({required bool clearRoom}) {
    _routeVisible = false;
    _clearPendingSocketUpdates();
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _wsStateSubscription?.cancel();
    _wsStateSubscription = null;
    if (clearRoom && _detailSocketActive) {
      _marketWebSocket?.sendEnterEmpty();
    }
    _detailSocketActive = false;
  }

  bool _wsSymbolMatches(Map<String, dynamic> data) {
    final sym =
        data['symbol'] as String? ??
        data['Symbol'] as String? ??
        data['symbol_name'] as String?;
    if (sym == null || sym.isEmpty) return true;
    return sym == _symbol;
  }

  bool _isCurrentRealtimeDetailSymbol(Map<String, dynamic> data) {
    final symbol = data['symbol']?.toString();
    return symbol != null && symbol.isNotEmpty && symbol == _symbol;
  }

  void _onWSMessage(MarketWSMessage message) {
    final data = message.data;

    if (message.type == 'UPDATE_SELL_AND_BUY') {
      if (!_isDetailSymbol(data['symbol']?.toString())) return;
      _pendingBidAskUpdate = Map<String, dynamic>.from(data);
      _scheduleQuoteFlush();
      return;
    }

    if (message.type == 'UPDATE_SYMBOL_REAL_TIME_PRICE') {
      if (!_isCurrentRealtimeDetailSymbol(data)) return;
      _pendingRealtimeUpdate = Map<String, dynamic>.from(data);
      _scheduleQuoteFlush();
      return;
    }

    if (!_wsSymbolMatches(data)) return;

    const tickStatTypes = {
      'SEND_SYMBOL_TICK_STAT',
      'SYMBOL_TICK_STAT',
      'UPDATE_SYMBOL_TICK_STAT',
      'TICK_STAT',
    };
    if (tickStatTypes.contains(message.type)) {
      _queueTickStatBar(Map<String, dynamic>.from(data));
      return;
    }

    if (message.type == 'PRICE_UPDATE') {
      _pendingPriceUpdate = Map<String, dynamic>.from(data);
      _scheduleQuoteFlush();
      return;
    }

    if (message.type == 'KLINE_UPDATE' ||
        message.type == 'UPDATE_KLINE' ||
        message.type == 'KLINE') {
      _mergeKlineFromSocket(data);
    }
  }

  void _clearPendingSocketUpdates() {
    _quoteFlushTimer?.cancel();
    _klineFlushTimer?.cancel();
    _quoteFlushTimer = null;
    _klineFlushTimer = null;
    _pendingBidAskUpdate = null;
    _pendingRealtimeUpdate = null;
    _pendingPriceUpdate = null;
    _pendingTickStatUpdate = null;
    _pendingKlineRowsUpdate = null;
  }

  void _scheduleQuoteFlush() {
    if (_quoteFlushTimer != null) return;
    _quoteFlushTimer = Timer(const Duration(milliseconds: 180), () {
      _quoteFlushTimer = null;
      _flushQuoteUpdates();
    });
  }

  void _flushQuoteUpdates() {
    if (!mounted) return;
    final bidAsk = _pendingBidAskUpdate;
    final realtime = _pendingRealtimeUpdate;
    final price = _pendingPriceUpdate;
    _pendingBidAskUpdate = null;
    _pendingRealtimeUpdate = null;
    _pendingPriceUpdate = null;
    if (bidAsk == null && realtime == null && price == null) return;

    setState(() {
      if (bidAsk != null) _applyBidAskMap(bidAsk);
      if (realtime != null) _applyRealtimePriceMap(realtime);
      if (price != null) _applyPriceUpdateMap(price);
    });
  }

  void _applyBidAskMap(Map<String, dynamic> data) {
    final ask = data['ask'];
    final bid = data['bid'];
    final spread = data['spread'];
    if (ask != null) _askStr = ask.toString();
    if (bid != null) _bidStr = bid.toString();
    if (spread != null) _spreadStr = spread.toString();
  }

  void _applyPriceUpdateMap(Map<String, dynamic> data) {
    _currentPrice =
        _pickDouble(data, ['price', 'last_price', 'lastPrice']) ??
        _currentPrice;
    _change = _pickDouble(data, ['change']) ?? _change;
    _changePercent =
        _pickDouble(data, ['change_percent', 'changePercent']) ??
        _changePercent;
    _high24h = _pickDouble(data, ['high']) ?? _high24h;
    _low24h = _pickDouble(data, ['low']) ?? _low24h;
    _applyBidAskMap(data);
  }

  void _queueTickStatBar(Map<String, dynamic> data) {
    _pendingTickStatUpdate = data;
    _scheduleKlineFlush();
  }

  void _queueKlineRows(List<Map<String, dynamic>> rows) {
    _pendingKlineRowsUpdate = rows;
    _scheduleKlineFlush();
  }

  void _scheduleKlineFlush() {
    if (_klineFlushTimer != null) return;
    _klineFlushTimer = Timer(const Duration(milliseconds: 250), () {
      _klineFlushTimer = null;
      _flushKlineUpdates();
    });
  }

  void _flushKlineUpdates() {
    if (!mounted) return;
    final rows = _pendingKlineRowsUpdate;
    final tick = _pendingTickStatUpdate;
    _pendingKlineRowsUpdate = null;
    _pendingTickStatUpdate = null;
    if (rows == null && tick == null) return;

    setState(() {
      if (rows != null) {
        _klineData = _sortKlineByTime(rows);
      } else if (tick != null) {
        _mergeTickStatBarNow(tick);
      }
    });
  }

  void _mergeTickStatBarNow(Map<String, dynamic> data) {
    final row = _normalizeKlineRow(data);
    if (row.isEmpty) return;
    final list = List<Map<String, dynamic>>.from(_klineData);
    final ts = row['time'] as int? ?? 0;
    if (list.isEmpty) {
      _klineData = [row];
      return;
    }
    if (ts == 0) {
      list[list.length - 1] = {...list.last, ...row};
      _klineData = list;
      return;
    }

    for (var i = list.length - 1; i >= 0; i--) {
      final oldTs = list[i]['time'] as int? ?? 0;
      if (oldTs == ts) {
        list[i] = {...list[i], ...row};
        _klineData = list;
        return;
      }
      if (oldTs < ts) {
        list.insert(i + 1, row);
        _trimKlineWindow(list);
        _klineData = list;
        return;
      }
    }

    list.insert(0, row);
    _trimKlineWindow(list);
    _klineData = list;
  }

  void _trimKlineWindow(List<Map<String, dynamic>> list) {
    const maxRows = 600;
    final over = list.length - maxRows;
    if (over > 0) list.removeRange(0, over);
  }

  void _mergeKlineFromSocket(Map<String, dynamic> data) {
    for (final key in ['bar', 'last_bar', 'lastBar', 'candle', 'tick', 'k']) {
      final v = data[key];
      if (v is Map) {
        final row = _normalizeKlineRow(Map<String, dynamic>.from(v));
        if (row.isNotEmpty) {
          _queueTickStatBar(row);
          return;
        }
      }
    }
    for (final key in [
      'kline',
      'list',
      'bars',
      'ticks',
      'items',
      'records',
      'tick_stats',
    ]) {
      final v = data[key];
      if (v is List && v.isNotEmpty) {
        final rows = v
            .map(_normalizeKlineRow)
            .where((row) => row.isNotEmpty)
            .toList();
        if (rows.isNotEmpty) {
          _queueKlineRows(rows);
        }
        return;
      }
    }
    final row = _normalizeKlineRow(data);
    if (row.isNotEmpty) _queueTickStatBar(row);
  }

  Future<void> _loadKlineData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _klineErrorMessage = null;
    });
    try {
      final service = ref.read(stServiceProvider);
      final endSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final rawData = await service.getKlineData(
        symbol: _symbol,
        chart: STService.chartParam(_selectedPeriod),
        endTime: endSec,
        count: 300,
      );
      if (!mounted) return;
      final rows = _sortKlineByTime(
        rawData.map(_normalizeKlineRow).where((row) => row.isNotEmpty).toList(),
      );
      setState(() {
        _klineData = rows;
        _klineErrorMessage = rows.isEmpty ? 'no_data' : null;
        _klineScrollNonce++;
        _noMoreKlineOlder = false;
      });
    } catch (e) {
      debugPrint('Failed to load kline data: $e');
      if (mounted) {
        setState(() {
          _klineData = [];
          _klineErrorMessage = 'requestfail';
        });
        _showIosErrorToast(_t('requestfail'), e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 对齐 iOS `klineViewDidMoveToLeftBorder:` + `requestKlineDataWithSymbol:endTime:`
  void _onChartNearLeftEdge() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastChartNearLeftMs < 900) return;
    _lastChartNearLeftMs = now;
    _loadOlderKlinePage();
  }

  Future<void> _loadOlderKlinePage() async {
    if (_loadingOlderKline ||
        _noMoreKlineOlder ||
        _klineData.isEmpty ||
        _isLoading) {
      return;
    }
    final firstMs = _klineData.first['time'] as int? ?? 0;
    if (firstMs <= 0) return;

    final endSec = firstMs ~/ 1000;
    setState(() => _loadingOlderKline = true);
    try {
      final service = ref.read(stServiceProvider);
      final raw = await service.getKlineData(
        symbol: _symbol,
        chart: STService.chartParam(_selectedPeriod),
        endTime: endSec,
        count: 300,
      );
      if (!mounted) return;
      final batch = _sortKlineByTime(
        raw.map(_normalizeKlineRow).where((row) => row.isNotEmpty).toList(),
      );
      if (batch.length < 300) {
        _noMoreKlineOlder = true;
      }
      final filtered = batch
          .where((r) => (r['time'] as int? ?? 0) != firstMs)
          .toList();
      if (filtered.isEmpty) {
        _noMoreKlineOlder = true;
      } else {
        setState(() {
          _klineData = _sortKlineByTime([...filtered, ..._klineData]);
        });
      }
    } catch (e) {
      debugPrint('Older kline load: $e');
      _showIosErrorToast(_t('requestfail'), e);
    } finally {
      if (mounted) setState(() => _loadingOlderKline = false);
    }
  }

  /// 对齐 iOS `stockDatasWithIndex:`：先拉 `get_tick_stats`，再在回调里 `sendSwitchKlineChartMessage`
  Future<void> _onPeriodChanged(String period) async {
    setState(() => _selectedPeriod = period);
    if (_primaryPeriods.any((e) => e.key == period)) {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(MarketChartPrefKeys.klinePeriod, period);
    }
    await _loadKlineData();
    if (!mounted) return;
    ref
        .read(marketWebSocketProvider)
        .sendSwitchKlineChart(_symbol, STService.chartParam(period));
  }

  void _showMorePeriodsSheet(BuildContext context) {
    unawaited(
      _showLocalModalBottomSheet<void>(
        context: context,
        backgroundColor: context.adaptivePageGrey,
        shape: const RoundedRectangleBorder(),
        builder: (ctx) {
          final items = [
            ..._morePeriods.map((e) => (period: e, title: _periodLabel(e))),
            (period: null, title: _t('time')),
          ];
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 21, 20, 24),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.35,
                ),
                itemBuilder: (_, i) {
                  final item = items[i];
                  final selected = item.period?.key == _selectedPeriod;
                  return Material(
                    color: context.adaptiveCard,
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        Navigator.pop(ctx);
                        final period = item.period;
                        if (period == null) {
                          _showTradeDetailSheet();
                        } else {
                          _onPeriodChanged(period.key);
                        }
                      },
                      child: Center(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: selected
                                ? _kIosAccentBlue
                                : context.adaptiveTextTertiary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTradeDetailSheet() {
    unawaited(
      _showLocalModalBottomSheet<void>(
        context: context,
        backgroundColor: context.adaptiveSurfacePrimary,
        shape: const RoundedRectangleBorder(),
        builder: (ctx) {
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(ctx).height * 0.45,
              child: Column(
                children: [
                  Container(
                    height: 31,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: context.adaptiveDivider),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _t('time'),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.adaptiveTextSecondary,
                          ),
                        ),
                        Text(
                          _t('price_usd'),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.adaptiveTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ValueListenableBuilder<List<_TradeDetailTick>>(
                      valueListenable: _tradeDetailTicksNotifier,
                      builder: (_, rows, __) {
                        if (rows.isEmpty) {
                          return Center(
                            child: Text(
                              _t('no_data'),
                              style: TextStyle(
                                fontSize: 13,
                                color: context.adaptiveTextSecondary,
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          itemExtent: 25,
                          itemCount: rows.length,
                          itemBuilder: (_, i) {
                            final row = rows[i];
                            final color = row.riseStatus > 0
                                ? CardTool.priceColor(1)
                                : row.riseStatus < 0
                                ? CardTool.priceColor(-1)
                                : context.adaptiveTextSecondary;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('HH:mm:ss').format(
                                      DateTime.fromMillisecondsSinceEpoch(
                                        row.timeSec * 1000,
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: context.adaptiveTextPrimary,
                                    ),
                                  ),
                                  Text(
                                    row.price,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _footerSideColor({required bool isBuy}) {
    final base = isBuy ? CardTool.priceColor(1) : CardTool.priceColor(-1);
    if (!_isInTradeTime) {
      return base.withValues(alpha: 0.2);
    }
    if (isBuy) {
      if (_tradeMode == '0' || _tradeMode == '3' || _tradeMode == '2') {
        return base.withValues(alpha: 0.2);
      }
    } else {
      if (_tradeMode == '0' || _tradeMode == '3' || _tradeMode == '1') {
        return base.withValues(alpha: 0.2);
      }
    }
    return base;
  }

  void _onFooterTradeTap(BuildContext context, {required bool isBuy}) {
    if (!_isInTradeTime) {
      STToast.show(context, _t('market_closed'));
      return;
    }
    if (isBuy) {
      if (_tradeMode == '0' || _tradeMode == '3' || _tradeMode == '2') return;
    } else {
      if (_tradeMode == '0' || _tradeMode == '3' || _tradeMode == '1') return;
    }
    unawaited(
      ref
          .read(stRouterProvider)
          .jumpToTradePage(
            context,
            symbol: _symbol,
            isBuy: isBuy,
            action: isBuy ? '行情详情-买入' : '行情详情-卖出',
          ),
    );
  }

  Widget _buildKlinePlaceholder() {
    final message = _t(_klineErrorMessage ?? 'no_data');
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: TextStyle(fontSize: 13, color: context.adaptiveTextTertiary),
          ),
          if (_klineErrorMessage == 'requestfail') ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadKlineData,
              child: Text(_t('dkplayer_retry')),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText(stLocalizationsOfContext(context, ref));
    ref.listen<UserState>(userStateProvider, (prev, next) {
      if (prev?.isLogin != next.isLogin) {
        _syncWatchlistFlag();
      }
    });

    final riseFall = ref.watch(
      userStateProvider.select((s) => s.riseAndFallType),
    );
    final isBUser = ref.watch(userStateProvider.select((s) => s.isB));
    CardTool.setRiseAndFallType(riseFall);
    final priceColor = CardTool.priceColor(_changePercent);
    final title = _productName.isNotEmpty ? _productName : _symbol;
    final dividerColor = context.adaptiveDivider;

    return Scaffold(
      backgroundColor: context.adaptiveSurfacePrimary,
      body: Column(
        children: [
          SafeArea(bottom: false, child: _buildDetailNavBar(title)),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chartHeight = max(600.0, constraints.maxHeight * 0.72);
                return SingleChildScrollView(
                  key: const ValueKey('market-detail-vertical-scroll'),
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom:
                        (isBUser ? MediaQuery.paddingOf(context).bottom : 0) +
                        12,
                  ),
                  child: Column(
                    children: [
                      _buildBasicQuotePanel(priceColor),
                      Divider(height: 1, thickness: 0.5, color: dividerColor),
                      _buildChartToolbar(context),
                      Divider(height: 1, thickness: 0.5, color: dividerColor),
                      SizedBox(
                        height: chartHeight,
                        child: ColoredBox(
                          color: context.adaptiveSurfacePrimary,
                          child: _isLoading
                              ? const Center(child: STLoadAnimationView())
                              : _klineData.isNotEmpty
                              ? Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    4,
                                    4,
                                    4,
                                    0,
                                  ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      KlineCandleChart(
                                        data: _klineData,
                                        precision: _precision,
                                        scrollToLatestNonce: _klineScrollNonce,
                                        onNearLeftEdge: _onChartNearLeftEdge,
                                        mainStyle: _chartStyle,
                                        mainOverlay: _overlayForIndicator(
                                          _mainIndicator,
                                        ),
                                        subChartType: _subChartForIndicator(
                                          _subIndicator,
                                        ),
                                        maPeriods: _maPeriods,
                                        emaPeriods: _emaPeriods,
                                        macdFast: _macdFast,
                                        macdSlow: _macdSlow,
                                        macdSignal: _macdSignal,
                                        kdjPeriod: _kdjPeriod,
                                        kdjKSmooth: _kdjKSmooth,
                                        kdjDSmooth: _kdjDSmooth,
                                        rsiPeriod: _rsiPeriod,
                                        dmiPeriod: _dmiPeriod,
                                        showGrid: _showGrid,
                                        enableCrosshair: _enableCrosshair,
                                        timeSharingMode:
                                            _selectedPeriod == 'FS',
                                      ),
                                      if (_loadingOlderKline)
                                        const Positioned(
                                          left: 8,
                                          top: 4,
                                          child: SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                )
                              : _buildKlinePlaceholder(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (!isBUser) _buildTradeFooter(context),
        ],
      ),
    );
  }

  /// 对齐 `STMarketDetailHeaderView`：返回 | 标题 | 列表 | … | 收藏 | 合约规格（受 app_config / h5 / 品种字段控制）
  Widget _buildDetailNavBar(String title) {
    final cfg = ref.watch(configDataManagerProvider);
    final showContractSpec = MarketDetailHeaderConfig.contractSpecButtonVisible(
      appConfigDic: cfg.appConfigDic,
      h5Config: cfg.h5Config,
      symbolOverride: _contractSpecSymbolOverride,
    );

    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => context.pop(),
              color: context.adaptiveTextPrimary,
            ),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.adaptiveTextPrimary,
                      ),
                    ),
                  ),
                  Container(
                    width: 0.5,
                    height: 18,
                    margin: const EdgeInsets.only(left: 12, right: 14),
                    color: context.adaptiveDivider,
                  ),
                  GestureDetector(
                    onTap: _showHeaderSymbolSheet,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _assetIcon(
                        keyName: 'market-detail-list-icon',
                        lightAsset: _MarketDetailIconAssets.list,
                        darkAsset: _MarketDetailIconAssets.listDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: _t('optional'),
              icon: _assetIcon(
                keyName: 'market-detail-favorite-icon',
                lightAsset: _inWatchlist
                    ? _MarketDetailIconAssets.collectSelected
                    : _MarketDetailIconAssets.collect,
                darkAsset: _inWatchlist
                    ? _MarketDetailIconAssets.collectDark
                    : _MarketDetailIconAssets.collectEmptyDark,
              ),
              onPressed: _toggleFavorite,
            ),
            if (showContractSpec)
              IconButton(
                tooltip: _t('contract_attributes'),
                icon: _assetIcon(
                  keyName: 'market-detail-contract-spec-icon',
                  lightAsset: _MarketDetailIconAssets.contractSpec,
                  darkAsset: _MarketDetailIconAssets.contractSpecDark,
                ),
                onPressed: () => context.push(
                  '/market/contract_specs?symbol=${Uri.encodeComponent(_symbol)}',
                  extra: _productDetailMap,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 对齐 `STMarketDetailBasicView`：左侧现价/涨跌/时间，右侧今开、昨收、低、高
  Widget _buildBasicQuotePanel(Color priceColor) {
    final timeLine = _updateTimeSec > 0
        ? DateFormat(
            'MM-dd HH:mm:ss',
          ).format(DateTime.fromMillisecondsSinceEpoch(_updateTimeSec * 1000))
        : '--';

    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 6, 15, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fmtPx(_currentPrice),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: priceColor,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _fmtRiseAmount(),
                      style: TextStyle(fontSize: 11, color: priceColor),
                    ),
                    const SizedBox(width: 18),
                    Text(
                      _fmtRisePercent(),
                      style: TextStyle(fontSize: 11, color: priceColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${_t('update_time')}：$timeLine',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 42,
            child: Column(
              children: [
                _basicStatLine(_t('open_now'), _fmtPx(_openToday)),
                _basicStatLine(_t('received_yesterday'), _fmtPx(_preClose)),
                _basicStatLine(_t('24hour_minimum'), _fmtPx(_low24h)),
                _basicStatLine(_t('24hour_maximum'), _fmtPx(_high24h)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _basicStatLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: context.adaptiveTextTertiary),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.adaptiveTextTertiary,
            ),
          ),
        ],
      ),
    );
  }

  /// 对齐 `STChartView`：横向周期 +「更多」+ 蜡烛样式 + 指标设置
  Widget _buildChartToolbar(BuildContext context) {
    final moreSelected = _morePeriods.any((e) => e.key == _selectedPeriod);
    final chartStyleEnabled = _selectedPeriod != 'FS';
    final periodLineHeight = MediaQuery.textScalerOf(context).scale(14) * 1.2;
    final toolbarHeight = max(42.0, (periodLineHeight + 18).ceilToDouble());
    return SizedBox(
      height: toolbarHeight,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                children: [
                  for (final item in _primaryPeriods) ...[
                    _periodTextChip(
                      label: _periodLabel(item),
                      selected: item.key == _selectedPeriod,
                      onTap: () => _onPeriodChanged(item.key),
                    ),
                    const SizedBox(width: 4),
                  ],
                  GestureDetector(
                    onTap: () => _showMorePeriodsSheet(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            moreSelected
                                ? _periodLabel(
                                    _morePeriods.firstWhere(
                                      (e) => e.key == _selectedPeriod,
                                    ),
                                  )
                                : _t('kline_More'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: moreSelected
                                  ? _kIosAccentBlue
                                  : const Color(0xFF656B78),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Opacity(
                            opacity: moreSelected ? 0.9 : 1,
                            child: _assetIcon(
                              keyName: 'market-detail-more-icon',
                              lightAsset: _MarketDetailIconAssets.more,
                              darkAsset: _MarketDetailIconAssets.moreDark,
                              size: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Opacity(
              opacity: chartStyleEnabled ? 1 : 0.35,
              child: _assetIcon(
                keyName: 'market-detail-chart-style-icon',
                lightAsset: _MarketDetailIconAssets.chartStyle,
                darkAsset: _MarketDetailIconAssets.chartStyleDark,
              ),
            ),
            onPressed: chartStyleEnabled ? _showChartStyleSheet : null,
            tooltip: _t('chart'),
          ),
          IconButton(
            icon: _assetIcon(
              keyName: 'market-detail-chart-settings-icon',
              lightAsset: _MarketDetailIconAssets.chartSetting,
              darkAsset: _MarketDetailIconAssets.chartSettingDark,
            ),
            onPressed: () async {
              await context.push('/market/chart_settings');
              if (!mounted) return;
              await _reloadChartPrefs();
            },
            tooltip: _t('kline_settings'),
          ),
        ],
      ),
    );
  }

  Widget _assetIcon({
    required String keyName,
    required String lightAsset,
    String? darkAsset,
    double size = 24,
  }) {
    return SizedBox(
      key: ValueKey(keyName),
      width: size,
      height: size,
      child: Image.asset(
        context.adaptiveIsDark ? (darkAsset ?? lightAsset) : lightAsset,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _periodTextChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? _kIosAccentBlue : const Color(0xFF656B78),
          ),
        ),
      ),
    );
  }

  void _showChartStyleSheet() {
    if (_selectedPeriod == 'FS') return;

    const options = <(KlineMainChartStyle, String)>[
      (KlineMainChartStyle.candle, 'candles'),
      (KlineMainChartStyle.candleHollowAll, 'hollow_candles'),
      (KlineMainChartStyle.candleHollowRise, 'candle_up_stroke'),
      (KlineMainChartStyle.candleHollowFall, 'candle_down_stroke'),
      (KlineMainChartStyle.usLine, 'bars'),
      (KlineMainChartStyle.area, 'area'),
    ];

    unawaited(
      _showLocalModalBottomSheet<void>(
        context: context,
        backgroundColor: context.adaptivePageGrey,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.adaptiveTextHint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _t('chart'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.45,
                  ),
                  itemCount: options.length,
                  itemBuilder: (_, i) {
                    final e = options[i];
                    final style = e.$1;
                    final label = _t(e.$2);
                    final sel = _chartStyle == style;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () async {
                          Navigator.pop(ctx);
                          setState(() => _chartStyle = style);
                          await _persistChartStyle(style);
                        },
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: context.adaptiveCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              width: sel ? 1.5 : 1,
                              color: sel
                                  ? _kChartStyleSelectedTeal
                                  : context.adaptiveDivider,
                            ),
                          ),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: sel
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: sel
                                  ? _kChartStyleSelectedTeal
                                  : context.adaptiveTextPrimary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showHeaderSymbolSheet() async {
    await _runWithLocalOverlayRouteGuard(
      () => MarketProductPickerSheet.show(
        context,
        ref,
        selectedSymbol: _symbol,
        onPick: (symbol) async {
          if (!mounted || symbol.trim().isEmpty || symbol == _symbol) return;
          await _changeProduct(symbol);
        },
      ),
    );
  }

  String _fmtPx(double v) {
    if (v.abs() < 1e-12) return '--';
    return v.toStringAsFixed(_precision);
  }

  String _fmtRiseAmount() {
    if (_currentPrice.abs() < 1e-12 || _preClose.abs() < 1e-12) {
      return '--';
    }
    final sign = _change > 0 ? '+' : '';
    return '$sign${_change.toStringAsFixed(_precision)}';
  }

  String _fmtRisePercent() {
    if (_currentPrice.abs() < 1e-12 || _preClose.abs() < 1e-12) {
      return '--';
    }
    final sign = _changePercent > 0 ? '+' : '';
    return '$sign${_changePercent.toStringAsFixed(2)}%';
  }

  /// 对齐 `STMarketDetailFooterView`：当前 iOS 预警入口注释隐藏，底部仅保留卖出/买入。
  Widget _buildTradeFooter(BuildContext context) {
    final sellBg = _footerSideColor(isBuy: false);
    final buyBg = _footerSideColor(isBuy: true);

    return Container(
      color: context.adaptiveSurfacePrimary,
      padding: EdgeInsets.fromLTRB(
        15,
        8,
        15,
        8 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: sellBg,
                          borderRadius: BorderRadius.circular(9),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: () =>
                                _onFooterTradeTap(context, isBuy: false),
                            child: Center(
                              child: _footerBidAskColumn(
                                label: _t('sell'),
                                price: _bidStr,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Material(
                          color: buyBg,
                          borderRadius: BorderRadius.circular(9),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: () =>
                                _onFooterTradeTap(context, isBuy: true),
                            child: Center(
                              child: _footerBidAskColumn(
                                label: _t('buy'),
                                price: _askStr,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.adaptiveSurfacePrimary,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: context.adaptiveDivider),
                    ),
                    child: Text(
                      _spreadStr,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: context.adaptiveTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerBidAskColumn({required String label, required String price}) {
    final disp = price.isEmpty ? '--' : price;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            disp,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
