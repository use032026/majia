import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/reader_edit_store.dart';
import '../domain/revision_session.dart';
import '../l10n/app_strings.dart';
import 'changes_page.dart';

class SummaryPage extends StatelessWidget {
  const SummaryPage({required this.store, required this.sessionId, super.key});

  final ReaderEditStore store;
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final session = store.sessionById(sessionId);
        return Scaffold(
          appBar: AppBar(title: Text(strings.summaryTitle)),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    _CompletionBanner(session: session),
                    const SizedBox(height: 26),
                    Text(
                      strings.completionCheck,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 10),
                    _PromiseCheck(
                      key: const ValueKey('promise_know_check'),
                      label: strings.promiseKnow,
                      valueText: session.knowPromise,
                      checked: session.knowChecked,
                      enabled: !store.isBusy,
                      onChanged: (value) =>
                          _saveCheck(context, knowChecked: value),
                    ),
                    _PromiseCheck(
                      key: const ValueKey('promise_feel_check'),
                      label: strings.promiseFeel,
                      valueText: session.feelPromise,
                      checked: session.feelChecked,
                      enabled: !store.isBusy,
                      onChanged: (value) =>
                          _saveCheck(context, feelChecked: value),
                    ),
                    _PromiseCheck(
                      key: const ValueKey('promise_wonder_check'),
                      label: strings.promiseWonder,
                      valueText: session.wonderPromise,
                      checked: session.wonderChecked,
                      enabled: !store.isBusy,
                      onChanged: (value) =>
                          _saveCheck(context, wonderChecked: value),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      strings.revisionResult,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              strings.changedSummary(
                                session.changedCount,
                                session.passages.length,
                              ),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              strings.flaggedSummary(
                                session.flaggedCount,
                                session.unresolvedCount,
                              ),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              key: const ValueKey('compare_button'),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChangesPage(session: session),
                                ),
                              ),
                              icon: const Icon(Icons.compare_arrows_rounded),
                              label: Text(strings.compareChanges),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      strings.revisedDraft,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: SelectableText(
                        session.revisedDraft,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          key: const ValueKey('copy_draft_button'),
                          onPressed: () => _copy(context, session.revisedDraft),
                          icon: const Icon(Icons.copy_all_outlined),
                          label: Text(strings.copyDraft),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey('copy_log_button'),
                          onPressed: () => _copy(
                            context,
                            session.revisionLog(chinese: strings.isChinese),
                          ),
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: Text(strings.copyLog),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveCheck(
    BuildContext context, {
    bool? knowChecked,
    bool? feelChecked,
    bool? wonderChecked,
  }) async {
    try {
      await store.setPromiseChecks(
        sessionId: sessionId,
        knowChecked: knowChecked,
        feelChecked: feelChecked,
        wonderChecked: wonderChecked,
      );
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).saveFailed)),
        );
      }
    }
  }

  Future<void> _copy(BuildContext context, String value) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppStrings.of(context).copied)));
      }
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).copyFailed)),
        );
      }
    }
  }
}

class _CompletionBanner extends StatelessWidget {
  const _CompletionBanner({required this.session});

  final RevisionSession session;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final complete = session.isComplete;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: complete
          ? const Color(0xFF2E8B6D).withValues(alpha: 0.13)
          : scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              complete ? Icons.task_alt_rounded : Icons.pending_actions_rounded,
              size: 34,
              color: complete
                  ? const Color(0xFF2E8B6D)
                  : scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    complete ? strings.complete : strings.incomplete,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    complete
                        ? strings.completeBody
                        : strings.flaggedSummary(
                            session.flaggedCount,
                            session.unresolvedCount,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromiseCheck extends StatelessWidget {
  const _PromiseCheck({
    required this.label,
    required this.valueText,
    required this.checked,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String valueText;
  final bool checked;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(label, style: Theme.of(context).textTheme.labelLarge),
      subtitle: Text(valueText, style: Theme.of(context).textTheme.bodyLarge),
      value: checked,
      onChanged: enabled ? (value) => onChanged(value ?? false) : null,
    );
  }
}
