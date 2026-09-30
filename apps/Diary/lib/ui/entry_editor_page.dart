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
    if (days <= 3) return 3;
    if (days <= 7) return 7;
    return 30;
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
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            key: const ValueKey<String>('entry_editor_scroll'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
                DropdownButtonFormField<int>(
                  key: const ValueKey<String>('revisit_dropdown'),
                  initialValue: _revisitDays,
                  decoration: InputDecoration(labelText: text.revisitDate),
                  items: <DropdownMenuItem<int>>[
                    DropdownMenuItem(value: 3, child: Text(text.inThreeDays)),
                    DropdownMenuItem(value: 7, child: Text(text.inOneWeek)),
                    DropdownMenuItem(value: 30, child: Text(text.inOneMonth)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _revisitDays = value;
                        _revisitChanged = true;
                      });
                    }
                  },
                ),
              ],
              const SizedBox(height: 28),
              FilledButton.icon(
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
            ],
          ),
        ),
      ),
    );
  }
}
