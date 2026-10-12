import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import 'controller.dart';
import 'copy.dart';
import 'domain.dart';
import 'privacy_web_page.dart';
import 'onboarding.dart';

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/onboarding/seed.png',
                  width: 168,
                  height: 168,
                ),
                const SizedBox(height: 12),
                Text(
                  copy.appName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      );
    }
    if (!controller.snapshot.onboardingComplete) {
      return OnboardingView(controller: controller, copy: copy);
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
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
        activeColor: Theme.of(context).colorScheme.primary,
        inactiveColor: Theme.of(context).colorScheme.onSurfaceVariant,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.55),
            width: 0.5,
          ),
        ),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(CupertinoIcons.sun_max, key: Key('todayTab')),
            label: widget.copy.today,
          ),
          BottomNavigationBarItem(
            icon: const Icon(CupertinoIcons.chart_bar, key: Key('journeyTab')),
            label: widget.copy.journey,
          ),
          BottomNavigationBarItem(
            icon: const Icon(
              CupertinoIcons.slider_horizontal_3,
              key: Key('settingsTab'),
            ),
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
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            sliver: SliverToBoxAdapter(child: _TodayHeader(copy: copy)),
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
                  const SizedBox(height: 14),
                  _TodayActions(
                    controller: controller,
                    copy: copy,
                    experiment: experiment,
                  ),
                  const SizedBox(height: 14),
                  _GentleNote(copy: copy),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.copy});

  final AppCopy copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 14,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                copy.t('21 天行为实验册', '21-DAY BEHAVIOR LAB'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          copy.today,
          style: theme.textTheme.displaySmall?.copyWith(
            fontSize: 44,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          copy.t(
            '记录事实，保留恢复的余地。',
            'Record what happened. Leave room to restart.',
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.3,
          ),
        ),
      ],
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
    final overall = JourneyTotals(controller.snapshot);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = scheme.surfaceContainer;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base,
            Color.alphaBlend(
              scheme.primaryContainer.withValues(alpha: 0.24),
              base,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    copy.t('当前实验', 'CURRENT EXPERIMENT'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                _TierPill(label: copy.tier(overall.tier)),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              experiment.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 17),
            _LabelValue(
              icon: Icons.bolt_outlined,
              label: copy.cueLabel,
              value: experiment.cue,
            ),
            const SizedBox(height: 10),
            _LabelValue(
              icon: Icons.check_circle_outline,
              label: copy.standardLabel,
              value: experiment.fullAction,
            ),
            const SizedBox(height: 10),
            _LabelValue(
              icon: Icons.spa_outlined,
              label: copy.minimumLabel,
              value: experiment.minimumAction,
            ),
            const SizedBox(height: 17),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: Text(
                    copy.progress,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  '${stats.practiceDays} / ${experiment.targetDays}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: stats.targetProgress,
                minHeight: 7,
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
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
      return _TodayPanel(
        child: Padding(
          padding: const EdgeInsets.all(18),
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
              const SizedBox(height: 14),
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
    return _TodayPanel(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              copy.todayDecision,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: copy.isZh ? 20 : 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
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
            const SizedBox(height: 14),
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

class _TodayPanel extends StatelessWidget {
  const _TodayPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          scheme.primaryContainer.withValues(alpha: 0.38),
          scheme.surfaceContainer,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.12)),
      ),
      child: child,
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
    final totals = JourneyTotals(controller.snapshot);
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
                _JourneyOverviewCard(
                  key: const Key('journeyPracticeLink'),
                  icon: CupertinoIcons.chart_bar_fill,
                  title: copy.practiceDays,
                  value: copy.days(totals.practiceDays),
                  subtitle: copy.t('所有实验的练习日', 'Across all experiments'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _JourneyPracticePage(
                        controller: controller,
                        copy: copy,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _JourneyOverviewCard(
                  key: const Key('journeyStageLink'),
                  icon: CupertinoIcons.flag_fill,
                  title: copy.stagePath,
                  value: copy.tier(totals.tier),
                  subtitle: copy.t('按累计练习日推进', 'Based on all practice days'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          _JourneyStagePage(controller: controller, copy: copy),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
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

class _JourneyOverviewCard extends StatelessWidget {
  const _JourneyOverviewCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.labelMedium),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 17,
                color: scheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyPracticePage extends StatelessWidget {
  const _JourneyPracticePage({required this.controller, required this.copy});

  final AppController controller;
  final AppCopy copy;

  @override
  Widget build(BuildContext context) {
    final totals = JourneyTotals(controller.snapshot);
    final experiments = controller.snapshot.experiments.reversed.toList();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('journeyDetailBackButton'),
          tooltip: copy.t('返回历程', 'Back to Journey'),
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(copy.practiceDays),
      ),
      body: ContentFrame(
        child: ListView(
          key: const Key('journeyPracticePage'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _JourneyDetailHero(
              title: copy.days(totals.practiceDays),
              subtitle: copy.t(
                '汇总所有实验中有行动的日期；同一天练习多个实验，只计一天。',
                'Counts dates with practice across every experiment. Multiple experiments on one date count as one day.',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _JourneyMetric(
                    label: copy.t('标准行动记录', 'Standard entries'),
                    value: '${totals.fullEntries}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _JourneyMetric(
                    label: copy.t('最低行动记录', 'Minimum entries'),
                    value: '${totals.minimumEntries}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              copy.t('各实验的练习', 'Practice by experiment'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (experiments.isEmpty)
              Text(copy.noEntries)
            else
              ...experiments.map((experiment) {
                final days = experiment.entries
                    .where((entry) => entry.isPractice)
                    .length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      title: Text(experiment.title),
                      subtitle: Text(
                        experiment.isArchived
                            ? copy.archivedExperiments
                            : copy.currentExperiment,
                      ),
                      trailing: Text(
                        copy.days(days),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _JourneyStagePage extends StatelessWidget {
  const _JourneyStagePage({required this.controller, required this.copy});

  final AppController controller;
  final AppCopy copy;

  @override
  Widget build(BuildContext context) {
    final totals = JourneyTotals(controller.snapshot);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('journeyDetailBackButton'),
          tooltip: copy.t('返回历程', 'Back to Journey'),
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(copy.stagePath),
      ),
      body: ContentFrame(
        child: ListView(
          key: const Key('journeyStagePage'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _JourneyDetailHero(
              title: copy.tier(totals.tier),
              subtitle: copy.t(
                '累计练习 ${totals.practiceDays} 天 · 阶段由所有实验的练习日决定。',
                '${totals.practiceDays} practice days · Your stage follows all experiments.',
              ),
            ),
            const SizedBox(height: 16),
            _TierPath(copy: copy, totals: totals),
          ],
        ),
      ),
    );
  }
}

class _JourneyDetailHero extends StatelessWidget {
  const _JourneyDetailHero({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineLarge?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _JourneyMetric extends StatelessWidget {
  const _JourneyMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
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
                    IconButton(
                      key: const Key('experimentActionsButton'),
                      tooltip: copy.t('实验操作', 'Experiment actions'),
                      icon: const Icon(CupertinoIcons.ellipsis),
                      onPressed: () async {
                        final action = await _showIosChoices<String>(
                          context,
                          title: copy.t('实验操作', 'Experiment actions'),
                          cancel: copy.cancel,
                          choices: [
                            _IosChoice('edit', copy.edit),
                            _IosChoice('archive', copy.archive),
                            _IosChoice(
                              'delete',
                              copy.delete,
                              destructive: true,
                            ),
                          ],
                        );
                        if (action != null && context.mounted) {
                          await _handleExperimentAction(
                            context,
                            controller,
                            copy,
                            experiment,
                            action,
                          );
                        }
                      },
                    ),
                  ],
                ),
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
                  '${copy.t('本实验进度', 'Experiment progress')}: ${stats.practiceDays}/${experiment.targetDays}',
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
        _ReviewHistory(
          copy: copy,
          experiment: experiment,
          controller: controller,
        ),
        const SizedBox(height: 14),
        _ObservationLink(copy: copy, experiment: experiment),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rate = stats.calendarPracticeRate.clamp(0, 1).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              copy.t('练习节奏', 'Practice rhythm'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _StreakTile(
                      key: const Key('currentStreakTile'),
                      icon: CupertinoIcons.flame_fill,
                      label: copy.currentStreak,
                      value: copy.days(stats.currentStreak),
                      highlighted: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StreakTile(
                      key: const Key('bestStreakTile'),
                      icon: CupertinoIcons.star_fill,
                      label: copy.bestStreak,
                      value: copy.days(stats.bestStreak),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    copy.calendarRate,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                Text(
                  '${(rate * 100).round()}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: rate,
                minHeight: 7,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _StatDetailRow(
                    icon: CupertinoIcons.arrow_counterclockwise,
                    label: copy.recoveries,
                    value: '${stats.recoveryCount}',
                  ),
                  Divider(height: 20, color: scheme.outlineVariant),
                  _StatDetailRow(
                    icon: CupertinoIcons.text_bubble,
                    label: copy.commonObstacle,
                    value: stats.commonObstacle == null
                        ? copy.noObstacle
                        : copy.obstacleLabel(stats.commonObstacle!),
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

class _StreakTile extends StatelessWidget {
  const _StreakTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlighted
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary, size: 20),
          const SizedBox(height: 10),
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDetailRow extends StatelessWidget {
  const _StatDetailRow({
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: scheme.primary),
        const SizedBox(width: 9),
        Expanded(flex: 2, child: Text(label)),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _TierPath extends StatelessWidget {
  const _TierPath({required this.copy, required this.totals});

  final AppCopy copy;
  final JourneyTotals totals;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 3 : 2;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: gap,
              runSpacing: 12,
              children: [
                for (final tier in progressTiers)
                  SizedBox(
                    width: width,
                    child: _TierBadge(
                      key: Key('stageBadge-${tier.minimum}'),
                      copy: copy,
                      tier: tier,
                      earnedDateKey: totals.earnedDateKey(tier),
                      current: tier == totals.tier,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              copy.t(
                '徽章只描述练习里程碑，不代表习惯已经形成。',
                'Badges mark practice milestones; they do not prove a habit has formed.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({
    super.key,
    required this.copy,
    required this.tier,
    required this.earnedDateKey,
    required this.current,
  });

  final AppCopy copy;
  final ProgressTier tier;
  final String? earnedDateKey;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unlocked = earnedDateKey != null;
    final foreground = unlocked
        ? scheme.onSurface
        : scheme.onSurfaceVariant.withValues(alpha: 0.7);
    return Material(
      color: unlocked
          ? scheme.primaryContainer.withValues(alpha: 0.5)
          : scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: current && unlocked
              ? scheme.primary.withValues(alpha: 0.5)
              : scheme.outlineVariant.withValues(alpha: 0.7),
          width: current && unlocked ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showCupertinoDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (_) => _BadgeDetailDialog(
            copy: copy,
            tier: tier,
            earnedDateKey: earnedDateKey,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 148),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _BadgeMedallion(tier: tier, unlocked: unlocked, size: 72),
                const SizedBox(height: 11),
                Text(
                  copy.tier(tier),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeMedallion extends StatelessWidget {
  const _BadgeMedallion({
    required this.tier,
    required this.unlocked,
    required this.size,
  });

  final ProgressTier tier;
  final bool unlocked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: unlocked
            ? scheme.primary
            : scheme.onSurfaceVariant.withValues(alpha: 0.38),
        border: Border.all(
          color: unlocked
              ? scheme.onPrimary.withValues(alpha: 0.8)
              : scheme.outlineVariant,
          width: 4,
        ),
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Icon(
        _tierIcon(tier),
        size: size * 0.45,
        color: unlocked ? scheme.onPrimary : scheme.surface,
      ),
    );
  }
}

class _BadgeDetailDialog extends StatefulWidget {
  const _BadgeDetailDialog({
    required this.copy,
    required this.tier,
    required this.earnedDateKey,
  });

  final AppCopy copy;
  final ProgressTier tier;
  final String? earnedDateKey;

  @override
  State<_BadgeDetailDialog> createState() => _BadgeDetailDialogState();
}

class _BadgeDetailDialogState extends State<_BadgeDetailDialog> {
  final _shareImageKey = GlobalKey();
  bool _sharing = false;

  Future<void> _shareBadge(BuildContext shareContext) async {
    if (_sharing || widget.earnedDateKey == null) return;
    setState(() => _sharing = true);
    try {
      final boundary =
          _shareImageKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Badge is not ready');
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('Badge image is empty');
      if (!shareContext.mounted) return;
      final box = shareContext.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png'),
          ],
          fileNameOverrides: ['steady21-badge-${widget.tier.minimum}.png'],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) _showIosToast(context, widget.copy.shareFailed);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unlocked = widget.earnedDateKey != null;
    return Dialog(
      key: const Key('badgeDetailDialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  key: const Key('closeBadgeDialog'),
                  tooltip: widget.copy.close,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(CupertinoIcons.xmark_circle_fill),
                ),
              ),
              RepaintBoundary(
                key: _shareImageKey,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
                  decoration: BoxDecoration(
                    color: unlocked
                        ? scheme.primaryContainer.withValues(alpha: 0.55)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [
                      _BadgeMedallion(
                        tier: widget.tier,
                        unlocked: unlocked,
                        size: 104,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.copy.tier(widget.tier),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 14),
                      if (widget.earnedDateKey case final dateKey?) ...[
                        Text(
                          widget.copy.achievementDate,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.copy.date(dateKey),
                          key: const Key('badgeAchievementDate'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ] else
                        Text(
                          widget.copy.badgeLocked,
                          key: const Key('badgeNotEarned'),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
              ),
              if (unlocked) ...[
                const SizedBox(height: 16),
                Builder(
                  builder: (shareContext) => SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      key: const Key('shareBadgeInDialog'),
                      onPressed: _sharing
                          ? null
                          : () => _shareBadge(shareContext),
                      child: Text(widget.copy.shareBadge),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

IconData _tierIcon(ProgressTier tier) => switch (tier.minimum) {
  0 => Icons.lightbulb_outline,
  1 => Icons.directions_walk_rounded,
  7 => Icons.auto_graph_rounded,
  15 => Icons.local_fire_department_outlined,
  21 => Icons.emoji_events_outlined,
  22 => Icons.verified_outlined,
  _ => Icons.all_inclusive_rounded,
};

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

class _ObservationLink extends StatelessWidget {
  const _ObservationLink({required this.copy, required this.experiment});
  final AppCopy copy;
  final Experiment experiment;

  @override
  Widget build(BuildContext context) {
    final entries = [...experiment.entries]
      ..sort((a, b) => b.date.compareTo(a.date));
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: InkWell(
        key: Key('observationLink-${experiment.id}'),
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) =>
                _ObservationListPage(copy: copy, experiment: experiment),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  CupertinoIcons.calendar,
                  size: 22,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.entries,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entries.isEmpty
                          ? copy.noEntries
                          : copy.t(
                              '已有 ${entries.length} 个观察日',
                              '${entries.length} ${entries.length == 1 ? 'day' : 'days'} recorded',
                            ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 17,
                color: scheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ObservationListPage extends StatelessWidget {
  const _ObservationListPage({required this.copy, required this.experiment});

  final AppCopy copy;
  final Experiment experiment;

  @override
  Widget build(BuildContext context) {
    final entries = [...experiment.entries]
      ..sort((a, b) => b.date.compareTo(a.date));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('observationListBackButton'),
          tooltip: copy.t('返回历程', 'Back to Journey'),
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(copy.entries),
      ),
      body: ContentFrame(
        child: ListView(
          key: const Key('observationListPage'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              experiment.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              copy.t(
                '${entries.length} 个有记录的日期',
                '${entries.length} dates with observations',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            if (entries.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Text(copy.noEntries),
                ),
              )
            else
              ...entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Card(
                    child: InkWell(
                      key: Key('observationDate-${entry.date}'),
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) => _ObservationDetailPage(
                            copy: copy,
                            experiment: experiment,
                            entry: entry,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 17,
                          vertical: 15,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              entry.kind == EntryKind.skipped
                                  ? CupertinoIcons.pause_circle
                                  : CupertinoIcons.checkmark_circle,
                              color: scheme.primary,
                              size: 23,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    copy.date(entry.date),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    copy.entryKind(entry.kind),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              CupertinoIcons.chevron_forward,
                              color: scheme.primary,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ObservationDetailPage extends StatelessWidget {
  const _ObservationDetailPage({
    required this.copy,
    required this.experiment,
    required this.entry,
  });

  final AppCopy copy;
  final Experiment experiment;
  final DailyEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final action = switch (entry.kind) {
      EntryKind.full => experiment.fullAction,
      EntryKind.minimum => experiment.minimumAction,
      EntryKind.skipped => null,
    };
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('observationDetailBackButton'),
          tooltip: copy.t('返回日期列表', 'Back to dates'),
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(copy.t('当日观察', 'Day observation')),
      ),
      body: ContentFrame(
        child: ListView(
          key: const Key('observationDetailPage'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              experiment.title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              copy.date(entry.date),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.entryKind(entry.kind),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (action != null) ...[
                      const SizedBox(height: 18),
                      _ObservationField(
                        label: copy.t('当日行动', 'Action'),
                        value: action,
                      ),
                    ],
                    const SizedBox(height: 18),
                    _ObservationField(
                      label: copy.t('观察笔记', 'Observation note'),
                      value: entry.note.isEmpty
                          ? copy.t(
                              '这一天没有填写文字观察',
                              'No written note for this day',
                            )
                          : entry.note,
                    ),
                    if (entry.obstacle != Obstacle.none) ...[
                      const SizedBox(height: 18),
                      _ObservationField(
                        label: copy.obstacle,
                        value: copy.obstacleLabel(entry.obstacle),
                      ),
                    ],
                    if (entry.recoveryPlan != RecoveryPlan.none) ...[
                      const SizedBox(height: 18),
                      _ObservationField(
                        label: copy.recovery,
                        value: copy.recoveryLabel(entry.recoveryPlan),
                      ),
                    ],
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

class _ObservationField extends StatelessWidget {
  const _ObservationField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 5),
        Text(value, style: theme.textTheme.bodyLarge),
      ],
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
    final scheme = Theme.of(context).colorScheme;
    final archivedDate = copy.date(
      localDateKey(experiment.archivedAt ?? controller.today),
    );
    return Card(
      child: InkWell(
        key: Key('archivedExperimentLink-${experiment.id}'),
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => _ArchivedExperimentPage(
              controller: controller,
              copy: copy,
              experiment: experiment,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  CupertinoIcons.archivebox,
                  color: scheme.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      experiment.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${copy.t('练习', 'Practice')} ${copy.days(stats.practiceDays)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${copy.t('归档于', 'Archived')} $archivedDate',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 16,
                color: scheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchivedExperimentPage extends StatelessWidget {
  const _ArchivedExperimentPage({
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
    final scheme = Theme.of(context).colorScheme;
    final archivedDate = copy.date(
      localDateKey(experiment.archivedAt ?? controller.today),
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('archivedDetailBackButton'),
          tooltip: copy.t('返回历程', 'Back to Journey'),
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(copy.t('已归档实验', 'Archived experiment')),
      ),
      body: ContentFrame(
        child: ListView(
          key: Key('archivedExperimentPage-${experiment.id}'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              '${copy.t('归档于', 'Archived')} $archivedDate',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ArchivedDefinition(copy: copy, experiment: experiment),
                    const SizedBox(height: 18),
                    Text(copy.reportIntro),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _StatsCard(stats: stats, copy: copy),
            if (experiment.reviews.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ReviewHistory(
                copy: copy,
                experiment: experiment,
                controller: controller,
              ),
            ],
            const SizedBox(height: 14),
            _ObservationLink(copy: copy, experiment: experiment),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('restoreArchivedButton'),
                    onPressed: controller.snapshot.active == null
                        ? () async {
                            final ok = await controller.restore(experiment.id);
                            if (!context.mounted) return;
                            if (ok) {
                              Navigator.of(context).pop();
                            } else {
                              _showSaveError(context, copy);
                            }
                          }
                        : null,
                    child: Text(copy.restore),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  key: const Key('deleteArchivedButton'),
                  tooltip: copy.delete,
                  onPressed: () async {
                    final confirmed = await _confirm(
                      context,
                      title: copy.deleteExperimentTitle,
                      body: copy.deleteExperimentBody,
                      confirm: copy.delete,
                      destructive: true,
                    );
                    if (!confirmed || !context.mounted) return;
                    final ok = await controller.deleteExperiment(experiment.id);
                    if (!context.mounted) return;
                    if (ok) {
                      Navigator.of(context).pop();
                    } else {
                      _showSaveError(context, copy);
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ContentFrame(
      child: ListView(
        key: const Key('settingsScroll'),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
        children: [
          _PageHeader(
            eyebrow: copy.t('偏好与资料', 'PREFERENCES & INFO'),
            title: copy.settings,
            subtitle: copy.t(
              '管理语言，了解记录与数据。',
              'Manage your language and understand your data.',
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _SettingsIcon(icon: CupertinoIcons.globe),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              copy.language,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              copy.t('应用显示语言', 'App display language'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<String>(
                      groupValue: controller.snapshot.localeCode,
                      backgroundColor: scheme.surfaceContainerHighest,
                      thumbColor: scheme.primaryContainer,
                      children: {
                        'zh': Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            copy.chinese,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        'en': Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            copy.english,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      },
                      onValueChanged: (value) async {
                        if (controller.isBusy || value == null) return;
                        final ok = await controller.setLocale(value);
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
          const SizedBox(height: 25),
          Text(
            copy.t('了解更多', 'Learn more'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                _SettingsActionRow(
                  key: const Key('privacyPolicyLink'),
                  icon: CupertinoIcons.lock,
                  title: copy.privacy,
                  subtitle: copy.t(
                    '数据存储、备份与删除',
                    'Storage, backups, and deletion',
                  ),
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => PrivacyWebPage(copy: copy),
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  indent: 70,
                  endIndent: 18,
                  color: scheme.outlineVariant,
                ),
                _SettingsActionRow(
                  key: const Key('aboutDaysLink'),
                  icon: CupertinoIcons.info,
                  title: copy.scienceBoundary,
                  subtitle: copy.t(
                    '为什么以 21 天作为复盘节点',
                    'Why 21 days is a reflection point',
                  ),
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => _AboutDaysPage(copy: copy),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          Text(
            copy.t('数据管理', 'Data management'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: _SettingsActionRow(
              key: const Key('deleteAllButton'),
              icon: CupertinoIcons.delete,
              title: copy.deleteAll,
              subtitle: copy.t(
                '清除所有实验与观察记录',
                'Erase every experiment and observation',
              ),
              destructive: true,
              onTap:
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
                        if (!ok && context.mounted) {
                          _showSaveError(context, copy);
                        }
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon, this.destructive = false});

  final IconData icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = destructive ? scheme.error : scheme.primary;
    final background = destructive
        ? scheme.errorContainer
        : scheme.primaryContainer;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: foreground, size: 21),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            _SettingsIcon(icon: icon, destructive: destructive),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: destructive ? scheme.error : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!destructive) ...[
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_forward,
                color: scheme.onSurfaceVariant,
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AboutDaysPage extends StatelessWidget {
  const _AboutDaysPage({required this.copy});

  final AppCopy copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: copy.t('返回设置', 'Back to Settings'),
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(copy.scienceBoundary),
      ),
      body: ContentFrame(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      CupertinoIcons.lightbulb,
                      color: scheme.primary,
                      size: 32,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      copy.scienceBoundary,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(copy.scienceBody, style: theme.textTheme.bodyLarge),
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
    return SingleChildScrollView(
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
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          CupertinoSlidingSegmentedControl<EntryKind>(
            groupValue: _kind,
            children: {
              EntryKind.full: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(widget.copy.t('标准', 'Standard')),
              ),
              EntryKind.minimum: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(widget.copy.t('最低', 'Minimum')),
              ),
              EntryKind.skipped: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(widget.copy.t('暂停', 'Pause')),
              ),
            },
            onValueChanged: (value) {
              if (value == null) return;
              setState(() {
                _kind = value;
                _error = null;
              });
            },
          ),
          if (_kind == EntryKind.skipped) ...[
            const SizedBox(height: 16),
            _IosSelectionField<Obstacle>(
              key: const Key('obstacleField'),
              title: widget.copy.obstacle,
              cancel: widget.copy.cancel,
              value: _obstacle,
              values: Obstacle.values,
              labelFor: widget.copy.obstacleLabel,
              onChanged: (value) => setState(() => _obstacle = value),
            ),
          ],
          if (showRecovery) ...[
            const SizedBox(height: 16),
            if (needsRecovery) Text(widget.copy.recoveryNeeded),
            const SizedBox(height: 8),
            _IosSelectionField<RecoveryPlan>(
              key: const Key('recoveryField'),
              title: widget.copy.recovery,
              cancel: widget.copy.cancel,
              value: _recovery,
              values: RecoveryPlan.values,
              labelFor: widget.copy.recoveryLabel,
              onChanged: (value) => setState(() => _recovery = value),
            ),
          ],
          const SizedBox(height: 16),
          Text(widget.copy.note),
          const SizedBox(height: 8),
          CupertinoTextField(
            key: const Key('entryNoteField'),
            controller: _note,
            maxLength: 240,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            placeholder: widget.copy.noteHint,
            padding: const EdgeInsets.all(14),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(
                  color: CupertinoDynamicColor.resolve(
                    CupertinoColors.systemRed,
                    context,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              key: const Key('saveEntryButton'),
              onPressed: widget.controller.isBusy ? null : _submit,
              child: Text(widget.copy.saveEntry),
            ),
          ),
          CupertinoButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.copy.cancel),
          ),
        ],
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.copy.reviewMilestone(widget.milestone),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(widget.copy.reviewQuestion),
          const SizedBox(height: 16),
          CupertinoListSection.insetGrouped(
            margin: EdgeInsets.zero,
            children: [
              for (final decision in ReviewDecision.values)
                CupertinoListTile(
                  title: Text(widget.copy.decisionLabel(decision)),
                  trailing: _decision == decision
                      ? const Icon(CupertinoIcons.check_mark)
                      : null,
                  onTap: () => setState(() => _decision = decision),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(widget.copy.reviewNote),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _note,
            maxLength: 240,
            maxLines: 3,
            padding: const EdgeInsets.all(14),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.systemRed,
                  context,
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: widget.controller.isBusy ? null : _submit,
              child: Text(widget.copy.save),
            ),
          ),
          CupertinoButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.copy.cancel),
          ),
        ],
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: scheme.primary),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.2,
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
  final saved = await _showIosFormSheet<bool>(
    context,
    builder: (_) => CheckInSheet(
      controller: controller,
      copy: copy,
      experiment: experiment,
      initialKind: kind,
    ),
  );
  if (saved == true && context.mounted) {
    _showIosToast(context, copy.entrySaved);
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
  await _showIosFormSheet<void>(
    context,
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
  return await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: Text(copy.cancel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: destructive,
              isDefaultAction: !destructive,
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirm),
            ),
          ],
        ),
      ) ??
      false;
}

void _showSaveError(BuildContext context, AppCopy copy) {
  _showIosToast(context, copy.saveFailed);
}

class _IosChoice<T> {
  const _IosChoice(this.value, this.label, {this.destructive = false});

  final T value;
  final String label;
  final bool destructive;
}

class _IosSelectionField<T> extends StatelessWidget {
  const _IosSelectionField({
    super.key,
    required this.title,
    required this.cancel,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  final String title;
  final String cancel;
  final T value;
  final List<T> values;
  final String Function(T) labelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () async {
        final selected = await _showIosChoices<T>(
          context,
          title: title,
          cancel: cancel,
          choices: [
            for (final option in values) _IosChoice(option, labelFor(option)),
          ],
        );
        if (selected != null && context.mounted) onChanged(selected);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        decoration: BoxDecoration(
          color: CupertinoDynamicColor.resolve(
            CupertinoColors.secondarySystemGroupedBackground,
            context,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 3),
                  Text(
                    labelFor(value),
                    style: TextStyle(
                      color: CupertinoDynamicColor.resolve(
                        CupertinoColors.label,
                        context,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_down, size: 16),
          ],
        ),
      ),
    );
  }
}

Future<T?> _showIosChoices<T>(
  BuildContext context, {
  required String title,
  required String cancel,
  required List<_IosChoice<T>> choices,
}) {
  FocusScope.of(context).unfocus();
  return showCupertinoModalPopup<T>(
    context: context,
    semanticsDismissible: true,
    builder: (popupContext) => CupertinoActionSheet(
      title: Text(title),
      actions: [
        for (final choice in choices)
          CupertinoActionSheetAction(
            isDestructiveAction: choice.destructive,
            onPressed: () => Navigator.pop(popupContext, choice.value),
            child: Text(choice.label),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(popupContext),
        child: Text(cancel),
      ),
    ),
  );
}

Future<T?> _showIosFormSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    semanticsDismissible: true,
    builder: (popupContext) {
      final media = MediaQuery.of(popupContext);
      return Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 640,
              maxHeight:
                  media.size.height -
                  media.padding.top -
                  media.viewInsets.bottom -
                  12,
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Material(
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.systemGroupedBackground,
                  popupContext,
                ),
                child: SafeArea(top: false, child: builder(popupContext)),
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _showIosToast(BuildContext context, String message) {
  final background = CupertinoDynamicColor.resolve(
    CupertinoColors.secondarySystemGroupedBackground,
    context,
  );
  final foreground = CupertinoDynamicColor.resolve(
    CupertinoColors.label,
    context,
  );
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      content: Text(message, style: TextStyle(color: foreground)),
    ),
  );
}
