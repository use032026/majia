import 'dart:convert';

import 'package:intl/intl.dart';

enum TradeOrderDetailType { position, pending, history }

enum TradeOrderDetailRowKind { normal, action, copy, arrow, tradeUser }

enum TradeOrderDetailRowAction {
  none,
  traderAccount,
  copyTradingUser,
  profitSharing,
  lossCompensation,
  copyTradingCommission,
}

class TradeOrderDetailLabels {
  const TradeOrderDetailLabels(this.text);

  static const Map<String, String> fallbackText = {
    'modify': '修改',
    'close_a_position': '平仓',
    'cancel_order': '撤单',
    'position_details': '持仓详情',
    'pengding_details': '挂单详情',
    'order_details': '成交详情',
    'direction': '方向',
    'open_price_title': '开仓价格',
    'closing_price': '平仓价格',
    'stop_loss': '止损',
    'take_profit': '止盈',
    'order_number': '订单号',
    'overnight_interest_2': '隔夜利息',
    'open_time': '开仓时间',
    'close_time': '平仓时间',
    'order_price': '委托价格',
    'validity_period': '有效期',
    'hanging_order_type': '挂单类型',
    'pending_time': '挂单时间',
    'closing_type': '平仓类型',
    'trade_mode': '交易模式',
    'bring_single': '带单',
    'order_tracking_sign': '跟单',
    'trader_account': '交易员账户',
    'copy_trading_user': '跟单用户',
    'copy_trading_commission': '跟单分润',
    'profit_sharing': '分润',
    'loss_compensation': '亏损补偿',
    'lots': '手数',
    'no_setting': '未设置',
    'buy': '买入',
    'sell': '卖出',
    'market_price': '市价',
    'limit_price': '限价',
    'stop_loss_other': '停损',
    'manual': '手动',
    'system': '系统',
    'system_liquidation': '系统强平',
    'unknown': '未知',
    'no_compensation_for_public': '公域不赔付',
    'compensation_limit_reached': '赔付额度已达上限',
    'insufficient_compensation_amount': '赔付金额不足',
    'not_enough_reimbursements': '赔付次数不足',
    'no_profit_required': '未满足盈利要求',
    'profit_and_loss': '盈亏',
    'net_profit_and_loss': '净盈亏',
  };

  static const TradeOrderDetailLabels fallback = TradeOrderDetailLabels(
    fallbackText,
  );

  final Map<String, String> text;

  String t(String key) => text[key] ?? fallbackText[key] ?? key;
}

class TradeOrderDetailH5Links {
  const TradeOrderDetailH5Links({
    this.traderCenterUrl = '',
    this.traderOrderDetailsUrl = '',
    this.myFollowOrderUrl = '',
    this.traderProfitUrl = '',
    this.traderProfitOrderUrl = '',
  });

  final String traderCenterUrl;
  final String traderOrderDetailsUrl;
  final String myFollowOrderUrl;
  final String traderProfitUrl;
  final String traderProfitOrderUrl;
}

class TradeOrderDetailMiniRoute {
  const TradeOrderDetailMiniRoute(this.link);

  final String link;
}

class TradeOrderDetailRow {
  const TradeOrderDetailRow({
    required this.label,
    required this.value,
    this.kind = TradeOrderDetailRowKind.normal,
    this.direction = 0,
    this.action = TradeOrderDetailRowAction.none,
  });

  final String label;
  final String value;
  final TradeOrderDetailRowKind kind;
  final int direction;
  final TradeOrderDetailRowAction action;
}

class TradeOrderDetailSection {
  const TradeOrderDetailSection(this.rows);

  final List<TradeOrderDetailRow> rows;
}

class TradeOrderDetailContract {
  const TradeOrderDetailContract({
    required this.type,
    required this.source,
    required this.title,
    required this.orderId,
    required this.symbol,
    required this.symbolAlias,
    required this.profit,
    required this.overnightInterest,
    required this.netProfit,
    required this.sections,
    required this.leftActionLabel,
    required this.rightActionLabel,
    required this.profitLabel,
    required this.netProfitLabel,
  });

  final TradeOrderDetailType type;
  final Map<String, dynamic> source;
  final String title;
  final String orderId;
  final String symbol;
  final String symbolAlias;
  final String profit;
  final String overnightInterest;
  final String netProfit;
  final List<TradeOrderDetailSection> sections;
  final String leftActionLabel;
  final String rightActionLabel;
  final String profitLabel;
  final String netProfitLabel;

