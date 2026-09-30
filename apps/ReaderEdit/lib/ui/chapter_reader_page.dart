import 'package:flutter/material.dart';

import '../app/reader_edit_store.dart';
import '../domain/novel.dart';
import '../domain/revision_session.dart';
import '../l10n/app_strings.dart';
import 'create_session_page.dart';
import 'revision_queue_page.dart';
import 'scan_page.dart';

class ChapterReaderPage extends StatefulWidget {
  const ChapterReaderPage({
    required this.store,
    required this.novelId,
    required this.chapterId,
    this.initiallyEditing = false,
    super.key,
  });

  final ReaderEditStore store;
  final String novelId;
  final String chapterId;
  final bool initiallyEditing;

  @override
  State<ChapterReaderPage> createState() => _ChapterReaderPageState();
}

class _ChapterReaderPageState extends State<ChapterReaderPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late bool _editing;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final chapter = widget.store.chapterById(widget.novelId, widget.chapterId);
    _titleController = TextEditingController(text: chapter.title);
    _contentController = TextEditingController(text: chapter.content);
    _editing = widget.initiallyEditing;
    _titleController.addListener(_markDirty);
    _contentController.addListener(_markDirty);
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_markDirty)
      ..dispose();
    _contentController
      ..removeListener(_markDirty)
      ..dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final chapter = widget.store.chapterById(widget.novelId, widget.chapterId);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final discard = await _confirmDiscard();
        if (discard && mounted) {
          setState(() => _dirty = false);
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _editing ? strings.text('编辑章节', 'Edit chapter') : chapter.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (_editing)
              TextButton.icon(
                key: const ValueKey('save_chapter_button'),
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(strings.text('保存', 'Save')),
              )
            else
              TextButton.icon(
                key: const ValueKey('edit_chapter_button'),
                onPressed: _beginEditing,
                icon: const Icon(Icons.edit_outlined),
                label: Text(strings.text('编辑', 'Edit')),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: _editing
                  ? _EditChapterBody(
                      titleController: _titleController,
                      contentController: _contentController,
                    )
                  : _ReadChapterBody(
                      chapter: chapter,
                      onRevise: () => _startRevision(chapter),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _beginEditing() {
    final chapter = widget.store.chapterById(widget.novelId, widget.chapterId);
    _titleController.text = chapter.title;
    _contentController.text = chapter.content;
    setState(() {
      _dirty = false;
      _editing = true;
    });
  }

  Future<void> _save() async {
    final strings = AppStrings.of(context);
    if (_titleController.text.trim().isEmpty) {
      _show(strings.text('章节名称不能为空。', 'Chapter title is required.'));
      return;
    }
    if (_contentController.text.length > NovelChapter.maxContentCharacters) {
      _show(
        strings.text(
          '章节超过 200 万字符上限。',
          'The chapter exceeds 2 million characters.',
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.store.updateChapter(
        novelId: widget.novelId,
        chapterId: widget.chapterId,
        title: _titleController.text,
        content: _contentController.text,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _dirty = false;
        _editing = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      _show(strings.saveFailed);
    }
  }

  Future<void> _startRevision(NovelChapter chapter) async {
    final strings = AppStrings.of(context);
    final passages = splitDraft(chapter.content);
    if (chapter.content.length > RevisionSession.maxDraftCharacters ||
        passages.length < 2 ||
        passages.length > RevisionSession.maxPassages) {
      _show(
        strings.text(
          '当前章节可直接编辑；逐段读者修订适合 2–80 段且不超过 3 万字符的章节。',
          'This chapter can be edited directly. Passage-by-passage revision supports 2–80 passages up to 30,000 characters.',
        ),
      );
      return;
    }
    final novel = widget.store.novelById(widget.novelId);
    final sessionId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CreateSessionPage(
          store: widget.store,
          initialTitle: '${novel.title} · ${chapter.title}',
          initialDraft: chapter.content,
        ),
      ),
    );
    if (sessionId == null || !mounted) return;
    final session = widget.store.sessionById(sessionId);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => session.allScanned
            ? RevisionQueuePage(store: widget.store, sessionId: sessionId)
            : ScanPage(store: widget.store, sessionId: sessionId),
      ),
    );
  }

  Future<bool> _confirmDiscard() async {
    final strings = AppStrings.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(strings.text('放弃未保存的章节修改？', 'Discard chapter edits?')),
            content: Text(
              strings.text(
                '返回后，这次尚未保存的正文修改会丢失。',
                'The unsaved chapter text will be lost.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(strings.discard),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReadChapterBody extends StatelessWidget {
  const _ReadChapterBody({required this.chapter, required this.onRevise});

  final NovelChapter chapter;
  final VoidCallback onRevise;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return ListView(
      key: const ValueKey('chapter_read_view'),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 56),
      children: [
        Text(chapter.title, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 10),
        Text(
          strings.text(
            '${chapter.content.runes.length} 字符 · 本地保存',
            '${chapter.content.runes.length} characters · saved locally',
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        if (chapter.content.trim().isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                strings.text(
                  '这个章节还是空的。点右上角“编辑”开始写作。',
                  'This chapter is empty. Tap Edit to start writing.',
                ),
              ),
            ),
          )
        else
          SelectableText(
            chapter.content,
            key: const ValueKey('chapter_content_text'),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(height: 1.9, fontSize: 18),
          ),
        const SizedBox(height: 36),
        OutlinedButton.icon(
          key: const ValueKey('chapter_revision_button'),
          onPressed: onRevise,
          icon: const Icon(Icons.chrome_reader_mode_outlined),
          label: Text(
            strings.text('进入读者视角修订', 'Start reader-perspective revision'),
          ),
        ),
      ],
    );
  }
}

class _EditChapterBody extends StatelessWidget {
  const _EditChapterBody({
    required this.titleController,
    required this.contentController,
  });

  final TextEditingController titleController;
  final TextEditingController contentController;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return ListView(
      key: const ValueKey('chapter_edit_view'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
      children: [
        TextField(
          key: const ValueKey('edit_chapter_title_field'),
          controller: titleController,
          maxLength: 120,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: strings.text('章节名称', 'Chapter title'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('edit_chapter_content_field'),
          controller: contentController,
          minLines: 18,
          maxLines: null,
          maxLength: NovelChapter.maxContentCharacters,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            labelText: strings.text('正文', 'Chapter text'),
            hintText: strings.text(
              '在这里写作或修改导入的正文…',
              'Write or edit the imported text here…',
            ),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}
