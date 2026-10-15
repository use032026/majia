double _jsonToDouble(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  if (v is String) return num.tryParse(v)?.toDouble() ?? fallback;
  return fallback;
}

int _jsonToInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toInt();
  if (v is String) return num.tryParse(v)?.toInt() ?? fallback;
  return fallback;
}

double? _jsonToDoubleOrNull(dynamic a, dynamic b) {
  if (a != null) return _jsonToDouble(a);
  if (b != null) return _jsonToDouble(b);
  return null;
}

/// 多键取非空 URL / 字符串（与 iOS 行情 JSON 多别名解码一致）
String? _jsonOptionalUrl(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v == null) continue;
    if (v is String) {
      final s = v.trim();
      if (s.isNotEmpty) return s;
    } else if (v is num) {
      final s = v.toString();
      if (s.isNotEmpty) return s;
    }
  }
  return null;
}

String? _jsonOptionalDisplayString(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final k in keys) {
    final v = json[k];
    if (v == null) continue;
    if (v is String) {
      final s = v.trim();
      if (s.isNotEmpty) return s;
    } else if (v is num) {
      return v.toString();
    }
  }
  return null;
}

double? _parsePercentLike(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return null;
    final noPct = s.replaceAll('%', '').replaceAll('+', '').trim();
    return num.tryParse(noPct)?.toDouble();
  }
  return null;
}

/// 涨跌幅百分比数值（对齐 iOS 多字段：`change_percent` / `change_rate` / `chg_pct` 及 `pre_close` 推算）
double _jsonChangePercent(Map<String, dynamic> json) {
  const keys = <String>[
    'change_percent',
    'changePercent',
    'change_rate',
    'changeRate',
    'chg_pct',
    'chgPct',
    'rise_rate',
    'riseRate',
    'price_change_percent',
    'priceChangePercent',
    'pct_change',
    'percent_change',
    'quote_change_percent',
    'quoteChangePercent',
    'zf',
  ];
  for (final k in keys) {
    final parsed = _parsePercentLike(json[k]);
    if (parsed != null && parsed.abs() > 1e-12) return parsed;
  }
  return _changePercentDerived(json);
}

double _changePercentDerived(Map<String, dynamic> json) {
  final change = _jsonToDouble(json['change']);
  if (change.abs() < 1e-12) return 0;
  var pre = _jsonToDouble(json['pre_close']);
  if (pre.abs() < 1e-12) pre = _jsonToDouble(json['preclose']);
  if (pre.abs() < 1e-12) pre = _jsonToDouble(json['preClose']);
  if (pre.abs() < 1e-12) pre = _jsonToDouble(json['yesterday_close']);
  if (pre.abs() < 1e-12) pre = _jsonToDouble(json['yesterdayClose']);
  if (pre.abs() < 1e-12) pre = _jsonToDouble(json['prev_close']);
  if (pre.abs() < 1e-12) pre = _jsonToDouble(json['prevClose']);
  if (pre.abs() < 1e-12) pre = _jsonToDouble(json['pre_close_price']);
  if (pre.abs() > 1e-12) return (change / pre) * 100.0;
  final last = _jsonToDouble(
    json['last_price'],
    _jsonToDouble(json['close'], _jsonToDouble(json['price'])),
  );
  final denom = last - change;
  if (denom.abs() > 1e-12) return (change / denom) * 100.0;
  return 0;
}

/// 行情产品模型
/// 对齐 iOS MarketProModel / STMarketProductModel（sparkline、双语图标等按 market_1 使用）；
/// 分类列表与 iOS `CategoryMarketModel` 的 `is_single_icon` / `icon` / `currency_base_icon` / `currency_profit_icon` 一致，见 [CategoryMarketProductModel]。
class MarketProductModel {
  final String symbol;
  final String name;
  final String title; // 用于去重
  double price;
  double buy;
  double sell;
  double spread;
  double open;
  double high;
  double low;
  double close;
  double change;
  double changePercent;
  int volume;
  int turnover;
  int precision; // 小数位数
  List<double> points; // sparkline 数据

  /// 中文副标题（Market1 左侧币种说明）
  final String? subTitle;

  /// 是否仅展示单图标（否则展示 currency_base + currency_profit 双图标）
  final bool isSingleIcon;

  final String? icon;
  final String? currencyBaseIcon;
  final String? currencyProfitIcon;

