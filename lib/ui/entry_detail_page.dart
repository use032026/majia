import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/diary_entry.dart';
import '../l10n/app_text.dart';
import '../state/diary_controller.dart';
import 'entry_editor_page.dart';
import 'entry_widgets.dart';

class EntryDetailPage extends StatelessWidget {
  const EntryDetailPage({
    super.key,
    required this.controller,
    required this.entryId,
  });

  final DiaryController controller;
  final String entryId;

  Future<void> _openEditor(BuildContext context, DiaryEntry entry) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EntryEditorPage(controller: controller, entry: entry),
      ),
    );
  }

  Future<void> _addEcho(BuildContext context, DiaryEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _EchoComposer(
        onSave: (draft) => controller.addEcho(
          entryId: entry.id,
          body: draft.body,
          shift: draft.shift,
          closeThread: draft.closeThread,
          nextRevisitAt: draft.closeThread
              ? null
              : DateTime.now().add(const Duration(days: 7)),
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context, DiaryEntry entry) async {
    final text = AppText.of(context);
    final buffer = StringBuffer()
      ..writeln(text.appName)
      ..writeln(entry.title.isEmpty ? text.pageUntitled : entry.title)
      ..writeln(formatDiaryDate(context, entry.createdAt))
      ..writeln('${text.mood}: ${moodLabel(text, entry.mood)}')
      ..writeln()
      ..writeln(text.originalPage)
      ..writeln(entry.body);
    if (entry.futureQuestion.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(text.questionForLater)
        ..writeln(entry.futureQuestion);
    }
    for (final echo in entry.echoes) {
      buffer
        ..writeln()
        ..writeln(
          '${text.echoes} · ${formatDiaryDate(context, echo.createdAt)} · ${shiftLabel(text, echo.shift)}',
        )
        ..writeln(echo.body);
    }
    try {
      await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text.copied)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text.copyFailed)));
    }
  }

  Future<void> _delete(BuildContext context, DiaryEntry entry) async {
    final text = AppText.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(text.confirmDeleteTitle),
        content: Text(text.confirmDeleteBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(text.cancel),
          ),
          FilledButton(
            key: const ValueKey<String>('confirm_move_to_trash'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(text.move),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final succeeded = await controller.moveToTrash(entry.id);
    if (!context.mounted) return;
    if (succeeded) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text.savedFailure)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final entry = controller.entryById(entryId);
        if (entry == null || entry.isDeleted) {
          return const Scaffold(body: SizedBox.shrink());
        }
        final text = AppText.of(context);
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(
            title: Text(entry.title.isEmpty ? text.pageUntitled : entry.title),
            actions: <Widget>[
              IconButton(
                tooltip: text.edit,
                onPressed: controller.isSaving
                    ? null
                    : () => _openEditor(context, entry),
                icon: const Icon(Icons.edit_outlined),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'copy') _copy(context, entry);
                  if (value == 'delete') _delete(context, entry);
                },
                itemBuilder: (_) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'copy',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.copy_all_outlined),
                      title: Text(text.copyRecord),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.delete_outline),
                      title: Text(text.delete),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 36),
              children: <Widget>[
                PageWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Chip(
                            avatar: Icon(moodIcon(entry.mood), size: 18),
                            label: Text(moodLabel(text, entry.mood)),
                          ),
                          Chip(
                            avatar: Icon(
                              entry.isClosed
                                  ? Icons.check_circle_outline
                                  : Icons.schedule_rounded,
                              size: 18,
                            ),
                            label: Text(
                              entry.futureQuestion.isEmpty
                                  ? text.plainPage
                                  : entry.isClosed
                                  ? text.closed
                                  : text.open,
                            ),
                          ),
                          Text(
                            formatDiaryDate(context, entry.createdAt),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _PaperSection(
                        eyebrow: text.originalPage,
                        child: SelectableText(
                          entry.body,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _PaperSection(
                        eyebrow: text.questionForLater,
                        emphasized: entry.futureQuestion.isNotEmpty,
                        child: Text(
                          entry.futureQuestion.isEmpty
                              ? text.noQuestion
                              : entry.futureQuestion,
                          style: entry.futureQuestion.isEmpty
                              ? Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: scheme.onSurfaceVariant)
                              : Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (entry.echoes.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 26),
                        Text(
                          text.echoes,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        ...entry.echoes.map(
                          (echo) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _EchoTile(echo: echo),
                          ),
                        ),
                      ],
                      if (entry.hasOpenThread) ...<Widget>[
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          key: const ValueKey<String>('add_echo'),
                          onPressed: controller.isSaving
                              ? null
                              : () => _addEcho(context, entry),
                          icon: const Icon(
                            Icons.subdirectory_arrow_right_rounded,
                          ),
                          label: Text(text.addEcho),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PaperSection extends StatelessWidget {
  const _PaperSection({
    required this.eyebrow,
    required this.child,
    this.emphasized = false,
  });

  final String eyebrow;
  final Widget child;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: emphasized
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: emphasized
              ? scheme.primary.withValues(alpha: 0.45)
              : scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            eyebrow.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EchoTile extends StatelessWidget {
  const _EchoTile({required this.echo});

  final DiaryEcho echo;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final scheme = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: <Widget>[
                        Text(
                          formatDiaryDate(context, echo.createdAt),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        Text(
                          '· ${shiftLabel(text, echo.shift)}',
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SelectableText(echo.body),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EchoDraft {
  const _EchoDraft({
    required this.body,
    required this.shift,
    required this.closeThread,
  });

  final String body;
  final EchoShift shift;
  final bool closeThread;
}

class _EchoComposer extends StatefulWidget {
  const _EchoComposer({required this.onSave});

  final Future<bool> Function(_EchoDraft draft) onSave;

  @override
  State<_EchoComposer> createState() => _EchoComposerState();
}

class _EchoComposerState extends State<_EchoComposer> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  EchoShift _shift = EchoShift.clearer;
  bool _close = true;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final succeeded = await widget.onSave(
      _EchoDraft(
        body: _controller.text.trim(),
        shift: _shift,
        closeThread: _close,
      ),
    );
    if (!mounted) return;
    if (succeeded) {
      setState(() => _saving = false);
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppText.of(context).savedFailure)));
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  text.addEcho,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  key: const ValueKey<String>('echo_body_field'),
                  controller: _controller,
                  autofocus: true,
                  minLines: 4,
                  maxLines: 9,
                  maxLength: 4000,
                  decoration: InputDecoration(
                    labelText: text.echoPrompt,
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? text.echoRequired
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  text.perspective,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: EchoShift.values
                      .map((shift) {
                        return ChoiceChip(
                          label: Text(shiftLabel(text, shift)),
                          selected: _shift == shift,
                          onSelected: (_) => setState(() {
                            _shift = shift;
                            if (shift == EchoShift.resolved) _close = true;
                          }),
                        );
                      })
                      .toList(growable: false),
                ),
                const SizedBox(height: 14),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_close ? text.closeThread : text.keepOpen),
                  value: _close,
                  onChanged: (value) => setState(() => _close = value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey<String>('cancel_echo'),
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(text.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey<String>('save_echo'),
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(text.save),
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
}
