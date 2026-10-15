import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/card_tool.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/models/user_state.dart';
import '../../core/models/market_product_model.dart';
import '../../core/network/market_websocket.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/network/st_service.dart';
import '../../core/providers/event_bus.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../shared/widgets/st_localized_prompt.dart';
import 'order_detail_contract.dart';
import 'trade_action_failed_dialog.dart';
import 'trade_confirm_dialog.dart';
import 'trade_order_live_update.dart';
import 'trade_position_action_sheet.dart';

/// 订单详情页面
/// 对齐 iOS `STTradeOrderDetailController`：
/// 入口使用列表传入的完整订单模型和显式类型；缺模型时不主动请求详情接口。
class OrderDetailPage extends ConsumerStatefulWidget {
  final String orderId;
  final TradeOrderDetailType? initialType;
  final Map<String, dynamic>? initialOrder;

  const OrderDetailPage({
    super.key,
    required this.orderId,
    this.initialType,
    this.initialOrder,
  });

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  static const Color _labelColor = Color(0xFF9A9DA2);

  bool _isSubmitting = false;
  Map<String, dynamic>? _orderData;
  late TradeOrderDetailType _orderType;
  StreamSubscription<MarketWSMessage>? _wsSub;
  void Function(Object? data)? _actionRefreshListener;
  ValueNotifier<Map<String, dynamic>>? _liveOrderNotifier;
  String? _liveSymbol;
  bool _actionRefreshRegistered = false;
  String? _languageCode;
  int _languageLoadToken = 0;
  TradeOrderDetailLabels _labels = TradeOrderDetailLabels.fallback;

  @override
  void initState() {
    super.initState();
    _orderType = widget.initialType ?? TradeOrderDetailType.position;
    if (!ref.read(userStateProvider).isLogin) {
      context.push('/login');
      return;
    }
    final initial = widget.initialOrder;
    if (initial != null && initial.isNotEmpty) {
      _orderData = Map<String, dynamic>.from(initial);
      _orderType =
          widget.initialType ?? TradeOrderDetailContract.inferType(initial);
      _syncLiveOrderNotifier();
      _startLiveRefresh();
    } else {
      _orderData = <String, dynamic>{'order_id': widget.orderId};
    }
  }

  @override
  void dispose() {
    final listener = _actionRefreshListener;
    if (listener != null) {
      EventBus().offData(EventBus.tradeActionViewRefresh, listener);
    }
    _wsSub?.cancel();
    _liveOrderNotifier?.dispose();
    super.dispose();
  }

  TradeOrderDetailContract get _detail => TradeOrderDetailContract.fromOrder(
    _orderData ?? const <String, dynamic>{},
    type: _orderType,
    labels: _labels,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode = stLanguageCodeOfContext(context);
    if (_languageCode == languageCode) return;
    _languageCode = languageCode;
    final token = ++_languageLoadToken;
    loadStLocalizedTextMap(
      context,
      ref,
      TradeOrderDetailLabels.fallbackText,
    ).then((text) {
      if (!mounted || token != _languageLoadToken) return;
      setState(() => _labels = TradeOrderDetailLabels(text));
    });
  }

  void _syncLiveOrderNotifier() {
    final order = _orderData;
    if (order == null) return;
    final snapshot = Map<String, dynamic>.from(order);
    final notifier = _liveOrderNotifier;
    if (notifier == null) {
      _liveOrderNotifier = ValueNotifier<Map<String, dynamic>>(snapshot);
    } else {
      notifier.value = snapshot;
    }
  }

  void _startLiveRefresh() {
    final order = _orderData;
    if (order == null || order.isEmpty) return;

    _wsSub ??= ref
        .read(marketWebSocketProvider)
        .messageStream
        .listen(_onTradeWsMessage);
    if (!_actionRefreshRegistered) {
      _actionRefreshListener ??= (payload) {
        if (payload is Map) {
          _applyLiveOrderUpdate(Map<String, dynamic>.from(payload));
        }
      };
      EventBus().onData(
        EventBus.tradeActionViewRefresh,
        _actionRefreshListener!,
      );
      _actionRefreshRegistered = true;
    }

    final symbol = _firstText(order, const ['symbol', 'symbol_code']);
    if (symbol.isEmpty || symbol == _liveSymbol) return;
    _liveSymbol = symbol;
    final ws = ref.read(marketWebSocketProvider);
    ws.connect();
    ws.sendEnterTransactionPage(symbol);
  }

