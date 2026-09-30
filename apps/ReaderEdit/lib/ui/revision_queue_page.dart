import 'package:flutter/material.dart';

import '../app/reader_edit_store.dart';
import '../domain/revision_session.dart';
import '../l10n/app_strings.dart';
import 'revision_editor_page.dart';
import 'scan_page.dart';
import 'summary_page.dart';

class RevisionQueuePage extends StatelessWidget {
  const RevisionQueuePage({
    required this.store,
    required this.sessionId,
    super.key,
  });

  final ReaderEditStore store;
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final session = store.sessionById(sessionId);
        final flagged = session.passages
            .where((passage) => passage.isFlagged)
            .toList();
        return Scaffold(
          appBar: AppBar(title: Text(strings.queueTitle)),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  children: [
                    Text(
                      session.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.queueIntro,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      strings.flaggedSummary(
                        flagged.length,
                        session.unresolvedCount,
                      ),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (flagged.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 40,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                strings.noFlagsTitle,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(strings.noFlagsBody),
                            ],
                          ),
                        ),
                      )
                    else
                      for (var index = 0; index < flagged.length; index++) ...[
                        _QueueCard(
                          passage: flagged[index],
                          index: index + 1,
                          onRevise: () =>
                              _openEditor(context, flagged[index].id),
                          onReopen: () => _reopen(context, flagged[index].id),
                          onReassess: () =>
                              _reassess(context, flagged[index].id),
                        ),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('summary_button'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                SummaryPage(store: store, sessionId: sessionId),
                          ),
                        ),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: Text(strings.goToSummary),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEditor(BuildContext context, String passageId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RevisionEditorPage(
          store: store,
          sessionId: sessionId,
          passageId: passageId,
        ),
      ),
    );
  }

  Future<void> _reopen(BuildContext context, String passageId) async {
    try {
      await store.reopenRevision(sessionId: sessionId, passageId: passageId);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).saveFailed)),
        );
      }
    }
  }

  Future<void> _reassess(BuildContext context, String passageId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScanPage(
          store: store,
          sessionId: sessionId,
          initialPassageId: passageId,
          returnAfterSave: true,
        ),
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.passage,
    required this.index,
    required this.onRevise,
    required this.onReopen,
    required this.onReassess,
  });

  final PassageRevision passage;
  final int index;
  final VoidCallback onRevise;
  final VoidCallback onReopen;
  final VoidCallback onReassess;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final signalColor = passage.signal == ReaderSignal.dragging
        ? const Color(0xFFC4662D)
        : const Color(0xFFB2405A);
    final signalText = passage.signal == ReaderSignal.dragging
        ? strings.signalDragging
        : strings.signalLost;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: signalColor.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$index · $signalText',
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: signalColor),
                  ),
                ),
                Text(
                  passage.isResolved ? strings.resolved : strings.openIssue,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: passage.isResolved
                        ? const Color(0xFF2E8B6D)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              passage.revised,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (passage.note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(passage.note),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  key: ValueKey('reassess_${passage.id}'),
                  onPressed: onReassess,
                  icon: const Icon(Icons.visibility_outlined),
                  label: Text(strings.reassessSignal),
                ),
                if (passage.isResolved)
                  TextButton.icon(
                    onPressed: onReopen,
                    icon: const Icon(Icons.undo_rounded),
                    label: Text(strings.reopen),
                  ),
                FilledButton.tonalIcon(
                  key: ValueKey('revise_${passage.id}'),
                  onPressed: onRevise,
                  icon: const Icon(Icons.compare_arrows_rounded),
                  label: Text(strings.revise),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