  /// Sparkline 纵轴范围（与 iOS MarketProModel.pointsMin / pointsMax 一致）
  final double? pointsMin;
  final double? pointsMax;

  /// 是否已在用户自选中（接口 `in_optional` / `inOptional`）
  bool inOptional;

  /// 品种分组（对齐 iOS `STMarketProductModel.symbolGroup`，如 Commodities / Forex）
  final String? symbolGroup;

  /// 买卖价变化方向与本地接收时间（对齐 iOS `buyPriceChangeDirection` / `lastBuyPriceChangeTime`）。
  final int buyPriceChangeDirection;
  final int sellPriceChangeDirection;
  final DateTime? lastBuyPriceChangeAt;
  final DateTime? lastSellPriceChangeAt;

  /// 涨跌色: 1=涨, -1=跌, 0=平
  int get riseAndFall {
    if (change > 0) return 1;
    if (change < 0) return -1;
    return 0;
  }

  /// 涨幅字符串（含 %）
  String get changePercentString =>
      '${changePercent >= 0 ? "+" : ""}${changePercent.toStringAsFixed(2)}%';

  /// 涨跌额字符串
  String get changeString =>
      '${change >= 0 ? "+" : ""}${change.toStringAsFixed(precision)}';

  MarketProductModel({
    required this.symbol,
    required this.name,
    String? title,
    this.price = 0,
    this.buy = 0,
    this.sell = 0,
    this.spread = 0,
    this.open = 0,
    this.high = 0,
    this.low = 0,
    this.close = 0,
    this.change = 0,
    this.changePercent = 0,
    this.volume = 0,
    this.turnover = 0,
    this.precision = 2,
    List<double>? points,
    this.subTitle,
    this.isSingleIcon = true,
    this.icon,
    this.currencyBaseIcon,
    this.currencyProfitIcon,
    this.pointsMin,
    this.pointsMax,
    this.inOptional = false,
    this.symbolGroup,
    this.buyPriceChangeDirection = 0,
    this.sellPriceChangeDirection = 0,
    this.lastBuyPriceChangeAt,
    this.lastSellPriceChangeAt,
  }) : title = title ?? name,
       points = points ?? [];

