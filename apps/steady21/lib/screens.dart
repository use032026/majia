import 'package:flutter/material.dart';

import 'controller.dart';
import 'copy.dart';
import 'domain.dart';

class BootstrapView extends StatelessWidget {
  const BootstrapView({
    super.key,
    required this.controller,
    required this.copy,
  });

  final AppController controller;
  final AppCopy copy;

  @override
  Widget build(BuildContext context) {
    if (controller.loadError != null) {
      return Scaffold(
        body: ContentFrame(
          child: Center(
            child: Semantics(
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder_off_outlined, size: 52),
                  const SizedBox(height: 16),
                  Text(
                    copy.loadFailed,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(copy.loadFailedBody, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: controller.load,
                    icon: const Icon(Icons.refresh),
                    label: Text(copy.retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (!controller.isReady) {
      return Scaffold(
        body: Center(
          child: Semantics(
            label: copy.loading,
            child: const CircularProgressIndicator(),
          ),
        ),
      );
    }
    return HomeShell(controller: controller, copy: copy);
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller, required this.copy});

  final AppController controller;
  final AppCopy copy;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayScreen(controller: widget.controller, copy: widget.copy),
      JourneyScreen(controller: widget.controller, copy: widget.copy),
      SettingsScreen(controller: widget.controller, copy: widget.copy),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          NavigationDestination(
            key: const Key('todayTab'),
            icon: const Icon(Icons.wb_sunny_outlined),
            selectedIcon: const Icon(Icons.wb_sunny),
            label: widget.copy.today,
          ),
          NavigationDestination(
            key: const Key('journeyTab'),
            icon: const Icon(Icons.route_outlined),
            selectedIcon: const Icon(Icons.route),
            label: widget.copy.journey,
          ),
          NavigationDestination(
            key: const Key('settingsTab'),
            icon: const Icon(Icons.tune_outlined),
            selectedIcon: const Icon(Icons.tune),
            label: widget.copy.settings,
          ),
        ],
      ),
    );
  }
}

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.controller, required this.copy});

  final AppController controller;
  final AppCopy copy;

  @override
  Widget build(BuildContext context) {
    final experiment = controller.snapshot.active;
    return ContentFrame(
      child: CustomScrollView(
        key: const Key('todayScroll'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            sliver: SliverToBoxAdapter(
              child: _PageHeader(
                eyebrow: copy.t('21 天行为实验册', '21-DAY BEHAVIOR LAB'),
                title: copy.today,
                subtitle: copy.t(
                  '记录事实，保留恢复的余地。',
                  'Record what happened. Leave room to restart.',
                ),
              ),
            ),
          ),
          if (experiment == null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyToday(controller: controller, copy: copy),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              sliver: SliverList.list(
                children: [
                  _TodayExperimentCard(
                    controller: controller,
                    copy: copy,
                    experiment: experiment,
                  ),
                  const SizedBox(height: 16),
                  _TodayActions(
                    controller: controller,
                    copy: copy,
                    experiment: experiment,
                  ),
                  const SizedBox(height: 16),
                  _GentleNote(copy: copy),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  const _EmptyToday({required this.controller, required this.copy});

  final AppController controller;
  final AppCopy copy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(Icons.science_outlined, size: 42),
          ),
          const SizedBox(height: 24),
          Text(
            copy.emptyTitle,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(copy.emptyBody, textAlign: TextAlign.center),
          const SizedBox(height: 28),
          FilledButton.icon(
            key: const Key('createExperimentButton'),
            onPressed: () => _openExperimentForm(context, controller, copy),
            icon: const Icon(Icons.add),
            label: Text(copy.createExperiment),
          ),
        ],
      ),
    );
  }
}

class _TodayExperimentCard extends StatelessWidget {
  const _TodayExperimentCard({
    required this.controller,
    required this.copy,
    required this.experiment,
  });

  final AppController controller;
  final AppCopy copy;
  final Experiment experiment;

  @override
  Widget build(BuildContext context) {
    final stats = ExperimentStats(experiment, controller.today);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    experiment.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _TierPill(label: copy.tier(stats.tier)),
              ],
            ),
            const SizedBox(height: 18),
            _LabelValue(
              icon: Icons.bolt_outlined,
              label: copy.cueLabel,
              value: experiment.cue,
            ),
            const SizedBox(height: 14),
            _LabelValue(
              icon: Icons.check_circle_outline,
              label: copy.standardLabel,
              value: experiment.fullAction,
            ),
            const SizedBox(height: 14),
            _LabelValue(
              icon: Icons.spa_outlined,
              label: copy.minimumLabel,
              value: experiment.minimumAction,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: stats.targetProgress,
                      minHeight: 9,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '${stats.practiceDays}/${experiment.targetDays}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayActions extends StatelessWidget {
  const _TodayActions({
    required this.controller,
    required this.copy,
    required this.experiment,
  });

  final AppController controller;
  final AppCopy copy;
  final Experiment experiment;

  @override
  Widget build(BuildContext context) {
    final existing = experiment.entryFor(controller.today);
    if (existing != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    existing.kind == EntryKind.skipped
                        ? Icons.pause_circle_outline
                        : Icons.task_alt,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      copy.entryKind(existing.kind),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(copy.date(existing.date)),
                ],
              ),
              if (existing.note.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(existing.note),
              ],
              const SizedBox(height: 18),
              OutlinedButton.icon(
                key: const Key('editTodayButton'),
                onPressed: () => _openCheckIn(
                  context,
                  controller,
                  copy,
                  experiment,
                  existing.kind,
                ),
                icon: const Icon(Icons.edit_outlined),
                label: Text(copy.editToday),
              ),
              TextButton(
                key: const Key('undoTodayButton'),
                onPressed: controller.isBusy
                    ? null
                    : () async {
                        final confirmed = await _confirm(
                          context,
                          title: copy.undoTitle,
                          body: copy.undoBody,
                          confirm: copy.undoToday,
                        );
                        if (confirmed && context.mounted) {
                          final ok = await controller.undoToday(experiment.id);
                          if (!ok && context.mounted) {
                            _showSaveError(context, copy);
                          }
                        }
                      },
                child: Text(copy.undoToday),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              copy.todayDecision,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (experiment.needsRecoveryBefore(controller.today)) ...[
              const SizedBox(height: 10),
              Text(
                copy.recoveryNeeded,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('checkInFullButton'),
              onPressed: () => _openCheckIn(
                context,
                controller,
                copy,
                experiment,
                EntryKind.full,
              ),
              icon: const Icon(Icons.check),
              label: Text(copy.fullDone),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('checkInMinimumButton'),
              onPressed: () => _openCheckIn(
                context,
                controller,
                copy,
                experiment,
                EntryKind.minimum,
              ),
              icon: const Icon(Icons.spa_outlined),
              label: Text(copy.minimumDone),
            ),
            TextButton.icon(
              key: const Key('checkInSkippedButton'),
              onPressed: () => _openCheckIn(
                context,
                controller,
                copy,
                experiment,
                EntryKind.skipped,
              ),
              icon: const Icon(Icons.pause_outlined),
              label: Text(copy.skipped),
            ),
          ],
        ),
      ),
    );
  }
}