  List<TradeOrderDetailRow> get rows =>
      sections.expand((section) => section.rows).toList(growable: false);

  bool get showProfitSummary =>
      type == TradeOrderDetailType.position ||
      type == TradeOrderDetailType.history;

  bool get showBottomActions =>
      type == TradeOrderDetailType.position ||
      type == TradeOrderDetailType.pending;

  bool get isBuy => _direction(source) == 0;

  TradeOrderDetailMiniRoute? miniRouteForRow(
    TradeOrderDetailRow row, {
    required TradeOrderDetailH5Links links,
  }) {
    final link = switch (row.action) {
      TradeOrderDetailRowAction.traderAccount => _traderAccountLink(links),
      TradeOrderDetailRowAction.copyTradingUser => _appendQuery(
        links.traderProfitOrderUrl,
        {'position_id': _positionId(source), 'active': '0'},
      ),
      TradeOrderDetailRowAction.profitSharing ||
      TradeOrderDetailRowAction.lossCompensation => _appendQuery(
        links.myFollowOrderUrl,
        {'active': '1'},
      ),
      TradeOrderDetailRowAction.copyTradingCommission => _appendQuery(
        links.traderProfitUrl,
        {'active': '1'},
      ),
      TradeOrderDetailRowAction.none => '',
    };
    if (link.trim().isEmpty) return null;
    return TradeOrderDetailMiniRoute(link);
  }

  String shareOrderJson() {
    return jsonEncode({
      'symbol': _firstText(source, const ['symbol']),
      'symbol_alias': _firstText(source, const ['symbol_alias', 'symbolAlias']),
      'direction': _direction(source),
      'lots': _lots(source),
      'symbol_group': _firstText(source, const ['symbol_group', 'symbolGroup']),
      'open_price': _firstText(source, const ['open_price', 'openPrice']),
      'current_price': _firstText(source, const [
        'current_price',
        'currentPrice',
      ]),
      'share_profit': _firstText(source, const ['profit', 'pnl']),
    });
  }

  String _traderAccountLink(TradeOrderDetailH5Links links) {
    if (_isOriginCopyOrder(source)) {
      return links.traderCenterUrl;
    }
    final follow = _nestedMap(source, 'follow_info', 'followInfo');
    return _appendQuery(links.traderOrderDetailsUrl, {
      'sp_id': _firstText(follow, const [
        'signal_provider_id',
        'signalProviderId',
      ]),
      'custom_public': _firstText(follow, const ['follow_type', 'followType']),
    });
  }

  static TradeOrderDetailType typeFromRoute(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    if (value == '1' || value == 'pending' || value == 'registration') {
      return TradeOrderDetailType.pending;
    }
    if (value == '2' || value == 'history') {
      return TradeOrderDetailType.history;
    }
    return TradeOrderDetailType.position;
  }

  static TradeOrderDetailType inferType(Map<String, dynamic> order) {
    if (_hasPositiveTime(order['close_time'] ?? order['closeTime'])) {
      return TradeOrderDetailType.history;
    }
    final pending = order['pending_price'] ?? order['pendingPrice'];
    if (pending != null && pending.toString().trim().isNotEmpty) {
      return TradeOrderDetailType.pending;
    }
    final orderType = order['order_type'] ?? order['orderType'];
    final status = order['status'];
    if (orderType?.toString().toLowerCase() == 'pending' ||
        status?.toString() == '2') {
      return TradeOrderDetailType.pending;
    }
    return TradeOrderDetailType.position;
  }

  static TradeOrderDetailContract fromOrder(
    Map<String, dynamic> order, {
    TradeOrderDetailType? type,
    TradeOrderDetailLabels labels = TradeOrderDetailLabels.fallback,
  }) {
    final resolvedType = type ?? inferType(order);
    return switch (resolvedType) {
      TradeOrderDetailType.position => _position(order, labels),
      TradeOrderDetailType.pending => _pending(order, labels),
      TradeOrderDetailType.history => _history(order, labels),
    };
  }

