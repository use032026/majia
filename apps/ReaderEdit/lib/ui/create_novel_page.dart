import 'package:flutter/material.dart';

import '../app/reader_edit_store.dart';
import '../l10n/app_strings.dart';

class CreateNovelPage extends StatefulWidget {
  const CreateNovelPage({required this.store, super.key});

  final ReaderEditStore store;

  @override
  State<CreateNovelPage> createState() => _CreateNovelPageState();
}

class _CreateNovelPageState extends State<CreateNovelPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('创建小说', 'Create novel'))),
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
                      '先建立一本本地小说，再添加、导入和编辑章节。',
                      'Create a local novel, then add, import, and edit chapters.',
                    ),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const ValueKey('novel_title_field'),
                    controller: _titleController,
                    autofocus: true,
                    maxLength: 100,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: strings.text('小说名称', 'Novel title'),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? strings.text('请填写小说名称', 'Enter a novel title')
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('novel_description_field'),
                    controller: _descriptionController,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: strings.text(
                        '简介（可选）',
                        'Description (optional)',
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const ValueKey('create_novel_submit_button'),
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.library_books_outlined),
                    label: Text(
                      strings.text('创建并添加章节', 'Create and add chapters'),
                    ),
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
      final novel = await widget.store.createNovel(
        title: _titleController.text,
        description: _descriptionController.text,
      );
      if (mounted) Navigator.pop(context, novel.id);
    } on Object {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).saveFailed)),
      );
    }
  }
}