  factory MarketProductModel.fromJson(Map<String, dynamic> json) {
    final change = _jsonToDouble(json['change']);
    // 对齐 iOS STMarketProductModel：last_price / close / price 均可能出现（接口可能返回字符串）
    final lastPrice = _jsonToDouble(
      json['last_price'],
      _jsonToDouble(json['close'], _jsonToDouble(json['price'])),
    );
    final singleIcon = _jsonIsSingleIconFlag(json);
    final inOptRaw = json['in_optional'] ?? json['inOptional'];
    final inOptional = inOptRaw is bool
        ? inOptRaw
        : (_jsonToInt(inOptRaw) != 0);
    return MarketProductModel(
      symbol: json['symbol'] as String? ?? json['title'] as String? ?? '',
      name: json['name'] as String? ?? '',
      title: json['title'] as String? ?? json['name'] as String? ?? '',
      price: lastPrice,
      buy: _jsonToDouble(json['buy'], _jsonToDouble(json['ask'])),
      sell: _jsonToDouble(json['sell'], _jsonToDouble(json['bid'])),
      spread: _jsonToDouble(json['spread']),
      open: _jsonToDouble(json['open']),
      high: _jsonToDouble(json['high']),
      low: _jsonToDouble(json['low']),
      close: _jsonToDouble(json['close'], lastPrice - change),
      change: change,
      changePercent: _jsonChangePercent(json),
      volume: _jsonToInt(json['volume']),
      turnover: _jsonToInt(json['turnover']),
      precision: _jsonToInt(json['precision'], _jsonToInt(json['digits'], 2)),
      points: _parsePointsList(json['points']),
      subTitle:
          json['sub_title'] as String? ??
          json['subTitle'] as String? ??
          json['alias'] as String?,
      isSingleIcon: singleIcon,
      icon: _jsonOptionalUrl(json, const [
        'icon',
        'Icon',
        'icon_url',
        'iconUrl',
        'symbol_icon',
        'currency_icon',
        'logo',
        'img',
      ]),
      currencyBaseIcon: _jsonOptionalUrl(json, const [
        'currency_base_icon',
        'currencyBaseIcon',
        'base_icon',
        'baseIcon',
        'base_currency_icon',
      ]),
      currencyProfitIcon: _jsonOptionalUrl(json, const [
        'currency_profit_icon',
        'currencyProfitIcon',
        'profit_icon',
        'quote_icon',
        'profitIcon',
      ]),
      pointsMin: _jsonToDoubleOrNull(json['points_min'], json['pointsMin']),
      pointsMax: _jsonToDoubleOrNull(json['points_max'], json['pointsMax']),
      inOptional: inOptional,
      symbolGroup:
          json['symbol_group'] as String? ?? json['symbolGroup'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'name': name,
    'title': title,
    'price': price,
    'buy': buy,
    'sell': sell,
    'spread': spread,
    'open': open,
    'high': high,
    'low': low,
    'close': close,
    'change': change,
    'change_percent': changePercent,
    'volume': volume,
    'turnover': turnover,
    'precision': precision,
    'points': points,
    if (subTitle != null) 'sub_title': subTitle,
    'is_single_icon': isSingleIcon,
    if (icon != null) 'icon': icon,
    if (currencyBaseIcon != null) 'currency_base_icon': currencyBaseIcon,
    if (currencyProfitIcon != null) 'currency_profit_icon': currencyProfitIcon,
    if (pointsMin != null) 'points_min': pointsMin,
    if (pointsMax != null) 'points_max': pointsMax,
    'in_optional': inOptional,
    'buy_price_change_direction': buyPriceChangeDirection,
    'sell_price_change_direction': sellPriceChangeDirection,
  };

  /// 深拷贝
  MarketProductModel copyWith({
    double? price,
    double? buy,
    double? sell,
    double? spread,
    double? change,
    double? changePercent,
    double? high,
    double? low,
    List<double>? points,
    String? subTitle,
    bool? isSingleIcon,
    String? icon,
    String? currencyBaseIcon,
    String? currencyProfitIcon,
    double? pointsMin,
    double? pointsMax,
    bool? inOptional,
    String? symbolGroup,
    int? buyPriceChangeDirection,
    int? sellPriceChangeDirection,
    DateTime? lastBuyPriceChangeAt,
    DateTime? lastSellPriceChangeAt,
  }) {
    return MarketProductModel(
      symbol: symbol,
      name: name,
      title: title,
      price: price ?? this.price,
      buy: buy ?? this.buy,
      sell: sell ?? this.sell,
      spread: spread ?? this.spread,
      open: open,
      high: high ?? this.high,
      low: low ?? this.low,
      close: close,
      change: change ?? this.change,
      changePercent: changePercent ?? this.changePercent,
      volume: volume,
      turnover: turnover,
      precision: precision,
      points: points ?? this.points,
      subTitle: subTitle ?? this.subTitle,
      isSingleIcon: isSingleIcon ?? this.isSingleIcon,
      icon: icon ?? this.icon,
      currencyBaseIcon: currencyBaseIcon ?? this.currencyBaseIcon,
      currencyProfitIcon: currencyProfitIcon ?? this.currencyProfitIcon,
      pointsMin: pointsMin ?? this.pointsMin,
      pointsMax: pointsMax ?? this.pointsMax,
      inOptional: inOptional ?? this.inOptional,
      symbolGroup: symbolGroup ?? this.symbolGroup,
      buyPriceChangeDirection:
          buyPriceChangeDirection ?? this.buyPriceChangeDirection,
      sellPriceChangeDirection:
          sellPriceChangeDirection ?? this.sellPriceChangeDirection,
      lastBuyPriceChangeAt: lastBuyPriceChangeAt ?? this.lastBuyPriceChangeAt,
      lastSellPriceChangeAt:
          lastSellPriceChangeAt ?? this.lastSellPriceChangeAt,
    );
  }

  /// 分类/自选等「仅报价」合并进列表时，保留已有 icon / 副标题（对齐 iOS 不全量覆盖展示字段）
  MarketProductModel withCoalescedPresentationFrom(MarketProductModel ref) {
    String? c(String? primary, String? fallback) {
      final x = primary?.trim();
      if (x != null && x.isNotEmpty) return x;
      final y = fallback?.trim();
      if (y != null && y.isNotEmpty) return y;
      return null;
    }

    final incomingHasIcons =
        (icon?.trim().isNotEmpty == true) ||
        (currencyBaseIcon?.trim().isNotEmpty == true) ||
        (currencyProfitIcon?.trim().isNotEmpty == true);
    return copyWith(
      icon: c(icon, ref.icon),
      currencyBaseIcon: c(currencyBaseIcon, ref.currencyBaseIcon),
      currencyProfitIcon: c(currencyProfitIcon, ref.currencyProfitIcon),
      subTitle: c(subTitle, ref.subTitle),
      isSingleIcon: incomingHasIcons ? isSingleIcon : ref.isSingleIcon,
    );
  }
}

/// iOS `CategoryMarketModel` / `STMarketProductModel`：`is_single_icon` 多键；
/// 缺省时若 base 与 profit 图标 URL 均存在且不同则按双币对展示。
bool _jsonIsSingleIconFlag(Map<String, dynamic> json) {
  const keys = <String>[
    'is_single_icon',
    'isSingleIcon',
    'single_icon',
    'singleIcon',
  ];
  for (final k in keys) {
    if (json[k] != null) return _parseBool(json[k], defaultValue: true);
  }
  final icon = _jsonOptionalUrl(json, const [
    'icon',
    'Icon',
    'icon_url',
    'iconUrl',
  ]);
  final base = _jsonOptionalUrl(json, const [
    'currency_base_icon',
    'currencyBaseIcon',
    'base_icon',
    'baseIcon',
  ]);
  final profit = _jsonOptionalUrl(json, const [
    'currency_profit_icon',
    'currencyProfitIcon',
    'profit_icon',
    'quote_icon',
  ]);
  if (profit == null || profit.isEmpty) return true;
  final left = (base != null && base.isNotEmpty) ? base : icon;
  if (left == null || left.isEmpty) return true;
  if (left == profit) return true;
  return false;
}

bool _parseBool(dynamic raw, {required bool defaultValue}) {
  if (raw == null) return defaultValue;
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  if (raw is String) {
    final s = raw.toLowerCase();
    if (s == '1' || s == 'true' || s == 'yes') return true;
    if (s == '0' || s == 'false' || s == 'no') return false;
  }
  return defaultValue;
}

List<double> _parsePointsList(dynamic raw) {
  if (raw is! List<dynamic>) return [];
  final out = <double>[];
  for (final e in raw) {
    if (e is num) {
      out.add(e.toDouble());
    } else if (e is String) {
      final d = num.tryParse(e)?.toDouble();
      if (d != null) out.add(d);
    } else if (e is Map<String, dynamic>) {
      final p = e['price'] ?? e['value'] ?? e['p'] ?? e['close'] ?? e['c'];
      out.add(_jsonToDouble(p));
    }
  }
  return out;
}

/// WebSocket 行情更新模型
/// 对齐 iOS SocketUpdateListModel
class SocketUpdateListModel {
  final String symbol;
  final int timestamp;
  final double price;
  final double buy;
  final double sell;
  final double spread;
  final double change;
  final double changePercent;
  final double high;
  final double low;
  final int volume;
  final List<double>? points;

  SocketUpdateListModel({
    required this.symbol,
    this.timestamp = 0,
    required this.price,
    this.buy = 0,
    this.sell = 0,
    this.spread = 0,
    this.change = 0,
    this.changePercent = 0,
    this.high = 0,
    this.low = 0,
    this.volume = 0,
    this.points,
  });

  factory SocketUpdateListModel.fromJson(Map<String, dynamic> json) {
    List<double>? pts;
    final rawPts = json['points'];
    if (rawPts is List<dynamic>) {
      pts = <double>[];
      for (final e in rawPts) {
        if (e is num) {
          pts.add(e.toDouble());
        } else if (e is String) {
          final d = num.tryParse(e)?.toDouble();
          if (d != null) pts.add(d);
        } else if (e is Map) {
          final m = Map<String, dynamic>.from(e);
          final v = m['price'] ?? m['value'] ?? m['p'] ?? m['close'] ?? m['c'];
          if (v != null) pts.add(_jsonToDouble(v));
        }
      }
    }
    return SocketUpdateListModel(
      symbol: json['symbol'] as String? ?? '',
      timestamp: _jsonToInt(json['timestamp']),
      price: _jsonToDouble(json['price'], _jsonToDouble(json['last_price'])),
      buy: _jsonToDouble(json['buy'], _jsonToDouble(json['ask'])),
      sell: _jsonToDouble(json['sell'], _jsonToDouble(json['bid'])),
      spread: _jsonToDouble(json['spread']),
      change: _jsonToDouble(json['change']),
      changePercent: _jsonChangePercent(json),
      high: _jsonToDouble(json['high']),
      low: _jsonToDouble(json['low']),
      volume: _jsonToInt(json['volume']),
      points: pts,
    );
  }
}

/// WebSocket 行情消息
class MarketWSMessage {
  final String type;
  final Map<String, dynamic> data;
  final Map<String, dynamic> raw;

  MarketWSMessage({required this.type, required this.data, required this.raw});

  /// 与服务端 / iOS `STMarketSocket` 下行帧对齐：`type` + 负载在 `data` 或 `message`（与客户端上行一致）
  factory MarketWSMessage.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    Map<String, dynamic> payload;
    final dataField = json['data'];
    final messageField = json['message'];
    if (dataField is Map<String, dynamic>) {
      payload = Map<String, dynamic>.from(dataField);
    } else if (dataField is List<dynamic>) {
      payload = {'data': dataField};
    } else if (messageField is Map<String, dynamic>) {
      payload = Map<String, dynamic>.from(messageField);
    } else {
      payload = Map<String, dynamic>.from(json);
    }
    return MarketWSMessage(type: type, data: payload, raw: json);
  }
}

/// 自选行情产品模型（含买卖价）
class SelfMarketProductModel {
  final String symbol;
  final String name;
  double price;
  double buy;
  double sell;
  double spread;
  double change;
  double changePercent;
  int precision;
  bool inOptional;
  List<double> points;

