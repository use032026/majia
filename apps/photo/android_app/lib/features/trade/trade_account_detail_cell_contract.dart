enum TradeAccountDetailSign { copy, origin }

enum TradeAccountDetailCellType { position, pending }

class TradeAccountDetailLabels {
  const TradeAccountDetailLabels(this.text);

  static const Map<String, String> fallbackText = {
    'stock_long': '买入',
    'stock_short': '卖出',
    'hand': '手',
    'order_tracking_sign': '跟单',
    'bring_single': '带单',
  };

  static const TradeAccountDetailLabels fallback = TradeAccountDetailLabels(
    fallbackText,
  );

  final Map<String, String> text;

  String t(String key) => text[key] ?? fallbackText[key] ?? key;
}

String tradeAccountDetailTitle(
  Map<String, dynamic> order,
  TradeAccountDetailCellType type,
) {
  return switch (type) {
    TradeAccountDetailCellType.position =>
      _pickString(order, const ['name', 'symbol']) ?? '',
    TradeAccountDetailCellType.pending =>
      _pickString(order, const ['symbol', 'name']) ?? '',
  };
}

String tradeAccountDetailAlias(Map<String, dynamic> order) {
  return _pickString(order, const ['symbol_alias', 'symbolAlias']) ?? '';
}

String tradeAccountDetailDirectionText(
  Map<String, dynamic> order, {
  TradeAccountDetailLabels labels = TradeAccountDetailLabels.fallback,
}) {
  return _directionInt(order) == 0
      ? labels.t('stock_long')
      : labels.t('stock_short');
}

String tradeAccountDetailProfitText(dynamic value) {
  final text = _valueText(value);
  if (text == null) return '--';
  final number = double.tryParse(text.replaceAll(',', ''));
  if (number != null && number > 0 && !text.startsWith('+')) return '+$text';
  return text;
}

String tradeAccountDetailLotText(
  Map<String, dynamic> order, {
  TradeAccountDetailLabels labels = TradeAccountDetailLabels.fallback,
}) {
  final lot = _pickString(order, const ['set_lot', 'setLot', 'lots', 'volume']);
  final unit = tradeAccountDetailLotUnit(order, labels: labels);
  return '${lot ?? '--'}$unit';
}

String tradeAccountDetailLotUnit(
  Map<String, dynamic> order, {
  TradeAccountDetailLabels labels = TradeAccountDetailLabels.fallback,
}) {
  final group = _pickString(order, const ['symbol_group', 'symbolGroup']);
  if (group == 'Crypto') {
    final name =
        _pickString(order, const ['name', 'symbol', 'symbol_name']) ?? '';
    return stripStableSuffixFromListingName(name);
  }
  return labels.t('hand');
}

String stripStableSuffixFromListingName(String name) {
  var result = name.trim();
  if (result.endsWith('USDT')) {
    result = result.substring(0, result.length - 4);
  } else if (result.endsWith('USD')) {
    result = result.substring(0, result.length - 3);
  }
  return result.trim();
}

TradeAccountDetailSign? tradeAccountDetailSign(Map<String, dynamic> order) {
  final isCopy = _truthy(order['is_copy_order'] ?? order['isCopyOrder']);
  final isOrigin = _truthy(order['is_origin_order'] ?? order['isOriginOrder']);
  if (isCopy && isOrigin) return TradeAccountDetailSign.origin;
  if (isCopy) return TradeAccountDetailSign.copy;
  return null;
}

String tradeAccountDetailSignText(
  TradeAccountDetailSign sign, {
  TradeAccountDetailLabels labels = TradeAccountDetailLabels.fallback,
}) {
  return switch (sign) {
    TradeAccountDetailSign.copy => labels.t('order_tracking_sign'),
    TradeAccountDetailSign.origin => labels.t('bring_single'),
  };
}

String tradeAccountPendingTrailingTimeText(Map<String, dynamic> order) {
  final raw =
      order['created_time'] ??
      order['createdTime'] ??
      order['create_time'] ??
      order['open_time'];
  return tradeAccountDetailTimeText(raw);
}

String tradeAccountPositionOpenPriceText(Map<String, dynamic> order) {
  return _pickString(order, const ['open_price', 'openPrice', 'price']) ?? '--';
}

String tradeAccountPendingPriceText(Map<String, dynamic> order) {
  final pending = _pickString(order, const ['pending_price', 'pendingPrice']);
  if (pending != null && pending != '-1') return pending;
  final signalName = _pickString(order, const ['signal_provider_name']);
  final orderType = _pickString(order, const ['order_type', 'orderType']);
  if (signalName != null && orderType != null && orderType != '0') {
    return _pickString(order, const ['price']) ?? '--';
  }
  return '--';
}

String tradeAccountCurrentPriceText(Map<String, dynamic> order) {
  final quote = _directionInt(order) == 0
      ? _pickString(order, const ['bid', 'sell'])
      : _pickString(order, const ['ask', 'buy']);
  return quote ??
      _pickString(order, const ['current_price', 'currentPrice']) ??
      '--';
}

String tradeAccountTakeProfitText(Map<String, dynamic> order) {
  return _dashIfUnset(
    _pickString(order, const ['take_profit', 'target_profit', 'targetProfit']),
  );
}

String tradeAccountStopLossText(Map<String, dynamic> order) {
  return _dashIfUnset(
    _pickString(order, const ['stop_loss', 'stopLosss', 'stopLoss']),
  );
}

String tradeAccountDetailTimeText(dynamic value) {
  if (value == null) return '--';
  final raw = value is num ? value.toInt() : int.tryParse(value.toString());
  if (raw == null || raw <= 0) return value.toString();
  final millis = raw > 100000000000 ? raw : raw * 1000;
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  final mm = dt.minute.toString().padLeft(2, '0');
  return '${dt.month}/${dt.day} ${dt.hour}:$mm';
}

String _dashIfUnset(String? value) {
  if (value == null || value.isEmpty) return '--';
  if (value == '-1') return '--';
  final number = double.tryParse(value.replaceAll(',', ''));
  if (number != null && number == 0) return '--';
  return value;
}

int _directionInt(Map<String, dynamic> order) {
  final raw = order['direction'];
  if (raw is num) return raw.toInt();
  final text = raw?.toString().trim().toLowerCase() ?? '';
  if (text == '1' || text == 'sell' || text == 'short') return 1;
  return 0;
}

String? _pickString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final text = _valueText(data[key]);
    if (text != null) return text;
  }
  return null;
}

String? _valueText(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return text;
}

bool _truthy(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase();
  return text == '1' || text == 'true' || text == 'yes';
}
