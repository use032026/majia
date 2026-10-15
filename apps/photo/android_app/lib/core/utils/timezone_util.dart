/// 时区工具
/// 对齐 iOS: 用户偏好设置中的时区选择
///
/// 将 UTC 偏移字符串（如 "UTC+8", "UTC-5"）解析为分钟偏移
/// 用于格式化时间戳时转换到用户所选时区
class TimezoneUtil {
  /// 对齐 iOS `STUserInfoManger.timeZone` 未设置时的默认值：
  /// 取系统 GMT 整小时偏移，并裁剪到 -12...+12。
  static String currentSystemIosUtcOffsetLabel() {
    final offset = DateTime.now().timeZoneOffset;
    final hour = offset.inSeconds ~/ Duration.secondsPerHour;
    return iosUtcCodeFromHourOffset(hour.clamp(-12, 12));
  }

  /// 从 UTC 偏移字符串解析时区偏移（分钟）
  /// - "UTC" → 0
  /// - "UTC+8" → 480
  /// - "UTC-5" → -300
  /// - "UTC+05:30" → 330
  static int parseOffsetMinutes(String timezone) {
    if (timezone == 'UTC' || timezone.isEmpty) return 0;

    // 去掉 "UTC" 前缀
    String offset = timezone.replaceAll('UTC', '').trim();
    if (offset.isEmpty) return 0;

    // 解析 +/- 符号
    int sign = 1;
    if (offset.startsWith('+')) {
      sign = 1;
      offset = offset.substring(1);
    } else if (offset.startsWith('-')) {
      sign = -1;
      offset = offset.substring(1);
    }

    // 解析小时:分钟或纯小时
    final parts = offset.split(':');
    int hours = 0;
    int minutes = 0;

    try {
      hours = int.parse(parts[0]);
      if (parts.length > 1) {
        minutes = int.parse(parts[1]);
      }
    } catch (_) {
      return 0;
    }

    return sign * (hours * 60 + minutes);
  }

  /// iOS `STUserInfoManger.selectedTimeZone` does not use a plain GMT offset
  /// for every row. It maps each saved hour offset to a concrete NSTimeZone
  /// name (for example UTC-05:00 -> America/New_York), so daylight saving must
  /// be applied when formatting timestamps or building calendar-day filters.
  static int iosSelectedOffsetMinutesAt(String timezone, DateTime utcTime) {
    final hour = _iosHourOffset(timezone);
    if (hour == null) return parseOffsetMinutes(timezone);
    final utc = utcTime.isUtc ? utcTime : utcTime.toUtc();

    return switch (hour) {
      -12 => -12 * 60, // Etc/GMT+12
      -11 => -11 * 60, // Pacific/Midway
      -10 => -10 * 60, // Pacific/Honolulu
      -9 => _northAmericaDstOffset(utc, standardHour: -9), // Anchorage
      -8 => _northAmericaDstOffset(utc, standardHour: -8), // Los Angeles
      -7 => _northAmericaDstOffset(utc, standardHour: -7), // Denver
      -6 => _northAmericaDstOffset(utc, standardHour: -6), // Chicago
      -5 => _northAmericaDstOffset(utc, standardHour: -5), // New York
      -4 => _northAmericaDstOffset(utc, standardHour: -4), // Halifax
      -3 => -3 * 60, // Buenos Aires
      -2 => _europeDstOffset(utc, standardHour: -2), // Godthab/Nuuk
      -1 => _europeDstOffset(utc, standardHour: -1), // Azores
      0 => 0,
      1 => _europeDstOffset(utc, standardHour: 1), // Paris
      2 => _europeDstOffset(utc, standardHour: 2), // Helsinki
      3 => 3 * 60, // Moscow
      4 => 4 * 60, // Dubai
      5 => 5 * 60, // Karachi
      6 => 6 * 60, // Dhaka
      7 => 7 * 60, // Bangkok
      8 => 8 * 60, // Shanghai
      9 => 9 * 60, // Tokyo
      10 => _sydneyOffset(utc),
      11 => 11 * 60, // Guadalcanal
      12 => _aucklandOffset(utc),
      _ => hour * 60,
    };
  }

  static DateTime dateTimeInSelectedTimeZone(
    DateTime utcTime,
    String timezone,
  ) {
    final utc = utcTime.isUtc ? utcTime : utcTime.toUtc();
    return utc.add(
      Duration(minutes: iosSelectedOffsetMinutesAt(timezone, utc)),
    );
  }

  static DateTime utcForIosLocalTime(DateTime localTime, String timezone) {
    final localUtcShape = DateTime.utc(
      localTime.year,
      localTime.month,
      localTime.day,
      localTime.hour,
      localTime.minute,
      localTime.second,
      localTime.millisecond,
      localTime.microsecond,
    );
    var offset = parseOffsetMinutes(timezone);
    var utc = localUtcShape.subtract(Duration(minutes: offset));
    for (var i = 0; i < 4; i++) {
      final nextOffset = iosSelectedOffsetMinutesAt(timezone, utc);
      final nextUtc = localUtcShape.subtract(Duration(minutes: nextOffset));
      if (nextUtc == utc) return utc;
      utc = nextUtc;
    }
    return utc;
  }

  /// 将时间戳（秒）转换为用户所选时区的时间字符串
  /// format: "MM/dd HH:mm"
  static String formatTimestamp(int timestampSec, String timezone) {
    if (timestampSec <= 0) return '';

    final utcTime = DateTime.fromMillisecondsSinceEpoch(
      timestampSec * 1000,
      isUtc: true,
    );
    final localTime = dateTimeInSelectedTimeZone(utcTime, timezone);

    return '${localTime.month.toString().padLeft(2, '0')}/${localTime.day.toString().padLeft(2, '0')} '
        '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
  }

