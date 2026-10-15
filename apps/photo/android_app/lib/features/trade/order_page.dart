import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';

import '../../core/config/card_tool.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/models/market_product_model.dart';
import '../../core/models/user_state.dart';
import '../../core/network/market_websocket.dart';
import '../../core/network/st_service.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../shared/widgets/st_localized_prompt.dart';

// ─── 颜色常量（对齐 iOS STColorManager）──────────────────────────────────────
Color get _kBuy => CardTool.priceColor(1); // 买入侧（STRiseColor）
Color get _kSell => CardTool.priceColor(-1); // 卖出侧（STFallColor）
const _kBlue = Color(0xFF00B57A);
const _kGrey = Color(0xFF9A9DA2);

/// 买入/卖出下单页面
///
/// 完整对齐 iOS `STTradeHomeRootViewController` 下单板 + `STTHTPSLStepperPanelView`
/// + `STTHOrderSubmitSummaryView` + `STTHVolumeLadderRowView`。
///
/// 功能：
/// - 买入/卖出双向切换，ASK/BID 实时价（WS 更新）
/// - 市价 / 限价 / 止损 三种下单类型
/// - 手数阶梯快捷选项 + ±步进
/// - 挂单价步进 + 有效期选择（仅挂单模式）
/// - 止盈/止损开关 + 步进输入（step = contract point）+ 预估盈亏
/// - 提交前验证：手数范围、挂单价范围、保证金余额
/// - 直接提交（无二次确认弹窗，对齐 iOS `confirm` 方法）
class OrderPage extends ConsumerStatefulWidget {
  final String symbol;
  final String direction;
  final String? lot;
  final String initialOrderType;
  final String? initialPendingPrice;
  final String? initialTakeProfit;
  final String? initialStopLoss;
  final String? initialPendingValidityYmd;

  const OrderPage({
    super.key,
    this.symbol = 'EUR/USD',
    this.direction = 'buy',
    this.lot,
    this.initialOrderType = 'market',
    this.initialPendingPrice,
    this.initialTakeProfit,
    this.initialStopLoss,
    this.initialPendingValidityYmd,
  });

