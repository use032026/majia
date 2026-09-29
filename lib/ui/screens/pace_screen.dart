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
                  const SizedBox(height: 16),
                  _Metrics(goal: goal, snapshot: snapshot),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const Key('record-week'),
                    onPressed: () => _record(context),
                    icon: const Icon(Icons.edit_note),
                    label: Text(text.get('recordWeek')),
                  ),
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
    final info = _statusInfo(context, text, snapshot.status);
    final planFraction = (snapshot.expectedCents / goal.targetCents).clamp(
      0.0,
      1.0,
    );
    final actualFraction = (snapshot.savedCents / goal.targetCents).clamp(
      0.0,
      1.0,
    );
    final semantic =
        '${info.$1}. ${text.get('planTrack')}: '
        '${formatMoney(snapshot.expectedCents, goal.currency)}. '
        '${text.get('actualTrack')}: ${formatMoney(snapshot.savedCents, goal.currency)}. '
        '${text.get('difference')}: '
        '${formatMoney(snapshot.savedCents - snapshot.expectedCents, goal.currency)}.';
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
                const SizedBox(height: 12),
                Text(info.$4),
                const SizedBox(height: 24),
                _Track(
                  label: text.get('planTrack'),
                  value: formatMoney(snapshot.expectedCents, goal.currency),
                  fraction: planFraction,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                _Track(
                  label: text.get('actualTrack'),
                  value: formatMoney(snapshot.savedCents, goal.currency),
                  fraction: actualFraction,
                  color: Theme.of(context).colorScheme.secondary,
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

class _Track extends StatelessWidget {
  const _Track({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });

  final String label;
  final String value;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(child: Text(label)),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 9,
            value: fraction,
            color: color,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.goal, required this.snapshot});

  final SavingsGoal goal;
  final PaceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth < 520
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            _Metric(
              width: itemWidth,
              label: text.get('weeklyPlan'),
              value: formatMoney(goal.currentPlan.weeklyCents, goal.currency),
              icon: Icons.calendar_view_week_outlined,
            ),
            _Metric(
              width: itemWidth,
              label: text.get('weeklyNeeded'),
              value: formatMoney(snapshot.requiredWeeklyCents, goal.currency),
              icon: Icons.speed_outlined,
            ),
            _Metric(
              width: itemWidth,
              label: text.get('difference'),
              value: formatMoney(
                snapshot.savedCents - snapshot.expectedCents,
                goal.currency,
              ),
              icon: Icons.compare_arrows,
            ),
            _Metric(
              width: itemWidth,
              label: text.get('remaining'),
              value: formatMoney(snapshot.remainingCents, goal.currency),
              icon: Icons.outlined_flag,
              hint: text.remainingWeeks(snapshot.weeksRemaining),
            ),
          ],
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    this.hint,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(value, style: Theme.of(context).textTheme.titleLarge),
                    if (hint != null)
                      Text(hint!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
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
              onPressed: () => _replace(context),
              icon: const Icon(Icons.restart_alt),
              label: Text(text.get('startNew')),
            ),
            if (controller.errorCode != null) ...<Widget>[
              const SizedBox(height: 12),
              ErrorBanner(
                message: text.get(
                  controller.errorCode == 'copyFailed'
                      ? 'copyFailed'
                      : 'saveFailed',
                ),
                onRetry: controller.errorCode == 'saveFailed'
                    ? () => _replace(context)
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _replace(BuildContext context) async {
    final text = AppText.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(text.get('replaceTitle')),
        content: Text(text.get('replaceBody')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(text.get('cancel')),
          ),
          TextButton(
            onPressed: () async {
              final copied = await controller.copySummary();
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(text.get(copied ? 'copied' : 'copyFailed')),
                  ),
                );
              }
            },
            child: Text(text.get('copySummary')),
          ),
          FilledButton(
            key: const Key('confirm-replace'),
            onPressed: () => Navigator.pop(dialogContext, 'replace'),
            child: Text(text.get('delete')),
          ),
        ],
      ),
    );
    if (result != 'replace' || !context.mounted) return;
    final cleared = await controller.deleteGoal();
    if (cleared && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CreateGoalScreen(controller: controller),
        ),
      );
    }
  }
}
