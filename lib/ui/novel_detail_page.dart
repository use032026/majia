import 'package:flutter/material.dart';

import '../app/reader_edit_store.dart';
import '../data/text_import_service.dart';
import '../domain/novel.dart';
import '../l10n/app_strings.dart';
import 'chapter_reader_page.dart';
import 'create_chapter_page.dart';

class NovelDetailPage extends StatelessWidget {
  const NovelDetailPage({
    required this.store,
    required this.novelId,
    required this.importService,
    super.key,
  });

  final ReaderEditStore store;
  final String novelId;
  final TextImportService importService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final novel = store.novelById(novelId);
        final strings = AppStrings.of(context);
        return Scaffold(
          appBar: AppBar(
            title: Text(
              novel.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
                  children: [
                    Text(
                      novel.title,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    if (novel.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        novel.description,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      strings.text(
                        '${novel.chapters.length} 章 · ${novel.characterCount} 字符',
                        '${novel.chapters.length} chapters · ${novel.characterCount} characters',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          key: const ValueKey('add_chapter_button'),
                          onPressed: store.isBusy
                              ? null
                              : () => _createChapter(context),
                          icon: const Icon(Icons.add),
                          label: Text(strings.text('新建章节', 'New chapter')),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey('import_chapters_button'),
                          onPressed: store.isBusy
                              ? null
                              : () => _importChapters(context),
                          icon: const Icon(Icons.file_open_outlined),
                          label: Text(strings.text('导入文本', 'Import text')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      strings.text('章节', 'Chapters'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 14),
                    if (novel.chapters.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.menu_book_outlined, size: 38),
                              const SizedBox(height: 14),
                              Text(
                                strings.text(
                                  '还没有章节。可以从空白开始，也可以导入 TXT / Markdown 长文本。',
                                  'No chapters yet. Start blank or import a TXT / Markdown manuscript.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      for (
                        var index = 0;
                        index < novel.chapters.length;
                        index++
                      ) ...[
                        _ChapterCard(
                          chapter: novel.chapters[index],
                          index: index,
                          onTap: () =>
                              _openChapter(context, novel.chapters[index].id),
                          onDelete: () => _confirmDeleteChapter(
                            context,
                            novel.chapters[index],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _createChapter(BuildContext context) async {
    final chapterId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CreateChapterPage(store: store, novelId: novelId),
      ),
    );
    if (chapterId != null && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChapterReaderPage(
            store: store,
            novelId: novelId,
            chapterId: chapterId,
            initiallyEditing: true,
          ),
        ),
      );
    }
  }

  Future<void> _importChapters(BuildContext context) async {
    final strings = AppStrings.of(context);
    try {
      final file = await importService.pickTextFile();
      if (file == null) return;
      final chapters = await store.importChapters(
        novelId: novelId,
        fileName: file.name,
        content: file.content,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.text(
              '已导入 ${chapters.length} 个章节。',
              'Imported ${chapters.length} chapters.',
            ),
          ),
        ),
      );
      await _openChapter(context, chapters.first.id);
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

  Future<void> _openChapter(BuildContext context, String chapterId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChapterReaderPage(
          store: store,
          novelId: novelId,
          chapterId: chapterId,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteChapter(
    BuildContext context,
    NovelChapter chapter,
  ) async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          strings.text('删除“${chapter.title}”？', 'Delete “${chapter.title}”?'),
        ),
        content: Text(
          strings.text(
            '章节正文会从本设备删除，无法恢复。',
            'The chapter text will be removed from this device and cannot be recovered.',
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
      await store.deleteChapter(novelId, chapter.id);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.saveFailed)));
      }
    }
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({
    required this.chapter,
    required this.index,
    required this.onTap,
    required this.onDelete,
  });

  final NovelChapter chapter;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Card(
      child: InkWell(
        key: ValueKey('chapter_${chapter.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${index + 1}'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.text(
                        '${chapter.content.runes.length} 字符',
                        '${chapter.content.runes.length} characters',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: strings.text('删除章节', 'Delete chapter'),
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
