import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/money.dart';
import '../../l10n/app_text.dart';
import '../../state/app_controller.dart';
import '../widgets/common.dart';

class CreateGoalScreen extends StatefulWidget {
  const CreateGoalScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends State<CreateGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _currency;
  late final TextEditingController _target;
  late final TextEditingController _starting;
  late final TextEditingController _weekly;
  late DateTime _targetDate;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _currency = TextEditingController(
      text: widget.controller.localeCode == 'zh' ? '¥' : r'$',
    );
    _target = TextEditingController();
    _starting = TextEditingController(text: '0');
    _weekly = TextEditingController();
    _targetDate = widget.controller.now.add(const Duration(days: 90));
    for (final controller in <TextEditingController>[
      _target,
      _starting,
      _weekly,
    ]) {
      controller.addListener(_refreshFeasibility);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _currency.dispose();
    _target.dispose();
    _starting.dispose();
    _weekly.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final target = parseMoneyToCents(_target.text);
    final starting = parseMoneyToCents(_starting.text, allowZero: true);
    final weekly = parseMoneyToCents(_weekly.text);
    final days = _targetDate
        .difference(_dateOnly(widget.controller.now))
        .inDays;
    final weeks = math.max(1, (math.max(0, days) / 7).ceil());
    final requiredWeekly =
        target != null && starting != null && target > starting
        ? ((target - starting) / weeks).ceil()
        : null;
    final feasible =
        requiredWeekly != null && weekly != null && weekly >= requiredWeekly;

    return Scaffold(
      appBar: AppBar(
        title: Text(text.get('createGoal')),
        actions: <Widget>[AppBarControls(controller: widget.controller)],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const OfflineBadge(),
                    const SizedBox(height: 20),
                    Text(
                      text.get('manualOnly'),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const Key('goal-name'),
                      controller: _name,
                      maxLength: 40,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: text.get('goalName'),
                        hintText: text.get('goalNameHint'),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return text.get('required');
                        }
                        if (value.trim().runes.length > 40) {
                          return text.get('nameTooLong');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('currency'),
                      controller: _currency,
                      maxLength: 4,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: text.get('currency'),
                      ),
                      validator: (value) {
                        final length = value?.trim().runes.length ?? 0;
                        return length < 1 || length > 4
                            ? text.get('currencyInvalid')
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _MoneyField(
                      key: const Key('target-amount'),
                      controller: _target,
                      label: text.get('targetAmount'),
                      text: text,
                    ),
                    const SizedBox(height: 12),
                    _MoneyField(
                      key: const Key('starting-amount'),
                      controller: _starting,
                      label: text.get('alreadySaved'),
                      text: text,
                      allowZero: true,
                      extraValidator: (value) {
                        final start = parseMoneyToCents(value, allowZero: true);
                        final goal = parseMoneyToCents(_target.text);
                        return start != null && goal != null && start >= goal
                            ? text.get('startingTooLarge')
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _MoneyField(
                      key: const Key('weekly-amount'),
                      controller: _weekly,
                      label: text.get('weeklyComfort'),
                      text: text,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      key: const Key('target-date'),
                      onTap: _chooseDate,
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: text.get('targetDate'),
                          suffixIcon: const Icon(Icons.calendar_month_outlined),
                        ),
                        child: Text(text.date(_targetDate)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (requiredWeekly != null && weekly != null)
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: feasible
                                ? Theme.of(
                                    context,
                                  ).colorScheme.secondaryContainer
                                : Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Icon(
                                feasible
                                    ? Icons.check_circle_outline
                                    : Icons.route_outlined,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${feasible ? text.get('planFeasible') : text.get('planTight')}\n'
                                  '${text.get('weeklyNeeded')}: '
                                  '${formatMoney(requiredWeekly, _currency.text.trim())}',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (widget.controller.errorCode != null) ...<Widget>[
                      const SizedBox(height: 16),
                      ErrorBanner(
                        message: text.get('saveFailed'),
                        onRetry: _submit,
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      key: const Key('submit-goal'),
                      onPressed: _busy ? null : _submit,
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward),
                      label: Text(text.get('create')),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: Text(text.get('cancel')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _refreshFeasibility() {
    if (mounted) setState(() {});
  }

  Future<void> _chooseDate() async {
    final now = _dateOnly(widget.controller.now);
    final chosen = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: now.add(const Duration(days: 1)),
      lastDate: DateTime(now.year + 20),
    );
    if (chosen != null && mounted) setState(() => _targetDate = chosen);
  }

  Future<void> _submit() async {
    widget.controller.clearError();
    if (!_formKey.currentState!.validate()) return;
    final now = _dateOnly(widget.controller.now);
    if (!_targetDate.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppText.of(context).get('dateInFuture'))),
      );
      return;
    }
    setState(() => _busy = true);
    final saved = await widget.controller.createGoal(
      CreateGoalInput(
        name: _name.text,
        currency: _currency.text,
        targetCents: parseMoneyToCents(_target.text)!,
        startingCents: parseMoneyToCents(_starting.text, allowZero: true)!,
        weeklyCents: parseMoneyToCents(_weekly.text)!,
        targetDate: _targetDate,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved) Navigator.pop(context);
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

class _MoneyField extends StatelessWidget {
  const _MoneyField({
    super.key,
    required this.controller,
    required this.label,
    required this.text,
    this.allowZero = false,
    this.extraValidator,
  });

  final TextEditingController controller;
  final String label;
  final AppText text;
  final bool allowZero;
  final String? Function(String value)? extraValidator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        LengthLimitingTextInputFormatter(16),
      ],
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final raw = value ?? '';
        if (parseMoneyToCents(raw, allowZero: allowZero) == null) {
          return text.get('invalidAmount');
        }
        return extraValidator?.call(raw);
      },
    );
  }
}