  final String? subTitle;
  final bool isSingleIcon;
  final String? icon;
  final String? currencyBaseIcon;
  final String? currencyProfitIcon;

  /// 品种分组（对齐 iOS `symbol_group`）
  final String? symbolGroup;

  int get riseAndFall {
    if (change > 0) return 1;
    if (change < 0) return -1;
    return 0;
  }

  SelfMarketProductModel({
    required this.symbol,
    required this.name,
    this.price = 0,
    this.buy = 0,
    this.sell = 0,
    this.spread = 0,
    this.change = 0,
    this.changePercent = 0,
    this.precision = 2,
    this.inOptional = false,
    List<double>? points,
    this.subTitle,
    this.isSingleIcon = true,
    this.icon,
    this.currencyBaseIcon,
    this.currencyProfitIcon,
    this.symbolGroup,
  }) : points = points ?? [];

  factory SelfMarketProductModel.fromJson(Map<String, dynamic> json) {
    final change = _jsonToDouble(json['change']);
    final lastPrice = _jsonToDouble(
      json['last_price'],
      _jsonToDouble(json['close'], _jsonToDouble(json['price'])),
    );
    final inOpt = json['in_optional'];
    final inOptional = inOpt is bool ? inOpt : _jsonToInt(inOpt) != 0;
    final singleIcon = _jsonIsSingleIconFlag(json);
    return SelfMarketProductModel(
      symbol: json['symbol'] as String? ?? json['title'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: lastPrice,
      buy: _jsonToDouble(json['buy'], _jsonToDouble(json['ask'])),
      sell: _jsonToDouble(json['sell'], _jsonToDouble(json['bid'])),
      spread: _jsonToDouble(json['spread']),
      change: change,
      changePercent: _jsonChangePercent(json),
      precision: _jsonToInt(json['precision'], _jsonToInt(json['digits'], 2)),
      inOptional: inOptional,
      points: _parsePointsList(json['points']),
      subTitle:
          json['sub_title'] as String? ??
          json['subTitle'] as String? ??
          json['alias'] as String?,
      isSingleIcon: singleIcon,
      icon: _jsonOptionalUrl(json, const [
        'icon',
        'Icon',
        'icon_url',
        'iconUrl',
        'symbol_icon',
        'currency_icon',
        'logo',
        'img',
      ]),
      currencyBaseIcon: _jsonOptionalUrl(json, const [
        'currency_base_icon',
        'currencyBaseIcon',
        'base_icon',
        'baseIcon',
        'base_currency_icon',
      ]),
      currencyProfitIcon: _jsonOptionalUrl(json, const [
        'currency_profit_icon',
        'currencyProfitIcon',
        'profit_icon',
        'quote_icon',
        'profitIcon',
      ]),
      symbolGroup:
          json['symbol_group'] as String? ?? json['symbolGroup'] as String?,
    );
  }
}

/// 分类行情产品模型（含 sparkline）
///
/// 字段语义对齐 iOS `CategoryMarketModel` / 列表行绑定的 `STMarketProductModel`：
/// `is_single_icon`、`icon`、`currency_base_icon`、`currency_profit_icon`、走势点列等。
class CategoryMarketProductModel {
  final String symbol;
  final String name;
  double price;
  double buy;
  double sell;
  double spread;
  double change;
  double changePercent;
  int precision;
  List<double> sparklinePrices;

