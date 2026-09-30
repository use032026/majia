import 'package:flutter/material.dart';

import '../app/reader_edit_store.dart';
import '../domain/revision_session.dart';
import '../l10n/app_strings.dart';
import 'revision_queue_page.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({
    required this.store,
    required this.sessionId,
    this.initialPassageId,
    this.returnAfterSave = false,
    super.key,
  });

  final ReaderEditStore store;
  final String sessionId;
  final String? initialPassageId;
  final bool returnAfterSave;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _noteController = TextEditingController();
  late int _index;
  ReaderSignal _signal = ReaderSignal.unset;
  bool _saving = false;
  bool _dirty = false;

  RevisionSession get _session => widget.store.sessionById(widget.sessionId);

  @override
  void initState() {
    super.initState();
    final requested = widget.initialPassageId == null
        ? -1
        : _session.passages.indexWhere(
            (passage) => passage.id == widget.initialPassageId,
          );
    final firstUnscanned = _session.passages.indexWhere(
      (passage) => passage.signal == ReaderSignal.unset,
    );
    _index = requested >= 0
        ? requested
        : (firstUnscanned == -1 ? 0 : firstUnscanned);
    _syncFromPassage();
    _noteController.addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    _noteController
      ..removeListener(_onNoteChanged)
      ..dispose();
    super.dispose();
  }

  void _syncFromPassage() {
    final passage = _session.passages[_index];
    _signal = passage.signal;
    _noteController.text = passage.note;
    _dirty = false;
  }

  void _onNoteChanged() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final session = _session;
    final passage = session.passages[_index];
    final isLast = _index == session.passages.length - 1;

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
        appBar: AppBar(title: Text(strings.scanTitle)),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.passageProgress(
                          _index + 1,
                          session.passages.length,
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strings.counts(
                          countCjkCharacters(passage.original),
                          countLatinWords(passage.original),
                          1,
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: (_index + 1) / session.passages.length,
                      minHeight: 7,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Material(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.visibility_outlined),
                          const SizedBox(width: 12),
                          Expanded(child: Text(strings.scanRule)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: SelectableText(
                        passage.original,
                        key: ValueKey('passage_text_${passage.id}'),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 19,
                          height: 1.85,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    strings.signalQuestion,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _SignalChip(
                        key: const ValueKey('signal_clear'),
                        icon: Icons.check_circle_outline,
                        label: strings.signalClear,
                        color: const Color(0xFF1D6B52),
                        selected: _signal == ReaderSignal.clear,
                        onSelected: () => _choose(ReaderSignal.clear),
                      ),
                      _SignalChip(
                        key: const ValueKey('signal_dragging'),
                        icon: Icons.hourglass_bottom_rounded,
                        label: strings.signalDragging,
                        color: const Color(0xFF95451E),
                        selected: _signal == ReaderSignal.dragging,
                        onSelected: () => _choose(ReaderSignal.dragging),
                      ),
                      _SignalChip(
                        key: const ValueKey('signal_lost'),
                        icon: Icons.help_outline_rounded,
                        label: strings.signalLost,
                        color: const Color(0xFF923149),
                        selected: _signal == ReaderSignal.lost,
                        onSelected: () => _choose(ReaderSignal.lost),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    key: const ValueKey('scan_note_field'),
                    controller: _noteController,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 280,
                    decoration: InputDecoration(
                      labelText: strings.optionalNote,
                      hintText: strings.noteHint,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (_index > 0) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _saveAndPrevious,
                            icon: const Icon(Icons.arrow_back),
                            label: Text(strings.previous),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          key: const ValueKey('scan_save_button'),
                          onPressed: _saving ? null : _saveAndContinue,
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  widget.returnAfterSave
                                      ? Icons.arrow_back_rounded
                                      : isLast
                                      ? Icons.playlist_add_check
                                      : Icons.arrow_forward,
                                ),
                          label: Text(
                            widget.returnAfterSave
                                ? strings.saveAndReturn
                                : isLast
                                ? strings.buildQueue
                                : strings.saveNext,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _choose(ReaderSignal value) {
    setState(() {
      _signal = value;
      _dirty = true;
    });
  }

  Future<bool> _save() async {
    if (_signal == ReaderSignal.unset) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).chooseSignal)),
      );
      return false;
    }
    setState(() => _saving = true);
    try {
      await widget.store.recordSignal(
        sessionId: widget.sessionId,
        passageId: _session.passages[_index].id,
        signal: _signal,
        note: _noteController.text,
      );
      if (mounted) {
        setState(() {
          _saving = false;
          _dirty = false;
        });
      }
      return true;
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).saveFailed)),
        );
      }
      return false;
    }
  }

  Future<void> _saveAndContinue() async {
    if (!await _save() || !mounted) return;
    if (widget.returnAfterSave) {
      Navigator.of(context).pop();
      return;
    }
    if (_index < _session.passages.length - 1) {
      setState(() {
        _index++;
        _syncFromPassage();
      });
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            RevisionQueuePage(store: widget.store, sessionId: widget.sessionId),
      ),
    );
  }

  Future<void> _saveAndPrevious() async {
    if (!await _save() || !mounted) return;
    setState(() {
      _index--;
      _syncFromPassage();
    });
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

class _SignalChip extends StatelessWidget {
  const _SignalChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: Icon(icon, size: 19, color: selected ? Colors.white : color),
      label: Text(label),
      selected: selected,
      selectedColor: color,
      labelStyle: TextStyle(
        color: selected
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}