  @override
  ConsumerState<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends ConsumerState<OrderPage> {
  static const Map<String, String> _fallbackText = {
    'spread': '点差',
    'stock_long': '买入',
    'stock_short': '卖出',
    'order_types': '订单类型',
    'market_price': '市价',
    'limit_price': '限价',
    'stop_order': '停损单',
    'lots': '交易量 (手)',
    'hand': '手',
    'validity_period': '有效期',
    'take_profit': '止盈',
    'stop_loss': '止损',
    'no_setting': '未设置',
    'margin_deposit': '保证金',
    'free_margin': '可用保证金',
    'please_pre_login': '请先登录',
    'flutter_prompt_kyc_before_order': '请先完成实名认证后再下单',
    'flutter_prompt_fund_password_before_order': '请先设置资金密码后再下单',
    'flutter_prompt_order_lot_range': '手数须在 {min} ~ {max} 之间',
    'flutter_prompt_order_pending_price_range': '挂单价须在 {min} ~ {max} 之间',
    'flutter_prompt_enter_valid_pending_price': '请输入有效的挂单价格',
    'flutter_prompt_trade_margin_not_enough': '可用保证金不足，请减少手数或入金',
    'system_busy': '系统繁忙，请稍后再试',
    'flutter_prompt_order_success': '下单成功',
    'flutter_prompt_pending_order_success': '挂单成功',
    'flutter_prompt_order_failed': '下单失败',
  };

  // ── 方向 & 类型 ──────────────────────────────────────────────────────────
  late bool _isBuy;

  /// `market` | `limit` | `stop`
  late String _orderType;

  // ── 报价（WS 实时）──────────────────────────────────────────────────────
  double _bid = 0;
  double _ask = 0;
  int _digits = 5;

  // ── 合约信息（from API）────────────────────────────────────────────────
  double _minLot = 0.01;
  double _maxLot = 10.0;
  double _stepLot = 0.01;
  double _point = 0.0001; // 单步（对齐 iOS point）
  double _leverage = 100.0;
  List<String> _lotLadder = const ['0.01', '0.1', '0.5', '1.0', '5.0'];

  // ── 手数 ────────────────────────────────────────────────────────────────
  late double _lots;

  // ── 挂单价 ──────────────────────────────────────────────────────────────
  final _pendingPriceCtrl = TextEditingController();
  double _pendingMinPrice = 0;
  double _pendingMaxPrice = 0;

  // ── 有效期 ──────────────────────────────────────────────────────────────
  late DateTime _validityDay;
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  // ── 止盈/止损 ────────────────────────────────────────────────────────────
  bool _tpEnabled = false;
  bool _slEnabled = false;
  final _tpCtrl = TextEditingController();
  final _slCtrl = TextEditingController();

  // ── UI 状态 ─────────────────────────────────────────────────────────────
  bool _isLoading = true;
  bool _isSubmitting = false;

  // ── WS ──────────────────────────────────────────────────────────────────
  StreamSubscription<MarketWSMessage>? _wsSub;
  String? _languageCode;
  int _languageLoadToken = 0;
  Map<String, String> _text = _fallbackText;

  // ─────────────────────────────────────────────
  // 生命周期
  // ─────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _isBuy = widget.direction.toLowerCase() != 'sell';
    _lots = double.tryParse(widget.lot ?? '0.01') ?? 0.01;
    final ot = widget.initialOrderType.toLowerCase().trim();
    _orderType = (ot == 'limit' || ot == 'stop') ? ot : 'market';

    _pendingPriceCtrl.text = widget.initialPendingPrice?.trim() ?? '';
    _tpCtrl.text = widget.initialTakeProfit?.trim() ?? '';
    _slCtrl.text = widget.initialStopLoss?.trim() ?? '';
    if (_tpCtrl.text.isNotEmpty) _tpEnabled = true;
    if (_slCtrl.text.isNotEmpty) _slEnabled = true;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 默认有效期：今日 + 6 天（对齐 iOS afterDateWithFilter:SevenDays）
    _validityDay = today.add(const Duration(days: 6));
    if (widget.initialPendingValidityYmd != null) {
      final parsed = DateTime.tryParse(widget.initialPendingValidityYmd!);
      if (parsed != null) {
        _validityDay = DateTime(parsed.year, parsed.month, parsed.day);
      }
    }

    _wsSub = ref
        .read(marketWebSocketProvider)
        .messageStream
        .listen(_onWsMessage);
    _loadSymbolInfo();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _pendingPriceCtrl.dispose();
    _tpCtrl.dispose();
    _slCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLocalizedTextsIfNeeded();
  }

  void _loadLocalizedTextsIfNeeded() {
    final localizations = stLocalizationsOfContext(context, ref);
    if (_languageCode == localizations.languageCode) return;
    _languageCode = localizations.languageCode;

    final token = ++_languageLoadToken;
    localizations.textMap(_fallbackText).then((value) {
      if (!mounted || token != _languageLoadToken) return;
      setState(() => _text = value);
    });
  }

  String _t(String key) => _text[key] ?? _fallbackText[key] ?? key;

  String _leverageLabel() {
    final code = (_languageCode ?? 'zh-Hans').toLowerCase();
    if (code.startsWith('ko')) return '레버리지';
    if (code.startsWith('en')) return 'Leverage';
    return '杠杆';
  }

  // ─────────────────────────────────────────────
  // WebSocket 实时报价
  // ─────────────────────────────────────────────

  void _onWsMessage(MarketWSMessage msg) {
    if (msg.type != 'TRANSACTION_UPDATE_SYMBOL_PRICE' &&
        msg.type != 'UPDATE_SELL_AND_BUY') {
      return;
    }
    final data = msg.data;
    final sym = data['symbol']?.toString() ?? '';
    if (sym != widget.symbol) return;
    final bid = _toDouble(data['bid']);
    final ask = _toDouble(data['ask']);
    if (!mounted) return;
    setState(() {
      if (bid > 0) _bid = bid;
      if (ask > 0) _ask = ask;
    });
  }

