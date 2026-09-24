import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../l10n/app_strings.dart';
import '../state/app_controller.dart';
import 'experiment_views.dart';

class LessonScreen extends StatefulWidget {
  const LessonScreen({
    required this.controller,
    required this.lesson,
    super.key,
  });

  final AppController controller;
  final Lesson lesson;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  Verdict? _verdict;
  late double _parameter;
  var _explored = false;
  var _revealed = false;
  var _saving = false;
  var _saved = false;

  @override
  void initState() {
    super.initState();
    _parameter = widget.lesson.initialParameter;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final lesson = widget.lesson;
    final isCorrect = _verdict == lesson.correctVerdict;
    final bottomSafeInset = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      appBar: AppBar(title: Text(lesson.subtitle.of(context))),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          key: const Key('secondary-page-scroll-view'),
          padding: EdgeInsets.fromLTRB(20, 6, 20, 36 + bottomSafeInset),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    lesson.title.of(context),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ClaimCard(lesson: lesson),
                  const SizedBox(height: 22),
                  Text(
                    strings.verdictPrompt,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(strings.verdictHelp),
                  const SizedBox(height: 13),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: Verdict.values
                        .map(
                          (verdict) => ChoiceChip(
                            key: Key('verdict-${verdict.name}'),
                            label: Text(strings.verdict(verdict)),
                            selected: _verdict == verdict,
                            onSelected: _revealed
                                ? null
                                : (_) => setState(() => _verdict = verdict),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          strings.investigate,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Icon(
                        _verdict == null
                            ? Icons.lock_outline_rounded
                            : Icons.lock_open_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _verdict == null
                        ? strings.lockedExperiment
                        : strings.exploreHint,
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: ExperimentView(
                        lesson: lesson,
                        value: _parameter,
                        enabled: _verdict != null && !_revealed,
                        onChanged: (value) {
                          setState(() {
                            _parameter = value;
                            _explored = true;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (!_revealed)
                    FilledButton.icon(
                      key: const Key('reveal-button'),
                      onPressed: _verdict != null && _explored && !_saving
                          ? _complete
                          : null,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.compare_arrows_rounded),
                      label: Text(strings.reveal),
                    )
                  else ...[
                    EvidenceComparison(lesson: lesson),
                    const SizedBox(height: 16),
                    _ExplanationCard(isCorrect: isCorrect, lesson: lesson),
                    if (!_saved) ...[
                      const SizedBox(height: 12),
                      _UnsavedCard(saving: _saving, onRetry: _complete),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('back-to-labs'),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(strings.backToLabs),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      key: const Key('retry-lesson'),
                      onPressed: _reset,
                      icon: const Icon(Icons.replay_rounded),
                      label: Text(strings.retry),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _complete() async {
    final verdict = _verdict;
    if (verdict == null) return;
    setState(() => _saving = true);
    final saved = await widget.controller.completeLesson(
      widget.lesson,
      verdict,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _revealed = true;
      _saved = saved;
    });
    if (!saved) {
      final strings = AppStrings(Localizations.localeOf(context));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.saveFailed)));
    }
  }

  void _reset() {
    setState(() {
      _verdict = null;
      _parameter = widget.lesson.initialParameter;
      _explored = false;
      _revealed = false;
      _saving = false;
      _saved = false;
    });
  }
}

class _UnsavedCard extends StatelessWidget {
  const _UnsavedCard({required this.saving, required this.onRetry});

  final bool saving;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('unsaved-result'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.resultNotSaved,
            style: TextStyle(
              color: scheme.onErrorContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('retry-save'),
            onPressed: saving ? null : onRetry,
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(strings.retrySave),
          ),
        ],
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign_outlined, color: foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lesson.prompt.of(context),
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: foreground),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '“${lesson.claim.of(context)}”',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.25,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({required this.isCorrect, required this.lesson});

  final bool isCorrect;
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final scheme = Theme.of(context).colorScheme;
    final foreground = isCorrect
        ? scheme.onSecondaryContainer
        : scheme.onErrorContainer;
    return Semantics(
      liveRegion: true,
      child: Card(
        color: isCorrect ? scheme.secondaryContainer : scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isCorrect
                        ? Icons.check_circle_rounded
                        : Icons.lightbulb_outline_rounded,
                    color: foreground,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      isCorrect ? strings.correct : strings.incorrect,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                lesson.explanation.of(context),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: foreground),
              ),
              const SizedBox(height: 18),
              Text(
                strings.checkNextTime,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: foreground,
                ),
              ),
              const SizedBox(height: 8),
              for (final item in lesson.checklist)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: foreground,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.of(context),
                          style: TextStyle(color: foreground),
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 24),
              if (lesson.source case final source?) ...[
                Text(
                  strings.sourceData(source.attribution, source.license),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: foreground),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  source.url,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: foreground),
                ),
              ] else
                Text(
                  strings.syntheticData,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: foreground),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
