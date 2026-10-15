abstract final class TradeSymbolFilter {
  static List<Map<String, dynamic>> visiblePositions(
    List<Map<String, dynamic>> positions, {
    required bool isolateCurrentSymbol,
    required String selectedSymbol,
    required String selectedAlias,
    required String rememberedTradeSymbol,
  }) {
    if (!isolateCurrentSymbol) return positions;
    final symbols = _currentSymbols(
      selectedSymbol: selectedSymbol,
      selectedAlias: selectedAlias,
      rememberedTradeSymbol: rememberedTradeSymbol,
    );
    if (symbols.isEmpty) return positions;
    return positions
        .where((position) {
          final rawSymbol = position['symbol']?.toString() ?? '';
          final alias =
              position['symbol_alias']?.toString() ??
              position['symbolAlias']?.toString() ??
              '';
          return symbols.contains(rawSymbol) ||
              symbols.contains(normalizeSymbol(rawSymbol)) ||
              symbols.contains(alias) ||
              symbols.contains(normalizeSymbol(alias));
        })
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> visiblePending(
    List<Map<String, dynamic>> pendingOrders, {
    required bool isolateCurrentSymbol,
    required String selectedSymbol,
    required String selectedAlias,
    required String rememberedTradeSymbol,
  }) {
    return pendingOrders;
  }

  static String normalizeSymbol(String symbol) {
    var normalized = symbol.trim().toUpperCase();
    for (final ch in const [' ', '-', '/', '_']) {
      normalized = normalized.replaceAll(ch, '');
    }
    return normalized;
  }

  static Set<String> _currentSymbols({
    required String selectedSymbol,
    required String selectedAlias,
    required String rememberedTradeSymbol,
  }) {
    final symbols = <String>{};
    void add(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      symbols.add(trimmed);
      final normalized = normalizeSymbol(trimmed);
      if (normalized.isNotEmpty) symbols.add(normalized);
    }

    add(selectedSymbol);
    add(selectedAlias);
    add(rememberedTradeSymbol);
    return symbols;
  }
}

class TradeActionResultSnapshot {
  const TradeActionResultSnapshot({
    required this.payload,
    required this.status,
    required this.orderId,
    required this.traderId,
    required this.currentTime,
  });

  final Map<String, dynamic> payload;
  final int status;
  final String orderId;
  final String traderId;
  final int currentTime;

  bool get hasOrderId => orderId.isNotEmpty && orderId != '0';
  bool get hasTraderId => traderId.isNotEmpty && traderId != '0';

  TradeActionResultSnapshot copyWithStatusLookup(Map<String, dynamic> data) {
    final nextPayload = <String, dynamic>{...payload, ...data};
    final nextOrderId = _firstText(data, const [
      'order_id',
      'orderId',
      'position_id',
      'positionId',
      'ticket',
      'deal_id',
      'dealId',
    ], fallback: orderId);
    if (nextOrderId.isNotEmpty) {
      nextPayload['order_id'] = nextOrderId;
    }
    return TradeActionResultContract.fromPayload(nextPayload);
  }

  TradeActionResultSnapshot copyWithDealLookup(Map<String, dynamic> data) {
    final orderInfo =
        data['order_info'] ??
        data['orderInfo'] ??
        data['order'] ??
        data['position'] ??
        data['result'];
    final dealPayload = orderInfo is Map
        ? Map<String, dynamic>.from(orderInfo)
        : <String, dynamic>{};
    return TradeActionResultContract.fromPayload({
      ...payload,
      ...dealPayload,
      'status': 1,
    });
  }

  static String _firstText(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }
}

abstract final class TradeActionResultContract {
  static TradeActionResultSnapshot fromPayload(Map<String, dynamic> payload) {
    final normalized = _normalizedPayload(payload);
    final statusValue = normalized['status'];
    final status = statusValue is Map
        ? _toInt(normalized['order_status'] ?? normalized['orderStatus'])
        : _toInt(statusValue);
    return TradeActionResultSnapshot(
      payload: normalized,
      status: status,
      orderId: TradeActionResultSnapshot._firstText(normalized, const [
        'order_id',
        'orderId',
        'position_id',
        'positionId',
        'ticket',
        'deal_id',
        'dealId',
      ]),
      traderId: TradeActionResultSnapshot._firstText(normalized, const [
        'trader_id',
        'traderId',
        'trade_id',
        'tradeId',
        'execution_id',
        'executionId',
        'execution_correlator_id',
        'executionCorrelatorId',
        'correlator_id',
        'correlatorId',
        'correlation_id',
        'correlationId',
        'request_id',
        'requestId',
      ]),
      currentTime: _toInt(
        normalized['current_time'] ?? normalized['currentTime'],
      ),
    );
  }

  static Map<String, dynamic> orderIdParams(TradeActionResultSnapshot result) {
    return {'id': _numericText(result.traderId)};
  }

  static Map<String, dynamic> orderStatusParams(
    TradeActionResultSnapshot result, {
    required int elapsedSeconds,
  }) {
    return {
      'order_id': _numericText(result.orderId),
      'from_time': result.currentTime,
      if (elapsedSeconds >= 5) 'direct': 1,
    };
  }

  static bool shouldPollDeal(
    TradeActionResultSnapshot result, {
    required String actionType,
  }) {
    if (actionType == 'pending') return false;
    return result.status == 1 && result.hasOrderId;
  }

  static bool statusLookupResolved(Map<String, dynamic> response) {
    final normalized = _normalizedPayload(response);
    final rawStatus = normalized['status'];
    final status = rawStatus is Map
        ? _toInt(normalized['order_status'] ?? normalized['orderStatus'])
        : _toInt(rawStatus);
    final orderId = TradeActionResultSnapshot._firstText(normalized, const [
      'order_id',
      'orderId',
      'position_id',
      'positionId',
      'ticket',
      'deal_id',
      'dealId',
    ]);
    return status == 1 && orderId.isNotEmpty;
  }

  static bool dealLookupResolved(Map<String, dynamic> response) {
    final normalized = _normalizedPayload(response);
    final success =
        normalized['success'] ??
        normalized['is_success'] ??
        normalized['isSuccess'] ??
        normalized['succeed'];
    if (success is bool) return success;
    if (success is num) return success != 0;
    final text = success?.toString().trim().toLowerCase();
    return text == '1' || text == 'true';
  }

  static Map<String, dynamic> _normalizedPayload(Map<String, dynamic> payload) {
    final normalized = <String, dynamic>{};

    void mergeNested(dynamic value) {
      if (value is Map<String, dynamic>) {
        normalized.addAll(_normalizedPayload(value));
      } else if (value is Map) {
        normalized.addAll(_normalizedPayload(Map<String, dynamic>.from(value)));
      }
    }

    for (final key in const [
      'data',
      'result',
      'order',
      'order_info',
      'orderInfo',
      'position',
      'trade',
    ]) {
      mergeNested(payload[key]);
    }
    normalized.addAll(payload);
    return normalized;
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Object _numericText(String value) {
    return int.tryParse(value) ?? value;
  }
}

abstract final class TradeExpectedProfit {
  static String calculate({
    required bool isBuy,
    required String openPrice,
    required String closePrice,
    required String lotText,
    required String contractSize,
    double conversionRate = 1,
  }) {
    final open = _toDouble(openPrice);
    final close = _toDouble(closePrice);
    final lot = _toDouble(lotText);
    final contract = _toDouble(contractSize);
    if (open <= 0 ||
        close <= 0 ||
        lot <= 0 ||
        contract <= 0 ||
        conversionRate <= 0) {
      return '--';
    }
    final pnl =
        (isBuy ? close - open : open - close) * lot * contract * conversionRate;
    if (!pnl.isFinite) return '--';
    return pnl.toStringAsFixed(2);
  }

  static double _toDouble(String value) {
    return double.tryParse(value.replaceAll(',', '').trim()) ?? 0;
  }
}
