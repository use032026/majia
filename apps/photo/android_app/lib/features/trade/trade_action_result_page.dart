import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/network/st_service.dart';
import '../../core/providers/event_bus.dart';
import '../../core/theme/context_adaptive_colors.dart';
import 'trade_action_failed_dialog.dart';
import 'trade_alignment.dart';

class TradeActionResultPage extends ConsumerStatefulWidget {
  const TradeActionResultPage({
    super.key,
    required this.payload,
    required this.actionType,
    required this.isProgress,
  });

  final Map<String, dynamic> payload;
  final String actionType;
  final bool isProgress;

  @override
  ConsumerState<TradeActionResultPage> createState() =>
      _TradeActionResultPageState();
}

class _TradeActionResultPageState extends ConsumerState<TradeActionResultPage> {
  late Map<String, dynamic> _payload;
  late bool _isProgress;
  late final DateTime _pollingStartedAt;
  String? _languageCode;
  int _languageLoadToken = 0;
  Map<String, String> _localized = _fallbackText;
  bool _polling = false;
  bool _disposed = false;
  Timer? _pollDelayTimer;
  Completer<bool>? _pollDelayCompleter;

  static const Map<String, String> _fallbackText = {
    'buy': '买入',
    'sell': '卖出',
    'see_pending': '查看挂单',
    'see_positions': '查看持仓',
    'complete': '完成',
    'closing_position': '正在平仓...',
    'pending_tip': '正在挂单...',
    'opening_tip': '正在开仓...',
    'close_success': '平仓成功',
    'pending_success': '挂单成功',
    'modify_success': '修改成功',
    'sorry_open_success': '开仓成功',
    'order_number': '订单号',
    'type': '类型',
    'category': '类别',
    'direction': '方向',
    'lots': '手数',
    'hand': '手',
    'order_price': '委托价',
    'validity_period': '有效期',
    'completed_price': '成交价',
    'stop_loss': '止损',
    'take_profit': '止盈',
    'time': '时间',
    'limit_price': '限价',
    'market_price': '市价',
    'close_a_position': '平仓',
    'open_position': '开仓',
    'no_setting': '未设置',
    'close_fail': '平仓失败',
    'order_placement_failed': '挂单失败',
    'sorry_open_fail': '开仓失败',
    'link_timeout': '连接超时',
    'net_unstable': '网络不稳定',
  };

