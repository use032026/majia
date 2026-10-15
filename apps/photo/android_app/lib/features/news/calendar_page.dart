import 'package:flutter/material.dart';
import 'package:jufu/shared/widgets/st_pull_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jufu/shared/widgets/st_localized_prompt.dart';

import '../../core/network/st_dio.dart';
import '../../core/network/st_service.dart';
import '../../core/theme/context_adaptive_colors.dart';

/// 财经日历（复合 Tab 子路由 `/calendar`）
/// 对齐 iOS `STCalendarViewController` + `STCalendarViewCell`：周历切换、按日请求列表、星级与前值/预测/公布。
class CalendarPage extends ConsumerStatefulWidget {
  final String? title;

  const CalendarPage({super.key, this.title});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarRow {
  _CalendarRow(this.raw);
  final Map<String, dynamic> raw;

  int get id => (raw['id'] as num?)?.toInt() ?? 0;
  int get createdAtSec => (raw['created_at'] as num?)?.toInt() ?? 0;
  String get data => raw['data']?.toString() ?? '';
  String get affect => raw['affect']?.toString() ?? '';
  String get front => raw['front']?.toString() ?? '';
  String get due => raw['due']?.toString() ?? '';
  String get publish => raw['publish']?.toString() ?? '';
  int get weight => (raw['weight'] as num?)?.toInt() ?? 0;
  String get interpretation => raw['interpretation']?.toString() ?? '';
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  static const int _limit = 20;

  late DateTime _selectedDay;
  _CalendarPickerMode _pickerMode = _CalendarPickerMode.week;
  bool _hasExplicitDaySelection = false;

  final ScrollController _scrollController = ScrollController();

  final List<_CalendarRow> _items = [];
  int _page = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reloadDay(reset: true),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  String _lang() => ref.read(stDioProvider).currentLanguage;

  int _dayStartSec(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    return local.millisecondsSinceEpoch ~/ 1000;
  }

  int _requestDaySec() {
    if (!_hasExplicitDaySelection) {
      return 0;
    }
    return _dayStartSec(_selectedDay);
  }

  Future<void> _reloadDay({
    bool reset = false,
    bool clearBeforeRequest = false,
  }) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (reset) {
        if (clearBeforeRequest) {
          _items.clear();
        }
        _page = 0;
        _hasMore = true;
      }
    });

    try {
      final svc = ref.read(stServiceProvider);
      final start = _requestDaySec();
      final rawList = await svc.getCalendarList(
        offset: 0,
        limit: _limit,
        lang: _lang(),
        startTimeSec: start,
        endTimeSec: start,
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(rawList.map((e) => _CalendarRow(e as Map<String, dynamic>)));
        _page = 1;
        _hasMore = rawList.length >= _limit;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final svc = ref.read(stServiceProvider);
      final start = _requestDaySec();
      final offset = _page * _limit;
      final rawList = await svc.getCalendarList(
        offset: offset,
        limit: _limit,
        lang: _lang(),
        startTimeSec: start,
        endTimeSec: start,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(
          rawList.map((e) => _CalendarRow(e as Map<String, dynamic>)),
        );
        _page++;
        _hasMore = rawList.length >= _limit;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _selectDay(DateTime d) {
    final next = DateTime(d.year, d.month, d.day);
    setState(() {
      _selectedDay = next;
      _hasExplicitDaySelection = true;
    });
    _reloadDay(reset: true, clearBeforeRequest: true);
  }

  void _setPickerMode(_CalendarPickerMode mode) {
    if (_pickerMode == mode) return;
    setState(() => _pickerMode = mode);
  }

  static int _starFilled(int weight) {
    if (weight <= 0) return 0;
    if (weight == 1) return 1;
    if (weight == 2) return 3;
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    final colors = _CalendarThemeColors.of(context);
    return ColoredBox(
      color: colors.pageBackground,
      child: Column(
        children: [
          _CalendarHeader(
            selectedDay: _selectedDay,
            mode: _pickerMode,
            onSelectDay: _selectDay,
            onChangeMode: _setPickerMode,
          ),
          Expanded(
            child: STPullRefresh(
              onRefresh: () => _reloadDay(reset: true),
              child: _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: colors.emptyIcon,
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: STLocalizedText(
                            '暂无消息',
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.emptyText,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _items.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= _items.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        return _CalendarEventTile(
                          row: _items[i],
                          starFilled: _starFilled(_items[i].weight),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _CalendarPickerMode { week, month, monthClose }

class _CalendarHeader extends StatelessWidget {
  final DateTime selectedDay;
  final _CalendarPickerMode mode;
  final void Function(DateTime d) onSelectDay;
  final void Function(_CalendarPickerMode mode) onChangeMode;

  const _CalendarHeader({
    required this.selectedDay,
    required this.mode,
    required this.onSelectDay,
    required this.onChangeMode,
  });

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _mondayOf(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  List<DateTime> _weekDates() {
    final monday = _mondayOf(selectedDay);
    return List.generate(7, (index) => monday.add(Duration(days: index)));
  }

  List<DateTime> _monthDates() {
    final monthStart = DateTime(selectedDay.year, selectedDay.month, 1);
    final firstDisplayDay = _mondayOf(monthStart);
    return List.generate(
      42,
      (index) => firstDisplayDay.add(Duration(days: index)),
    );
  }

  List<List<DateTime>> _rowsForMode() {
    final dates = mode == _CalendarPickerMode.month
        ? _monthDates()
        : _weekDates();
    return List.generate(
      dates.length ~/ 7,
      (row) => dates.skip(row * 7).take(7).toList(growable: false),
    );
  }

  String _titleText() {
    final format = mode == _CalendarPickerMode.week ? 'MM-dd' : 'yyyy-MM-dd';
    return DateFormat(format).format(selectedDay);
  }

  bool _isInCurrentMonth(DateTime date) {
    return date.year == selectedDay.year && date.month == selectedDay.month;
  }

  @override
  Widget build(BuildContext context) {
    final colors = _CalendarThemeColors.of(context);
    final dayRows = _rowsForMode();
    final monthSelected = mode != _CalendarPickerMode.week;
    return Material(
      color: colors.pageBackground,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  _titleText(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.primaryText,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 90,
                  height: 29,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.toggleTrack,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ModeToggleButton(
                          key: const ValueKey('calendar-mode-week'),
                          title: '周',
                          selected: !monthSelected,
                          onTap: () => onChangeMode(_CalendarPickerMode.week),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: _ModeToggleButton(
                          key: const ValueKey('calendar-mode-month'),
                          title: '月',
                          selected: monthSelected,
                          onTap: () => onChangeMode(_CalendarPickerMode.month),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: List.generate(
                7,
                (index) => Expanded(
                  child: Center(
                    child: STLocalizedText(
                      _weekdays[index],
                      style: TextStyle(fontSize: 12, color: colors.weekdayText),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            ...dayRows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: row
                      .map(
                        (date) => Expanded(
                          child: Center(
                            child: _CalendarDayCell(
                              date: date,
                              selected: _sameDay(date, selectedDay),
                              enabled:
                                  mode != _CalendarPickerMode.month ||
                                  _isInCurrentMonth(date),
                              onTap: () => onSelectDay(date),
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              key: const ValueKey('calendar-collapse-toggle'),
              onTap: () {
                if (mode == _CalendarPickerMode.week) return;
                onChangeMode(
                  mode == _CalendarPickerMode.month
                      ? _CalendarPickerMode.monthClose
                      : _CalendarPickerMode.month,
                );
              },
              child: Container(
                width: 56,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.toggleTrack,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeToggleButton extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _ModeToggleButton({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _CalendarThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.toggleThumb : colors.toggleTrack,
          borderRadius: BorderRadius.circular(2),
        ),
        child: STLocalizedText(
          title,
          style: TextStyle(
            fontSize: 12,
            color: selected ? colors.accent : colors.weekdayText,
          ),
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.date,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _CalendarThemeColors.of(context);
    final keyValue = DateFormat('yyyy-MM-dd').format(date);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        key: ValueKey('calendar-day-cell-$keyValue'),
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 16,
              color: selected ? colors.onAccent : colors.primaryText,
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarEventTile extends StatelessWidget {
  final _CalendarRow row;
  final int starFilled;

  const _CalendarEventTile({required this.row, required this.starFilled});

  @override
  Widget build(BuildContext context) {
    final colors = _CalendarThemeColors.of(context);
    final timeStr = row.createdAtSec > 0
        ? DateFormat(
            'hh:mm',
          ).format(DateTime.fromMillisecondsSinceEpoch(row.createdAtSec * 1000))
        : '';

    return Material(
      color: colors.pageBackground,
      child: InkWell(
        key: ValueKey('calendar-event-tile-${row.id}'),
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(fontSize: 14, color: colors.tertiaryText),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 25,
                    height: 20,
                    child: Icon(
                      Icons.flag_outlined,
                      size: 18,
                      color: colors.flagIcon,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _StarRow(filled: starFilled)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 14 + 43, right: 14, top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.affect,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.primaryText,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 14 + 43, right: 56, top: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _kv(context, '前值', row.front),
                    const SizedBox(width: 20),
                    _kv(context, '预测值', row.due),
                    const SizedBox(width: 20),
                    _kv(context, '公布值', row.publish),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(height: 0.5, color: colors.divider),
          ],
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    final colors = _CalendarThemeColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        STLocalizedText(
          k,
          style: TextStyle(fontSize: 13, color: colors.metricLabel),
        ),
        const SizedBox(width: 8),
        Text(
          v.isEmpty ? '—' : v,
          style: TextStyle(fontSize: 13, color: colors.primaryText),
        ),
      ],
    );
  }
}

class _StarRow extends StatelessWidget {
  final int filled;

  const _StarRow({required this.filled});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFB30F);
    final empty = _CalendarThemeColors.of(context).starEmpty;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Icon(
            i < filled ? Icons.star : Icons.star_border,
            size: 14,
            color: i < filled ? gold : empty,
          ),
        ),
      ),
    );
  }
}

class _CalendarThemeColors {
  const _CalendarThemeColors({
    required this.pageBackground,
    required this.primaryText,
    required this.tertiaryText,
    required this.weekdayText,
    required this.toggleTrack,
    required this.toggleThumb,
    required this.divider,
    required this.metricLabel,
    required this.emptyIcon,
    required this.emptyText,
    required this.flagIcon,
    required this.starEmpty,
    required this.accent,
    required this.onAccent,
  });

  final Color pageBackground;
  final Color primaryText;
  final Color tertiaryText;
  final Color weekdayText;
  final Color toggleTrack;
  final Color toggleThumb;
  final Color divider;
  final Color metricLabel;
  final Color emptyIcon;
  final Color emptyText;
  final Color flagIcon;
  final Color starEmpty;
  final Color accent;
  final Color onAccent;

  static _CalendarThemeColors of(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return _CalendarThemeColors(
      pageBackground: context.adaptiveSurfacePrimary,
      primaryText: context.adaptiveTextPrimary,
      tertiaryText: context.adaptiveTextTertiary,
      weekdayText: context.adaptiveTextSecondary,
      toggleTrack: context.adaptiveMutedBlock,
      toggleThumb: isDark ? context.adaptivePlaceholderSurface : Colors.white,
      divider: context.adaptiveDivider,
      metricLabel: context.adaptiveTextTertiary,
      emptyIcon: context.adaptiveTextHint,
      emptyText: context.adaptiveTextSecondary,
      flagIcon: context.adaptiveTextHint,
      starEmpty: isDark ? const Color(0xFF3A3D46) : const Color(0xFFE7EBED),
      accent: theme.colorScheme.primary,
      onAccent: theme.colorScheme.onPrimary,
    );
  }
}
