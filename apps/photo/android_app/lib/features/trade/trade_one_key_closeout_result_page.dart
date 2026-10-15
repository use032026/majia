import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/card_tool.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/models/user_state.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/network/st_service.dart';
import '../../core/theme/context_adaptive_colors.dart';
import 'trade_alignment.dart';

enum TradeOneKeyCloseOutState { waiting, success, failed }

class TradeOneKeyCloseOutResultPage extends ConsumerStatefulWidget {
  const TradeOneKeyCloseOutResultPage({
    super.key,
    required this.items,
    this.failedCount = 0,
  });

  final List<Map<String, dynamic>> items;
  final int failedCount;

  @override
  ConsumerState<TradeOneKeyCloseOutResultPage> createState() =>
      _TradeOneKeyCloseOutResultPageState();
}

class _TradeOneKeyCloseOutResultPageState
    extends ConsumerState<TradeOneKeyCloseOutResultPage> {
  late final DateTime _startedAt;
  late final List<_CloseOutResultItem> _items;
  final Set<int> _expanded = {};
  final List<Timer> _timers = [];
  String? _languageCode;
  int _languageLoadToken = 0;
  Map<String, String> _localized = _fallbackText;
  bool _disposed = false;

  static const Map<String, String> _fallbackText = {
    'close_position_result': '平仓结果',
    'close_position_tip1_ios': '平仓完成：成功 %@ 笔，失败 %@ 笔',
    'closing_position_progress_ios': '正在平仓... 已完成 %@/%@ 笔',
    'link_timeout': '请求超时，请先检查网络环境，然后在设置页切换可用线路',
    'system_busy': '系统繁忙，请稍后再试',
    'closing_position': '正在平仓...',
    'close_success': '平仓成功',
    'close_fail': '平仓失败',
    'order_number': '订单号',
    'completed_price': '成交时间',
    'open_price_title': '开仓价格',
    'closing_price': '平仓价格',
    'direction': '方向',
    'buy': '买入',
    'sell': '卖出',
    'hand': '手',
    'lots': '手数',
    'profit_and_loss': '盈亏',
    'position_order_id': '持仓订单ID',
    'fail_reason': '失败原因',
  };

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _items = widget.items
        .map((item) => _CloseOutResultItem.fromMap(item))
        .toList();
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].state == TradeOneKeyCloseOutState.waiting) {
        unawaited(_pollItem(i));
      }
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
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finished = _items
        .where((item) => item.state != TradeOneKeyCloseOutState.waiting)
        .length;
    final failed = _items
        .where((item) => item.state == TradeOneKeyCloseOutState.failed)
        .length;
    final allFinished = finished == _items.length;
    final resultText = allFinished
        ? _tf('close_position_tip1_ios', [_items.length - failed, failed])
        : _tf('closing_position_progress_ios', [finished, _items.length]);
    final shellColor = context.adaptivePageGrey;
    final navColor = context.adaptiveSurfacePrimary;
    final textColor = context.adaptiveTextPrimary;

    return Scaffold(
      backgroundColor: shellColor,
      appBar: AppBar(
        title: Text(_t('close_position_result')),
        centerTitle: true,
        backgroundColor: navColor,
        foregroundColor: textColor,
        surfaceTintColor: navColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 22),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF4DCB73),
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: Image.asset(
              'assets/images/st_trade_one_key_sec.png',
              width: 32,
              height: 32,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!allFinished) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF9A9DA2),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  resultText,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: textColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _items.length,
              itemBuilder: (context, index) {
                return _CloseOutResultCell(
                  key: ValueKey('trade_closeout_result_cell_$index'),
                  item: _items[index],
                  expanded: _expanded.contains(index),
                  text: _localized,
                  onTap: () {
                    if (_items[index].state ==
                        TradeOneKeyCloseOutState.waiting) {
                      return;
                    }
                    setState(() {
                      if (!_expanded.add(index)) _expanded.remove(index);
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pollItem(int index) async {
    final item = _items[index];
    while (!_disposed &&
        mounted &&
        item.state == TradeOneKeyCloseOutState.waiting) {
      final globalElapsed = DateTime.now().difference(_startedAt).inSeconds;
      if (globalElapsed >= 20) {
        _markFailed(index, _t('link_timeout'));
        return;
      }

      try {
        final snapshot = TradeActionResultContract.fromPayload(item.payload);
        if (TradeActionResultContract.shouldPollDeal(
          snapshot,
          actionType: 'close',
        )) {
          final elapsed = DateTime.now().difference(item.startedAt).inSeconds;
          final response = await ref
              .read(stServiceProvider)
              .getTradeOrderDeal(
                TradeActionResultContract.orderStatusParams(
                  snapshot,
                  elapsedSeconds: elapsed,
                ),
              );
          if (TradeActionResultContract.dealLookupResolved(response)) {
            final next = snapshot.copyWithDealLookup(response);
            _markSuccess(index, next.payload);
            return;
          }
        } else {
          if (!snapshot.hasTraderId) {
            _markFailed(index, _t('system_busy'));
            return;
          }
          final response = await ref
              .read(stServiceProvider)
              .getTradeOrderStatus(
                TradeActionResultContract.orderIdParams(snapshot),
              );
          if (TradeActionResultContract.statusLookupResolved(response)) {
            final next = snapshot.copyWithStatusLookup(response);
            if (!mounted || _disposed) return;
            setState(() {
              item.payload
                ..clear()
                ..addAll(next.payload);
              item.orderId = next.orderId;
            });
            continue;
          }
        }
      } catch (e) {
        _markFailed(index, stUserVisibleErrorMessage(e));
        return;
      }

      final shouldContinue = await _waitOneSecond();
      if (!shouldContinue) return;
    }
  }

  Future<bool> _waitOneSecond() {
    if (_disposed) return Future<bool>.value(false);
    final completer = Completer<bool>();
    late final Timer timer;
    timer = Timer(const Duration(seconds: 1), () {
      if (!completer.isCompleted) completer.complete(!_disposed);
      _timers.remove(timer);
    });
    _timers.add(timer);
    return completer.future;
  }

  void _markSuccess(int index, Map<String, dynamic> payload) {
    if (!mounted || _disposed) return;
    setState(() {
      final item = _items[index];
      item.state = TradeOneKeyCloseOutState.success;
      item.payload
        ..clear()
        ..addAll(payload);
      item.copyDisplayPayload(payload);
    });
  }

  void _markFailed(int index, String message) {
    if (!mounted || _disposed) return;
    setState(() {
      _items[index]
        ..state = TradeOneKeyCloseOutState.failed
        ..message = message.isEmpty ? _t('system_busy') : message;
    });
  }

  String _t(String key) => _localized[key] ?? _fallbackText[key] ?? key;

  String _tf(String key, List<Object> values) {
    var text = _t(key);
    for (final value in values) {
      text = text.replaceFirst(RegExp(r'%@|%s|%d'), '$value');
    }
    return text;
  }
}

class _CloseOutResultItem {
  _CloseOutResultItem({
    required this.payload,
    required this.positionId,
    required this.orderId,
    required this.symbol,
    required this.symbolAlias,
    required this.lots,
    required this.direction,
    required this.state,
    required this.startedAt,
    this.message = '',
  });

  final Map<String, dynamic> payload;
  String positionId;
  String orderId;
  String symbol;
  String symbolAlias;
  String lots;
  int direction;
  TradeOneKeyCloseOutState state;
  DateTime startedAt;
  String message;

  factory _CloseOutResultItem.fromMap(Map<String, dynamic> map) {
    final status = map['status'];
    final statusMap = status is Map ? Map<String, dynamic>.from(status) : null;
    final code = _toInt(statusMap?['code'] ?? map['code']);
    final explicitState = map['trade_close_result']?.toString();
    var state = TradeOneKeyCloseOutState.waiting;
    var message = _text(statusMap?['message'] ?? map['message']);
    if (explicitState == 'failed' || explicitState == 'fail') {
      state = TradeOneKeyCloseOutState.failed;
    } else if (explicitState == 'success') {
      state = TradeOneKeyCloseOutState.success;
    } else if (code != 0) {
      state = TradeOneKeyCloseOutState.failed;
    }
    if (state == TradeOneKeyCloseOutState.failed && message.isEmpty) {
      message = '系统繁忙，请稍后再试';
    }
    return _CloseOutResultItem(
      payload: Map<String, dynamic>.from(map),
      positionId: _firstText(map, const ['position_id', 'positionId', 'id']),
      orderId: _firstText(map, const ['order_id', 'orderId']),
      symbol: _firstText(map, const ['symbol', 'name']),
      symbolAlias: _firstText(map, const ['symbol_alias', 'symbolAlias']),
      lots: _firstText(map, const ['lots', 'set_lot', 'setLot']),
      direction: _toInt(map['direction']),
      state: state,
      startedAt: DateTime.now(),
      message: message,
    );
  }

  void copyDisplayPayload(Map<String, dynamic> next) {
    positionId = _firstText(next, const [
      'position_id',
      'positionId',
      'id',
    ], fallback: positionId);
    orderId = _firstText(next, const [
      'order_id',
      'orderId',
      'ticket',
      'deal_id',
      'dealId',
    ], fallback: orderId);
    symbol = _firstText(next, const ['symbol', 'name'], fallback: symbol);
    symbolAlias = _firstText(next, const [
      'symbol_alias',
      'symbolAlias',
    ], fallback: symbolAlias);
    lots = _firstText(next, const [
      'lots',
      'set_lot',
      'setLot',
    ], fallback: lots);
    direction = _toInt(next['direction'], fallback: direction);
  }
}

class _CloseOutResultCell extends StatelessWidget {
  const _CloseOutResultCell({
    super.key,
    required this.item,
    required this.expanded,
    required this.text,
    required this.onTap,
  });

  final _CloseOutResultItem item;
  final bool expanded;
  final Map<String, String> text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBuy = item.direction == 0;
    final cardColor = context.adaptiveCard;
    final textColor = context.adaptiveTextPrimary;
    final secondaryTextColor = context.adaptiveTextSecondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 0, 15, 9),
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: cardColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.fromLTRB(15, 10, 13, 10),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.symbol,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _DirectionBadge(isBuy: isBuy, text: text),
                              const SizedBox(width: 4),
                              _LotsBadge(lots: item.lots, text: text),
                            ],
                          ),
                          if (item.symbolAlias.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.symbolAlias,
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _StateView(state: item.state, text: text),
                  ],
                ),
              ),
              if (expanded) _ExpandedResult(item: item, text: text),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateView extends StatelessWidget {
  const _StateView({required this.state, required this.text});

  final TradeOneKeyCloseOutState state;
  final Map<String, String> text;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      TradeOneKeyCloseOutState.waiting => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF9A9DA2),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            _t('closing_position'),
            style: const TextStyle(fontSize: 12, color: Color(0xFF9A9DA2)),
          ),
        ],
      ),
      TradeOneKeyCloseOutState.success => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 18, color: Color(0xFF1BCC83)),
          const SizedBox(width: 6),
          Text(
            _t('close_success'),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1BCC83),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      TradeOneKeyCloseOutState.failed => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_rounded, size: 18, color: Color(0xFFF95959)),
          const SizedBox(width: 6),
          Text(
            _t('close_fail'),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFF95959),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    };
  }

  String _t(String key) =>
      text[key] ??
      _TradeOneKeyCloseOutResultPageState._fallbackText[key] ??
      key;
}