  static TradeOrderDetailContract _position(
    Map<String, dynamic> order,
    TradeOrderDetailLabels labels,
  ) {
    final orderId = _orderId(order);
    final profit = _displayText(order, const ['profit', 'pnl']);
    final overnight = _displayText(order, const [
      'overnight_interest',
      'overnightInterest',
      'swap',
    ]);
    return TradeOrderDetailContract(
      type: TradeOrderDetailType.position,
      source: Map<String, dynamic>.from(order),
      title: labels.t('position_details'),
      orderId: orderId,
      symbol: _displayText(order, const ['symbol']),
      symbolAlias: _displayText(order, const ['symbol_alias', 'symbolAlias']),
      profit: profit,
      overnightInterest: overnight,
      netProfit: _sumMoney(profit, overnight),
      leftActionLabel: labels.t('modify'),
      rightActionLabel: labels.t('close_a_position'),
      profitLabel: labels.t('profit_and_loss'),
      netProfitLabel: labels.t('net_profit_and_loss'),
      sections: [
        TradeOrderDetailSection([
          TradeOrderDetailRow(
            label: labels.t('direction'),
            value: _directionLabel(order, labels),
            kind: TradeOrderDetailRowKind.action,
            direction: _direction(order),
          ),
          TradeOrderDetailRow(
            label: _lotsLabel(order, labels),
            value: _lots(order),
          ),
        ]),
        TradeOrderDetailSection([
          TradeOrderDetailRow(
            label: labels.t('open_price_title'),
            value: _displayText(order, const [
              'open_price',
              'openPrice',
              'price',
            ]),
          ),
          TradeOrderDetailRow(
            label: labels.t('stop_loss'),
            value: _tpSl(order, 'stop_loss', labels),
          ),
          TradeOrderDetailRow(
            label: labels.t('take_profit'),
            value: _tpSl(order, 'take_profit', labels),
          ),
        ]),
        TradeOrderDetailSection([
          TradeOrderDetailRow(
            label: labels.t('order_number'),
            value: _orderNumber(orderId),
            kind: TradeOrderDetailRowKind.copy,
          ),
          TradeOrderDetailRow(
            label: labels.t('overnight_interest_2'),
            value: '$overnight USD',
          ),
          TradeOrderDetailRow(
            label: labels.t('open_time'),
            value: _timeText(order, const ['created_time', 'createdTime']),
          ),
        ]),
        ..._copySections(order, TradeOrderDetailType.position, labels),
      ],
    );
  }

  static TradeOrderDetailContract _pending(
    Map<String, dynamic> order,
    TradeOrderDetailLabels labels,
  ) {
    final orderId = _orderId(order);
    return TradeOrderDetailContract(
      type: TradeOrderDetailType.pending,
      source: Map<String, dynamic>.from(order),
      title: labels.t('pengding_details'),
      orderId: orderId,
      symbol: _displayText(order, const ['symbol']),
      symbolAlias: _displayText(order, const ['symbol_alias', 'symbolAlias']),
      profit: '--',
      overnightInterest: '--',
      netProfit: '--',
      leftActionLabel: labels.t('modify'),
      rightActionLabel: labels.t('cancel_order'),
      profitLabel: labels.t('profit_and_loss'),
      netProfitLabel: labels.t('net_profit_and_loss'),
      sections: [
        TradeOrderDetailSection([
          TradeOrderDetailRow(
            label: labels.t('direction'),
            value: _directionLabel(order, labels),
            kind: TradeOrderDetailRowKind.action,
            direction: _direction(order),
          ),
          TradeOrderDetailRow(
            label: _lotsLabel(order, labels),
            value: _lots(order),
          ),
        ]),
        TradeOrderDetailSection([
          TradeOrderDetailRow(
            label: labels.t('order_price'),
            value: _displayText(order, const [
              'pending_price',
              'pendingPrice',
              'price',
            ]),
          ),
          TradeOrderDetailRow(
            label: labels.t('stop_loss'),
            value: _tpSl(order, 'stop_loss', labels),
          ),
          TradeOrderDetailRow(
            label: labels.t('take_profit'),
            value: _tpSl(order, 'take_profit', labels),
          ),
        ]),
        TradeOrderDetailSection([
          TradeOrderDetailRow(
            label: labels.t('order_number'),
            value: _orderNumber(orderId),
            kind: TradeOrderDetailRowKind.copy,
          ),
          TradeOrderDetailRow(
            label: labels.t('validity_period'),
            value: _timeText(order, const ['expire_time', 'expireTime']),
          ),
          TradeOrderDetailRow(
            label: labels.t('hanging_order_type'),
            value: _actionLabel(order, labels),
          ),
          TradeOrderDetailRow(
            label: labels.t('pending_time'),
            value: _timeText(order, const ['created_time', 'createdTime']),
          ),
        ]),
      ],
    );
  }

