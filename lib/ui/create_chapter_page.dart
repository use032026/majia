import 'package:flutter/material.dart';

import '../app/reader_edit_store.dart';
import '../l10n/app_strings.dart';

class CreateChapterPage extends StatefulWidget {
  const CreateChapterPage({
    required this.store,
    required this.novelId,
    super.key,
  });

  final ReaderEditStore store;
  final String novelId;

  @override
  State<CreateChapterPage> createState() => _CreateChapterPageState();
}

class _CreateChapterPageState extends State<CreateChapterPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('新建章节', 'New chapter'))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  Text(
                    strings.text(
                      '创建后会直接进入编辑模式，可一边阅读一边切换修改。',
                      'The chapter opens in edit mode and can switch between reading and editing.',
                    ),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const ValueKey('chapter_title_field'),
                    controller: _titleController,
                    autofocus: true,
                    maxLength: 120,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: strings.text('章节名称', 'Chapter title'),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? strings.text('请填写章节名称', 'Enter a chapter title')
                        : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const ValueKey('create_chapter_submit_button'),
                    onPressed: _submitting ? null : _submit,
                    icon: const Icon(Icons.edit_note_rounded),
                    label: Text(strings.text('创建并编辑', 'Create and edit')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final chapter = await widget.store.addChapter(
        novelId: widget.novelId,
        title: _titleController.text,
      );
      if (mounted) Navigator.pop(context, chapter.id);
    } on Object {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).saveFailed)),
      );
    }
  }
}