class _ExpandedResult extends StatelessWidget {
  const _ExpandedResult({required this.item, required this.text});

  final _CloseOutResultItem item;
  final Map<String, String> text;

  @override
  Widget build(BuildContext context) {
    final rows = item.state == TradeOneKeyCloseOutState.success
        ? <MapEntry<String, String>>[
            MapEntry(_t('order_number'), item.orderId),
            MapEntry(
              _t('completed_price'),
              _timeText(item.payload['deal_time']),
            ),
            MapEntry(_t('open_price_title'), _text(item.payload['open_price'])),
            MapEntry(_t('closing_price'), _text(item.payload['close_price'])),
            MapEntry(
              _t('direction'),
              item.direction == 0 ? _t('buy') : _t('sell'),
            ),
            MapEntry(_t('lots'), '${item.lots}${_t('hand')}'),
            MapEntry(_t('profit_and_loss'), _text(item.payload['profit'])),
          ]
        : <MapEntry<String, String>>[
            MapEntry(_t('position_order_id'), item.positionId),
            MapEntry(_t('fail_reason'), item.message),
          ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 13, 15),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _ResultRow(label: rows[i].key, value: rows[i].value),
            if (i != rows.length - 1) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }

  String _t(String key) =>
      text[key] ??
      _TradeOneKeyCloseOutResultPageState._fallbackText[key] ??
      key;
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final labelColor = context.adaptiveTextSecondary;
    final valueColor = context.adaptiveTextPrimary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: labelColor)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value.isEmpty ? '--' : value,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 14, color: valueColor),
          ),
        ),
      ],
    );
  }
}