  /// 转成与 iOS `STUserInfoManger.timeZoneShow` 一致的 `UTC±HH:00`（整小时偏移）。
  /// 非整小时或无法解析则返回原始字符串。
  static String toIosUtcOffsetLabel(String timezone) {
    final t = timezone.trim();
    if (t.isEmpty) return timezone;
    final m = parseOffsetMinutes(t);
    final h = m ~/ 60;
    if (m % 60 != 0) return t;

    final absStr = h.abs().toString().padLeft(2, '0');
    if (h == 0) return 'UTC+00:00';
    return h > 0 ? 'UTC+$absStr:00' : 'UTC-$absStr:00';
  }

  /// 与原生 `[STUserInfoManger saveTimeZone:]` / `STUserTimeZone` 整点偏移一致。
  static String iosUtcCodeFromHourOffset(int hourOffset) {
    final absStr = hourOffset.abs().toString().padLeft(2, '0');
    if (hourOffset == 0) return 'UTC+00:00';
    return hourOffset > 0 ? 'UTC+$absStr:00' : 'UTC-$absStr:00';
  }

  /// 次要说明行，括号形式 GMT（与 Flutter 原先副标题样式一致）。
  static String gmtSubtitleForHourOffset(int hourOffset) {
    if (hourOffset == 0) return '(GMT±0:00)';
    final sign = hourOffset > 0 ? '+' : '-';
    final hh = hourOffset.abs().toString().padLeft(2, '0');
    return '(GMT$sign$hh:00)';
  }

  /// 列表选中等价判断（兼容 `UTC`、`UTC+8`、`UTC+08:00`）
  static bool utcOffsetsEquivalent(String a, String b) {
    if (a.trim() == b.trim()) return true;
    return parseOffsetMinutes(a) == parseOffsetMinutes(b);
  }

  static int? _iosHourOffset(String timezone) {
    final minutes = parseOffsetMinutes(timezone);
    if (minutes % 60 != 0) return null;
    final hour = minutes ~/ 60;
    if (hour < -12 || hour > 12) return null;
    return hour;
  }

  static int _northAmericaDstOffset(DateTime utc, {required int standardHour}) {
    final start = _nthWeekdayLocalAsUtc(
      utc.year,
      DateTime.march,
      DateTime.sunday,
      2,
      2,
      standardHour * 60,
    );
    final end = _nthWeekdayLocalAsUtc(
      utc.year,
      DateTime.november,
      DateTime.sunday,
      1,
      2,
      (standardHour + 1) * 60,
    );
    return (utc.compareTo(start) >= 0 && utc.compareTo(end) < 0
            ? standardHour + 1
            : standardHour) *
        60;
  }

  static int _europeDstOffset(DateTime utc, {required int standardHour}) {
    final start = DateTime.utc(
      utc.year,
      DateTime.march,
      _lastWeekdayDay(utc.year, DateTime.march, DateTime.sunday),
      1,
    );
    final end = DateTime.utc(
      utc.year,
      DateTime.october,
      _lastWeekdayDay(utc.year, DateTime.october, DateTime.sunday),
      1,
    );
    return (utc.compareTo(start) >= 0 && utc.compareTo(end) < 0
            ? standardHour + 1
            : standardHour) *
        60;
  }

  static int _sydneyOffset(DateTime utc) {
    const standardHour = 10;
    final start = _nthWeekdayLocalAsUtc(
      utc.year,
      DateTime.october,
      DateTime.sunday,
      1,
      2,
      standardHour * 60,
    );
    final end = _nthWeekdayLocalAsUtc(
      utc.year,
      DateTime.april,
      DateTime.sunday,
      1,
      3,
      (standardHour + 1) * 60,
    );
    return (utc.compareTo(start) >= 0 || utc.compareTo(end) < 0 ? 11 : 10) * 60;
  }

  static int _aucklandOffset(DateTime utc) {
    const standardHour = 12;
    final start = _lastWeekdayLocalAsUtc(
      utc.year,
      DateTime.september,
      DateTime.sunday,
      2,
      standardHour * 60,
    );
    final end = _nthWeekdayLocalAsUtc(
      utc.year,
      DateTime.april,
      DateTime.sunday,
      1,
      3,
      (standardHour + 1) * 60,
    );
    return (utc.compareTo(start) >= 0 || utc.compareTo(end) < 0 ? 13 : 12) * 60;
  }

  static DateTime _nthWeekdayLocalAsUtc(
    int year,
    int month,
    int weekday,
    int nth,
    int localHour,
    int offsetBeforeMinutes,
  ) {
    final day = _nthWeekdayDay(year, month, weekday, nth);
    return DateTime.utc(
      year,
      month,
      day,
      localHour,
    ).subtract(Duration(minutes: offsetBeforeMinutes));
  }

  static DateTime _lastWeekdayLocalAsUtc(
    int year,
    int month,
    int weekday,
    int localHour,
    int offsetBeforeMinutes,
  ) {
    final day = _lastWeekdayDay(year, month, weekday);
    return DateTime.utc(
      year,
      month,
      day,
      localHour,
    ).subtract(Duration(minutes: offsetBeforeMinutes));
  }

  static int _nthWeekdayDay(int year, int month, int weekday, int nth) {
    final first = DateTime.utc(year, month);
    final delta = (weekday - first.weekday) % DateTime.daysPerWeek;
    return 1 + delta + (nth - 1) * DateTime.daysPerWeek;
  }

  static int _lastWeekdayDay(int year, int month, int weekday) {
    final last = DateTime.utc(year, month + 1, 0);
    final delta = (last.weekday - weekday) % DateTime.daysPerWeek;
    return last.day - delta;
  }
}