  static TradeOrderDetailContract _history(
    Map<String, dynamic> order,
    TradeOrderDetailLabels labels,
  ) {
    final orderId = _orderId(order);
    final profit = _displayText(order, const ['profit', 'pnl']);
    final overnight = _displayText(order, const [
      'overnight_interest',
      'overnightInterest',
      'swap',
    ]);
    return TradeOrderDetailContract(
      type: TradeOrderDetailType.history,
      source: Map<String, dynamic>.from(order),
      title: labels.t('order_details'),
      orderId: orderId,
      symbol: _displayText(order, const ['symbol']),
      symbolAlias: _displayText(order, const ['symbol_alias', 'symbolAlias']),
      profit: profit,
      overnightInterest: overnight,
      netProfit: _sumMoney(profit, overnight),
      leftActionLabel: '',
      rightActionLabel: '',
      profitLabel: labels.t('profit_and_loss'),
      netProfitLabel: labels.t('net_profit_and_loss'),
      sections: [
        TradeOrderDetailSection([
          TradeOrderDetailRow(
            label: labels.t('direction'),
            value: _directionLabel(order, labels),
            kind: TradeOrderDetailRowKind.action,
            direction: _direction(order),
          ),
          TradeOrderDetailRow(
            label: _lotsLabel(order, labels),
            value: _lots(order),
          ),
        ]),
        TradeOrderDetailSection([
          TradeOrderDetailRow(
            label: labels.t('open_price_title'),
            value: _displayText(order, const ['open_price', 'openPrice']),
          ),
          TradeOrderDetailRow(
            label: labels.t('closing_price'),
            value: _displayText(order, const ['close_price', 'closePrice']),
          ),
          TradeOrderDetailRow(
            label: labels.t('stop_loss'),
            value: _tpSl(order, 'stop_loss', labels),
          ),
          TradeOrderDetailRow(
            label: labels.t('take_profit'),
            value: _tpSl(order, 'take_profit', labels),
          ),
        ]),
        TradeOrderDetailSection([
          TradeOrderDetailRow(
            label: labels.t('order_number'),
            value: _orderNumber(orderId),
            kind: TradeOrderDetailRowKind.copy,
          ),
          TradeOrderDetailRow(
            label: labels.t('overnight_interest_2'),
            value: '$overnight USD',
          ),
          TradeOrderDetailRow(
            label: labels.t('open_time'),
            value: _timeText(order, const ['open_time', 'openTime']),
          ),
          TradeOrderDetailRow(
            label: labels.t('close_time'),
            value: _timeText(order, const ['close_time', 'closeTime']),
          ),
          TradeOrderDetailRow(
            label: labels.t('closing_type'),
            value: _closeTypeLabel(order, labels),
          ),
        ]),
        ..._copySections(order, TradeOrderDetailType.history, labels),
      ],
    );
  }

