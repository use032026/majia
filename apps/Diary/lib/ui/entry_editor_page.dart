import 'package:flutter/material.dart';

import '../domain/diary_entry.dart';
import '../l10n/app_text.dart';
import '../state/diary_controller.dart';
import 'entry_widgets.dart';

class EntryEditorPage extends StatefulWidget {
  const EntryEditorPage({super.key, required this.controller, this.entry});

  final DiaryController controller;
  final DiaryEntry? entry;

  @override
  State<EntryEditorPage> createState() => _EntryEditorPageState();
}

class _EntryEditorPageState extends State<EntryEditorPage> {
  static const _revisitDayOptions = <int>[3, 7, 14, 30, 90, 180, 365];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _questionController;
  late EntryMood _mood;
  late int _revisitDays;
  bool _revisitChanged = false;
  bool _reopenClosedThread = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _titleController = TextEditingController(text: entry?.title ?? '');
    _bodyController = TextEditingController(text: entry?.body ?? '');
    _questionController = TextEditingController(
      text: entry?.futureQuestion ?? '',
    );
    _mood = entry?.mood ?? EntryMood.calm;
    _revisitDays = _initialRevisitDays(entry);
  }

  int _initialRevisitDays(DiaryEntry? entry) {
    final revisit = entry?.revisitAt;
    if (revisit == null) return 7;
    final days = revisit.difference(DateTime.now()).inDays;
    return _revisitDayOptions.firstWhere(
      (option) => days <= option,
      orElse: () => _revisitDayOptions.last,
    );
  }

  Future<void> _pickRevisitDays() async {
    FocusScope.of(context).unfocus();
    final selectedDays = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _RevisitPickerSheet(
        options: _revisitDayOptions,
        selectedDays: _revisitDays,
      ),
    );
    if (!mounted || selectedDays == null || selectedDays == _revisitDays) {
      return;
    }
    setState(() {
      _revisitDays = selectedDays;
      _revisitChanged = true;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final hasQuestion = _questionController.text.trim().isNotEmpty;
    final existing = widget.entry;
    final editingClosedThread =
        existing?.isClosed == true && existing!.futureQuestion.isNotEmpty;
    final shouldSchedule =
        hasQuestion && (!editingClosedThread || _reopenClosedThread);
    final revisitAt = !shouldSchedule
        ? null
        : existing?.revisitAt != null && !_revisitChanged
        ? existing!.revisitAt
        : DateTime.now().add(Duration(days: _revisitDays));
    final succeeded = existing == null
        ? await widget.controller.createEntry(
                title: _titleController.text,
                body: _bodyController.text,
                mood: _mood,
                futureQuestion: _questionController.text,
                revisitAt: revisitAt,
              ) !=
              null
        : await widget.controller.updateEntry(
            id: existing.id,
            title: _titleController.text,
            body: _bodyController.text,
            mood: _mood,
            futureQuestion: _questionController.text,
            revisitAt: revisitAt,
          );
    if (!mounted) return;
    if (succeeded) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppText.of(context).savedFailure)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final editing = widget.entry != null;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? text.editEntry : text.newEntry),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('save_entry'),
            onPressed: widget.controller.isSaving ? null : _save,
            child: Text(widget.controller.isSaving ? text.saving : text.save),
          ),
          TextButton(
            key: const ValueKey<String>('cancel_editor'),
            onPressed: widget.controller.isSaving
                ? null
                : () => Navigator.of(context).pop(false),
            child: Text(text.cancel),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          key: const ValueKey<String>('entry_editor_scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            TextFormField(
              key: const ValueKey<String>('title_field'),
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 80,
              decoration: InputDecoration(labelText: text.entryTitle),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey<String>('body_field'),
              controller: _bodyController,
              minLines: 7,
              maxLines: 16,
              maxLength: 12000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: text.entryBody,
                alignLabelWithHint: true,
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? text.requiredBody
                  : null,
            ),
            const SizedBox(height: 6),
            Text(text.mood, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: EntryMood.values
                  .map((mood) {
                    return ChoiceChip(
                      avatar: Icon(moodIcon(mood), size: 18),
                      label: Text(moodLabel(text, mood)),
                      selected: _mood == mood,
                      onSelected: (_) => setState(() => _mood = mood),
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 24),
            TextFormField(
              key: const ValueKey<String>('question_field'),
              controller: _questionController,
              minLines: 2,
              maxLines: 5,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: text.futureQuestion,
                hintText: text.futureQuestionHint,
                alignLabelWithHint: true,
              ),
            ),
            if (widget.entry?.isClosed == true &&
                widget.entry!.futureQuestion.isNotEmpty &&
                _questionController.text.trim().isNotEmpty) ...<Widget>[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(text.reopenThread),
                subtitle: Text(text.reopenThreadHint),
                value: _reopenClosedThread,
                onChanged: (value) {
                  setState(() => _reopenClosedThread = value);
                },
              ),
            ],
            if (_questionController.text.trim().isNotEmpty &&
                (!(widget.entry?.isClosed == true &&
                        widget.entry!.futureQuestion.isNotEmpty) ||
                    _reopenClosedThread)) ...<Widget>[
              const SizedBox(height: 10),
              Semantics(
                button: true,
                label:
                    '${text.revisitDate}: ${text.revisitAfter(_revisitDays)}',
                child: ExcludeSemantics(
                  child: InkWell(
                    key: const ValueKey<String>('revisit_dropdown'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: _pickRevisitDays,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: text.revisitDate,
                        suffixIcon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                        ),
                      ),
                      child: Text(text.revisitAfter(_revisitDays)),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
      bottomNavigationBar: keyboardVisible
          ? null
          : Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                top: false,
                maintainBottomViewPadding: true,
                minimum: const EdgeInsets.symmetric(horizontal: 20),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: FilledButton.icon(
                    key: const ValueKey<String>('save_entry_bottom'),
                    onPressed: widget.controller.isSaving ? null : _save,
                    icon: widget.controller.isSaving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bookmark_add_outlined),
                    label: Text(
                      widget.controller.isSaving ? text.saving : text.save,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _RevisitPickerSheet extends StatelessWidget {
  const _RevisitPickerSheet({
    required this.options,
    required this.selectedDays,
  });

  final List<int> options;
  final int selectedDays;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();

    return BottomSafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(text.revisitDate, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final days = options[index];
                  final selected = days == selectedDays;
                  final targetDate = now.add(Duration(days: days));
                  return Semantics(
                    button: true,
                    selected: selected,
                    label:
                        '${text.revisitAfter(days)}, ${formatDiaryDate(context, targetDate)}',
                    child: Material(
                      key: ValueKey<String>('revisit_option_surface_$days'),
                      color: selected
                          ? scheme.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        key: ValueKey<String>('revisit_option_$days'),
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.of(context).pop(days),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: ExcludeSemantics(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  text.revisitAfter(days),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: selected
                                        ? scheme.onPrimaryContainer
                                        : scheme.onSurface,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatDiaryDate(context, targetDate),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: selected
                                        ? scheme.onPrimaryContainer.withValues(
                                            alpha: 0.75,
                                          )
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
