import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../app_strings.dart';
import '../domain/almanac_content.dart';
import '../domain/almanac_models.dart';
import '../privacy_policy.dart';

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
        bottom: false,
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
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        toolbarHeight: 56 + (textScale - 1).clamp(0.0, 2.0) * 28,
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
    final date = strings.formatDate(leaf.createdAt);
    final dateParts = strings.useChinese ? date.split(' · ') : const <String>[];
    return _CenteredScroll(
      key: const Key('daily_leaf_scroll'),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            label: date,
            child: ExcludeSemantics(
              child: dateParts.length == 2
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          dateParts.first,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            dateParts.last,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                      ],
                    )
                  : Text(date, style: Theme.of(context).textTheme.titleLarge),
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
      key: const Key('verse_card'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.brightness == Brightness.light
              ? const <Color>[Color(0xFFF5F6ED), Color(0xFFE8F0E7)]
              : const <Color>[Color(0xFF294137), Color(0xFF203129)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.primary.withValues(alpha: 0.24)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: colors.secondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  strings.text('verseLabel'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.primary,
                    letterSpacing: strings.useChinese ? 1.2 : 0.2,
                  ),
                ),
              ),
              ExcludeSemantics(
                child: Icon(
                  Icons.auto_stories_outlined,
                  size: 20,
                  color: colors.primary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: colors.primary.withValues(alpha: 0.18)),
          const SizedBox(height: 18),
          for (var index = 0; index < lines.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == lines.length - 1 ? 0 : 8,
              ),
              child: Text(
                lines[index],
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: strings.useChinese ? 24 : 22,
                  height: 1.35,
                  letterSpacing: strings.useChinese ? -0.5 : -0.3,
                  fontWeight: FontWeight.w700,
                  color: index == lines.length - 1
                      ? colors.primary
                      : colors.onSurface,
                ),
              ),
            ),
          const SizedBox(height: 22),
          Divider(height: 1, color: colors.primary.withValues(alpha: 0.18)),
          const SizedBox(height: 10),
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
      key: const Key('sealed_card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.brightness == Brightness.light
            ? colors.surfaceContainerLow
            : const Color(0xFF222D28),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  strings.text('sealed'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 12),
              ExcludeSemantics(
                child: Transform.rotate(
                  angle: -0.08,
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: colors.secondary, width: 2),
                    ),
                    child: Text(
                      strings.useChinese ? '收' : '✓',
                      style: TextStyle(
                        color: colors.secondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 21,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Divider(height: 1, color: colors.outlineVariant),
          const SizedBox(height: 16),
          Text(
            strings.text('yourChoice'),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.primary,
              letterSpacing: strings.useChinese ? 0.8 : 0,
            ),
          ),
          const SizedBox(height: 11),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.65),
              ),
            ),
            child: Column(
              children: <Widget>[
                _ChoiceSummary(
                  side: PromptSide.suitable,
                  label: strings.text('suitable'),
                  value: promptById(
                    leaf.selectedSuitableId!,
                  ).text(useChinese: strings.useChinese),
                ),
                const SizedBox(height: 9),
                Divider(height: 1, color: colors.outlineVariant),
                const SizedBox(height: 9),
                _ChoiceSummary(
                  side: PromptSide.avoid,
                  label: strings.text('avoid'),
                  value: promptById(
                    leaf.selectedAvoidId!,
                  ).text(useChinese: strings.useChinese),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(15, 12, 15, 14),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  strings.text('todayIntention'),
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: colors.primary),
                ),
                const SizedBox(height: 5),
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
              ],
            ),
          ),
          const SizedBox(height: 16),
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
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                backgroundColor: colors.primary.withValues(alpha: 0.06),
                side: BorderSide(color: colors.primary.withValues(alpha: 0.35)),
              ),
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
        bottom: false,
        child: SingleChildScrollView(
          padding: _scrollPadding(
            context,
            const EdgeInsets.fromLTRB(20, 8, 20, 24),
          ),
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
  const _ChoiceSummary({
    required this.side,
    required this.label,
    required this.value,
  });

  final PromptSide side;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = side == PromptSide.suitable
        ? colors.primary
        : colors.secondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(color: accent, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: _scrollPadding(
            context,
            const EdgeInsets.fromLTRB(22, 6, 22, 28),
          ),
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
              _VersePanel(leaf: leaf, strings: strings),
              const SizedBox(height: 24),
              _ChoiceSummary(
                side: PromptSide.suitable,
                label: strings.text('suitable'),
                value: promptById(
                  leaf.selectedSuitableId!,
                ).text(useChinese: strings.useChinese),
              ),
              const SizedBox(height: 12),
              _ChoiceSummary(
                side: PromptSide.avoid,
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

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isOpeningPrivacy = false;

  AppController get controller => widget.controller;

  Future<void> _openPrivacy(AppStrings strings) async {
    if (_isOpeningPrivacy) return;
    setState(() => _isOpeningPrivacy = true);
    final opened = await openPrivacyPolicy(useChinese: strings.useChinese);
    if (!mounted) return;
    setState(() => _isOpeningPrivacy = false);
    if (!opened) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('settings'))),
      body: _CenteredScroll(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final data = controller.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _SettingsIntro(strings: strings),
                const SizedBox(height: 24),
                if (controller.hasSaveFailure)
                  _ErrorBanner(text: strings.text('saveError')),
                _SettingsHeading(
                  icon: Icons.translate_rounded,
                  title: strings.text('language'),
                  subtitle: strings.text('languageHint'),
                ),
                const SizedBox(height: 10),
                _SettingsGroup(
                  children: <Widget>[
                    for (final mode in AppLocaleMode.values) ...<Widget>[
                      if (mode != AppLocaleMode.values.first)
                        const _SettingsDivider(),
                      _SettingChoice(
                        key: Key('locale_${mode.name}'),
                        selected: data.localeMode == mode,
                        onTap: controller.isBusy
                            ? null
                            : () => controller.setLocaleMode(mode),
                        label: _localeLabel(strings, mode),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                _SettingsHeading(
                  icon: Icons.palette_outlined,
                  title: strings.text('appearance'),
                  subtitle: strings.text('appearanceHint'),
                ),
                const SizedBox(height: 10),
                _SettingsGroup(
                  children: <Widget>[
                    for (final mode in AppThemeMode.values) ...<Widget>[
                      if (mode != AppThemeMode.values.first)
                        const _SettingsDivider(),
                      _SettingChoice(
                        key: Key('theme_${mode.name}'),
                        selected: data.themeMode == mode,
                        onTap: controller.isBusy
                            ? null
                            : () => controller.setThemeMode(mode),
                        label: strings.text(mode.name),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                _SettingsHeading(
                  icon: Icons.shield_outlined,
                  title: strings.text('dataAndPrivacy'),
                ),
                const SizedBox(height: 10),
                _SettingsGroup(
                  children: <Widget>[
                    _SettingsAction(
                      key: const Key('copy_archive_button'),
                      icon: Icons.copy_all_outlined,
                      title: strings.text('copyArchive'),
                      subtitle: strings.text('copyArchiveHint'),
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
                    const _SettingsDivider(),
                    _SettingsAction(
                      key: const Key('privacy_button'),
                      icon: Icons.privacy_tip_outlined,
                      title: strings.text('privacyTitle'),
                      subtitle: strings.text('privacyHint'),
                      showChevron: true,
                      onTap: _isOpeningPrivacy
                          ? null
                          : () => _openPrivacy(strings),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _SettingsGroup(
                  children: <Widget>[
                    _SettingsAction(
                      key: const Key('clear_records_button'),
                      icon: Icons.delete_outline_rounded,
                      title: strings.text('clearRecords'),
                      subtitle: strings.text('clearRecordsHint'),
                      destructive: true,
                      onTap: controller.isBusy
                          ? null
                          : () => _confirmClear(context, strings),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
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

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _isOpeningPolicy = false;

  Future<void> _retryPolicy(AppStrings strings) async {
    if (_isOpeningPolicy) return;
    setState(() => _isOpeningPolicy = true);
    final opened = await openPrivacyPolicy(useChinese: strings.useChinese);
    if (!mounted) return;
    setState(() => _isOpeningPolicy = false);
    if (opened) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('privacyOpenFailed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      key: const Key('privacy_screen'),
      appBar: AppBar(title: Text(strings.text('privacyTitle'))),
      body: _CenteredScroll(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.shield_outlined,
                    size: 30,
                    color: colors.onPrimaryContainer,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      strings.text('privacyIntro'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('privacy_retry_button'),
              onPressed: _isOpeningPolicy ? null : () => _retryPolicy(strings),
              icon: const Icon(Icons.open_in_browser_outlined),
              label: Text(
                strings.text(
                  _isOpeningPolicy ? 'privacyOpening' : 'privacyRetry',
                ),
              ),
            ),
            const SizedBox(height: 16),
            _InfoPanel(
              title: strings.text('privacyStorageTitle'),
              body: strings.text('privacyStorageBody'),
              icon: Icons.storage_outlined,
            ),
            const SizedBox(height: 12),
            _InfoPanel(
              title: strings.text('privacyBackupTitle'),
              body: strings.text('privacyBackupBody'),
              icon: Icons.backup_outlined,
            ),
            const SizedBox(height: 12),
            _InfoPanel(
              title: strings.text('privacyDeleteTitle'),
              body: strings.text('privacyDeleteBody'),
              icon: Icons.delete_outline_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsIntro extends StatelessWidget {
  const _SettingsIntro({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.tune_rounded, color: colors.onPrimaryContainer, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  strings.text('settingsIntroTitle'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  strings.text('settingsIntroBody'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsHeading extends StatelessWidget {
  const _SettingsHeading({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 21, color: colors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 16, endIndent: 16);
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
        minTileHeight: 58,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        selected: selected,
        selectedTileColor: colors.primaryContainer.withValues(alpha: 0.4),
        onTap: onTap,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? colors.primary : colors.onSurfaceVariant,
        ),
        title: ExcludeSemantics(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showChevron = false,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = destructive ? colors.error : colors.primary;
    return ListTile(
      minTileHeight: 72,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: accent, size: 22),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: destructive ? colors.error : colors.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: showChevron
          ? Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant)
          : null,
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
      padding: _scrollPadding(context, padding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: child,
        ),
      ),
    );
  }
}

EdgeInsets _scrollPadding(BuildContext context, EdgeInsets padding) => padding
    .copyWith(bottom: padding.bottom + MediaQuery.paddingOf(context).bottom);
