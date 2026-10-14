import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// One visual language for transient choices and feedback on every platform.
Widget iosOverlayTheme(BuildContext context, Widget child) {
  final theme = Theme.of(context);
  return CupertinoTheme(
    data: CupertinoThemeData(
      brightness: theme.brightness,
      primaryColor: theme.colorScheme.primary,
    ),
    child: child,
  );
}

void showIosNotice(BuildContext context, String message) {
  final theme = Theme.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(
          message,
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
      ),
    );
}

class IosChoice<T> {
  const IosChoice(this.value, this.label);
  final T value;
  final String label;
}

Future<int?> showIosChoices<T>(
  BuildContext context, {
  required String title,
  required String cancelLabel,
  required List<IosChoice<T>> choices,
  T? selected,
}) => showCupertinoModalPopup<int>(
  context: context,
  builder: (popupContext) => iosOverlayTheme(
    context,
    CupertinoActionSheet(
      title: Text(title),
      actions: [
        for (var index = 0; index < choices.length; index++)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(popupContext, index),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(choices[index].label),
                if (choices[index].value == selected) ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.check_mark, size: 16),
                ],
              ],
            ),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(popupContext),
        child: Text(cancelLabel),
      ),
    ),
  ),
);

class IosChoiceField<T> extends StatelessWidget {
  const IosChoiceField({
    super.key,
    required this.label,
    required this.value,
    required this.choices,
    required this.cancelLabel,
    required this.onSelected,
  });

  final String label;
  final T value;
  final List<IosChoice<T>> choices;
  final String cancelLabel;
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedLabel = choices
        .where((choice) => choice.value == value)
        .firstOrNull
        ?.label;
    return Semantics(
      button: true,
      enabled: onSelected != null,
      label: '$label, ${selectedLabel ?? ''}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onSelected == null
            ? null
            : () async {
                final index = await showIosChoices<T>(
                  context,
                  title: label,
                  cancelLabel: cancelLabel,
                  choices: choices,
                  selected: value,
                );
                if (index != null && context.mounted) {
                  onSelected!(choices[index].value);
                }
              },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            enabled: onSelected != null,
            suffixIcon: const Icon(CupertinoIcons.chevron_down, size: 18),
          ),
          child: Text(selectedLabel ?? ''),
        ),
      ),
    );
  }
}

Future<DateTime?> showIosDatePicker({
  required BuildContext context,
  required String title,
  required String cancelLabel,
  required String doneLabel,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) => showCupertinoModalPopup<DateTime>(
  context: context,
  builder: (popupContext) => iosOverlayTheme(
    context,
    _IosDateSheet(
      title: title,
      cancelLabel: cancelLabel,
      doneLabel: doneLabel,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  ),
);

Future<DateTimeRange?> showIosDateRangePicker({
  required BuildContext context,
  required String title,
  required String cancelLabel,
  required String doneLabel,
  required String startLabel,
  required String endLabel,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialRange,
}) => showCupertinoModalPopup<DateTimeRange>(
  context: context,
  builder: (popupContext) => iosOverlayTheme(
    context,
    _IosDateRangeSheet(
      title: title,
      cancelLabel: cancelLabel,
      doneLabel: doneLabel,
      startLabel: startLabel,
      endLabel: endLabel,
      initialRange: initialRange,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  ),
);

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.cancelLabel,
    required this.doneLabel,
    required this.onDone,
    required this.child,
  });

  final String title;
  final String cancelLabel;
  final String doneLabel;
  final VoidCallback onDone;
  final Widget child;

  @override
  Widget build(BuildContext context) => CupertinoPopupSurface(
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 360,
        child: Column(
          children: [
            Row(
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(cancelLabel),
                ),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: CupertinoTheme.of(
                      context,
                    ).textTheme.navTitleTextStyle,
                  ),
                ),
                CupertinoButton(onPressed: onDone, child: Text(doneLabel)),
              ],
            ),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}

class _IosDateSheet extends StatefulWidget {
  const _IosDateSheet({
    required this.title,
    required this.cancelLabel,
    required this.doneLabel,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });
  final String title;
  final String cancelLabel;
  final String doneLabel;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_IosDateSheet> createState() => _IosDateSheetState();
}

class _IosDateSheetState extends State<_IosDateSheet> {
  late DateTime _date = DateUtils.dateOnly(widget.initialDate);

  @override
  Widget build(BuildContext context) => _SheetFrame(
    title: widget.title,
    cancelLabel: widget.cancelLabel,
    doneLabel: widget.doneLabel,
    onDone: () => Navigator.pop(context, _date),
    child: CupertinoDatePicker(
      mode: CupertinoDatePickerMode.date,
      initialDateTime: _date,
      minimumDate: widget.firstDate,
      maximumDate: widget.lastDate,
      onDateTimeChanged: (value) => _date = DateUtils.dateOnly(value),
    ),
  );
}

class _IosDateRangeSheet extends StatefulWidget {
  const _IosDateRangeSheet({
    required this.title,
    required this.cancelLabel,
    required this.doneLabel,
    required this.startLabel,
    required this.endLabel,
    required this.initialRange,
    required this.firstDate,
    required this.lastDate,
  });
  final String title;
  final String cancelLabel;
  final String doneLabel;
  final String startLabel;
  final String endLabel;
  final DateTimeRange? initialRange;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_IosDateRangeSheet> createState() => _IosDateRangeSheetState();
}

class _IosDateRangeSheetState extends State<_IosDateRangeSheet> {
  late DateTime _start = DateUtils.dateOnly(
    widget.initialRange?.start ?? DateTime.now(),
  );
  late DateTime _end = DateUtils.dateOnly(widget.initialRange?.end ?? _start);
  int _editing = 0;

  @override
  Widget build(BuildContext context) {
    final segmentStyle = TextStyle(
      color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
      decoration: TextDecoration.none,
    );
    return _SheetFrame(
      title: widget.title,
      cancelLabel: widget.cancelLabel,
      doneLabel: widget.doneLabel,
      onDone: () =>
          Navigator.pop(context, DateTimeRange(start: _start, end: _end)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _editing,
              children: {
                0: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(widget.startLabel, style: segmentStyle),
                ),
                1: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(widget.endLabel, style: segmentStyle),
                ),
              },
              onValueChanged: (value) {
                if (value != null) setState(() => _editing = value);
              },
            ),
          ),
          Expanded(
            child: CupertinoDatePicker(
              key: ValueKey(_editing),
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _editing == 0 ? _start : _end,
              minimumDate: _editing == 0 ? widget.firstDate : _start,
              maximumDate: widget.lastDate,
              onDateTimeChanged: (value) {
                final date = DateUtils.dateOnly(value);
                if (_editing == 0) {
                  _start = date;
                  if (_end.isBefore(date)) _end = date;
                } else {
                  _end = date;
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
