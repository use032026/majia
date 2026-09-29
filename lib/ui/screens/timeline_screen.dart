import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/money.dart';
import '../../l10n/app_text.dart';
import '../../state/app_controller.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final goal = controller.goal!;
    final items = <_TimelineItem>[
      ...goal.events.map(_TimelineItem.event),
      ...goal.plans.map(_TimelineItem.plan),
    ]..sort((a, b) => b.date.compareTo(a.date));
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: CustomScrollView(
            key: const PageStorageKey<String>('timeline-scroll'),
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        text.get('timeline'),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${text.eventCount(goal.events.length)} · ${text.planCount(goal.plans.length)}',
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        key: const Key('copy-summary'),
                        onPressed: () => _copy(context),
                        icon: const Icon(Icons.copy_all_outlined),
                        label: Text(text.get('copySummary')),
                      ),
                    ],
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
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  sliver: SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) => _TimelineTile(
                      item: items[index],
                      goal: goal,
                      isLast: index == items.length - 1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    final copied = await controller.copySummary();
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
  _TimelineItem.event(SavingsEvent value)
    : event = value,
      plan = null,
      date = value.occurredAt;

  _TimelineItem.plan(PlanVersion value)
    : event = null,
      plan = value,
      date = value.effectiveAt;

  final SavingsEvent? event;
  final PlanVersion? plan;
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
    final event = item.event;
    final plan = item.plan;
    late final IconData icon;
    late final String title;
    late final String detail;
    if (event != null) {
      switch (event.type) {
        case SavingsEventType.deposit:
          icon = Icons.south_west;
          title = text.get('deposit');
          detail = formatMoney(event.amountCents, goal.currency);
        case SavingsEventType.withdrawal:
          icon = Icons.north_east;
          title = text.get('withdrawal');
          detail = formatMoney(-event.amountCents, goal.currency);
        case SavingsEventType.skipped:
          icon = Icons.pause_circle_outline;
          title = text.get('skipped');
          detail = event.note;
      }
    } else {
      icon = plan!.reason == PlanReason.initial
          ? Icons.flag_outlined
          : Icons.alt_route;
      title = plan.reason == PlanReason.initial
          ? text.get('initialPlan')
          : text.get('planChanged');
      detail =
          '${text.get('weeklyPlan')}: ${formatMoney(plan.weeklyCents, goal.currency)}\n'
          '${text.get('targetDate')}: ${text.date(plan.targetDate)}';
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 44,
            child: Column(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        text.date(item.date),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (detail.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(detail),
                      ],
                      if (event != null &&
                          event.note.isNotEmpty &&
                          event.type != SavingsEventType.skipped) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(event.note),
                      ],
                    ],
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
