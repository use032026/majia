import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/money.dart';
import '../../domain/pace_calculator.dart';
import '../../l10n/app_text.dart';
import '../../state/app_controller.dart';
import '../widgets/common.dart';
import 'create_goal_screen.dart';
import 'record_event_sheet.dart';
import 'recovery_screen.dart';

class PaceScreen extends StatelessWidget {
  const PaceScreen({
    super.key,
    required this.controller,
    required this.openTimeline,
  });

  final AppController controller;
  final VoidCallback openTimeline;

  @override
  Widget build(BuildContext context) {
    final goal = controller.goal!;
    final snapshot = controller.snapshot!;
    final text = AppText.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const PageStorageKey<String>('pace-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final primary = <Widget>[
                  _StatusCard(goal: goal, snapshot: snapshot),
                  if (snapshot.status != PaceStatus.completed) ...<Widget>[
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      key: const Key('record-week'),
                      onPressed: () => _record(context),
                      icon: const Icon(Icons.edit_note),
                      label: Text(text.get('recordWeek')),
                    ),
                  ],
                  if (snapshot.status == PaceStatus.needsRecovery ||
                      snapshot.status == PaceStatus.expired) ...<Widget>[
                    const SizedBox(height: 16),
                    _RecoveryCard(
                      onOpen: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              RecoveryScreen(controller: controller),
                        ),
                      ),
                    ),
                  ],
                  if (snapshot.status == PaceStatus.completed) ...<Widget>[
                    const SizedBox(height: 16),
                    _CompletedCard(
                      controller: controller,
                      openTimeline: openTimeline,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _PaceDetails(goal: goal, snapshot: snapshot),
                ];
                final secondary = <Widget>[
                  _RecentEvents(goal: goal, openTimeline: openTimeline),
                  const SizedBox(height: 16),
                  _BoundaryCard(),
                ];
                if (!wide) {
                  return Column(
                    children: <Widget>[
                      ...primary,
                      const SizedBox(height: 16),
                      ...secondary,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 3, child: Column(children: primary)),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: Column(children: secondary)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _record(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => RecordEventSheet(controller: controller),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppText.of(context).get('saved'))));
    }
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.goal, required this.snapshot});

  final SavingsGoal goal;
  final PaceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final firstRecord =
        goal.events.isEmpty && snapshot.status != PaceStatus.completed;
    final info = firstRecord
        ? (
            text.get('firstRecordStatus'),
            Icons.edit_note_outlined,
            Theme.of(context).colorScheme.secondary,
            text.get('firstRecordHelp'),
          )
        : _statusInfo(context, text, snapshot.status);
    final progress = (snapshot.savedCents / goal.targetCents).clamp(0.0, 1.0);
    final semantic =
        '${info.$1}. ${goal.name}. ${text.get('savedProgress')}: '
        '${formatMoney(snapshot.savedCents, goal.currency)} / '
        '${formatMoney(goal.targetCents, goal.currency)}. '
        '${text.get('remainingShort')}: '
        '${formatMoney(snapshot.remainingCents, goal.currency)}.';
    return Semantics(
      label: semantic,
      child: ExcludeSemantics(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: info.$3.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(info.$2, color: info.$3),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            info.$1,
                            style: Theme.of(
                              context,
                            ).textTheme.labelLarge?.copyWith(color: info.$3),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            goal.name,
                            maxLines: 3,
                            overflow: TextOverflow.fade,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  text.get('savedProgress'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatMoney(snapshot.savedCents, goal.currency)} / '
                  '${formatMoney(goal.targetCents, goal.currency)}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: progress,
                    color: Theme.of(context).colorScheme.secondary,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 14),
                if (snapshot.status == PaceStatus.completed &&
                    goal.completedAt != null)
                  Text(
                    '${text.get('completedOn')}: '
                    '${text.date(goal.completedAt!)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  )
                else ...<Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: <Widget>[
                      Text(
                        '${text.get('remainingShort')} '
                        '${formatMoney(snapshot.remainingCents, goal.currency)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text('· ${text.remainingWeeks(snapshot.weeksRemaining)}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${text.get('plannedWeekly')}: '
                    '${formatMoney(goal.currentPlan.weeklyCents, goal.currency)}',
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: info.$3.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(info.$4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

(String, IconData, Color, String) _statusInfo(
  BuildContext context,
  AppText text,
  PaceStatus status,
) {
  final scheme = Theme.of(context).colorScheme;
  return switch (status) {
    PaceStatus.ahead => (
      text.get('statusAhead'),
      Icons.trending_up,
      scheme.secondary,
      text.get('aheadHelp'),
    ),
    PaceStatus.onTrack => (
      text.get('statusOnTrack'),
      Icons.check_circle_outline,
      scheme.secondary,
      text.get('onTrackHelp'),
    ),
    PaceStatus.needsRecovery => (
      text.get('statusRecovery'),
      Icons.alt_route,
      scheme.error,
      text.get('recoveryHelp'),
    ),
    PaceStatus.expired => (
      text.get('statusExpired'),
      Icons.event_busy_outlined,
      scheme.error,
      text.get('expiredHelp'),
    ),
    PaceStatus.completed => (
      text.get('statusCompleted'),
      Icons.flag_outlined,
      scheme.secondary,
      text.get('completedHelp'),
    ),
  };
}

class _PaceDetails extends StatelessWidget {
  const _PaceDetails({required this.goal, required this.snapshot});

  final SavingsGoal goal;
  final PaceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return Card(
      child: ExpansionTile(
        key: const PageStorageKey<String>('pace-details'),
        leading: const Icon(Icons.insights_outlined),
        title: Text(text.get('paceDetails')),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        children: <Widget>[
          _DetailRow(
            label: text.get('plannedWeekly'),
            value: formatMoney(goal.currentPlan.weeklyCents, goal.currency),
          ),
          _DetailRow(
            label: text.get('weeklyNeeded'),
            value: formatMoney(snapshot.requiredWeeklyCents, goal.currency),
          ),
          _DetailRow(
            label: text.get('planTrack'),
            value: formatMoney(snapshot.expectedCents, goal.currency),
          ),
          _DetailRow(
            label: text.get('difference'),
            value: formatMoney(
              snapshot.savedCents - snapshot.expectedCents,
              goal.currency,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          const SizedBox(width: 14),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.alt_route),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text.get('statusRecovery'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(text.get('recoveryHelp')),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              key: const Key('open-recovery'),
              onPressed: onOpen,
              icon: const Icon(Icons.arrow_forward),
              label: Text(text.get('viewRecovery')),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentEvents extends StatelessWidget {
  const _RecentEvents({required this.goal, required this.openTimeline});

  final SavingsGoal goal;
  final VoidCallback openTimeline;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final recent = goal.events.toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    text.get('recentEvents'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: openTimeline,
                  child: Text(text.get('viewAll')),
                ),
              ],
            ),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(text.get('noEvents')),
              )
            else
              ...recent
                  .take(3)
                  .map((event) => _EventRow(event: event, goal: goal)),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.goal});

  final SavingsEvent event;
  final SavingsGoal goal;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final (label, icon, sign) = switch (event.type) {
      SavingsEventType.deposit => (text.get('deposit'), Icons.south_west, 1),
      SavingsEventType.withdrawal => (
        text.get('withdrawal'),
        Icons.north_east,
        -1,
      ),
      SavingsEventType.skipped => (
        text.get('skipped'),
        Icons.pause_circle_outline,
        0,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  text.date(event.occurredAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (event.note.isNotEmpty) Text(event.note),
              ],
            ),
          ),
          if (sign != 0)
            Flexible(
              child: Text(
                formatMoney(event.amountCents * sign, goal.currency),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _BoundaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.lock_outline),
            const SizedBox(width: 10),
            Expanded(child: Text(AppText.of(context).get('appBoundary'))),
          ],
        ),
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  const _CompletedCard({required this.controller, required this.openTimeline});

  final AppController controller;
  final VoidCallback openTimeline;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final goal = controller.goal!;
    final completedAt = goal.completedAt;
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(text.get('completedHelp')),
            const SizedBox(height: 10),
            Text(
              '${completedAt == null ? '' : '${text.get('completedOn')}: ${text.date(completedAt)} · '}'
              '${text.planCount(goal.plans.length)}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: openTimeline,
              icon: const Icon(Icons.history),
              label: Text(text.get('viewReview')),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('start-new'),
              onPressed: () => _archiveAndStart(context),
              icon: const Icon(Icons.archive_outlined),
              label: Text(text.get('startNew')),
            ),
            if (controller.errorCode != null) ...<Widget>[
              const SizedBox(height: 12),
              ErrorBanner(
                message: text.get('saveFailed'),
                onRetry: controller.errorCode == 'saveFailed'
                    ? () => _archiveAndStart(context)
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _archiveAndStart(BuildContext context) async {
    final text = AppText.of(context);
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(text.get('archiveTitle')),
        content: Text(text.get('archiveBody')),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(text.get('cancel')),
          ),
          CupertinoDialogAction(
            key: const Key('confirm-archive'),
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(text.get('archiveAndStart')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final navigator = Navigator.of(context);
    final archived = await controller.archiveCompletedGoal();
    if (archived && navigator.mounted) {
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => CreateGoalScreen(controller: controller),
        ),
      );
    }
  }
}
