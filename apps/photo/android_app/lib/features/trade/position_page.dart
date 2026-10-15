import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jufu/shared/widgets/st_pull_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';

import '../../core/config/card_tool.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/models/market_product_model.dart';
import '../../core/models/user_state.dart';
import '../../core/network/market_websocket.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/network/st_service.dart';
import '../../core/providers/event_bus.dart';
import '../../core/theme/context_adaptive_colors.dart';
import 'trade_close_out_progress_dialog.dart';
import 'trade_confirm_dialog.dart';
import 'trade_empty_state.dart';
import 'package:jufu/shared/widgets/st_toast.dart';

// ─── 颜色常量 ───────────────────────────────────────────────────────────────
const _kGreen = Color(0xFF4DCB73);
const _kRed = Color(0xFFF95959);
const _kGrey = Color(0xFF9A9DA2);
const _kSep = Color(0xFFEEEEEE);
const _kText = Color(0xFF0B1023);

// ─── 实时买卖价缓存（对齐 iOS priceCache） ─────────────────────────────────
class _LiveBidAsk {
  final double bid;
  final double ask;
  const _LiveBidAsk(this.bid, this.ask);
}

/// 持仓列表页面
///
/// 对齐 iOS `STTradeHomeLedgerDetailCell`（持仓段）+
/// `STTradePositionActionView`（平仓/止盈止损底部面板）+
/// `STTradeHomeRootViewController`（WS 实时价刷新）
class PositionPage extends ConsumerStatefulWidget {
  final String? languageCodeOverride;

  const PositionPage({super.key, this.languageCodeOverride});

  @override
  ConsumerState<PositionPage> createState() => _PositionPageState();
}

class _PositionPageState extends ConsumerState<PositionPage> {
  static const Map<String, String> _fallbackText = {
    'positions': '持仓',
    'positions_num': r'持仓 (%1$s)',
    'floating_profit_loss': '浮动盈亏',
    'open_price_title': '开仓价',
    'current_price': '当前价',
    'take_profit': '止盈',
    'stop_loss': '止损',
    'stop_loss_and_take_profit': '止盈/止损',
    'close_a_position': '平仓',
    'confirm_close_position': '确认平仓',
    'cancel': '取消',
    'save': '保存',
    'select': '选择',
    'buy': '买入',
    'sell': '卖出',
    'hand': '手',
    'no_holder_positions': '暂无持仓',
    'commission': '佣金',
    'close_success': '平仓成功',
    'close_fail': '平仓失败',
    'modify_success': '修改成功',
    'modify_fail': '修改失败',
    'dkplayer_retry': '重试',
  };

  List<Map<String, dynamic>> _positions = [];
  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  String? _errorMessage;

  /// 批量选择模式（对齐 iOS 批量平仓交互）
  bool _batchMode = false;
  final Set<String> _selectedIds = {};

  /// WS 实时买卖价缓存
  final Map<String, _LiveBidAsk> _live = {};
  StreamSubscription<MarketWSMessage>? _wsSub;
  String? _languageCode;
  Future<Map<String, String>>? _localizedTextFuture;
  Map<String, String> _text = _fallbackText;

  // ── 总浮动盈亏 ───────────────────────────────
  double get _totalPnl => _positions.fold(0.0, (sum, pos) => sum + _pnlOf(pos));