  static List<TradeOrderDetailSection> _copySections(
    Map<String, dynamic> order,
    TradeOrderDetailType type,
    TradeOrderDetailLabels labels,
  ) {
    if (!_isCopyOrder(order)) return const [];
    if (_isOriginCopyOrder(order)) {
      final sp = _nestedMap(order, 'sp_info', 'spInfo');
      final rows = <TradeOrderDetailRow>[
        TradeOrderDetailRow(
          label: labels.t('trade_mode'),
          value: labels.t('bring_single'),
          kind: TradeOrderDetailRowKind.tradeUser,
        ),
        TradeOrderDetailRow(
          label: labels.t('trader_account'),
          value: _firstText(sp, const [
            'signal_provider_name',
            'signalProviderName',
          ], fallback: '--'),
          kind: TradeOrderDetailRowKind.arrow,
          action: TradeOrderDetailRowAction.traderAccount,
        ),
        TradeOrderDetailRow(
          label: labels.t('copy_trading_user'),
          value: _firstText(sp, const [
            'follow_count',
            'followCount',
          ], fallback: '0'),
          kind: TradeOrderDetailRowKind.arrow,
          action: TradeOrderDetailRowAction.copyTradingUser,
        ),
      ];
      if (type == TradeOrderDetailType.history) {
        rows.add(
          TradeOrderDetailRow(
            label: labels.t('copy_trading_commission'),
            value: _copyCommission(order, sp),
            kind: TradeOrderDetailRowKind.arrow,
            action: TradeOrderDetailRowAction.copyTradingCommission,
          ),
        );
      }
      return [TradeOrderDetailSection(rows)];
    }

    final follow = _nestedMap(order, 'follow_info', 'followInfo');
    final rows = <TradeOrderDetailRow>[
      TradeOrderDetailRow(
        label: labels.t('trade_mode'),
        value: labels.t('order_tracking_sign'),
        kind: TradeOrderDetailRowKind.tradeUser,
      ),
      TradeOrderDetailRow(
        label: labels.t('trader_account'),
        value: _firstText(follow, const [
          'signal_provider_name',
          'signalProviderName',
        ], fallback: '--'),
        kind: TradeOrderDetailRowKind.arrow,
        action: TradeOrderDetailRowAction.traderAccount,
      ),
    ];
    if (type == TradeOrderDetailType.history) {
      if (_bool(follow['is_profit'] ?? follow['isProfit'])) {
        rows.add(
          TradeOrderDetailRow(
            label: labels.t('profit_sharing'),
            value: _firstText(follow, const [
              'share_profit',
              'shareProfit',
            ], fallback: '--'),
            kind: TradeOrderDetailRowKind.arrow,
            action: TradeOrderDetailRowAction.profitSharing,
          ),
        );
      } else {
        rows.add(
          TradeOrderDetailRow(
            label: labels.t('loss_compensation'),
            value: _lossCompensation(order, follow, labels),
            action: TradeOrderDetailRowAction.lossCompensation,
          ),
        );
      }
    }
    return [TradeOrderDetailSection(rows)];
  }

  static String _orderId(Map<String, dynamic> order) => _firstText(
    order,
    const ['order_id', 'orderId', 'position_id', 'positionId', 'id'],
  );

  static String _positionId(Map<String, dynamic> order) => _firstText(
    order,
    const ['position_id', 'positionId', 'order_id', 'orderId', 'id'],
  );

  static String _orderNumber(String orderId) =>
      orderId.trim().isEmpty ? '--' : '#$orderId';

  static String _lotsLabel(
    Map<String, dynamic> order,
    TradeOrderDetailLabels labels,
  ) {
    if (_firstText(order, const ['symbol_group', 'symbolGroup']) == 'Crypto') {
      final name = _firstText(order, const ['name', 'symbol']);
      return name.isEmpty ? labels.t('lots') : name;
    }
    return labels.t('lots');
  }

  static String _lots(Map<String, dynamic> order) =>
      _displayText(order, const ['lots', 'set_lot', 'setLot', 'volume']);

  static bool _isCopyOrder(Map<String, dynamic> order) =>
      _bool(order['is_copy_order'] ?? order['isCopyOrder']);

  static bool _isOriginCopyOrder(Map<String, dynamic> order) =>
      _isCopyOrder(order) &&
      _bool(order['is_origin_order'] ?? order['isOriginOrder']);

