import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../domain/models.dart';
import 'strings.dart';

enum _ReviewExitAction { keep, delete }

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final strings = AppStrings(controller.localeCode);
    if (controller.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (controller.loadFailed) {
      return _LoadFailurePage(controller: controller, strings: strings);
    }
    if (controller.isRecording) {
      return RecordingPage(controller: controller, strings: strings);
    }
    if (controller.reviewSession != null) {
      return MorningReviewPage(controller: controller, strings: strings);
    }

    final pages = <Widget>[
      TonightPage(controller: controller, strings: strings),
      ArchivePage(controller: controller, strings: strings),
      SettingsPage(controller: controller, strings: strings),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _index,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (value) =>
                        setState(() => _index = value),
                    leading: const Padding(
                      padding: EdgeInsets.only(top: 12, bottom: 20),
                      child: _AppGlyph(size: 42),
                    ),
                    destinations: [
                      NavigationRailDestination(
                        icon: const Icon(Icons.nightlight_outlined),
                        selectedIcon: const Icon(Icons.nightlight),
                        label: Text(strings.t('tonight')),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.auto_stories_outlined),
                        selectedIcon: const Icon(Icons.auto_stories),
                        label: Text(strings.t('archive')),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.tune_outlined),
                        selectedIcon: const Icon(Icons.tune),
                        label: Text(strings.t('settings')),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: IndexedStack(index: _index, children: pages),
                  ),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          body: SafeArea(
            child: IndexedStack(index: _index, children: pages),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: [
              NavigationDestination(
                key: const Key('tonight_tab'),
                icon: const Icon(Icons.nightlight_outlined),
                selectedIcon: const Icon(Icons.nightlight),
                label: strings.t('tonight'),
              ),
              NavigationDestination(
                key: const Key('archive_tab'),
                icon: const Icon(Icons.auto_stories_outlined),
                selectedIcon: const Icon(Icons.auto_stories),
                label: strings.t('archive'),
              ),
              NavigationDestination(
                key: const Key('settings_tab'),
                icon: const Icon(Icons.tune_outlined),
                selectedIcon: const Icon(Icons.tune),
                label: strings.t('settings'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TonightPage extends StatefulWidget {
  const TonightPage({
    super.key,
    required this.controller,
    required this.strings,
  });

  final AppController controller;
  final AppStrings strings;

  @override
  State<TonightPage> createState() => _TonightPageState();
}

class _TonightPageState extends State<TonightPage> {
  final _promptController = TextEditingController();
  final Set<String> _contexts = {};
  static const _contextKeys = [
    'lateMeal',
    'stressfulDay',
    'caffeine',
    'travel',
    'sharedRoom',
  ];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = widget.strings;
    return _PageFrame(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 116),
            children: [
              const Align(alignment: Alignment.centerLeft, child: _AppGlyph()),
              const SizedBox(height: 26),
              Text(
                s.t('tonightTitle'),
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 10),
              Text(
                s.t('tonightSubtitle'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 22),
              if (c.error != null) ...[
                _ErrorBanner(controller: c, strings: s),
                const SizedBox(height: 16),
              ],
              if (c.interruptedMarker != null) ...[
                _InterruptedCard(controller: c, strings: s),
                const SizedBox(height: 16),
              ],
              if (c.pendingReviews.isNotEmpty) ...[
                ...c.pendingReviews.map(
                  (session) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _NightCard(
                      session: session,
                      strings: s,
                      onTap: () => c.resumeReview(session),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        key: const Key('prompt_field'),
                        controller: _promptController,
                        maxLength: 160,
                        maxLines: 4,
                        minLines: 2,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: s.t('promptLabel'),
                          hintText: s.t('promptHint'),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        s.t('contextTitle'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _contextKeys
                            .map(
                              (key) => FilterChip(
                                label: Text(s.contextName(key)),
                                selected: _contexts.contains(key),
                                onSelected: (selected) => setState(() {
                                  selected
                                      ? _contexts.add(key)
                                      : _contexts.remove(key);
                                }),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _TrustStrip(icon: Icons.lock_outline, text: s.t('localOnly')),
              const SizedBox(height: 8),
              _TrustStrip(
                icon: Icons.health_and_safety_outlined,
                text: s.t('notMedical'),
              ),
            ],
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 14,
            child: FilledButton.icon(
              key: const Key('prepare_button'),
              onPressed: c.busy || c.interruptedMarker != null
                  ? null
                  : _showConsent,
              icon: const Icon(Icons.mic_none_rounded),
              label: Text(s.t('prepare')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showConsent() async {
    final s = widget.strings;
    var confirmed = false;
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.t('consentTitle'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 14),
                Text(
                  s.t('consentBody'),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  key: const Key('room_consent_checkbox'),
                  value: confirmed,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(s.t('roomConsent')),
                  onChanged: (value) =>
                      setSheetState(() => confirmed = value ?? false),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(s.t('cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const Key('confirm_start_button'),
                        onPressed: confirmed
                            ? () => Navigator.pop(context, true)
                            : null,
                        child: Text(s.t('start')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    await widget.controller.startRecording(
      prompt: _promptController.text,
      contextTags: _contexts.toList(growable: false),
    );
  }
}

class RecordingPage extends StatelessWidget {
  const RecordingPage({
    super.key,
    required this.controller,
    required this.strings,
  });

  final AppController controller;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmStop(context);
      },
      child: Scaffold(
        body: SafeArea(
          child: _PageFrame(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 54,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _RecordingDot(
                              label: strings.t('recordingIndicator'),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Semantics(
                                liveRegion: true,
                                label: strings.t('recording'),
                                child: Text(
                                  strings.t('recording'),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          strings.formatDuration(controller.elapsed),
                          key: const Key('recording_timer'),
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w300,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          controller.isCalibrated
                              ? strings.t('listening')
                              : strings.t('calibrating'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 28),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _Metric(
                                    label: strings.t('momentsFound'),
                                    value: '${controller.candidateCount}',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _Metric(
                                    label: strings.t('amplitude'),
                                    value: controller.currentDb == null
                                        ? '—'
                                        : '${controller.currentDb!.round()} dB',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (controller.error != null) ...[
                          _ErrorBanner(
                            controller: controller,
                            strings: strings,
                          ),
                          const SizedBox(height: 14),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const Key('stop_recording_button'),
                            onPressed: controller.busy
                                ? null
                                : () => _confirmStop(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.secondary,
                              foregroundColor: const Color(0xFF32120F),
                            ),
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: Text(strings.t('stop')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmStop(BuildContext context) async {
    final shouldStop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.t('stopTitle')),
        content: Text(strings.t('stopBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.t('keepRecording')),
          ),
          FilledButton(
            key: const Key('confirm_stop_button'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.t('confirmStop')),
          ),
        ],
      ),
    );
    if (shouldStop == true) await controller.stopRecording();
  }
}

class MorningReviewPage extends StatefulWidget {
  const MorningReviewPage({
    super.key,
    required this.controller,
    required this.strings,
  });

  final AppController controller;
  final AppStrings strings;

  @override
  State<MorningReviewPage> createState() => _MorningReviewPageState();
}

class _MorningReviewPageState extends State<MorningReviewPage> {
  late final TextEditingController _noteController;
  late final Map<String, MomentLabel> _labels;

  @override
  void initState() {
    super.initState();
    final session = widget.controller.reviewSession!;
    _noteController = TextEditingController(text: session.morningNote);
    _labels = {for (final moment in session.moments) moment.id: moment.label};
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.controller.reviewSession!;
    final s = widget.strings;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitReview();
      },
      child: Scaffold(
        body: SafeArea(
          child: _PageFrame(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),
              children: [
                Text(
                  s.t('reviewTitle'),
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  s.t('reviewSubtitle'),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 18),
                if (widget.controller.error != null) ...[
                  _ErrorBanner(controller: widget.controller, strings: s),
                  const SizedBox(height: 16),
                ],
                TextField(
                  key: const Key('morning_note_field'),
                  controller: _noteController,
                  maxLength: 3000,
                  minLines: 4,
                  maxLines: 10,
                  decoration: InputDecoration(
                    labelText: s.t('morningNote'),
                    hintText: s.t('morningHint'),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                if (session.moments.isEmpty)
                  _InfoCard(
                    icon: Icons.graphic_eq_outlined,
                    text: s.t('noMoments'),
                  )
                else
                  ...session.moments.map(
                    (moment) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MomentEditor(
                        session: session,
                        moment: moment,
                        value: _labels[moment.id] ?? MomentLabel.pending,
                        strings: s,
                        controller: widget.controller,
                        onChanged: (value) =>
                            setState(() => _labels[moment.id] = value),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('review_later_button'),
                        onPressed: widget.controller.busy ? null : _exitReview,
                        child: Text(s.t('reviewLater')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('save_card_button'),
                        onPressed: widget.controller.busy
                            ? null
                            : () => widget.controller.saveReview(
                                morningNote: _noteController.text,
                                labels: _labels,
                              ),
                        icon: widget.controller.busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.bookmark_add_outlined),
                        label: Text(
                          widget.controller.busy
                              ? s.t('saving')
                              : s.t('saveCard'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exitReview() async {
    final action = await showDialog<_ReviewExitAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.strings.t('reviewExitTitle')),
        content: Text(widget.strings.t('reviewExitBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.strings.t('continueReview')),
          ),
          TextButton(
            key: const Key('keep_review_draft_button'),
            onPressed: () => Navigator.pop(context, _ReviewExitAction.keep),
            child: Text(widget.strings.t('keepDraft')),
          ),
          FilledButton(
            key: const Key('delete_review_draft_button'),
            onPressed: () => Navigator.pop(context, _ReviewExitAction.delete),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(widget.strings.t('deleteDraft')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _ReviewExitAction.keep:
        widget.controller.deferReview();
        return;
      case _ReviewExitAction.delete:
        await widget.controller.deleteReviewDraft();
        return;
      case null:
        return;
    }
  }
}

class ArchivePage extends StatelessWidget {
  const ArchivePage({
    super.key,
    required this.controller,
    required this.strings,
  });

  final AppController controller;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final reviewedSessions = controller.reviewedSessions;
    final contextCounts = <String, int>{};
    for (final session in reviewedSessions) {
      for (final tag in session.contextTags) {
        contextCounts.update(tag, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    return _PageFrame(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),
        children: [
          Text(
            strings.t('archiveTitle'),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            strings.t('archiveSubtitle'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          if (controller.error != null) ...[
            _ErrorBanner(controller: controller, strings: strings),
            const SizedBox(height: 16),
          ],
          if (contextCounts.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.t('backgroundPatterns'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: contextCounts.entries
                          .map(
                            (entry) => Chip(
                              label: Text(
                                '${strings.contextName(entry.key)} · ${entry.value}',
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (reviewedSessions.isEmpty)
            _EmptyState(strings: strings)
          else
            ...reviewedSessions.map(
              (session) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _NightCard(
                  session: session,
                  strings: strings,
                  onTap: () {
                    if (!session.isReviewed) {
                      controller.resumeReview(session);
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => NightDetailPage(
                          controller: controller,
                          strings: strings,
                          sessionId: session.id,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class NightDetailPage extends StatelessWidget {
  const NightDetailPage({
    super.key,
    required this.controller,
    required this.strings,
    required this.sessionId,
  });

  final AppController controller;
  final AppStrings strings;
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final matches = controller.sessions.where((item) => item.id == sessionId);
    if (matches.isEmpty) return const SizedBox.shrink();
    final session = matches.first;
    final kept = session.moments
        .where(
          (item) =>
              item.label != MomentLabel.pending &&
              item.label != MomentLabel.ignored,
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(strings.t('nightDetail'))),
      body: SafeArea(
        top: false,
        child: _PageFrame(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 36),
            children: [
              Text(
                strings.formatDate(session.startedAt),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 18),
              _DetailBlock(
                title: strings.t('duration'),
                body: strings.formatDuration(session.duration),
              ),
              if (session.prompt.isNotEmpty)
                _DetailBlock(title: strings.t('prompt'), body: session.prompt),
              if (session.contextTags.isNotEmpty)
                _DetailBlock(
                  title: strings.t('background'),
                  body: session.contextTags
                      .map(strings.contextName)
                      .join(' · '),
                ),
              _DetailBlock(
                title: strings.t('note'),
                body: session.morningNote.isEmpty
                    ? strings.t('noNote')
                    : session.morningNote,
              ),
              const SizedBox(height: 8),
              Text(
                strings.t('confirmedMoments'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (kept.isEmpty)
                Text(strings.t('noMoments'))
              else
                ...kept.map(
                  (moment) => Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: IconButton(
                        tooltip: strings.t('play'),
                        onPressed: () => controller.playMoment(session, moment),
                        icon: Icon(
                          controller.playingMomentId == moment.id
                              ? Icons.graphic_eq
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                      title: Text(strings.labelName(moment.label)),
                      subtitle: Text(
                        '${strings.momentTime(moment.offsetSeconds)} · ${strings.t('labeledByYou')}',
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                key: const Key('delete_night_button'),
                onPressed: controller.busy ? null : () => _delete(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                icon: const Icon(Icons.delete_outline),
                label: Text(strings.t('deleteNight')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await _confirmDestructive(
      context,
      title: strings.t('deleteTitle'),
      body: strings.t('deleteBody'),
      action: strings.t('delete'),
    );
    if (confirmed != true) return;
    final deleted = await controller.deleteSession(sessionId);
    if (deleted && context.mounted) Navigator.pop(context);
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.strings,
  });

  final AppController controller;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),
        children: [
          Text(
            strings.t('settings'),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 22),
          if (controller.error != null) ...[
            _ErrorBanner(controller: controller, strings: strings),
            const SizedBox(height: 16),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.t('language'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'zh',
                        label: Text(strings.t('chinese')),
                      ),
                      ButtonSegment(
                        value: 'en',
                        label: Text(strings.t('english')),
                      ),
                    ],
                    selected: {controller.localeCode},
                    onSelectionChanged: (value) =>
                        controller.setLocale(value.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.lock_outline,
            title: strings.t('privacyTitle'),
            text: strings.t('privacyBody'),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.health_and_safety_outlined,
            title: strings.t('medicalTitle'),
            text: strings.t('medicalBody'),
          ),
          const SizedBox(height: 26),
          Text(
            strings.t('dataTitle'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('clear_all_button'),
            onPressed: controller.sessions.isEmpty || controller.busy
                ? null
                : () => _clearAll(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            icon: const Icon(Icons.delete_forever_outlined),
            label: Text(strings.t('clearAll')),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAll(BuildContext context) async {
    final confirmed = await _confirmDestructive(
      context,
      title: strings.t('clearAllTitle'),
      body: strings.t('clearAllBody'),
      action: strings.t('clearAll'),
    );
    if (confirmed == true) await controller.clearAll();
  }
}

class _LoadFailurePage extends StatelessWidget {
  const _LoadFailurePage({required this.controller, required this.strings});

  final AppController controller;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_clock_outlined, size: 52),
                  const SizedBox(height: 18),
                  Text(
                    strings.t('loadFailedTitle'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    strings.t('loadFailedBody'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: controller.loading
                        ? null
                        : controller.initialize,
                    icon: const Icon(Icons.refresh),
                    label: Text(strings.t('retry')),
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

class _MomentEditor extends StatelessWidget {
  const _MomentEditor({
    required this.session,
    required this.moment,
    required this.value,
    required this.strings,
    required this.controller,
    required this.onChanged,
  });

  final NightSession session;
  final SoundMoment moment;
  final MomentLabel value;
  final AppStrings strings;
  final AppController controller;
  final ValueChanged<MomentLabel> onChanged;

  @override
  Widget build(BuildContext context) {
    const choices = [
      MomentLabel.pending,
      MomentLabel.possibleSpeech,
      MomentLabel.breathing,
      MomentLabel.environment,
      MomentLabel.uncertain,
      MomentLabel.ignored,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.momentTime(moment.offsetSeconds),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: strings.t('play'),
                  onPressed: () => controller.playMoment(session, moment),
                  icon: Icon(
                    controller.playingMomentId == moment.id
                        ? Icons.graphic_eq
                        : Icons.play_arrow_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<MomentLabel>(
              key: Key('label_${moment.id}'),
              initialValue: value,
              isExpanded: true,
              decoration: InputDecoration(labelText: strings.t('labeledByYou')),
              items: choices
                  .map(
                    (label) => DropdownMenuItem(
                      value: label,
                      child: Text(
                        strings.labelName(label),
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (label) {
                if (label != null) onChanged(label);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InterruptedCard extends StatelessWidget {
  const _InterruptedCard({required this.controller, required this.strings});

  final AppController controller;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.t('interruptedTitle'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(strings.t('interruptedBody')),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: controller.busy
                  ? null
                  : controller.discardInterruptedRecording,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: Text(strings.t('discardInterrupted')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.controller, required this.strings});

  final AppController controller;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final error = controller.error;
    if (error == null) return const SizedBox.shrink();
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.info_outline),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(strings.errorText(error))),
            IconButton(
              tooltip: strings.t('dismiss'),
              onPressed: controller.clearError,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _NightCard extends StatelessWidget {
  const _NightCard({
    required this.session,
    required this.strings,
    required this.onTap,
  });

  final NightSession session;
  final AppStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reviewed = session.moments.where(
      (item) =>
          item.label != MomentLabel.pending &&
          item.label != MomentLabel.ignored,
    );
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 64,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.auto_stories_outlined),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.formatDate(session.startedAt),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (!session.isReviewed) ...[
                      const SizedBox(height: 6),
                      Text(
                        strings.t('pendingReview'),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      !session.isReviewed
                          ? strings.t('pendingReviewBody')
                          : session.morningNote.isEmpty
                          ? strings.t('noNote')
                          : session.morningNote,
                      maxLines: 3,
                      overflow: TextOverflow.fade,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${strings.formatDuration(session.duration)} · ${reviewed.length} ${strings.t('events')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 42),
        child: Column(
          children: [
            const _AppGlyph(size: 54),
            const SizedBox(height: 16),
            Text(
              strings.t('emptyArchive'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(strings.t('emptyArchiveBody'), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(body, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: child,
      ),
    );
  }
}

class _AppGlyph extends StatelessWidget {
  const _AppGlyph({this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Somniloquy',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(size * 0.36),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.mode_night_rounded,
              color: Theme.of(context).colorScheme.onPrimary,
              size: size * 0.58,
            ),
            Positioned(
              right: size * 0.13,
              bottom: size * 0.13,
              child: Container(
                width: size * 0.2,
                height: size * 0.2,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingDot extends StatelessWidget {
  const _RecordingDot({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          color: Color(0xFFFF6B65),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text, this.title});

  final IconData icon;
  final String text;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(text),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> _confirmDestructive(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const Key('confirm_destructive_button'),
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(action),
        ),
      ],
    ),
  );
}
