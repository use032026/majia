import 'dart:convert';

import 'timezone_util.dart';

class IosTradeTimeRow {
  const IosTradeTimeRow({required this.day, required this.value});

  /// iOS `STMarketManager weakStringWithWeakNumber:` convention:
  /// Sunday is 0 or 7, Monday is 1.
  final int day;
  final String value;
}

bool iosHasTradeSessionsSinceSunday(dynamic raw) {
  final decoded = _decodeSessions(raw);
  return decoded is List;
}

bool iosIsInTradeTimeFromSinceSunday(
  dynamic raw, {
  required String selectedTimeZone,
  DateTime? nowUtc,
}) {
  final rows = iosTradeTimeRowsFromSinceSunday(
    raw,
    selectedTimeZone: selectedTimeZone,
  );
  if (rows.isEmpty) return false;

  final now = TimezoneUtil.dateTimeInSelectedTimeZone(
    nowUtc ?? DateTime.now().toUtc(),
    selectedTimeZone,
  );
  final currentDay = now.weekday == DateTime.sunday ? 0 : now.weekday;
  final currentMinutes = now.hour * 60 + now.minute;

  for (final row in rows) {
    if (row.day != currentDay) continue;
    if (_isCurrentMinuteInRange(row.value, currentMinutes)) return true;
  }
  return false;
}

List<IosTradeTimeRow> iosTradeTimeRowsFromSinceSunday(
  dynamic raw, {
  required String selectedTimeZone,
}) {
  final decoded = _decodeSessions(raw);
  if (decoded is! List || decoded.isEmpty) return const [];

  final offsetSeconds = TimezoneUtil.parseOffsetMinutes(selectedTimeZone) * 60;
  final rows = <({int day, String time})>[];
  for (final item in decoded) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    final start = _asInt(map['time_start'] ?? map['timeStart']);
    final end = _asInt(map['time_end'] ?? map['timeEnd']);
    if (start == null || end == null || end <= start) continue;

    var timeStart = start + offsetSeconds;
    var timeEnd = end + offsetSeconds;
    if (timeStart.toString().endsWith('99')) timeStart += 1;
    if (timeEnd.toString().endsWith('99')) timeEnd += 1;
    rows.addAll(_splitTradeRangeLikeIos(timeStart, timeEnd));
  }
  if (rows.isEmpty) return const [];

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
    for (final row in result) IosTradeTimeRow(day: row.day, value: row.time),
  ];
}

dynamic _decodeSessions(dynamic raw) {
  if (raw is String) {
    final text = raw.trim();
    if (text.startsWith('[')) {
      try {
        return jsonDecode(text);
      } catch (_) {
        return raw;
      }
    }
  }
  return raw;
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

bool _isCurrentMinuteInRange(String value, int currentMinutes) {
  for (final segment in value.split(',')) {
    final parts = segment.trim().split('-');
    if (parts.length != 2) continue;
    final start = _timeStringToMinutes(parts[0].trim());
    var end = _timeStringToMinutes(parts[1].trim());
    if (parts[1].trim() == '24:00') end = 24 * 60 - 1;
    if (start <= end) {
      if (currentMinutes >= start && currentMinutes <= end) return true;
    } else if (currentMinutes >= start || currentMinutes <= end) {
      return true;
    }
  }
  return false;
}

String _mergeTimeRanges(String raw) {
  final ranges = <({int start, int end})>[];
  for (final segment in raw.split(',')) {
    final parts = segment.split('-');
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
        (range) =>
            '${_minutesToTimeString(range.start)}-${range.end == 24 * 60 ? '24:00' : _minutesToTimeString(range.end)}',
      )
      .join(',');
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
