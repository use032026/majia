import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/money.dart';
import '../../domain/pace_calculator.dart';
import '../../l10n/app_text.dart';
import '../../state/app_controller.dart';
import '../widgets/common.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  late RecoveryStrategy _strategy;
  final _custom = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _strategy = widget.controller.snapshot?.status == PaceStatus.expired
        ? RecoveryStrategy.keepWeekly
        : RecoveryStrategy.keepDate;
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final goal = widget.controller.goal!;
    final expired = widget.controller.snapshot?.status == PaceStatus.expired;
    final customCents = parseMoneyToCents(_custom.text);
    PlanPreview? preview;
    try {
      preview = widget.controller.previewPlan(
        _strategy,
        customWeeklyCents: customCents,
      );
    } on FormatException {
      preview = null;
    }
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(text.get('recoveryTitle'))),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      text.get('recoveryIntro'),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    ...RecoveryStrategy.values.map(
                      (strategy) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _StrategyCard(
                          strategy: strategy,
                          selected: strategy == _strategy,
                          enabled:
                              !(expired &&
                                  strategy == RecoveryStrategy.keepDate),
                          onTap:
                              _busy ||
                                  (expired &&
                                      strategy == RecoveryStrategy.keepDate)
                              ? null
                              : () => setState(() => _strategy = strategy),
                        ),
                      ),
                    ),
                    if (_strategy == RecoveryStrategy.customWeekly) ...<Widget>[
                      const SizedBox(height: 6),
                      TextField(
                        key: const Key('custom-weekly'),
                        controller: _custom,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => FocusScope.of(context).unfocus(),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                          LengthLimitingTextInputFormatter(16),
                        ],
                        decoration: InputDecoration(
                          labelText: text.get('customWeekly'),
                          errorText:
                              _custom.text.isNotEmpty && customCents == null
                              ? text.get('invalidAmount')
                              : null,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (preview != null)
                      Semantics(
                        liveRegion: true,
                        child: Card(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  text.get('newWeekly'),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  formatMoney(
                                    preview.weeklyCents,
                                    goal.currency,
                                  ),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  text.get('newDate'),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  text.date(preview.targetDate),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (widget.controller.errorCode != null) ...<Widget>[
                      const SizedBox(height: 14),
                      ErrorBanner(
                        message: text.get('saveFailed'),
                        onRetry: preview == null ? null : _apply,
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      key: const Key('apply-plan'),
                      onPressed: _busy || preview == null ? null : _apply,
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_task),
                      label: Text(text.get('applyPlan')),
                    ),
                    const SizedBox(height: 8),
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

  Future<void> _apply() async {
    widget.controller.clearError();
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final saved = await widget.controller.applyPlan(
      _strategy,
      customWeeklyCents: parseMoneyToCents(_custom.text),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppText.of(context).get('planSaved'))),
      );
      Navigator.pop(context);
    }
  }
}

class _StrategyCard extends StatelessWidget {
  const _StrategyCard({
    required this.strategy,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final RecoveryStrategy strategy;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final (title, body, icon) = switch (strategy) {
      RecoveryStrategy.keepDate => (
        text.get('keepDate'),
        text.get(enabled ? 'keepDateHelp' : 'keepDateExpired'),
        Icons.event_available_outlined,
      ),
      RecoveryStrategy.keepWeekly => (
        text.get('keepWeekly'),
        text.get('keepWeeklyHelp'),
        Icons.ssid_chart,
      ),
      RecoveryStrategy.customWeekly => (
        text.get('customWeekly'),
        text.get('customWeeklyHelp'),
        Icons.tune,
      ),
    };
    return Semantics(
      selected: selected,
      enabled: enabled,
      button: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.62,
        child: InkWell(
          key: Key('strategy-${strategy.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                width: selected ? 2 : 1,
                color: selected
                    ? Theme.of(context).colorScheme.secondary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(body),
                    ],
                  ),
                ),
                Icon(selected ? Icons.check_circle : Icons.circle_outlined),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