  static Map<String, dynamic> _nestedMap(
    Map<String, dynamic> source,
    String snakeKey,
    String camelKey,
  ) {
    final value = source[snakeKey] ?? source[camelKey];
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static String _copyCommission(
    Map<String, dynamic> order,
    Map<String, dynamic> sp,
  ) {
    final value = _firstText(sp, const ['share_profit', 'shareProfit']);
    if (value.isEmpty) return '--';
    final currency = _firstText(order, const ['currency'], fallback: 'USD');
    return '$value $currency';
  }

  static String _lossCompensation(
    Map<String, dynamic> order,
    Map<String, dynamic> follow,
    TradeOrderDetailLabels labels,
  ) {
    if (_bool(follow['is_compensated'] ?? follow['isCompensated'])) {
      final value = _firstText(follow, const [
        'compensation_amount',
        'compensationAmount',
      ]);
      if (value.isEmpty) return '--';
      final currency = _firstText(order, const ['currency'], fallback: 'USD');
      return '$value $currency';
    }
    return _uncompensatedReasonLabel(
      _int(follow['uncompensated_reason'] ?? follow['uncompensatedReason']),
      labels,
    );
  }

  static String _uncompensatedReasonLabel(
    int reason,
    TradeOrderDetailLabels labels,
  ) {
    return switch (reason) {
      0 => labels.t('unknown'),
      1 => labels.t('no_compensation_for_public'),
      2 => labels.t('compensation_limit_reached'),
      3 => labels.t('insufficient_compensation_amount'),
      4 => labels.t('not_enough_reimbursements'),
      5 => labels.t('no_profit_required'),
      _ => '',
    };
  }

  static String _tpSl(
    Map<String, dynamic> order,
    String snakeKey,
    TradeOrderDetailLabels labels,
  ) {
    final keys = snakeKey == 'take_profit'
        ? const ['take_profit', 'target_profit', 'targetProfit', 'tp']
        : const ['stop_loss', 'stopLosss', 'sl'];
    final value = _firstText(order, keys);
    if (value.isEmpty || value == '-1' || _isZero(value)) {
      return labels.t('no_setting');
    }
    return value;
  }

  static String _directionLabel(
    Map<String, dynamic> order,
    TradeOrderDetailLabels labels,
  ) => _direction(order) == 0 ? labels.t('buy') : labels.t('sell');

  static int _direction(Map<String, dynamic> order) {
    final value = order['direction'] ?? order['deal_type'] ?? order['dealType'];
    if (value is num) return value.toInt() == 1 ? 1 : 0;
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text == '1' || text == 'sell' || text == '卖出') return 1;
    return 0;
  }

  static String _actionLabel(
    Map<String, dynamic> order,
    TradeOrderDetailLabels labels,
  ) {
    final raw =
        order['action'] ?? order['pending_type'] ?? order['pendingType'];
    final value = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString() ?? '');
    return switch (value) {
      0 => labels.t('market_price'),
      1 => labels.t('limit_price'),
      2 => labels.t('stop_loss_other'),
      3 => labels.t('manual'),
      4 => labels.t('take_profit'),
      5 => labels.t('stop_loss'),
      6 => labels.t('system'),
      _ => _firstText(order, const [
        'action_string',
        'actionString',
        'order_type',
        'orderType',
      ], fallback: '--'),
    };
  }

  static String _closeTypeLabel(
    Map<String, dynamic> order,
    TradeOrderDetailLabels labels,
  ) {
    final raw = order['close_type'] ?? order['closeType'];
    final value = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString() ?? '');
    return switch (value) {
      0 => labels.t('close_a_position'),
      1 => labels.t('take_profit'),
      2 => labels.t('stop_loss'),
      3 => labels.t('system_liquidation'),
      _ => _firstText(order, const [
        'close_type_string',
        'closeTypeString',
        'reason',
      ], fallback: '--'),
    };
  }

  static String _timeText(Map<String, dynamic> order, List<String> keys) {
    final raw = _firstValue(order, keys);
    final seconds = _seconds(raw);
    if (seconds == null || seconds <= 0) return '--';
    final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }

  static String _displayText(Map<String, dynamic> order, List<String> keys) =>
      _firstText(order, keys, fallback: '--');

  static Object? _firstValue(Map<String, dynamic> order, List<String> keys) {
    for (final key in keys) {
      if (order.containsKey(key)) return order[key];
    }
    return null;
  }

  static String _firstText(
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

  static bool _hasPositiveTime(Object? value) {
    final seconds = _seconds(value);
    return seconds != null && seconds > 0;
  }

  static int? _seconds(Object? value) {
    if (value == null) return null;
    if (value is num) {
      final raw = value.toInt();
      return raw > 100000000000 ? raw ~/ 1000 : raw;
    }
    final raw = int.tryParse(value.toString());
    if (raw == null) return null;
    return raw > 100000000000 ? raw ~/ 1000 : raw;
  }

  static bool _isZero(String value) {
    final number = double.tryParse(value);
    return number != null && number == 0;
  }

  static bool _bool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'true' || text == '1' || text == 'yes';
  }

  static int _int(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _appendQuery(String url, Map<String, String> query) {
    if (url.trim().isEmpty) return '';
    final parts = query.entries
        .where((entry) => entry.value.trim().isNotEmpty)
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
    if (parts.isEmpty) return url;
    return '$url${url.contains('?') ? '&' : '?'}$parts';
  }

  static String _sumMoney(String left, String right) {
    final a = double.tryParse(left);
    final b = double.tryParse(right);
    if (a == null || b == null) return '--';
    return (a + b).toStringAsFixed(2);
  }
}
