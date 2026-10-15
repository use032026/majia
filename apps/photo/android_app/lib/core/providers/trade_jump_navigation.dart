import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 跳转交易 Tab 并切换品种/买卖方向（对齐 iOS `STJumpToTradeNotification`）
class TradeJumpIntent {
  final String? symbol;
  final bool? isBuy;
  final int tick;

  const TradeJumpIntent({
    this.symbol,
    this.isBuy,
    required this.tick,
  });
}

class TradeJumpNavigationNotifier extends StateNotifier<TradeJumpIntent?> {
  TradeJumpNavigationNotifier() : super(null);
  int _tick = 0;

  void jumpToTrade({String? symbol, bool? isBuy}) {
    _tick++;
    state = TradeJumpIntent(
      symbol: symbol?.trim().isNotEmpty == true ? symbol!.trim() : null,
      isBuy: isBuy,
      tick: _tick,
    );
  }

  void clear() => state = null;
}

final tradeJumpNavigationProvider =
    StateNotifierProvider<TradeJumpNavigationNotifier, TradeJumpIntent?>(
  (ref) => TradeJumpNavigationNotifier(),
);