  // ─────────────────────────────────────────────
  // 加载合约信息（对齐 iOS fetchSymbolInfoWire）
  // ─────────────────────────────────────────────

  Future<void> _loadSymbolInfo() async {
    try {
      final st = ref.read(stServiceProvider);
      // 进入品种 WS 房间
      ref.read(marketWebSocketProvider).sendEnterTransactionPage(widget.symbol);

      final info = await st.getSymbolInfo(widget.symbol);

      final bid = _toDouble(info['bid'] ?? info['Bid'] ?? info['sell']);
      final ask = _toDouble(info['ask'] ?? info['Ask'] ?? info['buy']);
      final digits = _toInt(info['digits']) ?? 5;
      final minLot = _toDouble(
        info['min_lot'] ?? info['minLot'] ?? info['min_volume'],
      );
      final maxLot = _toDouble(
        info['max_lot'] ?? info['maxLot'] ?? info['max_volume'],
      );
      final stepLot = _toDouble(
        info['step_lot'] ??
            info['lotStep'] ??
            info['lot_step'] ??
            info['volume_step'],
      );
      final point = _toDouble(info['point'] ?? info['tick_size']);
      final leverage = _toDouble(info['leverage'] ?? info['contract_leverage']);

      if (!mounted) return;
      setState(() {
        if (bid > 0) _bid = bid;
        if (ask > 0) _ask = ask;
        _digits = digits;
        if (minLot > 0) _minLot = minLot;
        if (maxLot > 0) _maxLot = maxLot;
        if (stepLot > 0) _stepLot = stepLot;
        if (point > 0) _point = point;
        if (leverage > 0) _leverage = leverage;

        // 构建手数阶梯（对齐 iOS STTHVolumeLadderRowView）
        _lotLadder = _buildLotLadder(_minLot, _maxLot, _stepLot);

        // 确保当前手数在合法范围内
        if (_lots < _minLot) _lots = _minLot;
        if (_lots > _maxLot) _lots = _maxLot;

        // 挂单价区间（仅用于提交校验；iOS 从合约接口取 pendingMinPrice/pendingMaxPrice）
        final minP = _toDouble(info['pending_min_price'] ?? info['min_price']);
        final maxP = _toDouble(info['pending_max_price'] ?? info['max_price']);
        if (minP > 0) _pendingMinPrice = minP;
        if (maxP > 0) _pendingMaxPrice = maxP;

        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 构建 5 个快捷手数选项（对齐 iOS STTHVolumeLadderRowView lotLadder）
  static List<String> _buildLotLadder(double min, double max, double step) {
    final anchors = <double>[];
    var cur = min;
    while (anchors.length < 5 && cur <= max) {
      anchors.add(cur);
      if (cur < 0.1) {
        cur = (cur + step).clamp(0, max);
        if (cur < 0.1 && anchors.length < 4) continue;
        cur = 0.1;
      } else if (cur < 0.5) {
        cur = 0.5;
      } else if (cur < 1.0) {
        cur = 1.0;
      } else if (cur < 5.0) {
        cur = 5.0;
      } else {
        break;
      }
    }
    if (anchors.isEmpty) return ['0.01', '0.1', '0.5', '1.0', '5.0'];
    return anchors.map((v) => _fmtLots(v)).toList();
  }

  // ─────────────────────────────────────────────
  // 下单提交（对齐 iOS confirm 方法，无确认弹窗）
  // ─────────────────────────────────────────────

  Future<void> _refreshSubmitAuthStateIfNeeded() async {
    final user = ref.read(userStateProvider);
    if (!user.isLogin) return;
    if (user.isAuthed && user.isBindFundPassword) return;
    await ref.read(userStateProvider.notifier).refreshAuthStatus(
      ref.read(stServiceProvider),
    );
  }

  Future<void> _submit() async {
    await _refreshSubmitAuthStateIfNeeded();
    if (!mounted) return;
    final user = ref.read(userStateProvider);

    // ── 前置验证（对齐 iOS checkLogin + KYC + 资金密码）────────────────────
    if (!user.isLogin) {
      showStLocalizedToast(context, _fallbackText['please_pre_login']!);
      context.push('/auth/login');
      return;
    }
    if (!user.isAuthed) {
      showStLocalizedToast(
        context,
        _fallbackText['flutter_prompt_kyc_before_order']!,
      );
      return;
    }
    if (!user.isBindFundPassword) {
      showStLocalizedToast(
        context,
        _fallbackText['flutter_prompt_fund_password_before_order']!,
      );
      return;
    }

    // ── 手数校验（对齐 iOS lots range check）────────────────────────────────
    if (_lots < _minLot || _lots > _maxLot) {
      showStLocalizedToast(
        context,
        _fallbackText['flutter_prompt_order_lot_range']!,
        replacements: {'min': _fmtLots(_minLot), 'max': _fmtLots(_maxLot)},
      );
      return;
    }

    // ── 挂单价校验 ─────────────────────────────────────────────────────────
    String pendingPriceStr = '';
    if (_orderType != 'market') {
      pendingPriceStr = _pendingPriceCtrl.text.trim();
      final pp = double.tryParse(pendingPriceStr) ?? 0;
      if (pp <= 0) {
        showStLocalizedToast(
          context,
          _fallbackText['flutter_prompt_enter_valid_pending_price']!,
        );
        return;
      }
      if (_pendingMinPrice > 0 && _pendingMaxPrice > 0) {
        if (pp < _pendingMinPrice || pp > _pendingMaxPrice) {
          showStLocalizedToast(
            context,
            _fallbackText['flutter_prompt_order_pending_price_range']!,
            replacements: {
              'min': _fmtPrice(_pendingMinPrice),
              'max': _fmtPrice(_pendingMaxPrice),
            },
          );
          return;
        }
      }
    }

    // ── 保证金余额校验（对齐 iOS marginFree check）──────────────────────────
    // equity ≈ iOS marginFree（可用净值）
    final freeMarginStr = user.accountAry.isNotEmpty
        ? user.accountAry.first.equity
        : '';
    final freeMargin = double.tryParse(freeMarginStr) ?? 0;
    if (freeMargin > 0 && _estimatedMargin > freeMargin) {
      showStLocalizedToast(
        context,
        _fallbackText['flutter_prompt_trade_margin_not_enough']!,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final st = ref.read(stServiceProvider);
      final dirInt = _isBuy ? 0 : 1;
      final tp = _tpEnabled
          ? (_tpCtrl.text.trim().isEmpty ? '0' : _tpCtrl.text.trim())
          : '0';
      final sl = _slEnabled
          ? (_slCtrl.text.trim().isEmpty ? '0' : _slCtrl.text.trim())
          : '0';

      Map<String, dynamic> res;
      if (_orderType == 'market') {
        // 市价开仓（对齐 iOS openPositionWithParams:）
        res = await st.submitOrder({
          'symbol': widget.symbol,
          'direction': dirInt,
          'lots': _fmtLots(_lots),
          'take_profit': tp,
          'stop_loss': sl,
        });
      } else {
        // 挂单（对齐 iOS createPendingOrderWithParams:）
        final pendingType = _orderType == 'limit' ? 0 : 1; // 0=限价 1=止损
        res = await st.submitPendingOrder({
          'pending_type': pendingType,
          'symbol': widget.symbol,
          'direction': dirInt,
          'lots': _fmtLots(_lots),
          'price': pendingPriceStr,
          'expire_time': _endOfDayTs(_validityDay),
          'take_profit': tp,
          'stop_loss': sl,
        });
      }

      if (!mounted) return;

      // 对齐 iOS: code==200162 → 系统繁忙
      final code = res['code'];
      if (code == 200162 ||
          (code is num && code.toInt() == 200162) ||
          code?.toString() == '200162') {
        showStLocalizedToast(context, _fallbackText['system_busy']!);
        return;
      }

      ref
          .read(userStateProvider.notifier)
          .rememberTradeSelection(symbol: widget.symbol, lot: _fmtLots(_lots));

      if (mounted) {
        showStLocalizedToast(
          context,
          _orderType == 'market'
              ? _fallbackText['flutter_prompt_order_success']!
              : _fallbackText['flutter_prompt_pending_order_success']!,
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        showStLocalizedErrorToast(
          context,
          _fallbackText['flutter_prompt_order_failed']!,
          e,
          separator: '：',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─────────────────────────────────────────────
  // 计算值
  // ─────────────────────────────────────────────

  /// 当前方向报价（买看 ASK，卖看 BID，对齐 iOS）
  double get _quotePrice =>
      _isBuy ? (_ask > 0 ? _ask : _bid) : (_bid > 0 ? _bid : _ask);

  /// 点差
  double get _spread => (_ask > 0 && _bid > 0) ? (_ask - _bid) : 0;

  /// 预估占用保证金（对齐 iOS reservedMargin 公式：手数 × 合约面值 / 杠杆）
  double get _estimatedMargin {
    const contractSize = 100000.0; // 标准手合约面值
    return _quotePrice * _lots * contractSize / _leverage;
  }

  /// 止盈预估盈亏（用于展示，非精确）
  String _estimatePnL(String priceStr, {required bool isTP}) {
    final px = double.tryParse(priceStr) ?? 0;
    if (px <= 0 || _quotePrice <= 0) return '--';
    const contractSize = 100000.0;
    double pnl;
    if (_isBuy) {
      pnl = (px - _quotePrice) * _lots * contractSize;
    } else {
      pnl = (_quotePrice - px) * _lots * contractSize;
    }
    if (!isTP) pnl = -pnl;
    return '${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(2)}';
  }

  // ─────────────────────────────────────────────
  // 格式化
  // ─────────────────────────────────────────────

  String _fmtPrice(double v) {
    if (v == 0) return '--';
    return v.toStringAsFixed(_digits);
  }

  static String _fmtLots(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    // 最多 2 位小数
    final s = v.toStringAsFixed(2);
    return s.endsWith('00')
        ? v.toInt().toString()
        : s.replaceAll(RegExp(r'0+$'), '');
  }

  static int _endOfDayTs(DateTime day) {
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59);
    return end.millisecondsSinceEpoch ~/ 1000;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  // ─────────────────────────────────────────────
  // 日期选择
  // ─────────────────────────────────────────────

  Future<void> _pickValidity() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final init = _validityDay.isBefore(today) ? today : _validityDay;
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: _t('validity_period'),
    );
    if (picked != null && mounted) {
      setState(
        () => _validityDay = DateTime(picked.year, picked.month, picked.day),
      );
    }
  }

  // ─────────────────────────────────────────────
  // build
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final riseFall = ref.watch(
      userStateProvider.select((s) => s.riseAndFallType),
    );
    CardTool.setRiseAndFallType(riseFall);
    final activeColor = _isBuy ? _kBuy : _kSell;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = context.adaptivePageGrey;
    final navBg = context.adaptiveSurfacePrimary;
    final textColor = context.adaptiveTextPrimary;
    final dividerColor = context.adaptiveDivider;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: navBg,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        centerTitle: true,
        title: Text(
          widget.symbol,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: dividerColor),
        ),
      ),
      body: _isLoading
          ? const Center(child: STLoadAnimationView())
          : _buildBody(activeColor),
    );
  }

  Widget _buildBody(Color activeColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ① 买卖方向切换 + 报价
          _buildDirectionHeader(),
          const SizedBox(height: 8),

          // ② 订单类型
          _buildSection(child: _buildOrderTypeRow()),
          const SizedBox(height: 8),

          // ③ 手数
          _buildSection(child: _buildLotsRow()),
          const SizedBox(height: 8),

          // ④ 挂单价 + 有效期（pending only）
          if (_orderType != 'market') ...[
            _buildSection(child: _buildPendingPriceRow()),
            const SizedBox(height: 8),
            _buildSection(child: _buildValidityRow()),
            const SizedBox(height: 8),
          ],

          // ⑤ 止盈/止损
          _buildSection(child: _buildTPSLPanel()),
          const SizedBox(height: 8),

          // ⑥ 保证金摘要 + 提交
          _buildSubmitSection(activeColor),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── ① 买卖方向切换 ──────────────────────────────────────────────────────

  Widget _buildDirectionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // 买入
          Expanded(child: _buildDirButton(isBuy: true)),
          // 点差
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                Text(
                  _spread > 0 ? (_spread / _point).toStringAsFixed(0) : '--',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kGrey,
                  ),
                ),
                Text(
                  _t('spread'),
                  style: const TextStyle(fontSize: 10, color: _kGrey),
                ),
              ],
            ),
          ),
          // 卖出
          Expanded(child: _buildDirButton(isBuy: false)),
        ],
      ),
    );
  }

  Widget _buildDirButton({required bool isBuy}) {
    final isSelected = _isBuy == isBuy;
    final color = isBuy ? _kBuy : _kSell;
    final price = isBuy ? _ask : _bid;
    final label = isBuy ? _t('stock_long') : _t('stock_short');

    return GestureDetector(
      onTap: () => setState(() => _isBuy = isBuy),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 64,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _fmtPrice(price),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ② 订单类型 ──────────────────────────────────────────────────────────

  Widget _buildOrderTypeRow() {
    final types = [
      ('market', _t('market_price')),
      ('limit', _t('limit_price')),
      ('stop', _t('stop_order')),
    ];
    return Row(
      children: [
        _RowLabel(_t('order_types')),
        const Spacer(),
        ...types.map((t) {
          final sel = _orderType == t.$1;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: GestureDetector(
              onTap: () => setState(() {
                _orderType = t.$1;
                if (_orderType != 'market' && _pendingPriceCtrl.text.isEmpty) {
                  _pendingPriceCtrl.text = _fmtPrice(_quotePrice);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: sel ? _kBlue : context.adaptiveMutedBlock,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  t.$2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                    color: sel ? Colors.white : context.adaptiveTextTertiary,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ─── ③ 手数 ──────────────────────────────────────────────────────────────

  Widget _buildLotsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _RowLabel(_t('lots')),
            const Spacer(),
            // − stepper
            _StepperButton(
              icon: Icons.remove,
              onTap: () {
                final next = _lots - _stepLot;
                if (next >= _minLot) setState(() => _lots = _round(next));
              },
            ),
            const SizedBox(width: 10),
            // 当前值
            SizedBox(
              width: 72,
              child: Text(
                _fmtLots(_lots),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.adaptiveTextPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // + stepper
            _StepperButton(
              icon: Icons.add,
              onTap: () {
                final next = _lots + _stepLot;
                if (next <= _maxLot) setState(() => _lots = _round(next));
              },
            ),
          ],
        ),
        if (_lotLadder.isNotEmpty) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _lotLadder.map((l) {
                final v = double.tryParse(l) ?? 0;
                final sel = (_lots - v).abs() < 1e-9;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _lots = v),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 130),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? (_isBuy ? _kBuy : _kSell).withValues(alpha: 0.12)
                            : context.adaptiveMutedBlock,
                        borderRadius: BorderRadius.circular(16),
                        border: sel
                            ? Border.all(
                                color: _isBuy ? _kBuy : _kSell,
                                width: 1,
                              )
                            : null,
                      ),
                      child: Text(
                        l,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          color: sel
                              ? (_isBuy ? _kBuy : _kSell)
                              : context.adaptiveTextTertiary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 2),
        Text(
          _t('flutter_prompt_order_lot_range')
              .replaceAll('{min}', _fmtLots(_minLot))
              .replaceAll('{max}', _fmtLots(_maxLot)),
          style: const TextStyle(fontSize: 11, color: _kGrey),
        ),
      ],
    );
  }

  double _round(double v) =>
      double.parse(v.toStringAsFixed(_stepLot < 0.01 ? 3 : 2));

  // ─── ④ 挂单价 ────────────────────────────────────────────────────────────

  Widget _buildPendingPriceRow() {
    final label = _orderType == 'limit' ? _t('limit_price') : _t('stop_order');
    return Row(
      children: [
        _RowLabel(label),
        const Spacer(),
        _StepperButton(
          icon: Icons.remove,
          onTap: () {
            final cur = double.tryParse(_pendingPriceCtrl.text) ?? _quotePrice;
            setState(
              () => _pendingPriceCtrl.text = _fmtPrice(
                (cur - _point).clamp(0, double.infinity),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: TextField(
            controller: _pendingPriceCtrl,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.adaptiveTextPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 6,
                horizontal: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: context.adaptiveDivider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _kBlue),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _StepperButton(
          icon: Icons.add,
          onTap: () {
            final cur = double.tryParse(_pendingPriceCtrl.text) ?? _quotePrice;
            setState(() => _pendingPriceCtrl.text = _fmtPrice(cur + _point));
          },
        ),
      ],
    );
  }

  // ─── 有效期 ──────────────────────────────────────────────────────────────

  Widget _buildValidityRow() {
    return GestureDetector(
      onTap: _pickValidity,
      child: Row(
        children: [
          _RowLabel(_t('validity_period')),
          const Spacer(),
          Text(
            _dateFmt.format(_validityDay),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: context.adaptiveTextPrimary,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 18, color: _kGrey),
        ],
      ),
    );
  }

  // ─── ⑤ 止盈/止损面板（对齐 iOS STTHTPSLStepperPanelView）────────────────

  Widget _buildTPSLPanel() {
    return Column(
      children: [
        _buildTPSLRow(
          label: _t('take_profit'),
          enabled: _tpEnabled,
          ctrl: _tpCtrl,
          color: _kBuy,
          onToggle: (v) => setState(() {
            _tpEnabled = v;
            if (v && _tpCtrl.text.isEmpty) {
              _tpCtrl.text = _fmtPrice(_quotePrice);
            }
          }),
          estimatedPnL: _tpEnabled
              ? _estimatePnL(_tpCtrl.text, isTP: true)
              : null,
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Divider(height: 1, color: context.adaptiveDivider),
        ),
        _buildTPSLRow(
          label: _t('stop_loss'),
          enabled: _slEnabled,
          ctrl: _slCtrl,
          color: _kSell,
          onToggle: (v) => setState(() {
            _slEnabled = v;
            if (v && _slCtrl.text.isEmpty) {
              _slCtrl.text = _fmtPrice(_quotePrice);
            }
          }),
          estimatedPnL: _slEnabled
              ? _estimatePnL(_slCtrl.text, isTP: false)
              : null,
        ),
      ],
    );
  }

  Widget _buildTPSLRow({
    required String label,
    required bool enabled,
    required TextEditingController ctrl,
    required Color color,
    required ValueChanged<bool> onToggle,
    String? estimatedPnL,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // 复选框（对齐 iOS profitCheckBtn）
          GestureDetector(
            onTap: () => onToggle(!enabled),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled ? color : Colors.transparent,
                border: Border.all(color: enabled ? color : _kGrey, width: 1.5),
              ),
              child: enabled
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          _RowLabel(label),
          if (estimatedPnL != null) ...[
            const SizedBox(width: 6),
            Text(
              estimatedPnL,
              style: TextStyle(
                fontSize: 11,
                color: estimatedPnL.startsWith('+') ? _kBuy : _kSell,
              ),
            ),
          ],
          const Spacer(),
          if (enabled) ...[
            _StepperButton(
              icon: Icons.remove,
              onTap: () {
                final cur = double.tryParse(ctrl.text) ?? _quotePrice;
                setState(
                  () => ctrl.text = _fmtPrice(
                    (cur - _point).clamp(0, double.infinity),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: TextField(
                controller: ctrl,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.adaptiveTextPrimary,
                ),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: context.adaptiveDivider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: color),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _StepperButton(
              icon: Icons.add,
              onTap: () {
                final cur = double.tryParse(ctrl.text) ?? _quotePrice;
                setState(() => ctrl.text = _fmtPrice(cur + _point));
              },
            ),
          ] else
            Text(
              _t('no_setting'),
              style: const TextStyle(fontSize: 13, color: _kGrey),
            ),
        ],
      ),
    );
  }

  // ─── ⑥ 提交区（对齐 iOS STTHOrderSubmitSummaryView）─────────────────────

  Widget _buildSubmitSection(Color activeColor) {
    final user = ref.read(userStateProvider);
    final hasKyc = user.isAuthed;
    final hasFundPwd = user.isBindFundPassword;
    final freeMarginStr = user.accountAry.isNotEmpty
        ? user.accountAry.first.equity
        : '';
    final freeMargin = double.tryParse(freeMarginStr) ?? 0;
    final margin = _estimatedMargin;
    final marginInsufficient = freeMargin > 0 && margin > freeMargin;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // 保证金信息行
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.adaptiveCard,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: Column(
              children: [
                _InfoLine(
                  label: _t('margin_deposit'),
                  value: margin > 0 ? '\$${margin.toStringAsFixed(2)}' : '--',
                  valueColor: marginInsufficient ? _kSell : null,
                ),
                const SizedBox(height: 6),
                _InfoLine(
                  label: _leverageLabel(),
                  value: '1:${_leverage.toInt()}',
                ),
                if (freeMargin > 0) ...[
                  const SizedBox(height: 6),
                  _InfoLine(
                    label: _t('free_margin'),
                    value: '\$${freeMargin.toStringAsFixed(2)}',
                    valueColor: marginInsufficient ? _kSell : _kBuy,
                  ),
                ],
                if (marginInsufficient) ...[
                  const SizedBox(height: 8),
                  Text(
                    _t('flutter_prompt_trade_margin_not_enough'),
                    style: TextStyle(fontSize: 12, color: _kSell),
                  ),
                ],
              ],
            ),
          ),
          // 提示横幅（未认证/未设资金密码）
          if (!hasKyc || !hasFundPwd)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFFFF8E1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!hasKyc)
                    Text(
                      '• ${_t("flutter_prompt_kyc_before_order")}',
                      style: TextStyle(fontSize: 12, color: Color(0xFFE65100)),
                    ),
                  if (!hasFundPwd)
                    Text(
                      '• ${_t("flutter_prompt_fund_password_before_order")}',
                      style: TextStyle(fontSize: 12, color: Color(0xFFE65100)),
                    ),
                ],
              ),
            ),
          // 提交按钮
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: activeColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: activeColor.withValues(alpha: 0.5),
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(10),
                  ),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isBuy
                          ? '${_t("stock_long")} ${_fmtLots(_lots)} ${_t("hand")}'
                          : '${_t("stock_short")} ${_fmtLots(_lots)} ${_t("hand")}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 通用 Section 容器 ───────────────────────────────────────────────────

  Widget _buildSection({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────
// 子组件
// ─────────────────────────────────────────────

class _RowLabel extends StatelessWidget {
  final String text;
  const _RowLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: context.adaptiveTextPrimary,
    ),
  );
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: context.adaptiveMutedBlock,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 18, color: context.adaptiveTextPrimary),
    ),
  );
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoLine({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 13, color: context.adaptiveTextSecondary),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: valueColor ?? context.adaptiveTextPrimary,
        ),
      ),
    ],
  );
}
