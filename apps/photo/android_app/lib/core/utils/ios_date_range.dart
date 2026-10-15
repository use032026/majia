import 'timezone_util.dart';
import 'package:intl/intl.dart';

class IosDateRange {
  const IosDateRange({this.start, this.end});

  final int? start;
  final int? end;
}

DateTime iosCalendarDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime iosInclusiveStartDay(int days, {DateTime? now}) {
  final today = iosCalendarDay(now ?? DateTime.now());
  return today.subtract(Duration(days: days - 1));
}

int iosStartOfDaySeconds(DateTime date, {String? timezone}) =>
    _secondsForSelectedTimezoneDay(date, timezone: timezone);

int iosEndExclusiveSeconds(DateTime date, {String? timezone}) =>
    _secondsForSelectedTimezoneDay(
      iosCalendarDay(date).add(const Duration(days: 1)),
      timezone: timezone,
    );

int iosEndOfDaySeconds(DateTime date, {String? timezone}) =>
    iosEndExclusiveSeconds(date, timezone: timezone) - 1;

IosDateRange iosQuickRange(int index, {DateTime? now, String? timezone}) {
  final today = iosCalendarDay(now ?? _nowInSelectedTimezone(timezone));
  return switch (index) {
    1 => IosDateRange(
      start: iosStartOfDaySeconds(today, timezone: timezone),
      end: iosEndOfDaySeconds(today, timezone: timezone),
    ),
    2 => IosDateRange(
      start: iosStartOfDaySeconds(
        iosInclusiveStartDay(7, now: today),
        timezone: timezone,
      ),
      end: iosEndOfDaySeconds(today, timezone: timezone),
    ),
    3 => IosDateRange(
      start: iosStartOfDaySeconds(
        iosInclusiveStartDay(30, now: today),
        timezone: timezone,
      ),
      end: iosEndOfDaySeconds(today, timezone: timezone),
    ),
    _ => const IosDateRange(),
  };
}

DateTime _nowInSelectedTimezone(String? timezone) {
  if (timezone == null || timezone.trim().isEmpty) return DateTime.now();
  return TimezoneUtil.dateTimeInSelectedTimeZone(
    DateTime.now().toUtc(),
    timezone,
  );
}

int _secondsForSelectedTimezoneDay(DateTime date, {String? timezone}) {
  final day = iosCalendarDay(date);
  if (timezone == null || timezone.trim().isEmpty) {
    return day.millisecondsSinceEpoch ~/ 1000;
  }
  return TimezoneUtil.utcForIosLocalTime(
        day,
        timezone,
      ).millisecondsSinceEpoch ~/
      1000;
}

String iosYmdPattern(String? languageCode) =>
    languageCode == 'zh-Hans' ? 'yyyy/MM/dd' : 'dd/MM/yyyy';

String iosYmdHmPattern(String? languageCode) =>
    languageCode == 'zh-Hans' ? 'yyyy/MM/dd HH:mm' : 'dd/MM/yyyy HH:mm';

String iosYmdHmsPattern(String? languageCode) =>
    languageCode == 'zh-Hans' ? 'yyyy/MM/dd HH:mm:ss' : 'dd/MM/yyyy HH:mm:ss';

String formatIosYmd(DateTime date, {String? languageCode}) =>
    DateFormat(iosYmdPattern(languageCode)).format(date);

String formatIosYmdHm(DateTime date, {String? languageCode}) =>
    DateFormat(iosYmdHmPattern(languageCode)).format(date);

String formatIosYmdHms(DateTime date, {String? languageCode}) =>
    DateFormat(iosYmdHmsPattern(languageCode)).format(date);