class _DirectionBadge extends ConsumerWidget {
  const _DirectionBadge({required this.isBuy, required this.text});

  final bool isBuy;
  final Map<String, String> text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riseFall = ref.watch(
      userStateProvider.select((s) => s.riseAndFallType),
    );
    CardTool.setRiseAndFallType(riseFall);
    final color = isBuy ? CardTool.priceColor(1) : CardTool.priceColor(-1);
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        isBuy ? _shortDirection('buy') : _shortDirection('sell'),
        style: TextStyle(fontSize: 11, color: color),
      ),
    );
  }

  String _shortDirection(String key) {
    final value =
        text[key] ??
        _TradeOneKeyCloseOutResultPageState._fallbackText[key] ??
        key;
    if (value == '买入') return '买';
    if (value == '卖出') return '卖';
    return value;
  }
}

class _LotsBadge extends StatelessWidget {
  const _LotsBadge({required this.lots, required this.text});

  final String lots;
  final Map<String, String> text;

  @override
  Widget build(BuildContext context) {
    final badgeBg = context.adaptiveMutedBlock;
    final textColor = context.adaptiveTextTertiary;
    return Container(
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        '$lots${_t('hand')}',
        style: TextStyle(fontSize: 12, color: textColor),
      ),
    );
  }

  String _t(String key) =>
      text[key] ??
      _TradeOneKeyCloseOutResultPageState._fallbackText[key] ??
      key;
}

String _firstText(
  Map<String, dynamic> map,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = map[key];
    final text = _text(value);
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

String _text(Object? value) {
  if (value == null) return '';
  final text = value.toString().trim();
  return text;
}

int _toInt(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _timeText(Object? value) {
  final seconds = _toInt(value);
  if (seconds <= 0) return '--';
  final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
}
