import 'package:flutter/material.dart';

import '../data/lesson_catalog.dart';
import '../domain/models.dart';
import '../l10n/app_strings.dart';
import '../state/app_controller.dart';
import 'lesson_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({required this.controller, super.key});

  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final strings = AppStrings(Localizations.localeOf(context));
        final pages = [
          _LearnScreen(controller: widget.controller),
          _ReviewScreen(controller: widget.controller),
          _ProgressScreen(controller: widget.controller),
          _SettingsScreen(controller: widget.controller),
        ];
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                if (widget.controller.errorMessage != null)
                  Container(
                    key: const Key('storage-error-banner'),
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.errorContainer,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        Text(
                          switch (widget.controller.errorKind) {
                            AppErrorKind.load => strings.loadFailed,
                            AppErrorKind.clear => strings.clearFailed,
                            _ => strings.saveFailed,
                          },
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.controller.hasRecoverableLoadError)
                          TextButton(
                            key: const Key('reset-corrupt-data'),
                            onPressed: () => _confirmResetCorruptData(strings),
                            child: Text(strings.resetLocalData),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: IndexedStack(index: _index, children: pages),
                ),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (index) => setState(() => _index = index),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.science_outlined),
                selectedIcon: const Icon(Icons.science_rounded),
                label: strings.learn,
              ),
              NavigationDestination(
                icon: const Icon(Icons.replay_outlined),
                selectedIcon: const Icon(Icons.replay_rounded),
                label: strings.review,
              ),
              NavigationDestination(
                icon: const Icon(Icons.insights_outlined),
                selectedIcon: const Icon(Icons.insights_rounded),
                label: strings.progress,
              ),
              NavigationDestination(
                icon: const Icon(Icons.tune_outlined),
                selectedIcon: const Icon(Icons.tune_rounded),
                label: strings.settings,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmResetCorruptData(AppStrings strings) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.clearConfirmTitle),
        content: Text(strings.clearConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.clear),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final cleared = await widget.controller.clearProgress();
    if (cleared && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.cleared)));
    }
  }
}

class _ScreenFrame extends StatelessWidget {
  const _ScreenFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: child,
        ),
      ),
    );
  }
}

class _LearnScreen extends StatelessWidget {
  const _LearnScreen({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final onPrimaryContainer = Theme.of(context).colorScheme.onPrimaryContainer;
    final catalog = controller.activeLessons;
    final completeCount = catalog
        .where((lesson) => controller.completedLessonIds.contains(lesson.id))
        .length;
    final nextLesson = catalog.cast<Lesson?>().firstWhere(
      (lesson) => !controller.completedLessonIds.contains(lesson!.id),
      orElse: () => catalog.first,
    )!;
    return _ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.appName,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.homeTitle,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900, height: 1.12),
                    ),
                  ],
                ),
              ),
              Semantics(
                label:
                    '$completeCount / ${catalog.length} ${strings.completed}',
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: completeCount / catalog.length,
                        strokeWidth: 7,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                      Text('$completeCount/${catalog.length}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(strings.homeBody, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 14),
          Semantics(
            label: strings.offlineBadge,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.offline_bolt_outlined, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      strings.offlineBadge,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    strings.continueLearning,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: onPrimaryContainer),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    nextLesson.title.of(context),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => _openLesson(context, nextLesson),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(strings.start),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          for (final kind in LessonKind.values) ...[
            _ModuleHeader(kind: kind),
            const SizedBox(height: 10),
            for (final lesson in catalog.where((item) => item.kind == kind))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LessonTile(
                  lesson: lesson,
                  attempt: controller.latestAttemptByLesson[lesson.id],
                  onTap: () => _openLesson(context, lesson),
                ),
              ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Future<void> _openLesson(BuildContext context, Lesson lesson) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LessonScreen(controller: controller, lesson: lesson),
      ),
    );
  }
}

class _ModuleHeader extends StatelessWidget {
  const _ModuleHeader({required this.kind});