  final String? subTitle;
  final bool isSingleIcon;
  final String? icon;
  final String? currencyBaseIcon;
  final String? currencyProfitIcon;
  final String? displayPrice;
  final String? displayChangePercent;

  int get riseAndFall {
    if (change > 0) return 1;
    if (change < 0) return -1;
    return 0;
  }

  CategoryMarketProductModel({
    required this.symbol,
    required this.name,
    this.price = 0,
    this.buy = 0,
    this.sell = 0,
    this.spread = 0,
    this.change = 0,
    this.changePercent = 0,
    this.precision = 2,
    List<double>? sparklinePrices,
    this.subTitle,
    this.isSingleIcon = true,
    this.icon,
    this.currencyBaseIcon,
    this.currencyProfitIcon,
    this.displayPrice,
    this.displayChangePercent,
  }) : sparklinePrices = sparklinePrices ?? [];

  factory CategoryMarketProductModel.fromJson(Map<String, dynamic> json) {
    List<dynamic>? pts =
        (json['sparkline_prices'] as List<dynamic>?) ??
        (json['points'] as List<dynamic>?) ??
        (json['sparklinePrices'] as List<dynamic>?) ??
        (json['trend_points'] as List<dynamic>?) ??
        (json['trend'] as List<dynamic>?) ??
        (json['spark_line'] as List<dynamic>?) ??
        (json['mini_chart'] as List<dynamic>?);
    if ((pts == null || pts.isEmpty) && json['sparkline'] != null) {
      final sp = json['sparkline'];
      if (sp is List<dynamic>) pts = sp;
    }
    final spark = <double>[];
    if (pts != null) {
      for (final e in pts) {
        if (e is num) {
          spark.add(e.toDouble());
        } else if (e is String) {
          final d = num.tryParse(e)?.toDouble();
          if (d != null) spark.add(d);
        } else if (e is Map) {
          final m = Map<String, dynamic>.from(e);
          final v =
              m['price'] ??
              m['value'] ??
              m['p'] ??
              m['close'] ??
              m['c'] ??
              m['y'];
          if (v != null) spark.add(_jsonToDouble(v));
        }
      }
    }
    final singleIcon = _jsonIsSingleIconFlag(json);
    return CategoryMarketProductModel(
      symbol: json['symbol'] as String? ?? json['title'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: _jsonToDouble(
        json['last_price'],
        _jsonToDouble(json['close'], _jsonToDouble(json['price'])),
      ),
      buy: _jsonToDouble(json['buy'], _jsonToDouble(json['ask'])),
      sell: _jsonToDouble(json['sell'], _jsonToDouble(json['bid'])),
      spread: _jsonToDouble(json['spread']),
      change: _jsonToDouble(json['change']),
      changePercent: _jsonChangePercent(json),
      precision: _jsonToInt(json['precision'], _jsonToInt(json['digits'], 2)),
      sparklinePrices: spark,
      subTitle:
          json['sub_title'] as String? ??
          json['subTitle'] as String? ??
          json['alias'] as String?,
      isSingleIcon: singleIcon,
      icon: _jsonOptionalUrl(json, const [
        'icon',
        'Icon',
        'icon_url',
        'iconUrl',
        'symbol_icon',
        'currency_icon',
        'logo',
        'img',
      ]),
      currencyBaseIcon: _jsonOptionalUrl(json, const [
        'currency_base_icon',
        'currencyBaseIcon',
        'base_icon',
        'baseIcon',
        'base_currency_icon',
      ]),
      currencyProfitIcon: _jsonOptionalUrl(json, const [
        'currency_profit_icon',
        'currencyProfitIcon',
        'profit_icon',
        'quote_icon',
        'profitIcon',
      ]),
      displayPrice: _jsonOptionalDisplayString(json, const [
        'display_price',
        'displayPrice',
        'last_price',
        'lastPrice',
        'close',
        'price',
      ]),
      displayChangePercent: _jsonOptionalDisplayString(json, const [
        'zdfString',
        'zdf_string',
        'display_change_percent',
        'displayChangePercent',
        'change_percent_text',
        'changePercentText',
      ]),
    );
  }
}
