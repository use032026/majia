import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/models/user_state.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/network/st_service.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../core/utils/timezone_util.dart';

/// 合约规格（对齐 iOS `合约规格` 列表页）
///
/// 数据来自 `get_symbol_detail`，兼容多层嵌套（symbol_info / contract_spec / MT5 字段）及蛇形、驼峰命名。
class ContractSpecificationsPage extends ConsumerStatefulWidget {
  const ContractSpecificationsPage({
    super.key,
    required this.symbol,
    this.initialData,
  });

  final String symbol;
  final Map<String, dynamic>? initialData;

  static const _fallbackText = {
    'contract_attributes': '合约规格',
    'product_name': '产品名称',
    'contract_unit': '合约单位 (每手)',
    'base_currency': '基础货币',
    'revenue_currency': '报价货币',
    'quotation_decimal_places': '报价小数位',
    'single_transaction_volume': '单笔交易手数',
    'minimum_hanging_distance': '最小挂单距离',
    'hand_count_difference': '手数步进',
    'initial_margin': '初始保证金 (层级)',
    'holiday_deposit': '假日保证金 (层级)',
    'lock_up_margin': '锁仓保证金',
    'overnight_interest': '隔夜利息(买/卖)',
    'trading_hours': '交易时间',
    'settlement_time': '结算时间',
    'contract_expiration_date': '合约到期日',
    'margin_level_num': r'最低 %1$s 美元/手',
    'margin_lock_num': r'锁仓订单保证金总和的 %1$s%%',
    'no_data': '暂无数据',
    'dkplayer_retry': '重试',
    'monday': '周一',
    'tuesday': '周二',
    'wednesday': '周三',
    'thursday': '周四',
    'friday': '周五',
    'saturday': '周六',
    'sunday': '周日',
  };

  @override
  ConsumerState<ContractSpecificationsPage> createState() =>
      _ContractSpecificationsPageState();
}

