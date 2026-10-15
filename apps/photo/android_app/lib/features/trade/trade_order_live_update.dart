import '../../core/models/market_product_model.dart';
import 'trade_alignment.dart';

abstract final class TradeOrderLiveUpdate {
  static Map<String, dynamic>? fromMarketMessage({
    required Map<String, dynamic> order,
    required MarketWSMessage message,
    required bool pending,
  }) {
    if (message.type != 'TRANSACTION_UPDATE_SYMBOL_PRICE' &&
        message.type != 'UPDATE_SELL_AND_BUY') {
      return null;
    }
    final symbol = _text(message.data, const ['symbol']);
    if (symbol.isEmpty || !_sameSymbol(order, symbol)) return null;

    final bid = _text(message.data, const ['bid', 'buy']);
    final ask = _text(message.data, const ['ask', 'sell']);
    if (bid.isEmpty && ask.isEmpty) return null;

    final isBuy = _isBuy(order);
    final closePrice = isBuy
        ? (ask.isNotEmpty ? ask : _text(order, const ['current_price']))
        : (bid.isNotEmpty ? bid : _text(order, const ['current_price']));
    final next = <String, dynamic>{
      'symbol': _text(order, const ['symbol', 'symbol_code'], fallback: symbol),
      if (bid.isNotEmpty) 'buy': bid,
      if (ask.isNotEmpty) 'sell': ask,
      if (closePrice.isNotEmpty) 'current_price': closePrice,
    };

    final profit = _calculateProfit(
      order: {...order, ...next},
      closePrice: closePrice,
      pending: pending,
    );
    if (profit != null) next['profit'] = profit;

    final targetExpected = _calculateExpected(
      order: {...order, ...next},
      closeKey: const ['take_profit', 'target_profit', 'targetProfit', 'tp'],
      pending: pending,
    );
    if (targetExpected != null) next['target_profit_expected'] = targetExpected;

    final stopExpected = _calculateExpected(
      order: {...order, ...next},
      closeKey: const ['stop_loss', 'stopLosss', 'stopLoss', 'sl'],
      pending: pending,
    );
    if (stopExpected != null) next['stop_loss_expected'] = stopExpected;

    next.addAll(_rangeUpdate(order: {...order, ...next}, pending: pending));
    return next;
  }

  static bool matches(Map<String, dynamic> order, Map<String, dynamic> update) {
    final orderIds = [
      _text(order, const ['position_id', 'positionId']),
      _text(order, const ['order_id', 'orderId', 'id']),
    ].where((id) => id.isNotEmpty).toSet();
    final updateIds = [
      _text(update, const ['position_id', 'positionId']),
      _text(update, const ['order_id', 'orderId', 'id']),
    ].where((id) => id.isNotEmpty).toSet();
    if (orderIds.isNotEmpty &&
        updateIds.isNotEmpty &&
        orderIds.intersection(updateIds).isNotEmpty) {
      return true;
    }
    final symbol = _text(update, const ['symbol', 'symbol_code']);
    return symbol.isNotEmpty && _sameSymbol(order, symbol);
  }

  static Map<String, dynamic> merge(
    Map<String, dynamic> order,
    Map<String, dynamic> update,
  ) {
    return <String, dynamic>{...order, ...update};
  }

  static bool _sameSymbol(Map<String, dynamic> order, String symbol) {
    return _normalizeSymbol(_text(order, const ['symbol', 'symbol_code'])) ==
        _normalizeSymbol(symbol);
  }

  static String _normalizeSymbol(String value) {
    return value.replaceAll('/', '').replaceAll('_', '').toUpperCase().trim();
  }

  static String? _calculateProfit({
    required Map<String, dynamic> order,
    required String closePrice,
    required bool pending,
  }) {
    final openPrice = pending
        ? _text(order, const ['pending_price', 'pendingPrice', 'price'])
        : _text(order, const ['open_price', 'openPrice']);
    return _expectedProfit(
      order: order,
      openPrice: openPrice,
      closePrice: closePrice,
    );
  }

  static String? _calculateExpected({
    required Map<String, dynamic> order,
    required List<String> closeKey,
    required bool pending,
  }) {
    final closePrice = _text(order, closeKey);
    if (closePrice.isEmpty || closePrice == '-1' || closePrice == '0') {
      return null;
    }
    final openPrice = pending
        ? _text(order, const ['pending_price', 'pendingPrice', 'price'])
        : _text(order, const ['open_price', 'openPrice']);
    return _expectedProfit(
      order: order,
      openPrice: openPrice,
      closePrice: closePrice,
    );
  }

  static String? _expectedProfit({
    required Map<String, dynamic> order,
    required String openPrice,
    required String closePrice,
  }) {
    final contractSize = _text(order, const ['contract_size', 'contractSize']);
    final lots = _text(order, const ['lots', 'set_lot', 'setLot', 'volume']);
    if (openPrice.isEmpty ||
        closePrice.isEmpty ||
        contractSize.isEmpty ||
        lots.isEmpty) {
      return null;
    }
    final result = TradeExpectedProfit.calculate(
      isBuy: _isBuy(order),
      openPrice: openPrice,
      closePrice: closePrice,
      lotText: lots,
      contractSize: contractSize,
      conversionRate: _conversionRate(order),
    );
    return result == '--' ? null : result;
  }

