import 'package:flutter/material.dart';

import '../../l10n/app_text.dart';
import '../../state/app_controller.dart';
import '../widgets/common.dart';

class EmptyScreen extends StatelessWidget {
  const EmptyScreen({
    super.key,
    required this.controller,
    required this.onCreate,
  });

  final AppController controller;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const AppMark(size: 34),
            const SizedBox(width: 10),
            Flexible(child: Text(text.get('appName'))),
          ],
        ),
        actions: <Widget>[AppBarControls(controller: controller)],
      ),
      body: EmptyGoalContent(onCreate: onCreate),
    );
  }
}

class EmptyGoalContent extends StatelessWidget {
  const EmptyGoalContent({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return SafeArea(
      top: false,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const OfflineBadge(),
                const SizedBox(height: 30),
                _EmptyTrackGraphic(
                  plannedLabel: text.get('planTrack'),
                  actualLabel: text.get('actualTrack'),
                ),
                const SizedBox(height: 34),
                Text(
                  text.get('emptyTitle'),
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 14),
                Text(
                  text.get('emptyBody'),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.history_toggle_off,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(text.get('whyDifferent'))),
                  ],
                ),
                const SizedBox(height: 30),
                FilledButton.icon(
                  key: const Key('create-goal'),
                  onPressed: onCreate,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(text.get('createGoal')),
                ),
                const SizedBox(height: 18),
                Text(
                  text.get('manualOnly'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyTrackGraphic extends StatelessWidget {
  const _EmptyTrackGraphic({
    required this.plannedLabel,
    required this.actualLabel,
  });

  final String plannedLabel;
  final String actualLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$plannedLabel, $actualLabel',
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(plannedLabel, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              _GraphicTrack(color: scheme.primary, fraction: 0.78),
              const SizedBox(height: 22),
              Text(actualLabel, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              _GraphicTrack(color: scheme.secondary, fraction: 0.52),
            ],
          ),
        ),
      ),
    );
  }
}

class _GraphicTrack extends StatelessWidget {
  const _GraphicTrack({required this.color, required this.fraction});

  final Color color;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Container(
            width: constraints.maxWidth * fraction,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Positioned(
            left: constraints.maxWidth * fraction - 9,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