  @override
  void initState() {
    super.initState();
    _loadPositions();
    // 订阅 WS 行情推送（对齐 iOS th_onMarketSocketMessage）
    _wsSub = ref
        .read(marketWebSocketProvider)
        .messageStream
        .listen(_onWsMessage);
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  Future<Map<String, String>> _ensureLocalizedTexts() {
    final languageCode =
        widget.languageCodeOverride ?? stLanguageCodeOfContext(context);
    if (_localizedTextFuture != null && _languageCode == languageCode) {
      return _localizedTextFuture!;
    }
    _languageCode = languageCode;
    _localizedTextFuture = STLocalizations(
      bundle: ref.read(iosLanguageBundleProvider),
      languageCode: languageCode,
    ).textMap(_fallbackText);
    return _localizedTextFuture!;
  }

  String _t(String key) => _text[key] ?? _fallbackText[key] ?? key;

  // ─────────────────────────────────────────────
  // 数据加载
  // ─────────────────────────────────────────────

  Future<void> _loadPositions({bool showLoading = true}) async {
    final shouldShowLoading = showLoading || !_hasLoadedOnce;
    setState(() {
      _isLoading = shouldShowLoading;
      if (shouldShowLoading) {
        _errorMessage = null;
      }
    });
    try {
      final raw = await ref.read(stServiceProvider).getPositions();
      if (!mounted) return;
      final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        _positions = list;
        _hasLoadedOnce = true;
        _isLoading = false;
      });
      // 进入各品种 WS 房间（对齐 iOS sendEnterTransactionPage）
      final ws = ref.read(marketWebSocketProvider);
      final symbols = list.map((p) => _sym(p)).toSet();
      for (final s in symbols) {
        if (s.isNotEmpty) ws.sendEnterTransactionPage(s);
      }
    } catch (e) {
      if (!mounted) return;
      if (shouldShowLoading) {
        setState(() {
          _errorMessage = stUserVisibleErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  // ─────────────────────────────────────────────
  // WebSocket 实时报价
  // 对齐 iOS TRANSACTION_UPDATE_SYMBOL_PRICE 处理
  // ─────────────────────────────────────────────

  void _onWsMessage(MarketWSMessage msg) {
    if (msg.type == 'TRANSACTION_UPDATE_SYMBOL_PRICE' ||
        msg.type == 'UPDATE_SELL_AND_BUY') {
      final data = msg.data;
      final sym = data['symbol']?.toString() ?? '';
      if (sym.isEmpty) return;
      final bid = _toDouble(data['bid']);
      final ask = _toDouble(data['ask']);
      if (bid > 0 || ask > 0) {
        setState(() {
          _live[sym] = _LiveBidAsk(bid, ask);
        });
      }
    }
  }

  // ─────────────────────────────────────────────
  // 当前价（对齐 iOS 买仓用 bid，卖仓用 ask）
  // ─────────────────────────────────────────────

  double _currentPrice(Map<String, dynamic> pos) {
    final sym = _sym(pos);
    final live = _live[sym];
    if (live != null) {
      return _isBuy(pos) ? live.bid : live.ask;
    }
    return _toDouble(pos['current_price'] ?? pos['price']);
  }

  // ─────────────────────────────────────────────
  // 平仓
  // ─────────────────────────────────────────────

  Future<void> _closePosition(Map<String, dynamic> pos) async {
    final pid = _posId(pos);
    if (pid.isEmpty) return;

    final confirmed = await _showCloseSheet(pos);
    if (confirmed != true || !mounted) return;

    try {
      final body = <String, dynamic>{
        'symbol': _sym(pos),
        'direction': _dirInt(pos['direction']),
        'lots': _lotsStr(pos),
        'position_id': int.tryParse(pid) ?? pid,
      };
      await ref.read(stServiceProvider).closePosition(body);
      if (!mounted) return;
      _showSnack(_t('close_success'));
      EventBus().emit(EventBus.tradePositionListRefresh);
      _loadPositions();
    } catch (e) {
      if (mounted) {
        _showSnack(
          '${_t("close_fail")}: ${stUserVisibleErrorMessage(e)}',
          isError: true,
        );
      }
    }
  }

  Future<void> _batchClose() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await _showBatchCloseDialog();
    if (confirmed != true || !mounted) return;

    TradeCloseOutProgressOverlayController? progressOverlay;
    try {
      final selected = _positions
          .where((p) => _selectedIds.contains(_posId(p)))
          .map(
            (p) => {
              'symbol': _sym(p),
              'direction': _dirInt(p['direction']),
              'lots': _lotsStr(p),
              'position_id': int.tryParse(_posId(p)) ?? _posId(p),
            },
          )
          .toList();
      if (selected.isEmpty) return;
      progressOverlay = showTradeCloseOutProgressOverlay(
        context: context,
        progressValue: '0/${selected.length}',
      );
      await ref.read(stServiceProvider).batchClosePositions({
        'positions': selected,
      });
      progressOverlay.updateProgress('${selected.length}/${selected.length}');
      if (!mounted) return;
      setState(() {
        _batchMode = false;
        _selectedIds.clear();
      });
      _showSnack(_t('close_success'));
      EventBus().emit(EventBus.tradePositionListRefresh);
      _loadPositions();
    } catch (e) {
      if (mounted) {
        _showSnack(
          '${_t("close_fail")}: ${stUserVisibleErrorMessage(e)}',
          isError: true,
        );
      }
    } finally {
      progressOverlay?.dismiss();
    }
  }

  // ─────────────────────────────────────────────
  // 修改止盈止损
  // ─────────────────────────────────────────────

  Future<void> _editPosition(Map<String, dynamic> pos) async {
    final pid = _posId(pos);
    if (pid.isEmpty) return;

    final result = await _showEditSheet(pos);
    if (result == null || !mounted) return;

    try {
      final payload = <String, dynamic>{
        'symbol': _sym(pos),
        'take_profit': result['take_profit'] ?? '0',
        'stop_loss': result['stop_loss'] ?? '0',
      };
      final asInt = int.tryParse(pid);
      if (asInt != null) {
        payload['position_id'] = asInt;
      } else {
        payload['order_id'] = pid;
      }
      await ref.read(stServiceProvider).editPosition(payload);
      if (!mounted) return;
      _showSnack(_t('modify_success'));
      _loadPositions();
    } catch (e) {
      if (mounted) {
        _showSnack(
          '${_t("modify_fail")}: ${stUserVisibleErrorMessage(e)}',
          isError: true,
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  // 底部面板（对齐 iOS STTradePositionActionView）
  // ─────────────────────────────────────────────

  Future<bool?> _showCloseSheet(Map<String, dynamic> pos) {
    final sym = _sym(pos);
    final isBuy = _isBuy(pos);
    final cp = _currentPrice(pos);
    final op = _toDouble(pos['open_price'] ?? pos['price']);
    final pnl = _pnlOf(pos);

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖把
              const _DragHandle(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // 标题行
                    Row(
                      children: [
                        _DirBadge(
                          isBuy: isBuy,
                          buyText: _t('buy'),
                          sellText: _t('sell'),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          sym,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _kText,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_lotsStr(pos)} ${_t("hand")}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: _kSep),
                    const SizedBox(height: 16),
                    // 开仓 / 现价
                    Row(
                      children: [
                        Expanded(
                          child: _InfoTile(
                            label: _t('open_price_title'),
                            value: _fmtPrice(op, pos),
                          ),
                        ),
                        Expanded(
                          child: _InfoTile(
                            label: _t('current_price'),
                            value: _fmtPrice(cp, pos),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 浮动盈亏
                    _InfoTile(
                      label: _t('floating_profit_loss'),
                      value: '${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(2)}',
                      valueColor: pnl >= 0 ? _kGreen : _kRed,
                    ),
                    const SizedBox(height: 24),
                    // 平仓按钮
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: _LocalizedKeyText(
                          text: _t('confirm_close_position'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 取消
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: _LocalizedKeyText(
                          text: _t('cancel'),
                          style: TextStyle(color: _kGrey, fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showBatchCloseDialog() => showTradeConfirmDialog(
    context: context,
    message: _t('confirm_close_position'),
  );

  Future<Map<String, String>?> _showEditSheet(Map<String, dynamic> pos) {
    final slCtrl = TextEditingController(
      text: _toDouble(pos['stop_loss']) > 0 ? pos['stop_loss'].toString() : '',
    );
    final tpCtrl = TextEditingController(
      text: _toDouble(pos['take_profit']) > 0
          ? pos['take_profit'].toString()
          : '',
    );

    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: StatefulBuilder(
            builder: (ctx2, setSt) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _DragHandle(),
                  const SizedBox(height: 8),
                  // 标题
                  Row(
                    children: [
                      _DirBadge(
                        isBuy: _isBuy(pos),
                        buyText: _t('buy'),
                        sellText: _t('sell'),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _sym(pos),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _kText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 止损
                  _InputRow(
                    label: _t('stop_loss'),
                    hint: _t('stop_loss'),
                    controller: slCtrl,
                    color: _kRed,
                  ),
                  const SizedBox(height: 12),
                  // 止盈
                  _InputRow(
                    label: _t('take_profit'),
                    hint: _t('take_profit'),
                    controller: tpCtrl,
                    color: _kGreen,
                  ),
                  const SizedBox(height: 24),
                  // 确认
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop({
                        'stop_loss': slCtrl.text.trim().isEmpty
                            ? '0'
                            : slCtrl.text.trim(),
                        'take_profit': tpCtrl.text.trim().isEmpty
                            ? '0'
                            : tpCtrl.text.trim(),
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00B57A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: _LocalizedKeyText(
                        text: _t('save'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: _LocalizedKeyText(
                        text: _t('cancel'),
                        style: TextStyle(color: _kGrey, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
    return FutureBuilder<Map<String, String>>(
      future: _ensureLocalizedTexts(),
      initialData: _text,
      builder: (context, snapshot) {
        _text = snapshot.data ?? _fallbackText;
        final pageBg = context.adaptivePageGrey;
        final navBg = context.adaptiveSurfacePrimary;
        final textColor = context.adaptiveTextPrimary;
        return Scaffold(
          backgroundColor: pageBg,
          appBar: AppBar(
            backgroundColor: navBg,
            foregroundColor: textColor,
            surfaceTintColor: navBg,
            elevation: 0,
            centerTitle: true,
            title: _LocalizedKeyText(
              text: _t('positions'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            actions: [
              if (_positions.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() {
                    _batchMode = !_batchMode;
                    _selectedIds.clear();
                  }),
                  child: Text(
                    _batchMode ? _t('cancel') : _t('select'),
                    style: const TextStyle(
                      color: Color(0xFF00B57A),
                      fontSize: 15,
                    ),
                  ),
                ),
            ],
          ),
          body: STPullRefresh(
            onRefresh: () => _loadPositions(showLoading: false),
            child: _isLoading
                ? const Center(child: STLoadAnimationView())
                : _errorMessage != null
                ? _buildError()
                : _positions.isEmpty
                ? _buildEmpty()
                : _buildContent(),
          ),
          bottomNavigationBar: _batchMode && _selectedIds.isNotEmpty
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: ElevatedButton(
                      onPressed: _batchClose,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kRed,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        '${_t("close_a_position")} (${_selectedIds.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildError() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const SizedBox(height: 60),
      const Icon(Icons.error_outline, size: 64, color: _kRed),
      const SizedBox(height: 16),
      Center(
        child: Text(_errorMessage!, style: const TextStyle(color: _kRed)),
      ),
      const SizedBox(height: 16),
      Center(
        child: ElevatedButton(
          onPressed: _loadPositions,
          child: Text(_t('dkplayer_retry')),
        ),
      ),
    ],
  );

  Widget _buildEmpty() => TradeNoRecordsEmpty(
    message: _t('no_holder_positions'),
    scrollable: true,
    height: 300,
  );

  Widget _buildContent() {
    return Column(
      children: [
        _buildSummaryBar(),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _positions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _buildCard(i),
          ),
        ),
      ],
    );
  }

  // ─── 汇总栏 ───────────────────────────────────────────────────────────────

  Widget _buildSummaryBar() {
    final pnl = _totalPnl;
    final labelColor = context.adaptiveTextSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: context.adaptiveCard,
      child: Row(
        children: [
          Text(
            _t('positions_num').replaceAll('%1\$s', '${_positions.length}'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: labelColor,
            ),
          ),
          const Spacer(),
          Text(
            _t('floating_profit_loss'),
            style: TextStyle(fontSize: 13, color: labelColor),
          ),
          Text(
            '${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: pnl >= 0
                  ? CardTool.priceColor(1)
                  : CardTool.priceColor(-1),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 持仓卡片（对齐 iOS STTradeHomeLedgerDetailCell 布局）────────────────

  Widget _buildCard(int index) {
    final pos = _positions[index];
    final sym = _sym(pos);
    final isBuy = _isBuy(pos);
    final lots = _lotsStr(pos);
    final posId = _posId(pos);
    final isSelected = _selectedIds.contains(posId);

    final openPrice = _toDouble(pos['open_price'] ?? pos['price']);
    final cp = _currentPrice(pos);
    final pnl = _pnlOf(pos);
    final tp = _toDouble(pos['take_profit']);
    final sl = _toDouble(pos['stop_loss']);
    final swap = _toDouble(pos['swap']);
    final commission = _toDouble(pos['commission']);
    final cardColor = context.adaptiveCard;
    final textColor = context.adaptiveTextPrimary;
    final secondaryTextColor = context.adaptiveTextSecondary;
    final dividerColor = context.adaptiveDivider;
    final shadowColor = context.adaptiveIsDark
        ? Colors.black.withValues(alpha: 0.20)
        : Colors.black.withValues(alpha: 0.04);

    return GestureDetector(
      onTap: _batchMode
          ? () => setState(() {
              if (isSelected) {
                _selectedIds.remove(posId);
              } else {
                _selectedIds.add(posId);
              }
            })
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(10),
          border: _batchMode && isSelected
              ? Border.all(color: const Color(0xFF00B57A), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 行1：方向徽标 + 品种 + 手数 + （批量勾选）────────────────
              Row(
                children: [
                  if (_batchMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: const Color(0xFF00B57A),
                        size: 20,
                      ),
                    ),
                  _DirBadge(
                    isBuy: isBuy,
                    buyText: _t('buy'),
                    sellText: _t('sell'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    sym,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$lots ${_t("hand")}',
                    style: TextStyle(fontSize: 13, color: secondaryTextColor),
                  ),
                  if (posId.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '#$posId',
                        style: TextStyle(
                          fontSize: 11,
                          color: secondaryTextColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // ── 行2：开仓价 / 现价 ─────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _KeyValue(
                      label: _t('open_price_title'),
                      value: _fmtPrice(openPrice, pos),
                    ),
                  ),
                  Expanded(
                    child: _KeyValue(
                      label: _t('current_price'),
                      value: _fmtPrice(cp, pos),
                      valueColor: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── 行3：止盈 / 止损（有值时才显示）───────────────────────
              if (tp > 0 || sl > 0) ...[
                Row(
                  children: [
                    if (tp > 0)
                      Expanded(
                        child: _KeyValue(
                          label: _t('take_profit'),
                          value: _fmtPrice(tp, pos),
                          valueColor: _kGreen,
                        ),
                      ),
                    if (sl > 0)
                      Expanded(
                        child: _KeyValue(
                          label: _t('stop_loss'),
                          value: _fmtPrice(sl, pos),
                          valueColor: _kRed,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // ── 行4：浮动盈亏 + 手续费/隔夜利息 ────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _KeyValue(
                      label: _t('floating_profit_loss'),
                      value: '${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(2)}',
                      valueColor: pnl >= 0
                          ? CardTool.priceColor(1)
                          : CardTool.priceColor(-1),
                      bold: true,
                    ),
                  ),
                  if (swap != 0 || commission != 0)
                    Expanded(
                      child: _KeyValue(
                        label: _t('commission'),
                        value: (swap + commission).toStringAsFixed(2),
                        valueColor: secondaryTextColor,
                      ),
                    ),
                ],
              ),

              // ── 操作按钮（非批量模式）────────────────────────────────────
              if (!_batchMode) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: dividerColor),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // 止盈止损
                    Expanded(
                      child: _ActionButton(
                        label: _t('stop_loss_and_take_profit'),
                        color: const Color(0xFF00B57A),
                        outlined: true,
                        onTap: () => _editPosition(pos),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 平仓
                    Expanded(
                      child: _ActionButton(
                        label: _t('close_a_position'),
                        color: _kRed,
                        outlined: false,
                        onTap: () => _closePosition(pos),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 工具方法
  // ─────────────────────────────────────────────

  /// 对齐 iOS direction：0=买 / 1=卖，同时兼容 "buy"/"sell"
  bool _isBuy(Map<String, dynamic> pos) => _dirInt(pos['direction']) == 0;

  int _dirInt(dynamic d) {
    if (d == null) return 0;
    if (d is int) return d;
    if (d is num) return d.toInt();
    final s = d.toString().toLowerCase();
    if (s == 'sell' || s == '1') return 1;
    return 0;
  }

  String _sym(Map<String, dynamic> pos) => pos['symbol']?.toString() ?? '';

  String _posId(Map<String, dynamic> pos) =>
      (pos['position_id'] ?? pos['order_id'] ?? pos['id'])?.toString() ?? '';

  String _lotsStr(Map<String, dynamic> pos) =>
      '${pos['lots'] ?? pos['volume'] ?? '0.01'}';

  double _pnlOf(Map<String, dynamic> pos) {
    final raw = pos['profit'] ?? pos['pnl'] ?? 0;
    return (raw is num) ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  /// 按品种小数位数格式化价格
  String _fmtPrice(double price, Map<String, dynamic> pos) {
    if (price == 0) return '--';
    final digits = pos['digits'];
    final d = (digits is num)
        ? digits.toInt()
        : int.tryParse(digits?.toString() ?? '') ?? 5;
    return price.toStringAsFixed(d.clamp(0, 8));
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    STToast.show(context, msg, duration: const Duration(seconds: 2));
  }
}

// ─────────────────────────────────────────────
// 子组件
// ─────────────────────────────────────────────

class _DirBadge extends StatelessWidget {
  final bool isBuy;
  final String buyText;
  final String sellText;
  const _DirBadge({
    required this.isBuy,
    required this.buyText,
    required this.sellText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: (isBuy ? CardTool.priceColor(1) : CardTool.priceColor(-1))
            .withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: _LocalizedKeyText(
        text: isBuy ? buyText : sellText,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isBuy ? CardTool.priceColor(1) : CardTool.priceColor(-1),
        ),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  const _KeyValue({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = context.adaptiveTextSecondary;
    final valueTextColor = context.adaptiveTextPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LocalizedKeyText(
          text: label,
          style: TextStyle(fontSize: 11, color: labelColor),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: valueColor ?? valueTextColor,
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoTile({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final labelColor = context.adaptiveTextSecondary;
    final valueTextColor = context.adaptiveTextPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LocalizedKeyText(
          text: label,
          style: TextStyle(fontSize: 12, color: labelColor),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: valueColor ?? valueTextColor,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.color,
    required this.outlined,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: outlined
          ? OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: EdgeInsets.zero,
              ),
              child: _LocalizedKeyText(
                text: label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: EdgeInsets.zero,
                elevation: 0,
              ),
              child: _LocalizedKeyText(
                text: label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
    );
  }
}

class _InputRow extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final Color color;
  const _InputRow({
    required this.label,
    required this.hint,
    required this.controller,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 15, color: _kText),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _LocalizedKeyText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const _LocalizedKeyText({required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: style);
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFDDDDDD),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