class _GentleNote extends StatelessWidget {
  const _GentleNote({required this.copy});
  final AppCopy copy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: 12),
          Expanded(child: Text(copy.scienceBody)),
        ],
      ),
    );
  }
}

class JourneyScreen extends StatelessWidget {
  const JourneyScreen({
    super.key,
    required this.controller,
    required this.copy,
  });

  final AppController controller;
  final AppCopy copy;

  @override
  Widget build(BuildContext context) {
    final active = controller.snapshot.active;
    final archived = controller.snapshot.archived;
    return ContentFrame(
      child: CustomScrollView(
        key: const Key('journeyScroll'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            sliver: SliverToBoxAdapter(
              child: _PageHeader(
                eyebrow: copy.t('把中断也写进方法里', 'LEARN FROM THE BREAKS'),
                title: copy.journey,
                subtitle: copy.reportIntro,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            sliver: SliverList.list(
              children: [
                if (active == null)
                  _NoActiveCard(copy: copy, controller: controller)
                else
                  _ExperimentReport(
                    controller: controller,
                    copy: copy,
                    experiment: active,
                  ),
                if (archived.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text(
                    copy.archivedExperiments,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...archived.map(
                    (experiment) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ArchivedCard(
                        controller: controller,
                        copy: copy,
                        experiment: experiment,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoActiveCard extends StatelessWidget {
  const _NoActiveCard({required this.copy, required this.controller});
  final AppCopy copy;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(copy.noActive),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openExperimentForm(context, controller, copy),
              icon: const Icon(Icons.add),
              label: Text(copy.createExperiment),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExperimentReport extends StatelessWidget {
  const _ExperimentReport({
    required this.controller,
    required this.copy,
    required this.experiment,
  });

  final AppController controller;
  final AppCopy copy;
  final Experiment experiment;

  @override
  Widget build(BuildContext context) {
    final stats = ExperimentStats(experiment, controller.today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            copy.currentExperiment,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            experiment.title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: copy.t('实验操作', 'Experiment actions'),
                      onSelected: (action) => _handleExperimentAction(
                        context,
                        controller,
                        copy,
                        experiment,
                        action,
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'edit', child: Text(copy.edit)),
                        PopupMenuItem(
                          value: 'archive',
                          child: Text(copy.archive),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(copy.delete),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _TierPill(label: copy.tier(stats.tier)),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: stats.targetProgress,
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${copy.practiceDays}: ${stats.practiceDays}/${experiment.targetDays}',
                ),
                if (stats.targetReached) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${copy.targetReached} · ${copy.continueOrArchive}',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _StatsCard(stats: stats, copy: copy),
        if (stats.dueMilestones.isNotEmpty) ...[
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    copy.milestoneReview,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(copy.reviewQuestion),
                  const SizedBox(height: 14),
                  ...stats.dueMilestones.map(
                    (milestone) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FilledButton.tonalIcon(
                        onPressed: () => _openReview(
                          context,
                          controller,
                          copy,
                          experiment,
                          milestone,
                        ),
                        icon: const Icon(Icons.rate_review_outlined),
                        label: Text(copy.reviewMilestone(milestone)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        _TierPath(copy: copy, active: stats.tier),
        const SizedBox(height: 14),
        _ReviewHistory(
          copy: copy,
          experiment: experiment,
          controller: controller,
        ),
        const SizedBox(height: 14),
        _EntryHistory(copy: copy, experiment: experiment),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats, required this.copy});
  final ExperimentStats stats;
  final AppCopy copy;

  @override
  Widget build(BuildContext context) {
    final items = [
      (copy.practiceDays, copy.days(stats.practiceDays)),
      (copy.currentStreak, copy.days(stats.currentStreak)),
      (copy.bestStreak, copy.days(stats.bestStreak)),
      (copy.recoveries, '${stats.recoveryCount}'),
      (
        copy.calendarRate,
        '${(stats.calendarPracticeRate * 100).clamp(0, 100).round()}%',
      ),
      (
        copy.commonObstacle,
        stats.commonObstacle == null
            ? copy.noObstacle
            : copy.obstacleLabel(stats.commonObstacle!),
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 560
                ? (constraints.maxWidth - 24) / 3
                : (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: items
                  .map(
                    (item) => SizedBox(
                      width: width,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$1,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              item.$2,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}

class _TierPath extends StatelessWidget {
  const _TierPath({required this.copy, required this.active});
  final AppCopy copy;
  final ProgressTier active;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              copy.t('阶段路径', 'Stage path'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            ...progressTiers.map(
              (tier) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      tier == active
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: tier == active
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(copy.tier(tier))),
                    Text(_tierRange(copy, tier)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              copy.t(
                '称号只描述练习里程碑，不代表习惯已经形成。',
                'Titles mark practice milestones; they do not prove a habit has formed.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _tierRange(AppCopy copy, ProgressTier tier) {
    if (tier.minimum == tier.maximum) return copy.dayNumber(tier.minimum);
    if (tier.maximum == null) return '${tier.minimum}+';
    return '${tier.minimum}–${tier.maximum}';
  }
}

class _ReviewHistory extends StatelessWidget {
  const _ReviewHistory({
    required this.copy,
    required this.experiment,
    required this.controller,
  });

  final AppCopy copy;
  final Experiment experiment;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (experiment.reviews.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              copy.milestoneReview,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ...experiment.reviews.map(
              (review) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(copy.reviewMilestone(review.milestone)),
                subtitle: Text(
                  review.note.isEmpty
                      ? copy.decisionLabel(review.decision)
                      : '${copy.decisionLabel(review.decision)}\n${review.note}',
                ),
                isThreeLine: review.note.isNotEmpty,
                trailing: experiment.isArchived
                    ? null
                    : IconButton(
                        tooltip: copy.edit,
                        onPressed: () => _openReview(
                          context,
                          controller,
                          copy,
                          experiment,
                          review.milestone,
                          existing: review,
                        ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryHistory extends StatelessWidget {
  const _EntryHistory({required this.copy, required this.experiment});
  final AppCopy copy;
  final Experiment experiment;

  @override
  Widget build(BuildContext context) {
    final entries = [...experiment.entries]
      ..sort((a, b) => b.date.compareTo(a.date));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              copy.entries,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(copy.noEntries),
              )
            else
              ...entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        entry.kind == EntryKind.skipped
                            ? Icons.pause_circle_outline
                            : Icons.check_circle_outline,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${copy.date(entry.date)} · ${copy.entryKind(entry.kind)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (entry.obstacle != Obstacle.none)
                              Text(
                                '${copy.obstacle}: ${copy.obstacleLabel(entry.obstacle)}',
                              ),
                            if (entry.recoveryPlan != RecoveryPlan.none)
                              Text(
                                '${copy.recovery}: ${copy.recoveryLabel(entry.recoveryPlan)}',
                              ),
                            if (entry.note.isNotEmpty) Text(entry.note),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ArchivedCard extends StatelessWidget {
  const _ArchivedCard({
    required this.controller,
    required this.copy,
    required this.experiment,
  });
  final AppController controller;
  final AppCopy copy;
  final Experiment experiment;

  @override
  Widget build(BuildContext context) {
    final stats = ExperimentStats(
      experiment,
      experiment.archivedAt ?? controller.today,
    );
    return Card(
      child: ExpansionTile(
        key: Key('archivedTile-${experiment.id}'),
        title: Text(
          experiment.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${copy.tier(stats.tier)} · ${copy.days(stats.practiceDays)}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        children: [
          Align(alignment: Alignment.centerLeft, child: Text(copy.reportIntro)),
          const SizedBox(height: 12),
          _ArchivedDefinition(copy: copy, experiment: experiment),
          const SizedBox(height: 12),
          _StatsCard(stats: stats, copy: copy),
          const SizedBox(height: 12),
          _TierPath(copy: copy, active: stats.tier),
          if (experiment.reviews.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ReviewHistory(
              copy: copy,
              experiment: experiment,
              controller: controller,
            ),
          ],
          const SizedBox(height: 12),
          _EntryHistory(copy: copy, experiment: experiment),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: controller.snapshot.active == null
                      ? () async {
                          final ok = await controller.restore(experiment.id);
                          if (!ok && context.mounted) {
                            _showSaveError(context, copy);
                          }
                        }
                      : null,
                  child: Text(copy.restore),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: copy.delete,
                onPressed: () async {
                  final confirmed = await _confirm(
                    context,
                    title: copy.deleteExperimentTitle,
                    body: copy.deleteExperimentBody,
                    confirm: copy.delete,
                    destructive: true,
                  );
                  if (confirmed && context.mounted) {
                    final ok = await controller.deleteExperiment(experiment.id);
                    if (!ok && context.mounted) _showSaveError(context, copy);
                  }
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArchivedDefinition extends StatelessWidget {
  const _ArchivedDefinition({required this.copy, required this.experiment});

  final AppCopy copy;
  final Experiment experiment;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.bolt_outlined, copy.cueLabel, experiment.cue),
      (Icons.check_circle_outline, copy.standardLabel, experiment.fullAction),
      (Icons.spa_outlined, copy.minimumLabel, experiment.minimumAction),
    ];
    return Column(
      key: Key('archivedReport-${experiment.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          experiment.title,
          key: Key('archivedFullTitle-${experiment.id}'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.$1, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$2,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(item.$3),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.copy,
  });

  final AppController controller;
  final AppCopy copy;

  @override
  Widget build(BuildContext context) {
    return ContentFrame(
      child: ListView(
        key: const Key('settingsScroll'),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _PageHeader(
            eyebrow: copy.t('本地优先 · 无账号', 'LOCAL-FIRST · NO ACCOUNT'),
            title: copy.settings,
            subtitle: copy.versionNote,
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.language,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: [
                        ButtonSegment(value: 'zh', label: Text(copy.chinese)),
                        ButtonSegment(value: 'en', label: Text(copy.english)),
                      ],
                      selected: {controller.snapshot.localeCode},
                      onSelectionChanged: controller.isBusy
                          ? null
                          : (selection) async {
                              final ok = await controller.setLocale(
                                selection.single,
                              );
                              if (!ok && context.mounted) {
                                _showSaveError(context, copy);
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _InfoCard(
            title: copy.privacy,
            body: copy.privacyBody,
            icon: Icons.lock_outline,
          ),
          const SizedBox(height: 14),
          _InfoCard(
            title: copy.scienceBoundary,
            body: copy.scienceBody,
            icon: Icons.science_outlined,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: const Key('deleteAllButton'),
            onPressed:
                controller.snapshot.experiments.isEmpty || controller.isBusy
                ? null
                : () async {
                    final confirmed = await _confirm(
                      context,
                      title: copy.deleteAllTitle,
                      body: copy.deleteAllBody,
                      confirm: copy.deleteAll,
                      destructive: true,
                    );
                    if (confirmed && context.mounted) {
                      final ok = await controller.deleteAll();
                      if (!ok && context.mounted) _showSaveError(context, copy);
                    }
                  },
            icon: const Icon(Icons.delete_forever_outlined),
            label: Text(copy.deleteAll),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.body,
    required this.icon,
  });
  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExperimentFormPage extends StatefulWidget {
  const ExperimentFormPage({
    super.key,
    required this.controller,
    required this.copy,
    this.existing,
  });

  final AppController controller;
  final AppCopy copy;
  final Experiment? existing;

  @override
  State<ExperimentFormPage> createState() => _ExperimentFormPageState();
}

class _ExperimentFormPageState extends State<ExperimentFormPage> {
  late final TextEditingController _title;
  late final TextEditingController _cue;
  late final TextEditingController _full;
  late final TextEditingController _minimum;
  late final TextEditingController _target;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _cue = TextEditingController(text: existing?.cue ?? '');
    _full = TextEditingController(text: existing?.fullAction ?? '');
    _minimum = TextEditingController(text: existing?.minimumAction ?? '');
    _target = TextEditingController(text: '${existing?.targetDays ?? 21}');
  }

  @override
  void dispose() {
    _title.dispose();
    _cue.dispose();
    _full.dispose();
    _minimum.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final target = int.tryParse(_target.text.trim());
    if (target == null || target < 1 || target > 365) {
      setState(() => _error = widget.copy.targetRange);
      return;
    }
    if ([
      _title,
      _cue,
      _full,
      _minimum,
    ].any((value) => value.text.trim().isEmpty)) {
      setState(() => _error = widget.copy.required);
      return;
    }
    try {
      final ok = widget.existing == null
          ? await widget.controller.createExperiment(
              title: _title.text,
              cue: _cue.text,
              fullAction: _full.text,
              minimumAction: _minimum.text,
              targetDays: target,
            )
          : await widget.controller.updateExperiment(
              id: widget.existing!.id,
              title: _title.text,
              cue: _cue.text,
              fullAction: _full.text,
              minimumAction: _minimum.text,
              targetDays: target,
            );
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
      } else {
        setState(() => _error = widget.copy.saveFailed);
      }
    } on DomainValidationException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.code == 'active_exists'
            ? widget.copy.activeExists
            : widget.copy.required;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? widget.copy.createExperiment
              : widget.copy.edit,
        ),
        leading: IconButton(
          tooltip: widget.copy.cancel,
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ),
      body: ContentFrame(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            TextField(
              key: const Key('titleField'),
              controller: _title,
              textInputAction: TextInputAction.next,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: widget.copy.experimentTitle,
                hintText: widget.copy.experimentTitleHint,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('cueField'),
              controller: _cue,
              textInputAction: TextInputAction.next,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: widget.copy.cue,
                hintText: widget.copy.cueHint,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('fullActionField'),
              controller: _full,
              textInputAction: TextInputAction.next,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: widget.copy.fullAction,
                hintText: widget.copy.fullActionHint,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('minimumActionField'),
              controller: _minimum,
              textInputAction: TextInputAction.next,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: widget.copy.minimumAction,
                hintText: widget.copy.minimumActionHint,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('targetDaysField'),
              controller: _target,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: widget.copy.targetDays,
                helperText: widget.copy.targetDaysHelp,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('saveExperimentButton'),
              onPressed: widget.controller.isBusy ? null : _submit,
              child: Text(
                widget.existing == null
                    ? widget.copy.create
                    : widget.copy.update,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CheckInSheet extends StatefulWidget {
  const CheckInSheet({
    super.key,
    required this.controller,
    required this.copy,
    required this.experiment,
    required this.initialKind,
  });

  final AppController controller;
  final AppCopy copy;
  final Experiment experiment;
  final EntryKind initialKind;

  @override
  State<CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<CheckInSheet> {
  late EntryKind _kind;
  late Obstacle _obstacle;
  late RecoveryPlan _recovery;
  late final TextEditingController _note;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.experiment.entryFor(widget.controller.today);
    _kind = existing?.kind ?? widget.initialKind;
    _obstacle = existing?.obstacle ?? Obstacle.none;
    _recovery = existing?.recoveryPlan ?? RecoveryPlan.none;
    _note = TextEditingController(text: existing?.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    try {
      final ok = await widget.controller.saveEntry(
        experimentId: widget.experiment.id,
        kind: _kind,
        obstacle: _obstacle,
        recoveryPlan: _recovery,
        note: _note.text,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
      } else {
        setState(() => _error = widget.copy.saveFailed);
      }
    } on DomainValidationException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = switch (error.code) {
          'obstacle_required' => widget.copy.obstacleRequired,
          'recovery_required' => widget.copy.recoveryRequired,
          _ => widget.copy.saveFailed,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsRecovery = widget.experiment.needsRecoveryBefore(
      widget.controller.today,
    );
    final showRecovery = _kind == EntryKind.skipped || needsRecovery;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          key: const Key('checkInSheet'),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.copy.todayDecision,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              SegmentedButton<EntryKind>(
                segments: [
                  ButtonSegment(
                    value: EntryKind.full,
                    label: Text(widget.copy.t('标准', 'Standard')),
                  ),
                  ButtonSegment(
                    value: EntryKind.minimum,
                    label: Text(widget.copy.t('最低', 'Minimum')),
                  ),
                  ButtonSegment(
                    value: EntryKind.skipped,
                    label: Text(widget.copy.t('暂停', 'Pause')),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (selection) => setState(() {
                  _kind = selection.single;
                  _error = null;
                }),
              ),
              if (_kind == EntryKind.skipped) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<Obstacle>(
                  key: const Key('obstacleField'),
                  initialValue: _obstacle,
                  decoration: InputDecoration(labelText: widget.copy.obstacle),
                  items: Obstacle.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(widget.copy.obstacleLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _obstacle = value ?? Obstacle.none),
                ),
              ],
              if (showRecovery) ...[
                const SizedBox(height: 16),
                if (needsRecovery) Text(widget.copy.recoveryNeeded),
                const SizedBox(height: 8),
                DropdownButtonFormField<RecoveryPlan>(
                  key: const Key('recoveryField'),
                  initialValue: _recovery,
                  decoration: InputDecoration(labelText: widget.copy.recovery),
                  items: RecoveryPlan.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(widget.copy.recoveryLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _recovery = value ?? RecoveryPlan.none),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                key: const Key('entryNoteField'),
                controller: _note,
                maxLength: 240,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: widget.copy.note,
                  hintText: widget.copy.noteHint,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('saveEntryButton'),
                onPressed: widget.controller.isBusy ? null : _submit,
                child: Text(widget.copy.saveEntry),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(widget.copy.cancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MilestoneReviewSheet extends StatefulWidget {
  const MilestoneReviewSheet({
    super.key,
    required this.controller,
    required this.copy,
    required this.experiment,
    required this.milestone,
    this.existing,
  });

  final AppController controller;
  final AppCopy copy;
  final Experiment experiment;
  final int milestone;
  final MilestoneReview? existing;

  @override
  State<MilestoneReviewSheet> createState() => _MilestoneReviewSheetState();
}

class _MilestoneReviewSheetState extends State<MilestoneReviewSheet> {
  late ReviewDecision _decision;
  late final TextEditingController _note;
  String? _error;

  @override
  void initState() {
    super.initState();
    _decision = widget.existing?.decision ?? ReviewDecision.keep;
    _note = TextEditingController(text: widget.existing?.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    try {
      final ok = await widget.controller.saveMilestoneReview(
        experimentId: widget.experiment.id,
        milestone: widget.milestone,
        decision: _decision,
        note: _note.text,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
      } else {
        setState(() => _error = widget.copy.saveFailed);
      }
    } on DomainValidationException catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error.code == 'milestone_not_reached'
            ? widget.copy.milestoneNoLongerReached
            : widget.copy.saveFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.copy.reviewMilestone(widget.milestone),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(widget.copy.reviewQuestion),
              const SizedBox(height: 16),
              RadioGroup<ReviewDecision>(
                groupValue: _decision,
                onChanged: (value) =>
                    setState(() => _decision = value ?? _decision),
                child: Column(
                  children: ReviewDecision.values
                      .map(
                        (decision) => RadioListTile<ReviewDecision>(
                          contentPadding: EdgeInsets.zero,
                          value: decision,
                          title: Text(widget.copy.decisionLabel(decision)),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                maxLength: 240,
                maxLines: 3,
                decoration: InputDecoration(labelText: widget.copy.reviewNote),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _submit, child: Text(widget.copy.save)),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(widget.copy.cancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ContentFrame extends StatelessWidget {
  const ContentFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: child,
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });
  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.5,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          title,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(subtitle),
      ],
    );
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 3),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TierPill extends StatelessWidget {
  const _TierPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

Future<void> _openExperimentForm(
  BuildContext context,
  AppController controller,
  AppCopy copy, {
  Experiment? existing,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ExperimentFormPage(
        controller: controller,
        copy: copy,
        existing: existing,
      ),
    ),
  );
}

Future<void> _openCheckIn(
  BuildContext context,
  AppController controller,
  AppCopy copy,
  Experiment experiment,
  EntryKind kind,
) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (_) => CheckInSheet(
      controller: controller,
      copy: copy,
      experiment: experiment,
      initialKind: kind,
    ),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(copy.entrySaved)));
  }
}

Future<void> _openReview(
  BuildContext context,
  AppController controller,
  AppCopy copy,
  Experiment experiment,
  int milestone, {
  MilestoneReview? existing,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => MilestoneReviewSheet(
      controller: controller,
      copy: copy,
      experiment: experiment,
      milestone: milestone,
      existing: existing,
    ),
  );
}

Future<void> _handleExperimentAction(
  BuildContext context,
  AppController controller,
  AppCopy copy,
  Experiment experiment,
  String action,
) async {
  if (action == 'edit') {
    await _openExperimentForm(context, controller, copy, existing: experiment);
    return;
  }
  final isArchive = action == 'archive';
  final confirmed = await _confirm(
    context,
    title: isArchive ? copy.archiveTitle : copy.deleteExperimentTitle,
    body: isArchive ? copy.archiveBody : copy.deleteExperimentBody,
    confirm: isArchive ? copy.archive : copy.delete,
    destructive: !isArchive,
  );
  if (!confirmed || !context.mounted) return;
  final ok = isArchive
      ? await controller.archive(experiment.id)
      : await controller.deleteExperiment(experiment.id);
  if (!ok && context.mounted) _showSaveError(context, copy);
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  bool destructive = false,
}) async {
  final copy = AppCopy(
    Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'zh',
  );
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(copy.cancel),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    )
                  : null,
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirm),
            ),
          ],
        ),
      ) ??
      false;
}

void _showSaveError(BuildContext context, AppCopy copy) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(copy.saveFailed)));
}
