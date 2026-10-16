import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_notice.dart';

import 'page_safe_area.dart';

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
        body: PageSafeArea(
          builder: (context) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: pageScrollPadding(context),
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
                          fontSize: 17,
                          height: 1.7,
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
                  LayoutBuilder(
                    builder: (context, constraints) => Row(
                      children: [
                        Expanded(
                          child: _SignalChip(
                            key: const ValueKey('signal_clear'),
                            label: strings.signalClear,
                            color: const Color(0xFF1D6B52),
                            fontSize: constraints.maxWidth < 300 ? 13 : 14,
                            selected: _signal == ReaderSignal.clear,
                            onSelected: () => _choose(ReaderSignal.clear),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SignalChip(
                            key: const ValueKey('signal_dragging'),
                            label: strings.signalDragging,
                            color: const Color(0xFF95451E),
                            fontSize: constraints.maxWidth < 300 ? 13 : 14,
                            selected: _signal == ReaderSignal.dragging,
                            onSelected: () => _choose(ReaderSignal.dragging),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SignalChip(
                            key: const ValueKey('signal_lost'),
                            label: strings.signalLost,
                            color: const Color(0xFF923149),
                            fontSize: constraints.maxWidth < 300 ? 13 : 14,
                            selected: _signal == ReaderSignal.lost,
                            onSelected: () => _choose(ReaderSignal.lost),
                          ),
                        ),
                      ],
                    ),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_index > 0) ...[
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _saveAndPrevious,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                          icon: const Icon(Icons.arrow_back),
                          label: Text(
                            strings.previous,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton.icon(
                        key: const ValueKey('scan_save_button'),
                        onPressed: _saving ? null : _saveAndContinue,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
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
                          textAlign: TextAlign.center,
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
      showAppNotice(context, AppStrings.of(context).chooseSignal);
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
        showAppNotice(context, AppStrings.of(context).saveFailed);
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
    return await showCupertinoDialog<bool>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: Text(strings.unsavedTitle),
            content: Text(strings.unsavedBody),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(strings.cancel),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
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
    required this.label,
    required this.color,
    required this.selected,
    required this.fontSize,
    required this.onSelected,
    super.key,
  });

  final double fontSize;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      labelPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      label: SizedBox(
        width: double.infinity,
        child: Text(label, textAlign: TextAlign.center),
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: color,
      labelStyle: TextStyle(
        fontSize: fontSize,
        height: 1.3,
        color: selected
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}
