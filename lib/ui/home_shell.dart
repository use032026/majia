import 'package:flutter/material.dart';

import '../domain/diary_entry.dart';
import '../l10n/app_text.dart';
import '../state/diary_controller.dart';
import 'entry_detail_page.dart';
import 'entry_editor_page.dart';
import 'entry_widgets.dart';
import 'settings_page.dart';
import 'trash_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final DiaryController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  Future<void> _newEntry() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EntryEditorPage(controller: widget.controller),
      ),
    );
  }

  void _openEntry(DiaryEntry entry) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            EntryDetailPage(controller: widget.controller, entryId: entry.id),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final titles = <String>[text.today, text.revisit, text.archive];
    final useCompactFab = MediaQuery.textScalerOf(context).scale(1) > 1.6;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  text.appName.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.8,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(titles[_index]),
              ],
            ),
            actions: <Widget>[
              IconButton(
                tooltip: text.settings,
                onPressed: _openSettings,
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
          body: Column(
            children: <Widget>[
              if (widget.controller.recoveredFromBackup)
                MaterialBanner(
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        text.recoveredTitle,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(text.recoveredBody),
                    ],
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: widget.controller.dismissRecoveryNotice,
                      child: Text(text.dismiss),
                    ),
                  ],
                ),
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: <Widget>[
                    _TodayScreen(
                      controller: widget.controller,
                      onNew: _newEntry,
                      onOpen: _openEntry,
                    ),
                    _RevisitScreen(
                      controller: widget.controller,
                      onOpen: _openEntry,
                    ),
                    _ArchiveScreen(
                      controller: widget.controller,
                      onOpen: _openEntry,
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: _index == 0
              ? useCompactFab
                    ? FloatingActionButton(
                        key: const ValueKey<String>('new_entry'),
                        tooltip: text.newEntry,
                        onPressed: widget.controller.isSaving
                            ? null
                            : _newEntry,
                        child: const Icon(Icons.add_rounded),
                      )
                    : FloatingActionButton.extended(
                        key: const ValueKey<String>('new_entry'),
                        onPressed: widget.controller.isSaving
                            ? null
                            : _newEntry,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(text.newEntry),
                      )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: <NavigationDestination>[
              NavigationDestination(
                icon: const Icon(Icons.edit_note_outlined),
                selectedIcon: const Icon(Icons.edit_note_rounded),
                label: text.today,
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: widget.controller.dueEntries().isNotEmpty,
                  label: Text('${widget.controller.dueEntries().length}'),
                  child: const Icon(Icons.schedule_outlined),
                ),
                selectedIcon: const Icon(Icons.schedule_rounded),
                label: text.revisit,
              ),
              NavigationDestination(
                icon: const Icon(Icons.auto_stories_outlined),
                selectedIcon: const Icon(Icons.auto_stories_rounded),
                label: text.archive,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TodayScreen extends StatelessWidget {
  const _TodayScreen({
    required this.controller,
    required this.onNew,
    required this.onOpen,
  });

  final DiaryController controller;
  final VoidCallback onNew;
  final ValueChanged<DiaryEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final entries = controller.activeEntries;
    final due = controller.dueEntries();
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 3.0);
    return ListView(
      padding: EdgeInsets.only(bottom: 108 + ((textScale - 1) * 96)),
      children: <Widget>[
        PageWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _TodayHero(
                dueCount: due.length,
                openCount: controller.openThreads().length,
              ),
              const SizedBox(height: 26),
              if (entries.isEmpty)
                EmptyState(
                  icon: Icons.subdirectory_arrow_right_rounded,
                  title: text.noEntriesTitle,
                  body: text.noEntriesBody,
                )
              else ...<Widget>[
                if (due.isNotEmpty) ...<Widget>[
                  Text(
                    text.dueNow,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  ...due
                      .take(2)
                      .map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: EntryCard(
                            entry: entry,
                            showDue: true,
                            onTap: () => onOpen(entry),
                          ),
                        ),
                      ),
                  const SizedBox(height: 10),
                ],
                Text(
                  text.recentPages,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ...entries
                    .take(5)
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: EntryCard(
                          entry: entry,
                          onTap: () => onOpen(entry),
                        ),
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

class _TodayHero extends StatelessWidget {
  const _TodayHero({required this.dueCount, required this.openCount});

  final int dueCount;
  final int openCount;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            dueCount == 0 ? text.noDueTitle : text.dueNow,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: scheme.onPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            '$dueCount',
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(color: scheme.onPrimary),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: scheme.onPrimary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${text.openThreads} · $openCount',
              style: TextStyle(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevisitScreen extends StatelessWidget {
  const _RevisitScreen({required this.controller, required this.onOpen});

  final DiaryController controller;
  final ValueChanged<DiaryEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final due = controller.dueEntries();
    final dueIds = due.map((entry) => entry.id).toSet();
    final later = controller
        .openThreads()
        .where((entry) => !dueIds.contains(entry.id))
        .toList();
    if (due.isEmpty && later.isEmpty) {
      return EmptyState(
        icon: Icons.schedule_outlined,
        title: text.noDueTitle,
        body: text.noDueBody,
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 36),
      children: <Widget>[
        PageWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (due.isEmpty)
                EmptyState(
                  icon: Icons.schedule_outlined,
                  title: text.noDueTitle,
                  body: text.noDueBody,
                )
              else ...<Widget>[
                Text(
                  text.dueNow,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ...due.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: EntryCard(
                      entry: entry,
                      showDue: true,
                      onTap: () => onOpen(entry),
                    ),
                  ),
                ),
              ],
              if (later.isNotEmpty) ...<Widget>[
                const SizedBox(height: 18),
                Text(
                  text.upcoming,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ...later.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: EntryCard(entry: entry, onTap: () => onOpen(entry)),
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

enum _ArchiveFilter { all, waiting, closed }

class _ArchiveScreen extends StatefulWidget {
  const _ArchiveScreen({required this.controller, required this.onOpen});

  final DiaryController controller;
  final ValueChanged<DiaryEntry> onOpen;

  @override
  State<_ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<_ArchiveScreen> {
  final _searchController = TextEditingController();
  _ArchiveFilter _filter = _ArchiveFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final entries = widget.controller.activeEntries.where((entry) {
      if (!entry.matches(_searchController.text)) return false;
      return switch (_filter) {
        _ArchiveFilter.all => true,
        _ArchiveFilter.waiting => entry.hasOpenThread,
        _ArchiveFilter.closed => !entry.hasOpenThread,
      };
    }).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 36),
      children: <Widget>[
        PageWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                key: const ValueKey<String>('search_field'),
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: text.search,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  ChoiceChip(
                    label: Text(text.all),
                    selected: _filter == _ArchiveFilter.all,
                    onSelected: (_) =>
                        setState(() => _filter = _ArchiveFilter.all),
                  ),
                  ChoiceChip(
                    label: Text(text.waiting),
                    selected: _filter == _ArchiveFilter.waiting,
                    onSelected: (_) =>
                        setState(() => _filter = _ArchiveFilter.waiting),
                  ),
                  ChoiceChip(
                    label: Text(text.completed),
                    selected: _filter == _ArchiveFilter.closed,
                    onSelected: (_) =>
                        setState(() => _filter = _ArchiveFilter.closed),
                  ),
                  ActionChip(
                    avatar: const Icon(
                      Icons.restore_from_trash_outlined,
                      size: 18,
                    ),
                    label: Text(
                      '${text.recentlyDeleted} · ${widget.controller.trashEntries.length}',
                    ),
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            TrashPage(controller: widget.controller),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (entries.isEmpty)
                EmptyState(
                  icon: Icons.auto_stories_outlined,
                  title: widget.controller.activeEntries.isEmpty
                      ? text.noEntriesTitle
                      : text.noResults,
                  body: widget.controller.activeEntries.isEmpty
                      ? text.noEntriesBody
                      : '',
                )
              else
                ...entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: EntryCard(
                      entry: entry,
                      onTap: () => widget.onOpen(entry),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