class _ContractSpecificationsPageState
    extends ConsumerState<ContractSpecificationsPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};
  Map<String, String> _localizedText = ContractSpecificationsPage._fallbackText;
  String? _localizedLanguageCode;

  static const _nestedMergeKeys = <String>[
    'symbol_info',
    'symbolInfo',
    'quote',
    'Quote',
    'symbol_spec',
    'symbolSpec',
    'contract_spec',
    'contractSpec',
    'symbol_contract',
    'contract_info',
    'contractInfo',
    'specification',
    'mt5_symbol',
    'mt5Symbol',
    'symbol_detail',
    'symbolDetail',
    'detail',
    'market_rule',
    'marketRule',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final initial = widget.initialData;
    if (initial != null && initial.isNotEmpty) {
      final m = Map<String, dynamic>.from(initial);
      _flattenContractNested(m);
      setState(() {
        _data = m;
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await ref
          .read(stServiceProvider)
          .getProductDetail(widget.symbol);
      final m = _unwrapDetailMap(raw);
      if (!mounted) return;
      if (m == null || m.isEmpty) {
        setState(() {
          _loading = false;
          _error = _t('no_data');
        });
        return;
      }
      setState(() {
        _data = m;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = stUserVisibleErrorMessage(e);
      });
    }
  }

  bool _successCode(dynamic code) {
    if (code == null) return true;
    if (code is num) return code == 0 || code == 200;
    if (code is String) {
      final s = code.trim();
      if (s.isEmpty) return true;
      final n = int.tryParse(s);
      if (n != null) return n == 0 || n == 200;
      return s.toLowerCase() == 'ok' || s.toLowerCase() == 'success';
    }
    return true;
  }

  /// 兼容 `{ code, data }`、仅 `data`，或直接扁平的品种字典。
  Map<String, dynamic>? _unwrapDetailMap(Map<String, dynamic> raw) {
    Map<String, dynamic> map;
    final hasCode = raw.containsKey('code');
    final data = raw['data'];

    if (hasCode) {
      if (!_successCode(raw['code'])) return null;
      if (data is Map) {
        map = Map<String, dynamic>.from(data);
      } else {
        return null;
      }
    } else if (data is Map) {
      map = Map<String, dynamic>.from(data);
    } else {
      map = Map<String, dynamic>.from(raw);
    }

    _flattenContractNested(map);
    return map;
  }

  /// 拍平嵌套合约字段（与 iOS `symbol_info` + 扩展字典一致）
  void _flattenContractNested(Map<String, dynamic> map) {
    var guard = 0;
    while (guard < 8) {
      guard++;
      var merged = false;
      for (final key in _nestedMergeKeys) {
        final nested = map[key];
        if (nested is Map) {
          final inner = Map<String, dynamic>.from(nested);
          for (final e in inner.entries) {
            if (!map.containsKey(e.key) ||
                map[e.key] == null ||
                (map[e.key] is String &&
                    (map[e.key] as String).trim().isEmpty)) {
              map[e.key] = e.value;
              merged = true;
            }
          }
        }
      }
      if (!merged) break;
    }
  }

  String _pick(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      if (v is num && v != v) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '--';
  }

  String _pickNum(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      if (v is num) {
        if (v is double && (v == v)) {
          final t = v.roundToDouble() == v
              ? v.toInt().toString()
              : v.toString();
          return t;
        }
        return v.toString();
      }
      if (v is String) {
        final s = v.trim();
        if (s.isNotEmpty) return s;
      }
    }
    return '--';
  }

  String _pickIosGNumber(Map<String, dynamic> m, List<String> keys) {
    final raw = _pick(m, keys);
    if (raw == '--') return '--';
    return _formatNumberLike(raw);
  }

  String _lotsRange(Map<String, dynamic> m) {
    final combined = _pick(m, [
      'volume_range',
      'volumeRange',
      'lot_range',
      'lotRange',
      'min_max_volume',
      'min_max_lot',
    ]);
    if (combined != '--' &&
        (combined.contains('-') || combined.contains('～'))) {
      return combined.replaceAll('～', '-');
    }

    final minL = _pick(m, [
      'min_lot',
      'min_volume',
      'volume_min',
      'minLot',
      'MinLot',
      'lot_min',
      'LotMin',
      'min_trade_volume',
    ]);
    final maxL = _pick(m, [
      'max_lot',
      'max_volume',
      'volume_max',
      'maxLot',
      'MaxLot',
      'lot_max',
      'LotMax',
      'max_trade_volume',
    ]);
    if (minL != '--' || maxL != '--') {
      return '${minL == '--' ? '?' : minL} - ${maxL == '--' ? '?' : maxL}';
    }
    return '--';
  }

  String _swapBuySell(Map<String, dynamic> m) {
    final swapObj = m['swap'] ?? m['Swap'];
    if (swapObj is Map) {
      final sm = Map<String, dynamic>.from(swapObj);
      final buy = _pickIosGNumber(sm, [
        'long',
        'swap_long',
        'swapLong',
        'buy',
        'overnight_buy',
      ]);
      final sell = _pickIosGNumber(sm, [
        'short',
        'swap_short',
        'swapShort',
        'sell',
        'overnight_sell',
      ]);
      if (buy != '--' || sell != '--') return '$buy / $sell';
    }

    final buy = _pickIosGNumber(m, [
      'swap_long',
      'swapLong',
      'swap_buy',
      'swapBuy',
      'overnight_buy',
      'overnightBuy',
      'SwapLong',
      'swap_long_points',
    ]);
    final sell = _pickIosGNumber(m, [
      'swap_short',
      'swapShort',
      'swap_sell',
      'swapSell',
      'overnight_sell',
      'overnightSell',
      'SwapShort',
      'swap_short_points',
    ]);
    if (buy == '--' && sell == '--') return '--';
    return '$buy / $sell';
  }

  bool _marginTypeIsFixed(Map<String, dynamic> m) {
    final type = _pick(m, ['margin_type', 'marginType', 'MarginType']);
    return type == '0';
  }

  String _formatNumberLike(String raw) {
    final s = raw.trim();
    if (s.isEmpty || s == '--') return '--';
    final n = double.tryParse(s);
    if (n == null) return s;
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toString();
  }

  String _fixedMarginValue(Map<String, dynamic> m, List<String> keys) {
    final v = _pick(m, keys);
    if (v == '--') return '--';
    return _formatLocalizedTemplate('margin_level_num', _formatNumberLike(v));
  }

  String _hedgedMarginValue(Map<String, dynamic> m) {
    final v = _pick(m, ['margin_hedged', 'marginHedged', 'MarginHedged']);
    if (v == '--') return '';
    return _formatLocalizedTemplate('margin_lock_num', v);
  }

  String _formatTimestampValue(
    Map<String, dynamic> m,
    List<String> keys, {
    required bool dateAndTime,
  }) {
    final raw = _pick(m, keys);
    if (raw == '--') return '--';
    final n = double.tryParse(raw);
    if (n == null || n <= 0) return raw;
    final utc = DateTime.fromMillisecondsSinceEpoch(
      n.toInt() * 1000,
      isUtc: true,
    );
    final dt = TimezoneUtil.dateTimeInSelectedTimeZone(
      utc,
      ref.read(userStateProvider).selectedTimeZone,
    );
    final hms =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    if (!dateAndTime) return hms;
    return '${dt.year.toString().padLeft(4, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} $hms';
  }

  List<({String day, String time})> _tradeRowsFromSinceSunday(dynamic raw) {
    if (raw is String && raw.trim().startsWith('[')) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {}
    }
    if (raw is! List || raw.isEmpty) return [];

    final offsetSeconds =
        TimezoneUtil.parseOffsetMinutes(
          ref.read(userStateProvider).selectedTimeZone,
        ) *
        60;
    final rows = <({int day, String time})>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final im = Map<String, dynamic>.from(item);
      final start = _asInt(im['time_start'] ?? im['timeStart']);
      final end = _asInt(im['time_end'] ?? im['timeEnd']);
      if (start == null || end == null || end <= start) continue;
      var timeStart = start + offsetSeconds;
      var timeEnd = end + offsetSeconds;
      if (timeStart.toString().endsWith('99')) timeStart += 1;
      if (timeEnd.toString().endsWith('99')) timeEnd += 1;
      rows.addAll(_splitTradeRangeLikeIos(timeStart, timeEnd));
    }

    if (rows.isEmpty) return [];

    final nonSunday = <({int day, String time})>[];
    final sundayTimes = <String>[];
    for (final row in rows) {
      if (row.day == 0 || row.day == 7) {
        sundayTimes.add(row.time);
      } else {
        nonSunday.add(row);
      }
    }
    if (sundayTimes.isNotEmpty) {
      nonSunday.insert(0, (
        day: 0,
        time: _mergeTimeRanges(sundayTimes.join(',')),
      ));
    }

    final result = <({int day, String time})>[];
    for (final row in nonSunday) {
      final index = result.indexWhere((e) => e.day == row.day);
      if (index >= 0) {
        final old = result[index];
        result[index] = (day: old.day, time: '${old.time},${row.time}');
      } else {
        result.add(row);
      }
    }

    return [
      for (final row in result) (day: _weakString(row.day), time: row.time),
    ];
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  List<({int day, String time})> _splitTradeRangeLikeIos(int start, int end) {
    final startDay = start ~/ 86400;
    final endDay = end ~/ 86400;
    final startTime = _secondsOfDayString(start);
    final endTime = _secondsOfDayString(end);
    if (startDay == endDay) {
      return [(day: startDay, time: '$startTime-$endTime')];
    }
    return [
      (day: startDay, time: '$startTime-24:00'),
      (day: endDay, time: '00:00-$endTime'),
    ];
  }

  String _secondsOfDayString(int seconds) {
    final day = seconds ~/ 86400;
    final s = seconds - day * 86400;
    final h = s ~/ 3600;
    final m = (s - h * 3600) ~/ 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String _weakString(int day) {
    const days = {
      0: 'sunday',
      1: 'monday',
      2: 'tuesday',
      3: 'wednesday',
      4: 'thursday',
      5: 'friday',
      6: 'saturday',
      7: 'sunday',
    };
    final key = days[day];
    return key == null ? '' : _t(key);
  }

  String _mergeTimeRanges(String raw) {
    final ranges = <({int start, int end})>[];
    for (final range in raw.split(',')) {
      final parts = range.split('-');
      if (parts.length != 2) continue;
      final start = _timeStringToMinutes(parts[0].trim());
      var end = _timeStringToMinutes(parts[1].trim());
      if (end == 0 && parts[1].trim() == '24:00') end = 24 * 60;
      if (start < end) ranges.add((start: start, end: end));
    }
    if (ranges.isEmpty) return '';
    ranges.sort((a, b) => a.start.compareTo(b.start));

    final merged = <({int start, int end})>[];
    var current = ranges.first;
    for (final next in ranges.skip(1)) {
      if (next.start <= current.end) {
        current = (
          start: current.start,
          end: next.end > current.end ? next.end : current.end,
        );
      } else {
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);
    return merged
        .map(
          (e) =>
              '${_minutesToTimeString(e.start)}-${e.end == 24 * 60 ? '24:00' : _minutesToTimeString(e.end)}',
        )
        .join(',');
  }

  List<String> _tradeTimeSegments(String value) {
    return value
        .split(',')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .map((segment) => segment.replaceAll('-', ' - '))
        .toList(growable: false);
  }

  int _timeStringToMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  String _minutesToTimeString(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  List<({String day, String time})> _tradingHourRows() {
    final m = _data;

    final sinceSunday = _tradeRowsFromSinceSunday(
      m['sessions_trades_since_sunday'] ?? m['sessionsTradesSinceSunday'],
    );
    if (sinceSunday.isNotEmpty) return sinceSunday;

    dynamic sessionsRaw =
        m['trade_sessions'] ?? m['tradeSessions'] ?? m['sessions'];
    if (sessionsRaw is String && sessionsRaw.trim().startsWith('[')) {
      try {
        sessionsRaw = jsonDecode(sessionsRaw);
      } catch (_) {}
    }

    if (sessionsRaw is List && sessionsRaw.isNotEmpty) {
      final out = <({String day, String time, int sort})>[];
      for (final item in sessionsRaw) {
        if (item is Map) {
          final im = Map<String, dynamic>.from(item);
          final day =
              im['day'] ??
              im['weekday'] ??
              im['week_day'] ??
              im['name'] ??
              im['title'];
          final time =
              im['time'] ??
              im['session'] ??
              im['range'] ??
              im['hours'] ??
              im['value'];
          if (day != null && time != null) {
            final label = _cnWeekday(day.toString());
            final sort = _weekdaySortKey(im, label);
            out.add((day: label, time: time.toString().trim(), sort: sort));
          }
        }
      }
      if (out.isNotEmpty) {
        out.sort((a, b) => a.sort.compareTo(b.sort));
        return [for (final e in out) (day: e.day, time: e.time)];
      }
    }

    final schedule =
        m['trade_time_schedule'] ??
        m['tradeTimeSchedule'] ??
        m['quotes_sessions'] ??
        m['trade_hours'];
    if (schedule is String && schedule.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(schedule);
        if (decoded is Map) {
          return _scheduleMapToRows(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }
    if (schedule is Map) {
      return _scheduleMapToRows(Map<String, dynamic>.from(schedule));
    }

    final plain =
        m['trade_time'] ??
        m['tradeTime'] ??
        m['session_desc'] ??
        m['sessions_desc'];
    if (plain != null && plain.toString().trim().isNotEmpty) {
      return [(day: '', time: plain.toString())];
    }

    return [];
  }

  List<({String day, String time})> _scheduleMapToRows(
    Map<String, dynamic> schedule,
  ) {
    final out = <({String day, String time, int sort})>[];
    for (final e in schedule.entries) {
      final label = _cnWeekday(e.key.toString());
      final sort = _weekdaySortKey(null, label);
      final tv = e.value;
      final timeStr = tv == null
          ? '--'
          : (tv is Map ? jsonEncode(tv) : tv.toString().trim());
      out.add((day: label, time: timeStr, sort: sort));
    }
    out.sort((a, b) => a.sort.compareTo(b.sort));
    return [for (final e in out) (day: e.day, time: e.time)];
  }

  /// 周一=0 … 周日=6；未知置后。
  int _weekdaySortKey(Map<String, dynamic>? item, String dayLabel) {
    final wd =
        item?['week_day'] ??
        item?['weekday'] ??
        item?['day_index'] ??
        item?['dow'];
    if (wd is num) {
      var i = wd.toInt();
      if (i >= 1 && i <= 7) {
        i = i - 1;
        return i % 7;
      }
    }
    if (wd is String) {
      final n = int.tryParse(wd);
      if (n != null && n >= 1 && n <= 7) return (n - 1) % 7;
    }

    final order = [
      _t('monday'),
      _t('tuesday'),
      _t('wednesday'),
      _t('thursday'),
      _t('friday'),
      _t('saturday'),
      _t('sunday'),
      '周一',
      '周二',
      '周三',
      '周四',
      '周五',
      '周六',
      '周日',
      '周二 - 周五',
      '星期二',
      '星期三',
      '星期四',
      '星期五',
      '星期六',
      '星期日',
    ];
    final idx = order.indexOf(dayLabel);
    if (idx >= 0) return idx;
    return 100 + dayLabel.hashCode % 1000;
  }

  static const Map<String, String> _weekKeys = {
    'monday': 'monday',
    'mon': 'monday',
    '1': 'monday',
    '周一': 'monday',
    '星期一': 'monday',
    'tuesday': 'tuesday',
    'tue': 'tuesday',
    '2': 'tuesday',
    '周二': 'tuesday',
    '星期二': 'tuesday',
    'wednesday': 'wednesday',
    'wed': 'wednesday',
    '3': 'wednesday',
    '周三': 'wednesday',
    '星期三': 'wednesday',
    'thursday': 'thursday',
    'thu': 'thursday',
    '4': 'thursday',
    '周四': 'thursday',
    '星期四': 'thursday',
    'friday': 'friday',
    'fri': 'friday',
    '5': 'friday',
    '周五': 'friday',
    '星期五': 'friday',
    'saturday': 'saturday',
    'sat': 'saturday',
    '6': 'saturday',
    '周六': 'saturday',
    '星期六': 'saturday',
    'sunday': 'sunday',
    'sun': 'sunday',
    '7': 'sunday',
    '周日': 'sunday',
    '星期日': 'sunday',
  };

  String _cnWeekday(String raw) {
    final t = raw.trim();
    final lower = t.toLowerCase();
    final key = _weekKeys[lower] ?? _weekKeys[t];
    if (key != null) return _t(key);
    if (lower == 'tuesday-friday' ||
        lower == 'tue-fri' ||
        lower == 'tuesday_friday') {
      return '${_t('tuesday')} - ${_t('friday')}';
    }
    return t;
  }

  void _ensureLocalizedText(STLocalizations localizations) {
    final languageCode = localizations.languageCode;
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    _localizedText = ContractSpecificationsPage._fallbackText;
    localizations.textMap(ContractSpecificationsPage._fallbackText).then((
      text,
    ) {
      if (!mounted || _localizedLanguageCode != languageCode) return;
      setState(() {
        _localizedText = text;
        if (_error == ContractSpecificationsPage._fallbackText['no_data']) {
          _error = _t('no_data');
        }
      });
    });
  }

  String _t(String key) =>
      _localizedText[key] ??
      ContractSpecificationsPage._fallbackText[key] ??
      key;

  String _formatLocalizedTemplate(String key, String value) {
    return _t(key)
        .replaceAll('%1\$s', value)
        .replaceAll('%@', value)
        .replaceAll('%s', value)
        .replaceAll('%%', '%');
  }

  Color get _pageBackgroundColor => context.adaptiveIsDark
      ? const Color(0xFF181A1A)
      : const Color(0xFFF6F7F7);

  Color get _sectionCardColor => context.adaptiveIsDark
      ? const Color(0xFF212229)
      : const Color(0xFFFEFFFF);

  Color get _sectionBorderColor => context.adaptiveDivider;

  Color get _normalLabelColor => context.adaptiveIsDark
      ? const Color(0xFFABAFB7)
      : const Color(0xFF60656D);

  Color get _normalValueColor => context.adaptiveTextPrimary;

  Color get _tradeTitleColor => context.adaptiveTextPrimary;

  Color get _tradeSubtitleColor => context.adaptiveTextSecondary;

  Color get _tradeRowBackgroundColor => context.adaptiveIsDark
      ? const Color(0xFF18191A)
      : const Color(0xFFFFFFFF);

  Color get _tradeChipBackgroundColor => context.adaptiveIsDark
      ? const Color(0xFF212329)
      : const Color(0xFFF7F7F7);

  Color get _tradeChipTextColor => const Color(0xFF60656D);

  String _gmtLabel() {
    final minutes = TimezoneUtil.parseOffsetMinutes(
      ref.read(userStateProvider).selectedTimeZone,
    );
    if (minutes == 0) return 'GMT+0';
    final sign = minutes >= 0 ? '+' : '-';
    final absoluteMinutes = minutes.abs();
    final hours = absoluteMinutes ~/ 60;
    final remainMinutes = absoluteMinutes % 60;
    if (remainMinutes == 0) return 'GMT$sign$hours';
    final minuteText = remainMinutes.toString().padLeft(2, '0');
    return 'GMT$sign$hours:$minuteText';
  }

  List<List<String>> _tradeTimeRowsForDisplay(List<String> segments) {
    if (segments.isEmpty) return const [];
    final rows = <List<String>>[];
    for (var index = 0; index < segments.length; index += 2) {
      final end = index + 2 > segments.length ? segments.length : index + 2;
      rows.add(segments.sublist(index, end));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText(stLocalizationsOfContext(context, ref));

    return Scaffold(
      backgroundColor: _pageBackgroundColor,
      appBar: AppBar(
        backgroundColor: _pageBackgroundColor,
        foregroundColor: context.adaptiveTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 44,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: context.adaptiveTextPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _t('contract_attributes'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.adaptiveTextPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: STLoadAnimationView())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _load,
                      child: Text(_t('dkplayer_retry')),
                    ),
                  ],
                ),
              ),
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final m = _data;
    final fixedMargin = _marginTypeIsFixed(m);
    final basicRows = <({String label, String value})>[
      (
        label: _t('product_name'),
        value: _pick(m, [
          'name',
          'symbol',
          'Symbol',
          'title',
          'listing_name',
          'instrument_name',
        ]),
      ),
      (
        label: _t('contract_unit'),
        value: _pickIosGNumber(m, [
          'contract_size',
          'contractSize',
          'volume_contract',
          'trade_contract_size',
          'ContractSize',
          'lot_size',
          'TradeContractSize',
        ]),
      ),
      (
        label: _t('base_currency'),
        value: _pick(m, [
          'currency_base',
          'currencyBase',
          'base_currency',
          'baseCurrency',
          'CurrencyBase',
          'profit_currency_base',
        ]),
      ),
      (
        label: _t('revenue_currency'),
        value: _pick(m, [
          'currency_quote',
          'currencyQuote',
          'currency_profit',
          'currencyProfit',
          'quote_currency',
          'quoteCurrency',
          'CurrencyProfit',
          'ProfitCurrency',
        ]),
      ),
      (
        label: _t('quotation_decimal_places'),
        value: _pickNum(m, [
          'precision',
          'digits',
          'Digits',
          'trade_digits',
          'quote_digits',
          'decimal_places',
        ]),
      ),
      (label: _t('single_transaction_volume'), value: _lotsRange(m)),
      (
        label: _t('minimum_hanging_distance'),
        value: _pickNum(m, [
          'stops_level',
          'stop_level',
          'freeze_level',
          'trade_stops_level',
          'TradeStopsLevel',
          'min_pending_distance',
          'pending_distance',
          'StopsLevel',
          'stop_distance',
        ]),
      ),
      (
        label: _t('hand_count_difference'),
        value: _pick(m, [
          'step_lot',
          'volume_step',
          'lot_step',
          'stepLot',
          'VolumeStep',
          'LotStep',
          'min_volume_step',
        ]),
      ),
      (
        label: _t('initial_margin'),
        value: _fixedMarginValue(m, [
          'margin_initial',
          'marginInitial',
          'MarginInitial',
        ]),
      ),
      if (fixedMargin)
        (
          label: _t('holiday_deposit'),
          value: _fixedMarginValue(m, [
            'margin_maintenance',
            'marginMaintenance',
            'MarginMaintenance',
          ]),
        ),
      if (fixedMargin)
        (label: _t('lock_up_margin'), value: _hedgedMarginValue(m)),
      (label: _t('overnight_interest'), value: _swapBuySell(m)),
    ];
    if (!fixedMargin) {
      basicRows.removeWhere((row) => row.label == _t('initial_margin'));
    }

    final sessions = _tradingHourRows();
    final settlement = _formatTimestampValue(m, [
      'overnight_time',
      'overnightTime',
      'settlement_time',
      'settlementTime',
      'daily_settlement',
      'clearing_time',
      'settlement_time_gmt',
      'daily_close_time',
    ], dateAndTime: false);
    final expiry = _formatTimestampValue(m, [
      'time_expiration',
      'timeExpiration',
      'contract_expiration',
      'contractExpiration',
      'expiration_time',
      'expiry_time',
      'expire_time',
      'contract_expiry',
      'ExpiryTime',
      'expiration',
    ], dateAndTime: true);
    final settlementRows = <({String label, String value})>[
      (label: _t('settlement_time'), value: settlement),
      (label: _t('contract_expiration_date'), value: expiry),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
      children: [
        if (basicRows.isNotEmpty) _normalSection(basicRows),
        _tradeTimeSection(sessions),
        _normalSection(settlementRows),
      ],
    );
  }

  Widget _normalSection(List<({String label, String value})> rows) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _sectionCardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _sectionBorderColor, width: 0.5),
        ),
        child: Column(
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              _kvRow(rows[index].label, rows[index].value),
              if (index != rows.length - 1)
                Divider(
                  height: 0.5,
                  thickness: 0.5,
                  indent: 16,
                  endIndent: 16,
                  color: _sectionBorderColor,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kvRow(String label, String value) {
    final valueTextStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: _normalValueColor,
      height: 1.35,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 150,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _normalLabelColor,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    softWrap: false,
                    style: valueTextStyle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tradeTimeSection(List<({String day, String time})> sessions) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _sectionCardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _sectionBorderColor, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _t('trading_hours'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: _tradeTitleColor,
                      ),
                    ),
                  ),
                  Text(
                    _gmtLabel(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _tradeSubtitleColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (sessions.isEmpty)
                const SizedBox(height: 46)
              else
                Column(
                  children: [
                    for (var index = 0; index < sessions.length; index++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: index == sessions.length - 1 ? 0 : 6,
                        ),
                        child: _tradeTimeRow(
                          day: sessions[index].day,
                          segments: _tradeTimeSegments(sessions[index].time),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tradeTimeRow({required String day, required List<String> segments}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _tradeRowBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _sectionBorderColor, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 22, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 42,
              child: Text(
                day,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _tradeSubtitleColor,
                ),
              ),
            ),
            const SizedBox(width: 26),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final chipRows = _tradeTimeRowsForDisplay(segments);
                  final availableWidth = constraints.maxWidth;
                  final columnWidth = ((availableWidth - 12) / 2).clamp(
                    92.0,
                    double.infinity,
                  );
                  return Column(
                    children: [
                      for (var index = 0; index < chipRows.length; index++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: index == chipRows.length - 1 ? 0 : 4,
                          ),
                          child: Row(
                            children: [
                              _tradeTimeChip(
                                chipRows[index].first,
                                width: columnWidth,
                              ),
                              if (chipRows[index].length > 1) ...[
                                const SizedBox(width: 12),
                                _tradeTimeChip(
                                  chipRows[index][1],
                                  width: columnWidth,
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tradeTimeChip(String text, {double? width}) {
    final child = DecoratedBox(
      decoration: BoxDecoration(
        color: _tradeChipBackgroundColor,
        borderRadius: BorderRadius.circular(13),
      ),
      child: SizedBox(
        height: 26,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _tradeChipTextColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (width == null) return child;
    return SizedBox(width: width, child: child);
  }
}
