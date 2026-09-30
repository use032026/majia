import 'package:flutter/material.dart';

import '../app/reader_edit_store.dart';
import '../domain/revision_session.dart';
import '../l10n/app_strings.dart';

class RevisionEditorPage extends StatefulWidget {
  const RevisionEditorPage({
    required this.store,
    required this.sessionId,
    required this.passageId,
    super.key,
  });

  final ReaderEditStore store;
  final String sessionId;
  final String passageId;

  @override
  State<RevisionEditorPage> createState() => _RevisionEditorPageState();
}

class _RevisionEditorPageState extends State<RevisionEditorPage> {
  late final PassageRevision _originalState;
  late final TextEditingController _controller;
  late bool _resolved;
  bool _saving = false;

  PassageRevision get _passage => widget.store
      .sessionById(widget.sessionId)
      .passages
      .firstWhere((passage) => passage.id == widget.passageId);

  bool get _dirty =>
      _controller.text.trim() != _originalState.revised.trim() ||
      _resolved != _originalState.isResolved;

  @override
  void initState() {
    super.initState();
    _originalState = _passage;
    _controller = TextEditingController(text: _passage.revised);
    _resolved = _passage.isResolved;
    _controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (discard && mounted) {
          _controller.text = _originalState.revised;
          setState(() => _resolved = _originalState.isResolved);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(strings.revisionTitle)),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                children: [
                  Text(
                    strings.before,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SelectableText(
                      _originalState.original,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  if (_originalState.note.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 20,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_originalState.note)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 26),
                  Text(
                    strings.after,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('revision_field'),
                    controller: _controller,
                    minLines: 8,
                    maxLines: 18,
                    maxLength: 10000,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: strings.after,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    key: const ValueKey('resolved_checkbox'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(strings.markResolved),
                    value: _resolved,
                    onChanged: (value) =>
                        setState(() => _resolved = value ?? false),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    key: const ValueKey('save_revision_button'),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(strings.saveRevision),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final strings = AppStrings.of(context);
    if (_controller.text.trim().isEmpty) {
      _show(strings.emptyRevision);
      return;
    }
    if (_resolved &&
        _controller.text.trim() == _originalState.original.trim()) {
      _show(strings.resolutionNeedsChange);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.store.saveRevision(
        sessionId: widget.sessionId,
        passageId: widget.passageId,
        revised: _controller.text,
        isResolved: _resolved,
      );
      if (mounted) Navigator.pop(context);
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        _show(strings.saveFailed);
      }
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmDiscard() async {
    final strings = AppStrings.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(strings.unsavedTitle),
            content: Text(strings.unsavedBody),
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
