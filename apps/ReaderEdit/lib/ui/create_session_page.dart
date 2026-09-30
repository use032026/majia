import 'package:flutter/material.dart';

import '../app/reader_edit_store.dart';
import '../domain/revision_session.dart';
import '../l10n/app_strings.dart';

class CreateSessionPage extends StatefulWidget {
  const CreateSessionPage({
    required this.store,
    this.initialTitle = '',
    this.initialDraft = '',
    super.key,
  });

  final ReaderEditStore store;
  final String initialTitle;
  final String initialDraft;

  @override
  State<CreateSessionPage> createState() => _CreateSessionPageState();
}

class _CreateSessionPageState extends State<CreateSessionPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _draftController;
  final _knowController = TextEditingController();
  final _feelController = TextEditingController();
  final _wonderController = TextEditingController();
  bool _submitting = false;
  bool _dirty = false;

  Iterable<TextEditingController> get _controllers => [
    _titleController,
    _draftController,
    _knowController,
    _feelController,
    _wonderController,
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _draftController = TextEditingController(text: widget.initialDraft);
    for (final controller in _controllers) {
      controller.addListener(_markDirty);
    }
    _dirty = widget.initialTitle.isNotEmpty || widget.initialDraft.isNotEmpty;
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller
        ..removeListener(_markDirty)
        ..dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final discard = await _confirmDiscard();
        if (discard && mounted) {
          setState(() => _dirty = false);
          await WidgetsBinding.instance.endOfFrame;
          if (mounted) navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(strings.createTitle)),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    Text(
                      strings.createIntro,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const ValueKey('title_field'),
                      controller: _titleController,
                      textInputAction: TextInputAction.next,
                      maxLength: 80,
                      decoration: InputDecoration(
                        labelText: strings.titleLabel,
                      ),
                      validator: (value) => _required(value, strings),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const ValueKey('draft_field'),
                      controller: _draftController,
                      minLines: 10,
                      maxLines: 20,
                      maxLength: RevisionSession.maxDraftCharacters,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        labelText: strings.draftLabel,
                        hintText: strings.draftHint,
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        final required = _required(value, strings);
                        if (required != null) return required;
                        if (value!.length >
                            RevisionSession.maxDraftCharacters) {
                          return strings.tooLong;
                        }
                        final passages = splitDraft(value);
                        if (passages.length < 2) return strings.twoPassages;
                        if (passages.length > RevisionSession.maxPassages) {
                          return strings.tooManyPassages;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    Text(
                      strings.readerPromise,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const ValueKey('know_field'),
                      controller: _knowController,
                      textInputAction: TextInputAction.next,
                      maxLength: 140,
                      decoration: InputDecoration(
                        labelText: strings.knowPrompt,
                      ),
                      validator: (value) => _required(value, strings),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const ValueKey('feel_field'),
                      controller: _feelController,
                      textInputAction: TextInputAction.next,
                      maxLength: 140,
                      decoration: InputDecoration(
                        labelText: strings.feelPrompt,
                      ),
                      validator: (value) => _required(value, strings),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const ValueKey('wonder_field'),
                      controller: _wonderController,
                      textInputAction: TextInputAction.done,
                      maxLength: 140,
                      decoration: InputDecoration(
                        labelText: strings.wonderPrompt,
                      ),
                      validator: (value) => _required(value, strings),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      key: const ValueKey('create_submit_button'),
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_outline_rounded),
                      label: Text(strings.startScan),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value, AppStrings strings) {
    return value == null || value.trim().isEmpty ? strings.requiredField : null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final session = await widget.store.createSession(
        title: _titleController.text,
        draft: _draftController.text,
        knowPromise: _knowController.text,
        feelPromise: _feelController.text,
        wonderPromise: _wonderController.text,
      );
      if (mounted) {
        setState(() => _dirty = false);
        Navigator.pop(context, session.id);
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).saveFailed)),
        );
        setState(() => _submitting = false);
      }
    }
  }

  Future<bool> _confirmDiscard() async {
    final strings = AppStrings.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(strings.createUnsavedTitle),
            content: Text(strings.createUnsavedBody),
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
}
