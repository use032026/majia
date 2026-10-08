import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/diary_entry.dart';
import '../l10n/app_text.dart';

String formatDiaryDate(BuildContext context, DateTime date) {
  final localizations = MaterialLocalizations.of(context);
  return localizations.formatMediumDate(date);
}

String moodLabel(AppText text, EntryMood mood) {
  return switch (mood) {
    EntryMood.calm => text.calm,
    EntryMood.bright => text.bright,
    EntryMood.heavy => text.heavy,
    EntryMood.uncertain => text.uncertain,
    EntryMood.energized => text.energized,
  };
}

IconData moodIcon(EntryMood mood) {
  return switch (mood) {
    EntryMood.calm => Icons.water_drop_outlined,
    EntryMood.bright => Icons.wb_sunny_outlined,
    EntryMood.heavy => Icons.cloud_outlined,
    EntryMood.uncertain => Icons.blur_on_rounded,
    EntryMood.energized => Icons.bolt_rounded,
  };
}

String shiftLabel(AppText text, EchoShift shift) {
  return switch (shift) {
    EchoShift.same => text.same,
    EchoShift.clearer => text.clearer,
    EchoShift.changed => text.changed,
    EchoShift.resolved => text.resolved,
  };
}

double bottomSafeSpacing(BuildContext context, {double minimum = 20}) {
  final mediaQuery = MediaQuery.of(context);
  return minimum +
      math.max(mediaQuery.viewPadding.bottom, mediaQuery.viewInsets.bottom);
}

class BottomSafeArea extends StatelessWidget {
  const BottomSafeArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(top: false, maintainBottomViewPadding: true, child: child);
  }
}

class PageWidth extends StatelessWidget {
  const PageWidth({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class EntryCard extends StatelessWidget {
  const EntryCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.showDue = false,
  });

  final DiaryEntry entry;
  final VoidCallback onTap;
  final bool showDue;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final scheme = Theme.of(context).colorScheme;
    final title = entry.title.isEmpty ? text.pageUntitled : entry.title;
    final status = entry.futureQuestion.isEmpty
        ? text.plainPage
        : entry.isClosed
        ? text.closed
        : showDue
        ? text.due
        : text.open;
    return Semantics(
      button: true,
      label: '$title, $status',
      child: Card(
        child: InkWell(
          key: ValueKey<String>('entry_${entry.id}'),
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    moodIcon(entry.mood),
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusPill(label: status, emphasized: showDue),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatDiaryDate(context, entry.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        entry.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (entry.futureQuestion.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer.withValues(
                              alpha: 0.55,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            entry.futureQuestion,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.emphasized});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: emphasized ? scheme.primary : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: emphasized ? scheme.onPrimary : scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 12),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center),
          if (action != null) ...<Widget>[const SizedBox(height: 22), action!],
        ],
      ),
    );
  }
}
