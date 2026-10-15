import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/utils/ios_date_range.dart';
import 'package:jufu/shared/widgets/st_localized_prompt.dart';

Future<DateTime?> showIosDatePickerSheet({
  required BuildContext context,
  DateTime? initialDate,
  DateTime? minimumDate,
  DateTime? maximumDate,
}) {
  final min = iosCalendarDay(minimumDate ?? DateTime(2000));
  var max = iosCalendarDay(maximumDate ?? DateTime(2050, 12, 30));
  if (max.isBefore(min)) max = min;
  var selected = iosCalendarDay(initialDate ?? DateTime.now());
  if (selected.isBefore(min)) selected = min;
  if (selected.isAfter(max)) selected = max;

  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (ctx) => SafeArea(
      top: false,
      child: SizedBox(
        key: const ValueKey('ios-date-picker-sheet'),
        height: 309,
        child: Column(
          children: [
            SizedBox(
              key: const ValueKey('ios-date-picker-toolbar'),
              height: 56,
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF397BD8),
                      textStyle: const TextStyle(fontSize: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                    ),
                    child: STLocalizedText('取消'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(selected),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF397BD8),
                      textStyle: const TextStyle(fontSize: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                    ),
                    child: STLocalizedText('确定'),
                  ),
                ],
              ),
            ),
            const Divider(
              height: 0.5,
              thickness: 0.5,
              color: Color(0xFFE5E5E5),
            ),
            const SizedBox(
              key: ValueKey('ios-date-picker-top-gap'),
              height: 64,
            ),
            SizedBox(
              height: 188,
              child: _IosDateWheelPicker(
                initialDate: selected,
                minimumDate: min,
                maximumDate: max,
                onChanged: (value) => selected = value,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _IosDateWheelPicker extends ConsumerStatefulWidget {
  const _IosDateWheelPicker({
    required this.initialDate,
    required this.minimumDate,
    required this.maximumDate,
    required this.onChanged,
  });

  final DateTime initialDate;
  final DateTime minimumDate;
  final DateTime maximumDate;
  final ValueChanged<DateTime> onChanged;

  @override
  ConsumerState<_IosDateWheelPicker> createState() =>
      _IosDateWheelPickerState();
}

class _IosDateWheelPickerState extends ConsumerState<_IosDateWheelPicker> {
  static const double _itemExtent = 35;
  static const double _textFontSize = 18;
  static const Map<String, String> _defaultUnitLabels = <String, String>{
    'year': '年',
    'month': '月',
    'day': '日',
  };

  late DateTime _selected;
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dayController;

  List<int> get _years => [
    for (
      var year = widget.minimumDate.year;
      year <= widget.maximumDate.year;
      year++
    )
      year,
  ];

  List<int> get _months {
    var start = 1;
    var end = 12;
    if (_selected.year == widget.minimumDate.year) {
      start = widget.minimumDate.month;
    }
    if (_selected.year == widget.maximumDate.year) {
      end = widget.maximumDate.month;
    }
    return [for (var month = start; month <= end; month++) month];
  }

  List<int> get _days {
    var start = 1;
    var end = _daysInMonth(_selected.year, _selected.month);
    if (_selected.year == widget.minimumDate.year &&
        _selected.month == widget.minimumDate.month) {
      start = widget.minimumDate.day;
    }
    if (_selected.year == widget.maximumDate.year &&
        _selected.month == widget.maximumDate.month) {
      end = widget.maximumDate.day;
    }
    return [for (var day = start; day <= end; day++) day];
  }

  @override
  void initState() {
    super.initState();
    _selected = _normalize(
      year: widget.initialDate.year,
      month: widget.initialDate.month,
      day: widget.initialDate.day,
    );
    _yearController = FixedExtentScrollController(
      initialItem: _years.indexOf(_selected.year),
    );
    _monthController = FixedExtentScrollController(
      initialItem: _months.indexOf(_selected.month),
    );
    _dayController = FixedExtentScrollController(
      initialItem: _days.indexOf(_selected.day),
    );
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unitLabelsFuture = ref
        .watch(stLocalizationsProvider)
        .textMap(_defaultUnitLabels);
    return FutureBuilder<Map<String, String>>(
      future: unitLabelsFuture,
      initialData: _defaultUnitLabels,
      builder: (context, snapshot) {
        final unitLabels = snapshot.data ?? _defaultUnitLabels;
        return Stack(
          key: const ValueKey('ios-date-picker-wheel'),
          alignment: Alignment.center,
          children: [
            KeyedSubtree(
              key: ValueKey('ios-date-picker-min-day-${_days.first}'),
              child: const SizedBox.shrink(),
            ),
            const SizedBox(
              height: _itemExtent,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFD8D8D8), width: 0.5),
                    bottom: BorderSide(color: Color(0xFFD8D8D8), width: 0.5),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                _wheel(
                  key: const ValueKey('ios-date-picker-year-wheel'),
                  controller: _yearController,
                  values: _years,
                  selectedValue: _selected.year,
                  labelBuilder: (value) => '$value${unitLabels['year'] ?? '年'}',
                  onChanged: (value) => _updateDate(year: value),
                ),
                _wheel(
                  key: const ValueKey('ios-date-picker-month-wheel'),
                  controller: _monthController,
                  values: _months,
                  selectedValue: _selected.month,
                  labelBuilder: (value) =>
                      '$value${unitLabels['month'] ?? '月'}',
                  onChanged: (value) => _updateDate(month: value),
                ),
                _wheel(
                  key: const ValueKey('ios-date-picker-day-wheel'),
                  controller: _dayController,
                  values: _days,
                  selectedValue: _selected.day,
                  labelBuilder: (value) => '$value${unitLabels['day'] ?? '日'}',
                  onChanged: (value) => _updateDate(day: value),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _wheel({
    required Key key,
    required FixedExtentScrollController controller,
    required List<int> values,
    required int selectedValue,
    required String Function(int value) labelBuilder,
    required ValueChanged<int> onChanged,
  }) {
    return Expanded(
      child: CupertinoPicker(
        key: key,
        scrollController: controller,
        itemExtent: _itemExtent,
        diameterRatio: 1.6,
        squeeze: 1.05,
        selectionOverlay: const SizedBox.shrink(),
        onSelectedItemChanged: (index) => onChanged(values[index]),
        children: [
          for (final value in values)
            Center(
              child: Text(
                labelBuilder(value),
                maxLines: 1,
                style: TextStyle(
                  fontSize: _textFontSize,
                  fontWeight: FontWeight.w400,
                  height: 1,
                  color: value == selectedValue
                      ? Colors.black
                      : const Color(0xFF9A9DA2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _updateDate({int? year, int? month, int? day}) {
    final next = _normalize(
      year: year ?? _selected.year,
      month: month ?? _selected.month,
      day: day ?? _selected.day,
    );
    if (next == _selected) return;
    setState(() => _selected = next);
    widget.onChanged(next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _jumpToSelectedItems();
    });
  }

  DateTime _normalize({
    required int year,
    required int month,
    required int day,
  }) {
    final normalizedYear = _clampInt(
      year,
      widget.minimumDate.year,
      widget.maximumDate.year,
    );
    final monthStart = normalizedYear == widget.minimumDate.year
        ? widget.minimumDate.month
        : 1;
    final monthEnd = normalizedYear == widget.maximumDate.year
        ? widget.maximumDate.month
        : 12;
    final normalizedMonth = _clampInt(month, monthStart, monthEnd);
    final dayStart =
        normalizedYear == widget.minimumDate.year &&
            normalizedMonth == widget.minimumDate.month
        ? widget.minimumDate.day
        : 1;
    final dayEnd =
        normalizedYear == widget.maximumDate.year &&
            normalizedMonth == widget.maximumDate.month
        ? widget.maximumDate.day
        : _daysInMonth(normalizedYear, normalizedMonth);
    return DateTime(
      normalizedYear,
      normalizedMonth,
      _clampInt(day, dayStart, dayEnd),
    );
  }

  void _jumpToSelectedItems() {
    _yearController.jumpToItem(_years.indexOf(_selected.year));
    _monthController.jumpToItem(_months.indexOf(_selected.month));
    _dayController.jumpToItem(_days.indexOf(_selected.day));
  }

  static int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }
}
