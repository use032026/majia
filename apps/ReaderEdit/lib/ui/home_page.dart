import 'package:flutter/material.dart';

import '../app/reader_edit_store.dart';
import '../data/text_import_service.dart';
import '../domain/novel.dart';
import '../domain/revision_session.dart';
import '../l10n/app_strings.dart';
import 'create_novel_page.dart';
import 'create_session_page.dart';
import 'novel_detail_page.dart';
import 'revision_queue_page.dart';
import 'scan_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({required this.store, required this.importService, super.key});

  final ReaderEditStore store;
  final TextImportService importService;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    if (!store.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (store.loadFailed) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.appName)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    strings.loadFailed,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: store.isBusy ? null : store.load,
                    icon: const Icon(Icons.refresh),
                    label: Text(strings.retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const _BrandMark(),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                strings.appName,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('settings_button'),
            tooltip: strings.settings,
            onPressed: () => _showSettings(context),
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                if (store.recoveredFromBackup) ...[
                  _RecoveryBanner(store: store),
                  const SizedBox(height: 20),
                ],
                Text(
                  strings.tagline,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        strings.localOnly,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _LibrarySection(
                  store: store,
                  onCreate: () => _openCreateNovel(context),
                  onImport: () => _importNovel(context),
                  onOpen: (novel) => _openNovel(context, novel.id),
                  onDelete: (novel) => _confirmDeleteNovel(context, novel),
                ),
                const SizedBox(height: 36),
                Text(
                  strings.text('读者视角修订', 'Reader-perspective revisions'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 14),
                if (store.sessions.isEmpty)
                  _EmptyDesk(
                    store: store,
                    onNew: () => _openCreate(context),
                    onSample: () => _createSample(context),
                  )
                else ...[
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Text(
                        strings.yourSessions,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      FilledButton.icon(
                        key: const ValueKey('new_session_button'),
                        onPressed: () => _openCreate(context),
                        icon: const Icon(Icons.add),
                        label: Text(strings.newRevision),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final session in store.sessions) ...[
                    _SessionCard(
                      session: session,
                      onTap: () => _openSession(context, session.id),
                      onDelete: () => _confirmDelete(context, session),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateNovel(BuildContext context) async {
    final novelId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => CreateNovelPage(store: store)),
    );
    if (novelId != null && context.mounted) {
      await _openNovel(context, novelId);
    }
  }

  Future<void> _importNovel(BuildContext context) async {
    final strings = AppStrings.of(context);
    try {
      final file = await importService.pickTextFile();
      if (file == null) return;
      final novel = await store.importNovel(
        fileName: file.name,
        content: file.content,
      );
      if (context.mounted) await _openNovel(context, novel.id);
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.text(
              '导入失败。请选择 UTF-8 / UTF-16 编码且不超过 200 万字符的 TXT / Markdown 文件。',
              'Import failed. Choose a UTF-8 / UTF-16 TXT or Markdown file under 2 million characters.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _openNovel(BuildContext context, String novelId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NovelDetailPage(
          store: store,
          novelId: novelId,
          importService: importService,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteNovel(BuildContext context, Novel novel) async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          strings.text('删除“${novel.title}”？', 'Delete “${novel.title}”?'),
        ),
        content: Text(
          strings.text(
            '小说和全部章节会从本设备删除，无法恢复。',
            'The novel and every chapter will be removed from this device and cannot be recovered.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await store.deleteNovel(novel.id);
    } on Object {
      if (context.mounted) _showSaveError(context);
    }
  }

  Future<void> _openCreate(BuildContext context) async {
    final sessionId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => CreateSessionPage(store: store)),
    );
    if (sessionId != null && context.mounted) {
      await _openSession(context, sessionId);
    }
  }

  Future<void> _createSample(BuildContext context) async {
    final strings = AppStrings.of(context);
    try {
      final session = await store.createSession(
        title: strings.sampleTitle,
        draft: strings.sampleDraft,
        knowPromise: strings.sampleKnow,
        feelPromise: strings.sampleFeel,
        wonderPromise: strings.sampleWonder,
      );
      if (context.mounted) {
        await _openSession(context, session.id);
      }
    } on Object {
      if (context.mounted) _showSaveError(context);
    }
  }

  Future<void> _openSession(BuildContext context, String sessionId) async {
    final session = store.sessionById(sessionId);
    final page = session.allScanned
        ? RevisionQueuePage(store: store, sessionId: sessionId)
        : ScanPage(store: store, sessionId: sessionId);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _confirmDelete(
    BuildContext context,
    RevisionSession session,
  ) async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.deleteTitle.replaceAll('{title}', session.title)),
        content: Text(strings.deleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await store.deleteSession(session.id);
    } on Object {
      if (context.mounted) _showSaveError(context);
    }
  }

  Future<void> _showSettings(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _SettingsSheet(store: store),
    );
  }

  void _showSaveError(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.of(context).saveFailed)));
  }
}

class _LibrarySection extends StatelessWidget {
  const _LibrarySection({
    required this.store,
    required this.onCreate,
    required this.onImport,
    required this.onOpen,
    required this.onDelete,
  });

