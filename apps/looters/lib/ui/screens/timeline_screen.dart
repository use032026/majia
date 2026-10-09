import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/money.dart';
import '../../l10n/app_text.dart';
import '../../state/app_controller.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  late int _section;

  @override
  void initState() {
    super.initState();
    _section = widget.controller.goal == null ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final activeGoal = widget.controller.goal;
    final section = activeGoal == null ? 1 : _section;
    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      text.get('records'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoSlidingSegmentedControl<int>(
                        groupValue: section,
                        children: <int, Widget>{
                          0: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(text.get('currentGoal')),
                          ),
                          1: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '${text.get('completedGoals')} '
                              '(${widget.controller.completedGoals.length})',
                            ),
                          ),
                        },
                        onValueChanged: (value) {
                          if (value != null) setState(() => _section = value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: section == 0 && activeGoal != null
                ? _GoalTimelineView(
                    goal: activeGoal,
                    controller: widget.controller,
                  )
                : _CompletedGoalsView(controller: widget.controller),
          ),
        ],
      ),
    );
  }
}

class _CompletedGoalsView extends StatelessWidget {
  const _CompletedGoalsView({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final goals = controller.completedGoals;
    if (goals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.emoji_events_outlined,
                size: 42,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 14),
              Text(
                text.get('noCompletedGoals'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      key: const PageStorageKey<String>('completed-goals'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      itemCount: goals.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final goal = goals[index];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Card(
              child: InkWell(
                key: Key('completed-goal-${goal.id}'),
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CompletedGoalDetailScreen(
                      goal: goal,
                      controller: controller,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.emoji_events_outlined),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              goal.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${text.get('completedOn')}: '
                              '${text.date(goal.completedAt!)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${formatMoney(goal.savedCents, goal.currency)} / '
                              '${formatMoney(goal.targetCents, goal.currency)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: Key('delete-completed-${goal.id}'),
                        tooltip: text.get('deleteCompleted'),
                        color: Theme.of(context).colorScheme.error,
                        onPressed: () => _delete(context, goal),
                        icon: const Icon(Icons.delete_outline),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _delete(BuildContext context, SavingsGoal goal) async {
    await _confirmDeleteCompletedGoal(context, controller, goal);
  }
}

class CompletedGoalDetailScreen extends StatelessWidget {
  const CompletedGoalDetailScreen({
    super.key,
    required this.goal,
    required this.controller,
  });

  final SavingsGoal goal;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(goal.name),
        actions: <Widget>[
          IconButton(
            key: Key('delete-completed-detail-${goal.id}'),
            tooltip: AppText.of(context).get('deleteCompleted'),
            color: Theme.of(context).colorScheme.error,
            onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _GoalTimelineView(
          goal: goal,
          controller: controller,
          completed: true,
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final navigator = Navigator.of(context);
    final deleted = await _confirmDeleteCompletedGoal(
      context,
      controller,
      goal,
    );
    if (deleted && navigator.mounted) navigator.pop();
  }
}

Future<bool> _confirmDeleteCompletedGoal(
  BuildContext context,
  AppController controller,
  SavingsGoal goal,
) async {
  final text = AppText.of(context);
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(text.get('deleteCompletedTitle')),
      content: Text('${goal.name}\n\n${text.get('deleteCompletedBody')}'),
      actions: <Widget>[
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(text.get('cancel')),
        ),
        CupertinoDialogAction(
          key: Key('confirm-delete-completed-${goal.id}'),
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(text.get('delete')),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  final deleted = await controller.deleteCompletedGoal(goal.id);
  if (!deleted && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text.get('deleteFailed'))));
  }
  return deleted;
}

class _GoalTimelineView extends StatelessWidget {
  const _GoalTimelineView({
    required this.goal,
    required this.controller,
    this.completed = false,
  });

  final SavingsGoal goal;
  final AppController controller;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    var runningCents = goal.startingCents;
    final eventItems = <_TimelineItem>[];
    for (final event in goal.events) {
      switch (event.type) {
        case SavingsEventType.deposit:
          runningCents += event.amountCents;
        case SavingsEventType.withdrawal:
          runningCents -= event.amountCents;
        case SavingsEventType.skipped:
          break;
      }
      eventItems.add(
        _TimelineItem.event(event, balanceAfterCents: runningCents),
      );
    }
    final items = <_TimelineItem>[
      ...eventItems,
      ...goal.plans.map(_TimelineItem.plan),
    ]..sort((a, b) => b.date.compareTo(a.date));
    return CustomScrollView(
      key: PageStorageKey<String>('goal-timeline-${goal.id}'),
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Card(
                  color: completed
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                goal.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${formatMoney(goal.savedCents, goal.currency)} / '
                                '${formatMoney(goal.targetCents, goal.currency)}',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${text.eventCount(goal.events.length)} · '
                                '${text.planCount(goal.plans.length)}',
                              ),
                              if (completed && goal.completedAt != null)
                                Text(
                                  '${text.get('completedOn')}: '
                                  '${text.date(goal.completedAt!)}',
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: Key('copy-summary-${goal.id}'),
                          tooltip: text.get('copySummary'),
                          onPressed: () => _copy(context),
                          icon: const Icon(Icons.copy_all_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(text.get('timelineEmpty')),
              ),
            ),
          )
        else ...<Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 10),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      text.get('progressHistory'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, index) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: _TimelineTile(
                    item: items[index],
                    goal: goal,
                    isLast: index == items.length - 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _copy(BuildContext context) async {
    final copied = await controller.copySummary(goal);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppText.of(context).get(copied ? 'copied' : 'copyFailed'),
          ),
        ),
      );
    }
  }
}

class _TimelineItem {
  _TimelineItem.event(SavingsEvent value, {required this.balanceAfterCents})
    : event = value,
      plan = null,
      date = value.occurredAt;

  _TimelineItem.plan(PlanVersion value)
    : event = null,
      plan = value,
      balanceAfterCents = null,
      date = value.effectiveAt;

  final SavingsEvent? event;
  final PlanVersion? plan;
  final int? balanceAfterCents;
  final DateTime date;
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.item,
    required this.goal,
    required this.isLast,
  });

  final _TimelineItem item;
  final SavingsGoal goal;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final scheme = Theme.of(context).colorScheme;
    final event = item.event;
    final plan = item.plan;
    late final IconData icon;
    late final String title;
    late final Color accent;
    if (event != null) {
      switch (event.type) {
        case SavingsEventType.deposit:
          icon = Icons.south_west;
          title = text.get('deposit');
          accent = scheme.secondary;
        case SavingsEventType.withdrawal:
          icon = Icons.north_east;
          title = text.get('withdrawal');
          accent = scheme.error;
        case SavingsEventType.skipped:
          icon = Icons.pause_circle_outline;
          title = text.get('skipped');
          accent = scheme.tertiary;
      }
    } else {
      icon = plan!.reason == PlanReason.initial
          ? Icons.flag_outlined
          : Icons.alt_route;
      title = plan.reason == PlanReason.initial
          ? text.get('initialPlan')
          : text.get('planChanged');
      accent = scheme.primary;
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 36,
            child: Column(
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 17, color: accent),
                ),
                if (!isLast)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Container(
                        width: 1,
                        color: scheme.outlineVariant.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Container(
                key: Key(
                  event != null
                      ? 'timeline-event-${event.id}'
                      : 'timeline-plan-${plan!.id}',
                ),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    accent.withValues(alpha: 0.035),
                    scheme.surfaceContainerLowest,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: event != null
                      ? _EventTimelineContent(
                          event: event,
                          goal: goal,
                          title: title,
                          date: text.date(item.date),
                          accent: accent,
                          balanceAfterCents: item.balanceAfterCents!,
                        )
                      : _PlanTimelineContent(
                          plan: plan!,
                          goal: goal,
                          title: title,
                          date: text.date(item.date),
                          accent: accent,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventTimelineContent extends StatelessWidget {
  const _EventTimelineContent({
    required this.event,
    required this.goal,
    required this.title,
    required this.date,
    required this.accent,
    required this.balanceAfterCents,
  });

  final SavingsEvent event;
  final SavingsGoal goal;
  final String title;
  final String date;
  final Color accent;
  final int balanceAfterCents;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final amount = switch (event.type) {
      SavingsEventType.deposit => formatMoney(event.amountCents, goal.currency),
      SavingsEventType.withdrawal => formatMoney(
        -event.amountCents,
        goal.currency,
      ),
      SavingsEventType.skipped => '',
    };
    final progress = (balanceAfterCents / goal.targetCents).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _TimelineHeader(title: title, date: date, accent: accent),
        if (amount.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            amount,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (event.note.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Text(event.note),
        ] else if (event.type == SavingsEventType.skipped) ...<Widget>[
          const SizedBox(height: 10),
          Text(text.get('skippedHelp')),
        ],
        const SizedBox(height: 14),
        Text(
          '${text.get('progressAfterEvent')} · '
          '${formatMoney(balanceAfterCents, goal.currency)} / '
          '${formatMoney(goal.targetCents, goal.currency)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            color: accent,
            backgroundColor: accent.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class _PlanTimelineContent extends StatelessWidget {
  const _PlanTimelineContent({
    required this.plan,
    required this.goal,
    required this.title,
    required this.date,
    required this.accent,
  });

  final PlanVersion plan;
  final SavingsGoal goal;
  final String title;
  final String date;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _TimelineHeader(title: title, date: date, accent: accent),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _TimelineMetric(
                icon: Icons.calendar_view_week_outlined,
                label: text.get('weeklyPlan'),
                value: formatMoney(plan.weeklyCents, goal.currency),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TimelineMetric(
                icon: Icons.event_outlined,
                label: text.get('targetDate'),
                value: text.date(plan.targetDate),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimelineHeader extends StatelessWidget {
  const _TimelineHeader({
    required this.title,
    required this.date,
    required this.accent,
  });

  final String title;
  final String date;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              date,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineMetric extends StatelessWidget {
  const _TimelineMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 15, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