  final LessonKind kind;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            _kindIcon(kind),
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.moduleName(kind),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                strings.moduleDescription(kind),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.attempt,
    required this.onTap,
  });

  final Lesson lesson;
  final Attempt? attempt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Icon(
                attempt == null
                    ? Icons.radio_button_unchecked_rounded
                    : attempt!.isCorrect
                    ? Icons.check_circle_rounded
                    : Icons.replay_circle_filled_rounded,
                color: attempt == null
                    ? colorScheme.outline
                    : attempt!.isCorrect
                    ? colorScheme.secondary
                    : colorScheme.error,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title.of(context),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(lesson.subtitle.of(context)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                attempt == null
                    ? strings.start
                    : attempt!.isCorrect
                    ? strings.done
                    : strings.needsReview,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewScreen extends StatelessWidget {
  const _ReviewScreen({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final reviewLessons = controller.activeLessons
        .where((lesson) => controller.reviewLessonIds.contains(lesson.id))
        .toList(growable: false);
    return _ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            reviewLessons.isEmpty ? strings.noReviewTitle : strings.reviewTitle,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            reviewLessons.isEmpty ? strings.noReviewBody : strings.reviewBody,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 22),
          if (reviewLessons.isEmpty)
            const _EmptyIllustration(icon: Icons.fact_check_outlined)
          else
            for (final lesson in reviewLessons)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LessonTile(
                  lesson: lesson,
                  attempt: controller.latestAttemptByLesson[lesson.id],
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) =>
                          LessonScreen(controller: controller, lesson: lesson),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _ProgressScreen extends StatelessWidget {
  const _ProgressScreen({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final activeIds = controller.activeLessons
        .map((lesson) => lesson.id)
        .toSet();
    final latest = controller.latestAttemptByLesson.entries
        .where((entry) => activeIds.contains(entry.key))
        .map((entry) => entry.value);
    final mastered = latest.where((attempt) => attempt.isCorrect).length;
    final misconceptionCounts = <String, int>{};
    for (final attempt in controller.attempts.where(
      (item) => !item.isCorrect,
    )) {
      final label =
          attempt.misconceptionText?.of(context) ??
          lessonById(
            attempt.misconception,
            controller.activeLessons,
          )?.misconception.of(context) ??
          attempt.misconception;
      misconceptionCounts.update(
        label,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final sortedMisconceptions = misconceptionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.progressTitle,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(strings.localOnly),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricCard(
                label: strings.attempts,
                value: '${controller.attempts.length}',
              ),
              _MetricCard(
                label: strings.accuracy,
                value: '${(controller.accuracy * 100).round()}%',
              ),
              _MetricCard(
                label: strings.mastered,
                value: '$mastered/${controller.activeLessons.length}',
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            strings.misconceptionMap,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (controller.attempts.isEmpty)
            Text(strings.noAttempts)
          else if (sortedMisconceptions.isEmpty)
            Text(strings.noReviewTitle)
          else
            for (final entry in sortedMisconceptions)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.psychology_alt_outlined),
                  title: Text(entry.key),
                  trailing: Text('×${entry.value}'),
                ),
              ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 154,
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final catalogRevision = controller.catalogRevision;
    return _ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.settings,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    strings.language,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    key: const Key('language-selector'),
                    segments: [
                      ButtonSegment(
                        value: 'zh',
                        label: Text(strings.simplifiedChinese),
                      ),
                      ButtonSegment(value: 'en', label: Text(strings.english)),
                    ],
                    selected: {controller.locale.languageCode},
                    onSelectionChanged: (selection) {
                      controller.setLocale(Locale(selection.single));
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sync_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          strings.contentUpdates,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(strings.contentUpdateBody),
                  const SizedBox(height: 8),
                  Text(
                    catalogRevision != null
                        ? strings.contentVersion(
                            catalogRevision,
                            controller.remoteLessonCount,
                          )
                        : strings.bundledContentOnly,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (controller.catalogErrorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      strings.contentUpdateFailed,
                      key: const Key('content-update-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('refresh-content'),
                    onPressed: controller.isRefreshingCatalog
                        ? null
                        : () => controller.refreshLessons(force: true),
                    icon: controller.isRefreshingCatalog
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(
                      controller.isRefreshingCatalog
                          ? strings.refreshingContent
                          : strings.refreshContent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.privacy_tip_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          strings.privacyTitle,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(strings.privacyBody),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            key: const Key('clear-progress'),
            onPressed:
                controller.attempts.isEmpty &&
                    !controller.hasRecoverableLoadError
                ? null
                : () => _confirmClear(context, strings),
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(strings.clearProgress),
          ),
          const SizedBox(height: 12),
          Text(
            '1.0.0 · ${strings.offlineBadge}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, AppStrings strings) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.clearConfirmTitle),
        content: Text(strings.clearConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.clear),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final cleared = await controller.clearProgress();
    if (cleared && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.cleared)));
    }
  }
}

class _EmptyIllustration extends StatelessWidget {
  const _EmptyIllustration({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Icon(icon, size: 84, color: Theme.of(context).colorScheme.outline),
    );
  }
}

IconData _kindIcon(LessonKind kind) => switch (kind) {
  LessonKind.axis => Icons.stacked_bar_chart_rounded,
  LessonKind.correlation => Icons.scatter_plot_rounded,
  LessonKind.sample => Icons.groups_2_outlined,
  LessonKind.risk => Icons.percent_rounded,
};