  final ReaderEditStore store;
  final VoidCallback onCreate;
  final VoidCallback onImport;
  final ValueChanged<Novel> onOpen;
  final ValueChanged<Novel> onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            Text(
              strings.text('我的小说', 'My novels'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('import_novel_button'),
                  onPressed: store.isBusy ? null : onImport,
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(strings.text('导入', 'Import')),
                ),
                FilledButton.icon(
                  key: const ValueKey('create_novel_button'),
                  onPressed: store.isBusy ? null : onCreate,
                  icon: const Icon(Icons.add),
                  label: Text(strings.text('创建小说', 'Create novel')),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (store.novels.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 38,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.text('从一本小说开始', 'Start with a novel'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.text(
                            '创建空白小说，或导入 TXT / Markdown。导入后可按章节阅读并随时切换编辑。',
                            'Create a blank novel or import TXT / Markdown, then read by chapter and switch into editing at any time.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          for (final novel in store.novels) ...[
            _NovelCard(
              novel: novel,
              onTap: () => onOpen(novel),
              onDelete: () => onDelete(novel),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _NovelCard extends StatelessWidget {
  const _NovelCard({
    required this.novel,
    required this.onTap,
    required this.onDelete,
  });

  final Novel novel;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Card(
      child: InkWell(
        key: ValueKey('novel_${novel.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 17, 8, 17),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.book_outlined),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      novel.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      strings.text(
                        '${novel.chapters.length} 章 · ${novel.characterCount} 字符',
                        '${novel.chapters.length} chapters · ${novel.characterCount} characters',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (novel.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        novel.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: strings.text('删除小说', 'Delete novel'),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      excludeSemantics: true,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Text(
          'R·',
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _EmptyDesk extends StatelessWidget {
  const _EmptyDesk({
    required this.store,
    required this.onNew,
    required this.onSample,
  });

  final ReaderEditStore store;
  final VoidCallback onNew;
  final VoidCallback onSample;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.chrome_reader_mode_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              strings.emptyTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(
              strings.emptyBody,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  key: const ValueKey('empty_new_session_button'),
                  onPressed: store.isBusy ? null : onNew,
                  icon: const Icon(Icons.add),
                  label: Text(strings.newRevision),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('sample_button'),
                  onPressed: store.isBusy ? null : onSample,
                  icon: const Icon(Icons.auto_stories_outlined),
                  label: Text(strings.trySample),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  final RevisionSession session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final scanned = session.passages
        .where((passage) => passage.signal != ReaderSignal.unset)
        .length;
    final progress = session.passages.isEmpty
        ? 0.0
        : scanned / session.passages.length;
    return Card(
      child: InkWell(
        key: ValueKey('session_${session.id}'),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
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
                          session.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          strings.sessionStage(
                            session.allScanned,
                            session.unresolvedCount,
                            session.isComplete,
                          ),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: strings.deleteSession,
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: session.allScanned ? 1 : progress,
                  minHeight: 7,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                strings.counts(
                  countCjkCharacters(session.revisedDraft),
                  countLatinWords(session.revisedDraft),
                  session.passages.length,
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecoveryBanner extends StatelessWidget {
  const _RecoveryBanner({required this.store});

  final ReaderEditStore store;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Material(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.restore_rounded),
            const SizedBox(width: 12),
            Expanded(child: Text(strings.recovered)),
            TextButton(
              onPressed: store.dismissRecoveryNotice,
              child: Text(strings.understood),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({required this.store});

  final ReaderEditStore store;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  strings.settings,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                Text(
                  strings.language,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  key: const ValueKey('language_selector'),
                  segments: [
                    ButtonSegment(value: 'zh', label: Text(strings.chinese)),
                    ButtonSegment(value: 'en', label: Text(strings.english)),
                  ],
                  selected: {store.languageCode},
                  onSelectionChanged: store.isBusy
                      ? null
                      : (selection) async {
                          try {
                            await store.setLanguageCode(selection.first);
                          } on Object {
                            if (context.mounted) _showError(context);
                          }
                        },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  key: const ValueKey('dark_mode_switch'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(strings.darkMode),
                  value: store.darkMode,
                  onChanged: store.isBusy
                      ? null
                      : (value) async {
                          try {
                            await store.setDarkMode(value);
                          } on Object {
                            if (context.mounted) _showError(context);
                          }
                        },
                ),
                const Divider(height: 36),
                Text(
                  strings.dataPrivacy,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(strings.dataPrivacyBody),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed:
                      (store.sessions.isEmpty && store.novels.isEmpty) ||
                          store.isBusy
                      ? null
                      : () => _confirmClear(context),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: Text(strings.clearAll),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.clearAllTitle),
        content: Text(strings.clearAllBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.erase),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await store.clearAll();
      if (context.mounted) Navigator.pop(context);
    } on Object {
      if (context.mounted) _showError(context);
    }
  }

  void _showError(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.of(context).saveFailed)));
  }
}
