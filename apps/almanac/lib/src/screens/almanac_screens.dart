import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../app_strings.dart';
import '../domain/almanac_content.dart';
import '../domain/almanac_models.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.controller,
    required this.strings,
  });

  final AppController controller;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: _CenteredScroll(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  ExcludeSemantics(
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: colors.secondary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '宜',
                        style: TextStyle(
                          color: colors.onSecondary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      strings.text('appName'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 54),
              Text(
                strings.text('introEyebrow'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.primary,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                strings.text('introTitle'),
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 18),
              Text(
                strings.text('introBody'),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 30),
              _PrincipleRow(
                icon: Icons.explore_outlined,
                text: strings.text('notDivination'),
              ),
              const SizedBox(height: 14),
              _PrincipleRow(
                icon: Icons.shield_outlined,
                text: strings.text('privateByDesign'),
              ),
              const SizedBox(height: 44),
              if (controller.hasSaveFailure)
                _ErrorBanner(text: strings.text('saveError')),
              FilledButton.icon(
                key: const Key('open_today_button'),
                onPressed: controller.isBusy
                    ? null
                    : () => controller.completeOnboarding(),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  controller.isBusy
                      ? strings.text('saving')
                      : strings.text('openToday'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrincipleRow extends StatelessWidget {
  const _PrincipleRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 23, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}

class RecoveryScreen extends StatelessWidget {
  const RecoveryScreen({
    super.key,
    required this.controller,
    required this.strings,
  });

  final AppController controller;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _CenteredScroll(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 48),
              Icon(
                Icons.lock_clock_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 24),
              Text(
                strings.text('loadErrorTitle'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(
                strings.text('loadErrorBody'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              FilledButton(
                key: const Key('retry_load_button'),
                onPressed: controller.isBusy ? null : controller.load,
                child: Text(strings.text('retry')),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('reset_local_button'),
                onPressed: controller.isBusy
                    ? null
                    : () => _confirmRecoveryReset(context),
                child: Text(strings.text('resetLocal')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRecoveryReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('resetConfirmTitle')),
        content: Text(strings.text('resetConfirmBody')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.text('cancel')),
          ),
          FilledButton(
            key: const Key('confirm_reset_button'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.text('resetLocal')),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.recoverWithReset();
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller, required this.strings});

  final AppController controller;
  final AppStrings strings;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  Timer? _dateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dateTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => widget.controller.refreshForCurrentDate(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.controller.hasCurrentDateLeaf) {
        widget.controller.refreshForCurrentDate();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.refreshForCurrentDate();
    }
  }

  @override
  void dispose() {
    _dateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(strings.text('appName')),
            Text(
              strings.text('tagline'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            key: const Key('settings_button'),
            tooltip: strings.text('settings'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(controller: widget.controller),
              ),
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          DailyLeafScreen(
            controller: widget.controller,
            strings: strings,
            leaf: widget.controller.todayLeaf,
          ),
          FolioScreen(controller: widget.controller, strings: strings),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: <NavigationDestination>[
          NavigationDestination(
            key: const Key('today_tab'),
            icon: const Icon(Icons.wb_sunny_outlined),
            selectedIcon: const Icon(Icons.wb_sunny_rounded),
            label: strings.text('today'),
          ),
          NavigationDestination(
            key: const Key('folio_tab'),
            icon: const Icon(Icons.layers_outlined),
            selectedIcon: const Icon(Icons.layers_rounded),
            label: strings.text('folio'),
          ),
        ],
      ),
    );
  }
}

class DailyLeafScreen extends StatefulWidget {
  const DailyLeafScreen({
    super.key,
    required this.controller,
    required this.strings,
    required this.leaf,
  });

  final AppController controller;
  final AppStrings strings;
  final DailyLeaf leaf;

  @override
  State<DailyLeafScreen> createState() => _DailyLeafScreenState();
}

class _DailyLeafScreenState extends State<DailyLeafScreen> {
  String? _suitableId;
  String? _avoidId;
  late final TextEditingController _intentionController;

  @override
  void initState() {
    super.initState();
    _syncFromLeaf();
    _intentionController = TextEditingController(
      text: widget.leaf.intention ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant DailyLeafScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.leaf != widget.leaf) {
      _syncFromLeaf();
      _intentionController.text = widget.leaf.intention ?? '';
    }
  }

  void _syncFromLeaf() {
    _suitableId = widget.leaf.selectedSuitableId;
    _avoidId = widget.leaf.selectedAvoidId;
  }

  @override
  void dispose() {
    _intentionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leaf = widget.leaf;
    final strings = widget.strings;
    return _CenteredScroll(
      key: const Key('daily_leaf_scroll'),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              strings.formatDate(leaf.createdAt),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _QuietLabel(
              icon: Icons.info_outline_rounded,
              text: strings.text('culturalLabel'),
            ),
          ),
          const SizedBox(height: 24),
          _VersePanel(leaf: leaf, strings: strings),
          const SizedBox(height: 26),
          if (leaf.isSealed)
            _SealedLeaf(
              controller: widget.controller,
              leaf: leaf,
              strings: strings,
            )
          else ...<Widget>[
            if (widget.controller.hasDayChangedNotice)
              _NoticeBanner(text: strings.text('dayChanged')),
            Text(
              strings.text('chooseOneEach'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            _PromptSection(
              title: strings.text('suitable'),
              side: PromptSide.suitable,
              ids: leaf.suitablePromptIds,
              selectedId: _suitableId,
              strings: strings,
              onSelected: (id) => setState(() => _suitableId = id),
            ),
            const SizedBox(height: 22),
            _PromptSection(
              title: strings.text('avoid'),
              side: PromptSide.avoid,
              ids: leaf.avoidPromptIds,
              selectedId: _avoidId,
              strings: strings,
              onSelected: (id) => setState(() => _avoidId = id),
            ),
            const SizedBox(height: 26),
            TextField(
              key: const Key('intention_field'),
              controller: _intentionController,
              maxLength: 140,
              minLines: 2,
              maxLines: 4,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: strings.text('intentionLabel'),
                hintText: strings.text('intentionHint'),
                alignLabelWithHint: true,
              ),
            ),
            if (widget.controller.hasSaveFailure)
              _ErrorBanner(text: strings.text('saveError')),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('seal_leaf_button'),
              onPressed:
                  _suitableId == null ||
                      _avoidId == null ||
                      widget.controller.isBusy
                  ? null
                  : _seal,
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: Text(
                widget.controller.isBusy
                    ? strings.text('saving')
                    : strings.text('seal'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _seal() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await widget.controller.sealToday(
      suitableId: _suitableId!,
      avoidId: _avoidId!,
      intention: _intentionController.text,
    );
  }
}

class _VersePanel extends StatelessWidget {
  const _VersePanel({required this.leaf, required this.strings});

  final DailyLeaf leaf;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final lines = strings.useChinese ? leaf.verseZh : leaf.verseEn;
    return Container(
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings.text('verseLabel'),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.primary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 16),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                line,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: strings.useChinese ? 26 : 23,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            strings.text('composedLocally'),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _PromptSection extends StatelessWidget {
  const _PromptSection({
    required this.title,
    required this.side,
    required this.ids,
    required this.selectedId,
    required this.strings,
    required this.onSelected,
  });

  final String title;
  final PromptSide side;
  final List<String> ids;
  final String? selectedId;
  final AppStrings strings;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        for (final id in ids) ...<Widget>[
          _PromptOption(
            key: Key('prompt_$id'),
            label: promptById(id).text(useChinese: strings.useChinese),
            side: side,
            selected: selectedId == id,
            onTap: () => onSelected(id),
          ),
          if (id != ids.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _PromptOption extends StatelessWidget {
  const _PromptOption({
    super.key,
    required this.label,
    required this.side,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final PromptSide side;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = side == PromptSide.suitable
        ? colors.primary
        : colors.secondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? accent.withValues(alpha: 0.14)
            : colors.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              child: Row(
                children: <Widget>[
                  ExcludeSemantics(
                    child: Icon(
                      side == PromptSide.suitable
                          ? Icons.add_circle_outline_rounded
                          : Icons.remove_circle_outline_rounded,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  if (selected)
                    ExcludeSemantics(
                      child: Icon(Icons.check_rounded, color: accent),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SealedLeaf extends StatelessWidget {
  const _SealedLeaf({
    required this.controller,
    required this.leaf,
    required this.strings,
  });

  final AppController controller;
  final DailyLeaf leaf;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              ExcludeSemantics(
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.secondary, width: 2),
                  ),
                  child: Text(
                    strings.useChinese ? '收' : '✓',
                    style: TextStyle(
                      color: colors.secondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  strings.text('sealed'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _ChoiceSummary(
            label: strings.text('suitable'),
            value: promptById(
              leaf.selectedSuitableId!,
            ).text(useChinese: strings.useChinese),
          ),
          const SizedBox(height: 10),
          _ChoiceSummary(
            label: strings.text('avoid'),
            value: promptById(
              leaf.selectedAvoidId!,
            ).text(useChinese: strings.useChinese),
          ),
          const SizedBox(height: 14),
          Text(
            (leaf.intention ?? '').isEmpty
                ? strings.text('noIntention')
                : leaf.intention!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontStyle: (leaf.intention ?? '').isEmpty
                  ? FontStyle.italic
                  : FontStyle.normal,
              color: (leaf.intention ?? '').isEmpty
                  ? colors.onSurfaceVariant
                  : colors.onSurface,
            ),
          ),
          const SizedBox(height: 22),
          if (controller.hasSaveFailure)
            _ErrorBanner(text: strings.text('saveError')),
          if (leaf.outcome == null)
            OutlinedButton.icon(
              key: const Key('reflect_button'),
              onPressed: controller.isBusy
                  ? null
                  : () => _showReflection(context),
              icon: const Icon(Icons.replay_circle_filled_outlined),
              label: Text(strings.text('reflect')),
            )
          else
            _QuietLabel(
              icon: Icons.done_all_rounded,
              text: strings.outcome(leaf.outcome!.name),
            ),
        ],
      ),
    );
  }

  Future<void> _showReflection(BuildContext context) async {
    final outcome = await showModalBottomSheet<ReflectionOutcome>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                strings.text('reflectionPrompt'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              for (final value in ReflectionOutcome.values)
                ListTile(
                  key: Key('outcome_${value.name}'),
                  minTileHeight: 52,
                  leading: Icon(_outcomeIcon(value)),
                  title: Text(strings.text(value.name)),
                  onTap: () => Navigator.pop(context, value),
                ),
            ],
          ),
        ),
      ),
    );
    if (outcome != null) await controller.reflectToday(outcome);
  }

  IconData _outcomeIcon(ReflectionOutcome outcome) {
    switch (outcome) {
      case ReflectionOutcome.practiced:
        return Icons.check_circle_outline_rounded;
      case ReflectionOutcome.reframed:
        return Icons.change_circle_outlined;
      case ReflectionOutcome.released:
        return Icons.air_rounded;
    }
  }
}

class _ChoiceSummary extends StatelessWidget {
  const _ChoiceSummary({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ),
      ],
    );
  }
}

class FolioScreen extends StatelessWidget {
  const FolioScreen({
    super.key,
    required this.controller,
    required this.strings,
  });

  final AppController controller;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final leaves = controller.archivedLeaves;
    if (leaves.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: <Widget>[
                Icon(
                  Icons.layers_outlined,
                  size: 52,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 18),
                Text(
                  strings.text('emptyFolio'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  strings.text('emptyFolioBody'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      key: const Key('folio_list'),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      itemCount: leaves.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final leaf = leaves[index];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _FolioCard(
              key: Key('folio_leaf_${leaf.dateKey}'),
              leaf: leaf,
              strings: strings,
            ),
          ),
        );
      },
    );
  }
}

class _FolioCard extends StatelessWidget {
  const _FolioCard({super.key, required this.leaf, required this.strings});

  final DailyLeaf leaf;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final verse = (strings.useChinese ? leaf.verseZh : leaf.verseEn).first;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      leaf.dateKey,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: colors.primary),
                    ),
                  ),
                  _QuietLabel(
                    icon: leaf.outcome == null
                        ? Icons.more_time_rounded
                        : Icons.done_all_rounded,
                    text: strings.outcome(leaf.outcome?.name),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(verse, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(
                '${strings.text('suitable')} · ${promptById(leaf.selectedSuitableId!).text(useChinese: strings.useChinese)}   '
                '${strings.text('avoid')} · ${promptById(leaf.selectedAvoidId!).text(useChinese: strings.useChinese)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetail(BuildContext context) {
    final verse = strings.useChinese ? leaf.verseZh : leaf.verseEn;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                strings.text('detail'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(leaf.dateKey, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              Text(
                verse.join('\n'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              _ChoiceSummary(
                label: strings.text('suitable'),
                value: promptById(
                  leaf.selectedSuitableId!,
                ).text(useChinese: strings.useChinese),
              ),
              const SizedBox(height: 12),
              _ChoiceSummary(
                label: strings.text('avoid'),
                value: promptById(
                  leaf.selectedAvoidId!,
                ).text(useChinese: strings.useChinese),
              ),
              const SizedBox(height: 20),
              Text(
                (leaf.intention ?? '').isEmpty
                    ? strings.text('noIntention')
                    : leaf.intention!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 26),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(strings.text('close')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('settings'))),
      body: _CenteredScroll(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final data = controller.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (controller.hasSaveFailure)
                  _ErrorBanner(text: strings.text('saveError')),
                _SettingsHeading(strings.text('language')),
                for (final mode in AppLocaleMode.values)
                  _SettingChoice(
                    key: Key('locale_${mode.name}'),
                    selected: data.localeMode == mode,
                    onTap: controller.isBusy
                        ? null
                        : () => controller.setLocaleMode(mode),
                    label: _localeLabel(strings, mode),
                  ),
                const SizedBox(height: 18),
                _SettingsHeading(strings.text('appearance')),
                for (final mode in AppThemeMode.values)
                  _SettingChoice(
                    key: Key('theme_${mode.name}'),
                    selected: data.themeMode == mode,
                    onTap: controller.isBusy
                        ? null
                        : () => controller.setThemeMode(mode),
                    label: strings.text(mode.name),
                  ),
                const SizedBox(height: 18),
                _SettingsHeading(strings.text('dataAndPrivacy')),
                ListTile(
                  key: const Key('copy_archive_button'),
                  minTileHeight: 56,
                  leading: const Icon(Icons.copy_all_outlined),
                  title: Text(strings.text('copyArchive')),
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text: controller.exportMarkdown(
                          useChinese: strings.useChinese,
                        ),
                      ),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(strings.text('copied'))),
                      );
                    }
                  },
                ),
                ListTile(
                  key: const Key('clear_records_button'),
                  minTileHeight: 56,
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    strings.text('clearRecords'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: controller.isBusy
                      ? null
                      : () => _confirmClear(context, strings),
                ),
                const SizedBox(height: 18),
                _InfoPanel(
                  title: strings.text('privacyTitle'),
                  body: strings.text('privacyBody'),
                  icon: Icons.shield_outlined,
                ),
                const SizedBox(height: 12),
                _InfoPanel(
                  title: strings.text('methodTitle'),
                  body: strings.text('methodBody'),
                  icon: Icons.auto_stories_outlined,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _localeLabel(AppStrings strings, AppLocaleMode mode) {
    switch (mode) {
      case AppLocaleMode.system:
        return strings.text('systemLanguage');
      case AppLocaleMode.zhHans:
        return strings.text('chinese');
      case AppLocaleMode.en:
        return strings.text('english');
    }
  }

  Future<void> _confirmClear(BuildContext context, AppStrings strings) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('clearConfirmTitle')),
        content: Text(strings.text('clearConfirmBody')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.text('cancel')),
          ),
          FilledButton(
            key: const Key('confirm_clear_button'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.text('clear')),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.clearRecords();
  }
}

class _SettingsHeading extends StatelessWidget {
  const _SettingsHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SettingChoice extends StatelessWidget {
  const _SettingChoice({
    super.key,
    required this.selected,
    required this.onTap,
    required this.label,
  });

  final bool selected;
  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: ListTile(
        minTileHeight: 52,
        onTap: onTap,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? colors.primary : colors.onSurfaceVariant,
        ),
        title: ExcludeSemantics(child: Text(label)),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _QuietLabel extends StatelessWidget {
  const _QuietLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: colors.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.today_outlined, color: colors.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: colors.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredScroll extends StatelessWidget {
  const _CenteredScroll({
    super.key,
    required this.padding,
    required this.child,
  });

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: child,
        ),
      ),
    );
  }
}