  void _onTradeWsMessage(MarketWSMessage message) {
    final order = _orderData;
    if (order == null) return;
    final update = TradeOrderLiveUpdate.fromMarketMessage(
      order: order,
      message: message,
      pending: _orderType == TradeOrderDetailType.pending,
    );
    if (update == null) return;
    _applyLiveOrderUpdate(update);
  }

  void _applyLiveOrderUpdate(Map<String, dynamic> update) {
    final order = _orderData;
    if (order == null || !TradeOrderLiveUpdate.matches(order, update)) return;
    final next = TradeOrderLiveUpdate.merge(order, update);
    if (!mounted) return;
    setState(() => _orderData = next);
    _liveOrderNotifier?.value = Map<String, dynamic>.from(next);
  }

  @override
  Widget build(BuildContext context) {
    final riseFall = ref.watch(
      userStateProvider.select((s) => s.riseAndFallType),
    );
    CardTool.setRiseAndFallType(riseFall);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: context.adaptivePageGrey,
      appBar: AppBar(
        title: Text(_detail.title),
        centerTitle: true,
        backgroundColor: context.adaptiveSurfacePrimary,
        foregroundColor: context.adaptiveTextPrimary,
        surfaceTintColor: context.adaptiveSurfacePrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: context.adaptiveTextPrimary),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: context.adaptiveTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    final detail = _detail;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              15,
              21,
              18,
              detail.showBottomActions ? 18 : 5,
            ),
            children: [
              _buildHeader(detail),
              const SizedBox(height: 18),
              ...detail.sections.map(_buildSection),
            ],
          ),
        ),
        if (detail.showBottomActions) _buildBottomActions(detail),
      ],
    );
  }

  Widget _buildHeader(TradeOrderDetailContract detail) {
    final hasAlias =
        detail.symbolAlias != '--' && detail.symbolAlias.isNotEmpty;
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Text(
              detail.symbol,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            if (hasAlias)
              Text(
                detail.symbolAlias,
                style: const TextStyle(fontSize: 12, color: Color(0xFF60656D)),
              ),
          ],
        ),
        if (detail.showProfitSummary) ...[
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _profitColumn('${detail.profitLabel}(USD)', detail.profit),
              const SizedBox(width: 32),
              _profitColumn('${detail.netProfitLabel}(USD)', detail.netProfit),
            ],
          ),
        ],
      ],
    );
  }

  Widget _profitColumn(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: _labelColor)),
        const SizedBox(height: 2),
        Text(
          _moneyText(value),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: _moneyColor(value),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(TradeOrderDetailSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: Colors.white,
          child: Column(
            children: [
              for (var i = 0; i < section.rows.length; i++)
                _buildRow(
                  section.rows[i],
                  showDivider: i != section.rows.length - 1,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(TradeOrderDetailRow row, {required bool showDivider}) {
    final content = Container(
      height: 35,
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0xFFF3F3F3)))
            : null,
      ),
      padding: const EdgeInsets.only(left: 21, right: 15),
      child: Row(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              row.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: _labelColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: _rowValue(row),
            ),
          ),
        ],
      ),
    );
    if (row.action == TradeOrderDetailRowAction.none) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleRowAction(row),
      child: content,
    );
  }

  Widget _rowValue(TradeOrderDetailRow row) {
    switch (row.kind) {
      case TradeOrderDetailRowKind.action:
        final color = row.direction == 0
            ? CardTool.priceColor(1)
            : CardTool.priceColor(-1);
        return Container(
          height: 18,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              row.value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        );
      case TradeOrderDetailRowKind.copy:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              row.value,
              style: const TextStyle(fontSize: 14, color: Colors.black),
            ),
            const SizedBox(width: 3),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _copy(row.value),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.copy_rounded, size: 14, color: _labelColor),
              ),
            ),
          ],
        );
      case TradeOrderDetailRowKind.arrow:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              row.value,
              style: const TextStyle(fontSize: 14, color: Colors.black),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right, size: 16, color: _labelColor),
          ],
        );
      case TradeOrderDetailRowKind.tradeUser:
        return _tradeModeBadge(row.value);
      case TradeOrderDetailRowKind.normal:
        return Text(
          row.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 14, color: Colors.black),
        );
    }
  }

  Widget _tradeModeBadge(String value) {
    final isOrigin =
        value == TradeOrderDetailLabels.fallback.t('bring_single') ||
        value == _labels.t('bring_single');
    return Container(
      height: 18,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isOrigin ? Colors.black : const Color(0xFF00B57A),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        value,
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
    );
  }

  Widget _buildBottomActions(TradeOrderDetailContract detail) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Row(
          children: [
            Expanded(
              child: _bottomButton(
                detail.leftActionLabel,
                _isSubmitting ? null : () => _leftAction(detail),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: _bottomButton(
                detail.rightActionLabel,
                _isSubmitting ? null : () => _rightAction(detail),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomButton(String label, VoidCallback? onTap) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: context.adaptiveSurfacePrimary,
          foregroundColor: context.adaptiveTextPrimary,
          disabledBackgroundColor: context.adaptiveSurfacePrimary.withValues(
            alpha: 0.55,
          ),
          disabledForegroundColor: Colors.black38,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }

  void _leftAction(TradeOrderDetailContract detail) {
    switch (detail.type) {
      case TradeOrderDetailType.position:
        _editPosition(detail);
      case TradeOrderDetailType.pending:
        _editPending(detail);
      case TradeOrderDetailType.history:
        break;
    }
  }

  Future<void> _handleRowAction(TradeOrderDetailRow row) async {
    final detail = _detail;
    final h5 = ref.read(userStateProvider).h5AddressModel;
    final route = detail.miniRouteForRow(
      row,
      links: TradeOrderDetailH5Links(
        traderCenterUrl: h5?.traderCenterUrl ?? '',
        traderOrderDetailsUrl: h5?.traderOrderDetailsUrl ?? '',
        myFollowOrderUrl: h5?.myFollowOrderUrl ?? '',
        traderProfitUrl: h5?.traderProfitUrl ?? '',
        traderProfitOrderUrl: h5?.traderProfitOrderUrl ?? '',
      ),
    );
    if (route == null) return;
    if (row.action == TradeOrderDetailRowAction.copyTradingUser) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shareOrder', detail.shareOrderJson());
      if (!mounted) return;
    }
    final query = Uri(
      queryParameters: {'link': route.link, 'permission': 'login'},
    ).query;
    context.push('/mini?$query');
  }

  void _rightAction(TradeOrderDetailContract detail) {
    switch (detail.type) {
      case TradeOrderDetailType.position:
        _closePosition(detail);
      case TradeOrderDetailType.pending:
        _cancelPending(detail);
      case TradeOrderDetailType.history:
        break;
    }
  }

  Future<void> _editPosition(TradeOrderDetailContract detail) async {
    final result = await _showPositionEditDialog(detail);
    if (result == null || !mounted) return;
    await _submitAction(
      failureTitleZhHans: '止盈止损失败',
      action: () => ref.read(stServiceProvider).editPosition(result),
      onSuccess: (_) {
        _mergeOrder(result);
        _toastZhHans('修改成功');
      },
    );
  }

  Future<void> _editPending(TradeOrderDetailContract detail) async {
    final result = await _showPendingEditDialog(detail);
    if (result == null || !mounted) return;
    await _submitAction(
      failureTitleZhHans: '修改失败',
      action: () => ref.read(stServiceProvider).editPendingOrder(result),
      onSuccess: (_) {
        _mergeOrder({
          'pending_price': result['price'],
          'take_profit': result['take_profit'],
          'stop_loss': result['stop_loss'],
          if (result['expire_time'] != null)
            'expire_time': result['expire_time'],
        });
        _toastZhHans('修改成功');
      },
    );
  }

  Future<void> _closePosition(TradeOrderDetailContract detail) async {
    final ok = await showTradeClosePositionDialog(
      context: context,
      symbol: detail.symbol,
      lots: _lots(detail.source),
    );
    if (ok != true || !mounted) return;
    final body = <String, dynamic>{
      'symbol': detail.symbol,
      'direction': detail.isBuy ? 0 : 1,
      'lots': _lots(detail.source),
      'position_id': int.tryParse(detail.orderId) ?? detail.orderId,
    };
    await _submitAction(
      failureTitleZhHans: '平仓失败',
      action: () => ref.read(stServiceProvider).closePosition(body),
      onSuccess: (response) {
        EventBus().emit(EventBus.tradePositionListRefresh);
        final payload = <String, dynamic>{
          ...detail.source,
          ...response,
          'order_id': response['order_id'] ?? detail.orderId,
          'symbol': detail.symbol,
          'symbol_alias': detail.symbolAlias == '--' ? '' : detail.symbolAlias,
          'lots': _lots(detail.source),
          'direction': detail.isBuy ? 0 : 1,
        };
        context.push(
          '/trade/action_result?type=close&progress=1',
          extra: payload,
        );
      },
    );
  }

  Future<void> _cancelPending(TradeOrderDetailContract detail) async {
    final ok = await showTradeCancelOrderDialog(
      context: context,
      orderId: detail.orderId,
    );
    if (ok != true || !mounted) return;
    final body = <String, dynamic>{
      'symbol': detail.symbol,
      'order_id': int.tryParse(detail.orderId) ?? detail.orderId,
    };
    await _submitAction(
      failureTitleZhHans: '撤单失败',
      action: () => ref.read(stServiceProvider).deleteOrder(body),
      onSuccess: (_) {
        _toastZhHans('订单已取消');
        if (context.canPop()) context.pop(true);
      },
    );
  }

  Future<Map<String, dynamic>?> _showPositionEditDialog(
    TradeOrderDetailContract detail,
  ) async {
    return showTradePositionStopLossPayloadSheet(
      context: context,
      order: detail.source,
      orderListenable: _liveOrderNotifier,
    );
  }

  Future<Map<String, dynamic>?> _showPendingEditDialog(
    TradeOrderDetailContract detail,
  ) async {
    return showTradePendingEditPayloadSheet(
      context: context,
      order: detail.source,
      orderListenable: _liveOrderNotifier,
    );
  }

  Future<void> _submitAction({
    required String failureTitleZhHans,
    required Future<Map<String, dynamic>> Function() action,
    required void Function(Map<String, dynamic> response) onSuccess,
  }) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final response = await action();
      if (_isSystemBusyCode(response)) {
        _toastZhHans('系统繁忙，请稍后再试');
        return;
      }
      if (!mounted) return;
      onSuccess(response);
    } catch (e) {
      if (mounted) {
        final failureTitle = await stLocalizedTextFromZhHans(
          context,
          failureTitleZhHans,
        );
        await showTradeActionFailedDialog(
          context: context,
          title: failureTitle,
          reason: stUserVisibleErrorMessage(e),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _mergeOrder(Map<String, dynamic> next) {
    setState(() {
      _orderData = <String, dynamic>{...?_orderData, ...next};
    });
    _syncLiveOrderNotifier();
  }

  bool _isSystemBusyCode(Map<String, dynamic> response) {
    final code = response['code'];
    return code == 200162 ||
        (code is num && code.toInt() == 200162) ||
        code?.toString() == '200162';
  }

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    _toastZhHans('复制成功');
  }

  void _toastZhHans(String message) {
    if (!mounted) return;
    showStLocalizedToast(
      context,
      message,
      duration: const Duration(seconds: 1),
    );
  }

  Color _moneyColor(String value) {
    final number = double.tryParse(value);
    if (number == null || number == 0) return _labelColor;
    return number > 0 ? CardTool.priceColor(1) : CardTool.priceColor(-1);
  }

  String _moneyText(String value) {
    final number = double.tryParse(value);
    if (number == null) return '--';
    final sign = number > 0 ? '+' : '';
    return '$sign${number.toStringAsFixed(2)}';
  }

  String _lots(Map<String, dynamic> order) => _firstText(order, const [
    'lots',
    'set_lot',
    'setLot',
    'volume',
  ], fallback: '0');

  String _firstText(
    Map<String, dynamic> order,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = order[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return fallback;
  }
}