  static Map<String, dynamic> _rangeUpdate({
    required Map<String, dynamic> order,
    required bool pending,
  }) {
    final bid = _number(_text(order, const ['buy', 'bid']));
    final ask = _number(_text(order, const ['sell', 'ask']));
    final point = _point(order);
    final pips = _number(_text(order, const ['pips', 'pip']));
    final step = pips > 0 ? pips : point;
    if (bid <= 0 || ask <= 0 || point <= 0 || step <= 0) {
      return const <String, dynamic>{};
    }

    final maxFinite = _maxFinite(order, point);
    final isBuy = _isBuy(order);
    final result = <String, dynamic>{};

    double profitMin;
    double profitMax;
    double lossMin;
    double lossMax;

    if (pending) {
      final open = _number(
        _text(order, const ['pending_price', 'pendingPrice', 'price']),
      );
      final base = open > 0 ? open : (isBuy ? ask : bid);
      if (isBuy) {
        profitMin = base + step;
        profitMax = maxFinite;
        lossMin = point;
        lossMax = _positive(base - step, point);
      } else {
        profitMin = point;
        profitMax = _positive(base - step, point);
        lossMin = base + step;
        lossMax = maxFinite;
      }

      final isLimit = _pendingAction(order) == 1;
      double pendingMin;
      double pendingMax;
      if (isLimit) {
        if (isBuy) {
          pendingMin = point;
          pendingMax = _positive(ask - step, point);
        } else {
          pendingMin = bid + step;
          pendingMax = maxFinite;
        }
      } else {
        if (isBuy) {
          pendingMin = ask + step;
          pendingMax = maxFinite;
        } else {
          pendingMin = point;
          pendingMax = _positive(bid - step, point);
        }
      }
      result['pending_min_price'] = _formatPrice(pendingMin, order);
      result['pending_max_price'] = _formatPrice(pendingMax, order);
    } else if (isBuy) {
      profitMin = bid + step;
      profitMax = maxFinite;
      lossMin = point;
      lossMax = _positive(bid - step, point);
    } else {
      profitMin = point;
      profitMax = _positive(ask - step, point);
      lossMin = ask + step;
      lossMax = maxFinite;
    }

    result['target_profit_min'] = _formatPrice(profitMin, order);
    result['target_profit_max'] = _formatPrice(profitMax, order);
    result['stop_loss_min'] = _formatPrice(lossMin, order);
    result['stop_loss_max'] = _formatPrice(lossMax, order);
    return result;
  }

  static double _conversionRate(Map<String, dynamic> order) {
    final explicit = _number(
      _text(order, const [
        'conversion_rate',
        'conversionRate',
        'profit_conversion_rate',
        'profitCurrencyToAccountRate',
      ]),
    );
    if (explicit > 0) return explicit;
    final profitToUsd = _number(
      _text(order, const [
        'profit_currency_to_usd_rate',
        'profitCurrencyToUsdRate',
      ]),
    );
    final usdToAccount = _number(
      _text(order, const [
        'usd_to_account_currency_rate',
        'usdToAccountCurrencyRate',
      ]),
    );
    if (profitToUsd > 0 && usdToAccount > 0) {
      return profitToUsd * usdToAccount;
    }
    return 1;
  }

  static int _pendingAction(Map<String, dynamic> order) {
    final raw = _text(order, const [
      'action',
      'order_action',
      'orderAction',
      'pending_type',
      'pendingType',
      'order_type',
      'orderType',
    ]).toLowerCase();
    if (raw.contains('stop')) return 2;
    if (raw.contains('limit')) return 1;
    return int.tryParse(raw) ?? 1;
  }

  static bool _isBuy(Map<String, dynamic> order) {
    final raw = _text(order, const [
      'direction',
      'cmd',
      'cmd_type',
      'cmdType',
      'trade_direction',
    ]).toLowerCase();
    return !(raw == '1' || raw.contains('sell'));
  }

  static double _point(Map<String, dynamic> order) {
    final explicit = _number(_text(order, const ['point', 'tick_size']));
    if (explicit > 0) return explicit;
    final digits = int.tryParse(_text(order, const ['digits']));
    if (digits != null && digits > 0) {
      return 1 / _pow10(digits);
    }
    return 0.0001;
  }

  static double _maxFinite(Map<String, dynamic> order, double point) {
    final existing = _number(
      _text(order, const ['price_max', 'max_price', 'maxPrice']),
    );
    if (existing > 0) return existing;
    final digits = _digits(order, point);
    return digits >= 3 ? 999.9999 : 999999;
  }

  static int _digits(Map<String, dynamic> order, double point) {
    final digits = int.tryParse(_text(order, const ['digits']));
    if (digits != null && digits >= 0) return digits;
    final text = _text(order, const ['point']);
    final index = text.indexOf('.');
    if (index >= 0) return text.length - index - 1;
    final pointText = point.toString();
    final pointIndex = pointText.indexOf('.');
    return pointIndex >= 0 ? pointText.length - pointIndex - 1 : 2;
  }

  static String _formatPrice(double value, Map<String, dynamic> order) {
    final point = _point(order);
    final fixed = value.toStringAsFixed(_digits(order, point));
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static double _positive(double value, double floor) {
    return value > floor ? value : floor;
  }

  static int _pow10(int exponent) {
    var value = 1;
    for (var i = 0; i < exponent; i++) {
      value *= 10;
    }
    return value;
  }

  static double _number(String value) {
    return double.tryParse(value.replaceAll(',', '').trim()) ?? 0;
  }

  static String _text(
    Map<String, dynamic> source,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return fallback;
  }
}
