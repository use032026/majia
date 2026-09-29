import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models.dart';
import '../../domain/money.dart';
import '../../l10n/app_text.dart';
import '../../state/app_controller.dart';
import '../widgets/common.dart';

class RecordEventSheet extends StatefulWidget {
  const RecordEventSheet({super.key, required this.controller});

  final AppController controller;

  @override
  State<RecordEventSheet> createState() => _RecordEventSheetState();
}

class _RecordEventSheetState extends State<RecordEventSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  SavingsEventType _type = SavingsEventType.deposit;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    text.get('eventTitle'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 6),
                Text(text.get('eventSubtitle')),
                const SizedBox(height: 18),
                ...SavingsEventType.values.map(
                  (type) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TypeChoice(
                      type: type,
                      selected: _type == type,
                      onTap: _busy ? null : () => setState(() => _type = type),
                    ),
                  ),
                ),
                if (_type != SavingsEventType.skipped) ...<Widget>[
                  const SizedBox(height: 6),
                  TextFormField(
                    key: const Key('event-amount'),
                    controller: _amount,
                    autofocus: false,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      LengthLimitingTextInputFormatter(16),
                    ],
                    decoration: InputDecoration(labelText: text.get('amount')),
                    validator: (value) {
                      final cents = parseMoneyToCents(value ?? '');
                      if (cents == null) return text.get('invalidAmount');
                      if (_type == SavingsEventType.withdrawal &&
                          cents > widget.controller.goal!.savedCents) {
                        return text.get('withdrawalTooLarge');
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('event-note'),
                  controller: _note,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 120,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(
                    labelText: text.get('reasonOptional'),
                    hintText: text.get('reasonHint'),
                  ),
                  validator: (value) => (value?.runes.length ?? 0) > 120
                      ? text.get('noteTooLong')
                      : null,
                ),
                if (widget.controller.errorCode != null) ...<Widget>[
                  const SizedBox(height: 10),
                  ErrorBanner(message: text.get(widget.controller.errorCode!)),
                ],
                const SizedBox(height: 14),
                FilledButton.icon(
                  key: const Key('save-event'),
                  onPressed: _busy ? null : _save,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(text.get('saveEvent')),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context, false),
                  child: Text(text.get('cancel')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    widget.controller.clearError();
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final saved = await widget.controller.recordEvent(
      type: _type,
      amountCents: _type == SavingsEventType.skipped
          ? 0
          : parseMoneyToCents(_amount.text)!,
      note: _note.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved) Navigator.pop(context, true);
  }
}

class _TypeChoice extends StatelessWidget {
  const _TypeChoice({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final SavingsEventType type;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final (title, body, icon) = switch (type) {
      SavingsEventType.deposit => (
        text.get('deposit'),
        text.get('depositHelp'),
        Icons.south_west,
      ),
      SavingsEventType.withdrawal => (
        text.get('withdrawal'),
        text.get('withdrawalHelp'),
        Icons.north_east,
      ),
      SavingsEventType.skipped => (
        text.get('skipped'),
        text.get('skippedHelp'),
        Icons.pause_circle_outline,
      ),
    };
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.secondaryContainer
                : Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
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
                    const SizedBox(height: 3),
                    Text(body),
                  ],
                ),
              ),
              Icon(selected ? Icons.check_circle : Icons.circle_outlined),
            ],
          ),
        ),
      ),
    );
  }
}