  @override
  void initState() {
    super.initState();
    _payload = Map<String, dynamic>.from(widget.payload);
    _isProgress = widget.isProgress;
    _pollingStartedAt = DateTime.now();
    if (_isProgress) {
      unawaited(_pollActionResult());
    } else {
      _emitLedgerRefreshIfNeeded();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode = stLanguageCodeOfContext(context);
    if (_languageCode == languageCode) return;
    _languageCode = languageCode;
    final token = ++_languageLoadToken;
    loadStLocalizedTextMap(context, ref, _fallbackText).then((entries) {
      if (!mounted || _disposed || token != _languageLoadToken) return;
      setState(() => _localized = entries);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _pollDelayTimer?.cancel();
    final completer = _pollDelayCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final symbol = _text('symbol', fallback: '--');
    final lots = _text('lots', fallback: '--');
    final direction = _int('direction') == 1 ? _t('sell') : _t('buy');
    final isBuy = _int('direction') != 1;
    final title = _isProgress ? _progressTitle : _successTitle;
    final accent = _isProgress
        ? const Color(0xFF9A9DA2)
        : const Color(0xFF1BCC83);
    final lotUnit = _lotUnit;
    final shellColor = context.adaptiveSurfacePrimary;
    final textColor = context.adaptiveTextPrimary;
    final tertiaryTextColor = context.adaptiveTextTertiary;
    final badgeBg = context.adaptiveMutedBlock;

    return Scaffold(
      backgroundColor: shellColor,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.close, size: 22, color: textColor),
                onPressed: _returnToTradeHome,
              ),
            ),
            SizedBox(height: _isProgress ? 151 : 10),
            if (_isProgress)
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: Color(0xFF9A9DA2),
                ),
              )
            else
              Image.asset(
                'assets/images/st_common_success.png',
                width: 64,
                height: 64,
              ),
            SizedBox(height: _isProgress ? 26 : 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _isProgress ? textColor : accent,
              ),
            ),
            SizedBox(height: _isProgress ? 12 : 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  symbol,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ).copyWith(color: textColor),
                ),
                const SizedBox(width: 8),
                _Badge(
                  text: direction,
                  color: isBuy
                      ? const Color(0xFF00C2B8)
                      : const Color(0xFFFF5177),
                ),
                const SizedBox(width: 4),
                Container(
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '$lots$lotUnit',
                    style: TextStyle(fontSize: 12, color: tertiaryTextColor),
                  ),
                ),
              ],
            ),
            if (!_isProgress) ...[
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: _ResultTable(rows: _rows),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.push(
                      widget.actionType == 'pending'
                          ? '/trade/accountprofile?fromType=2'
                          : '/trade/accountprofile?fromType=1',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B57A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(
                      widget.actionType == 'pending'
                          ? _t('see_pending')
                          : _t('see_positions'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _returnToTradeHome,
                    style: TextButton.styleFrom(
                      foregroundColor: textColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    child: Text(
                      _t('complete'),
                      style: TextStyle(color: textColor),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _progressTitle {
    switch (widget.actionType) {
      case 'close':
        return _t('closing_position');
      case 'pending':
        return _t('pending_tip');
      default:
        return _t('opening_tip');
    }
  }

  String get _successTitle {
    switch (widget.actionType) {
      case 'close':
        return _t('close_success');
      case 'pending':
        return _t('pending_success');
      case 'edit':
        return _t('modify_success');
      default:
        return _t('sorry_open_success');
    }
  }

  List<MapEntry<String, String>> get _rows {
    final rows = <MapEntry<String, String>>[
      MapEntry(
        _t('order_number'),
        _text('order_id', fallback: _text('position_id')),
      ),
      MapEntry(_t('type'), _orderType),
      MapEntry(_t('category'), _category),
      MapEntry(
        _t('direction'),
        _int('direction') == 1 ? _t('sell') : _t('buy'),
      ),
      MapEntry(
        _lotUnit == _t('hand') ? _t('lots') : _lotUnit,
        _text('lots', fallback: '--'),
      ),
    ];
    if (widget.actionType == 'pending') {
      rows.add(
        MapEntry(_t('order_price'), _text('price', fallback: _t('no_setting'))),
      );
      rows.add(MapEntry(_t('validity_period'), _time('expire_time')));
    } else {
      rows.add(
        MapEntry(
          _t('completed_price'),
          _text('deal_price', fallback: _t('no_setting')),
        ),
      );
    }
    rows.add(MapEntry(_t('stop_loss'), _zeroAsUnset('stop_loss')));
    rows.add(MapEntry(_t('take_profit'), _zeroAsUnset('take_profit')));
    rows.add(MapEntry(_t('time'), _resultTime));
    return rows;
  }

  String get _orderType {
    if (widget.actionType == 'pending') {
      return _int('pending_type') == 1 ? _t('stop_loss') : _t('limit_price');
    }
    return _t('market_price');
  }

  String get _category {
    if (widget.actionType == 'close') return _t('close_a_position');
    return _t('open_position');
  }

  String get _lotUnit {
    if (!_isProgress && _text('symbol_group') == 'Crypto') {
      final symbol = _text('symbol');
      if (symbol.endsWith('USDT') && symbol.length > 4) {
        return symbol.substring(0, symbol.length - 4);
      }
      if (symbol.endsWith('USD') && symbol.length > 3) {
        return symbol.substring(0, symbol.length - 3);
      }
      if (symbol.isNotEmpty) return symbol;
    }
    return _t('hand');
  }

  String get _resultTime {
    if (widget.actionType == 'pending') {
      return _time('created_time');
    }
    return _time('deal_time', fallbackKey: 'created_time');
  }

  String _zeroAsUnset(String key) {
    final v = _text(key);
    if (v.isEmpty || v == '-1' || v == '0' || v == '0.0' || v == '0.00') {
      return _t('no_setting');
    }
    return v;
  }

  String _text(String key, {String fallback = ''}) {
    final v = _payload[key];
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  int _int(String key) {
    final v = _payload[key];
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  String _time(String key, {String? fallbackKey}) {
    final raw =
        _payload[key] ?? (fallbackKey == null ? null : _payload[fallbackKey]);
    final seconds = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString() ?? '');
    if (seconds == null || seconds <= 0) return '--';
    final millis = seconds > 100000000000 ? seconds : seconds * 1000;
    return DateFormat(
      'yyyy.MM.dd HH:mm:ss',
    ).format(DateTime.fromMillisecondsSinceEpoch(millis));
  }

  Future<void> _pollActionResult() async {
    if (_polling || _disposed) return;
    _polling = true;
    try {
      while (!_disposed && mounted && _isProgress) {
        final elapsed = DateTime.now().difference(_pollingStartedAt).inSeconds;
        if (elapsed >= 20) {
          await _showPollingFailure(
            title: _t('link_timeout'),
            reason: _t('net_unstable'),
          );
          return;
        }

        final snapshot = TradeActionResultContract.fromPayload(_payload);
        if (snapshot.status == 1 &&
            snapshot.hasOrderId &&
            !TradeActionResultContract.shouldPollDeal(
              snapshot,
              actionType: widget.actionType,
            )) {
          _completeProgress(snapshot);
          return;
        }

        final wasPollingDeal = TradeActionResultContract.shouldPollDeal(
          snapshot,
          actionType: widget.actionType,
        );
        final next = await _pollNextSnapshot(snapshot, elapsed);
        if (next != null) {
          if (!mounted || _disposed) return;
          setState(() => _payload = next.payload);
          final shouldPollDeal = TradeActionResultContract.shouldPollDeal(
            next,
            actionType: widget.actionType,
          );
          if (wasPollingDeal || !shouldPollDeal) {
            _completeProgress(next);
            return;
          }
        }
        final shouldContinue = await _waitForNextPoll();
        if (!shouldContinue) return;
      }
    } catch (e) {
      if (mounted && !_disposed) {
        await _showPollingFailure(
          title: _progressFailureTitle,
          reason: stUserVisibleErrorMessage(e),
        );
      }
    } finally {
      _polling = false;
    }
  }

  Future<bool> _waitForNextPoll() {
    if (_disposed) return Future<bool>.value(false);
    final completer = Completer<bool>();
    _pollDelayCompleter = completer;
    _pollDelayTimer = Timer(const Duration(seconds: 1), () {
      if (!completer.isCompleted) {
        completer.complete(!_disposed);
      }
    });
    return completer.future.whenComplete(() {
      if (identical(_pollDelayCompleter, completer)) {
        _pollDelayCompleter = null;
      }
      _pollDelayTimer = null;
    });
  }

  Future<TradeActionResultSnapshot?> _pollNextSnapshot(
    TradeActionResultSnapshot snapshot,
    int elapsedSeconds,
  ) async {
    final service = ref.read(stServiceProvider);
    if (TradeActionResultContract.shouldPollDeal(
      snapshot,
      actionType: widget.actionType,
    )) {
      final response = await service.getTradeOrderDeal(
        TradeActionResultContract.orderStatusParams(
          snapshot,
          elapsedSeconds: elapsedSeconds,
        ),
      );
      if (TradeActionResultContract.dealLookupResolved(response)) {
        return snapshot.copyWithDealLookup(response);
      }
      return null;
    }

    if (!snapshot.hasTraderId) {
      debugPrint(
        'TradeActionResult polling stopped: missing trader_id in $_payload',
      );
      await _showPollingFailure(
        title: _progressFailureTitle,
        reason: '下单响应缺少交易执行ID',
      );
      return null;
    }
    final response = await service.getTradeOrderStatus(
      TradeActionResultContract.orderIdParams(snapshot),
    );
    if (TradeActionResultContract.statusLookupResolved(response)) {
      return snapshot.copyWithStatusLookup(response);
    }
    return null;
  }

  void _completeProgress(TradeActionResultSnapshot snapshot) {
    if (!mounted || _disposed) return;
    setState(() {
      _payload = snapshot.payload;
      _isProgress = false;
    });
    _emitLedgerRefreshIfNeeded();
  }

  void _emitLedgerRefreshIfNeeded() {
    if (widget.actionType == 'open' ||
        widget.actionType == 'close' ||
        widget.actionType == 'pending') {
      EventBus().emit(EventBus.tradePositionListRefresh);
    }
  }

  String get _progressFailureTitle {
    switch (widget.actionType) {
      case 'close':
        return _t('close_fail');
      case 'pending':
        return _t('order_placement_failed');
      default:
        return _t('sorry_open_fail');
    }
  }

  String _t(String key) => _localized[key] ?? _fallbackText[key] ?? key;

  Future<void> _showPollingFailure({
    required String title,
    required String reason,
  }) async {
    if (!mounted || _disposed) return;
    await showTradeActionFailedDialog(
      context: context,
      title: title,
      reason: reason,
    );
    if (mounted && !_disposed) {
      _returnToTradeHome();
    }
  }

  void _returnToTradeHome() {
    if (!mounted || _disposed) return;
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/?tab=trade');
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

class _ResultTable extends StatelessWidget {
  const _ResultTable({required this.rows});

  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    final tableBg = context.adaptiveMutedBlock;
    final labelColor = context.adaptiveTextSecondary;
    final valueColor = context.adaptiveTextPrimary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Container(
        color: tableBg,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: rows
              .map(
                (row) => SizedBox(
                  height: 30,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Row(
                      children: [
                        Text(
                          row.key,
                          style: TextStyle(fontSize: 12, color: labelColor),
                        ),
                        const Spacer(),
                        Text(
                          row.value,
                          style: TextStyle(
                            fontSize: 12,
                            color: valueColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
