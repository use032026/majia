import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'layout.dart';

class _Input {
  _Input(this.controller, this.readOnly, this.lines)
    : focus = FocusNode(skipTraversal: readOnly, canRequestFocus: !readOnly);
  final TextEditingController controller;
  final bool readOnly;
  final int lines;
  final FocusNode focus;
  final key = GlobalKey<FormFieldState<String>>();
}

/// Shares keyboard geometry and submission handling, never edits IME composing
/// text and leaves deletion/selection to Flutter's native text editing pipeline.
abstract class EditorState<T extends StatefulWidget> extends State<T>
    with WidgetsBindingObserver {
  final form = GlobalKey<FormState>();
  final scroll = ScrollController();
  final _viewport = GlobalKey();
  final _inputs = <TextEditingController, _Input>{};
  bool saving = false;
  String? error;
  double _inset = 0;
  double? _originalOffset;
  int _positionGeneration = 0;
  Timer? _slowTimer;
  bool _slow = false;
  VoidCallback? _submit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    _updateInset(inset);
    if (_inset > 0) _centerFocused();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final view = View.of(context);
    _updateInset(view.viewInsets.bottom / view.devicePixelRatio);
    setState(() {});
    if (_inset > 0) _centerFocused();
  }

  void _updateInset(double value) {
    if (_inset == value) return;
    final wasVisible = _inset > 0;
    _inset = value;
    if (!wasVisible && value > 0) {
      _originalOffset = scroll.hasClients ? scroll.offset : 0;
    }
    if (wasVisible && value == 0) {
      final original = _originalOffset;
      _originalOffset = null;
      final generation = ++_positionGeneration;
      void restore(Duration _) {
        if (!mounted ||
            generation != _positionGeneration ||
            !scroll.hasClients) {
          return;
        }
        scroll.jumpTo(
          (original ?? 0).clamp(0, scroll.position.maxScrollExtent),
        );
      }

      // The second frame also follows EditableText's own caret reveal request.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        restore(Duration.zero);
        WidgetsBinding.instance.addPostFrameCallback(restore);
      });
    } else if (value > 0) {
      _centerFocused();
    }
  }

  RenderEditable? _editable(RenderObject object) {
    if (object is RenderEditable) return object;
    RenderEditable? result;
    object.visitChildren((child) => result ??= _editable(child));
    return result;
  }

  void _centerFocused() {
    final generation = ++_positionGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _positionGeneration ||
          _inset == 0 ||
          !scroll.hasClients) {
        return;
      }
      final input = _inputs.values.where((f) => f.focus.hasFocus).firstOrNull;
      final fieldBox = input?.key.currentContext?.findRenderObject();
      final viewportBox = _viewport.currentContext?.findRenderObject();
      if (fieldBox is! RenderBox ||
          viewportBox is! RenderBox ||
          !fieldBox.attached ||
          !viewportBox.attached) {
        return;
      }
      var target = fieldBox.localToGlobal(fieldBox.size.center(Offset.zero)).dy;
      if (fieldBox.size.height > viewportBox.size.height) {
        final editable = _editable(fieldBox);
        final selection = input!.controller.selection;
        if (editable != null && selection.isValid) {
          final caret = editable.getLocalRectForCaret(selection.extent);
          target = editable.localToGlobal(caret.center).dy;
        }
      }
      final center = viewportBox
          .localToGlobal(viewportBox.size.center(Offset.zero))
          .dy;
      final offset = (scroll.offset + target - center).clamp(
        0.0,
        scroll.position.maxScrollExtent,
      );
      if ((offset - scroll.offset).abs() > 1) scroll.jumpTo(offset);
    });
  }

  bool _move(_Input input, int direction) {
    final fields = _inputs.values.where((f) => !f.readOnly).toList();
    final next = fields.indexOf(input) + direction;
    if (next < 0 || next >= fields.length) return false;
    fields[next].focus.requestFocus();
    return true;
  }

  KeyEventResult _key(_Input input, KeyEvent event) {
    if (event is KeyUpEvent || saving) return KeyEventResult.ignored;
    final value = input.controller.value;
    if (value.composing.isValid && !value.composing.isCollapsed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (input.lines == 1 ||
          keyboard.isControlPressed ||
          keyboard.isMetaPressed) {
        if (event is KeyDownEvent) _submit?.call();
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.tab &&
        !keyboard.isAltPressed &&
        !keyboard.isControlPressed &&
        !keyboard.isMetaPressed &&
        _move(input, keyboard.isShiftPressed ? -1 : 1)) {
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown) &&
        !keyboard.isShiftPressed &&
        !keyboard.isControlPressed &&
        !keyboard.isMetaPressed &&
        !keyboard.isAltPressed &&
        value.selection.isValid &&
        value.selection.isCollapsed) {
      final up = key == LogicalKeyboardKey.arrowUp;
      final object = input.key.currentContext?.findRenderObject();
      final editable = object == null ? null : _editable(object);
      // Soft wraps are real line boundaries too. If layout is catching up to
      // rapid typing, leave navigation to EditableText rather than steal focus.
      final line = editable?.plainText == value.text
          ? editable?.getLineAtOffset(value.selection.extent)
          : null;
      final boundary =
          line != null &&
          (up ? line.start == 0 : line.end >= value.text.length);
      if (input.lines == 1 || boundary) {
        _move(input, up ? -1 : 1);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> submit(
    Future<bool> Function() action,
    bool zh, {
    String? Function()? failureMessage,
  }) async {
    if (saving) return;
    if (!form.currentState!.validate()) {
      final invalid = _inputs.values
          .where((f) => f.key.currentState?.hasError ?? false)
          .firstOrNull;
      invalid?.focus.requestFocus();
      _centerFocused();
      return;
    }
    if (_inputs.values.any(
      (f) =>
          f.controller.value.composing.isValid &&
          !f.controller.value.composing.isCollapsed,
    )) {
      setState(
        () => error = zh
            ? '请先确认正在输入的文字，再保存。'
            : 'Finish composing your text before saving.',
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
      _slow = false;
    });
    _slowTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && saving) setState(() => _slow = true);
    });
    var ok = false;
    try {
      await WidgetsBinding.instance.endOfFrame;
      ok = await action();
      if (!ok && mounted) {
        setState(
          () => error =
              failureMessage?.call() ??
              (zh
                  ? '未能保存，输入内容已保留。请检查输入与存储空间后重试。'
                  : 'Could not save. Your input is retained. Check values and storage, then retry.'),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = zh
              ? '未能保存，输入内容已保留，请重试。'
              : 'Could not save. Your input is retained. Please retry.',
        );
      }
    } finally {
      _slowTimer?.cancel();
      if (mounted) setState(() => saving = false);
    }
    if (ok && mounted) {
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.pop(context, true);
    }
  }

  Widget field(
    TextEditingController controller,
    String label, {
    int maxLength = 80,
    int lines = 1,
    bool required = false,
    TextInputType? keyboard,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    final input = _inputs.putIfAbsent(controller, () {
      final entry = _Input(controller, readOnly, lines);
      entry.focus.addListener(() {
        if (entry.focus.hasFocus) _centerFocused();
      });
      return entry;
    });
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          label: label,
          child: Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) => _key(input, event),
            child: TextFormField(
              key: input.key,
              controller: controller,
              focusNode: input.focus,
              decoration: InputDecoration(
                filled: true,
                fillColor: scheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.65),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: scheme.primary, width: 1.5),
                ),
                prefixIcon: readOnly
                    ? const Icon(Icons.lock_outline_rounded, size: 18)
                    : null,
              ),
              style: Theme.of(context).textTheme.bodyMedium,
              buildCounter:
                  (
                    context, {
                    required currentLength,
                    required isFocused,
                    required maxLength,
                  }) => isFocused
                  ? Text(
                      '$currentLength / $maxLength',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  : null,
              maxLength: maxLength,
              minLines: lines,
              maxLines: lines,
              enabled: !saving,
              readOnly: readOnly,
              keyboardType:
                  keyboard ??
                  (lines > 1 ? TextInputType.multiline : TextInputType.text),
              textInputAction: lines > 1
                  ? TextInputAction.newline
                  : TextInputAction.done,
              // The default completion clears composing text before onSubmitted.
              // Keep it intact so the shared submit gate can wait for IME commit.
              onEditingComplete: () {},
              onFieldSubmitted: (_) {
                if (lines == 1) _submit?.call();
              },
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              validator:
                  validator ??
                  (required
                      ? (v) => v == null || v.trim().isEmpty ? '$label *' : null
                      : null),
            ),
          ),
        ),
      ],
    );
  }

  Widget editorScaffold({
    required String title,
    required bool zh,
    required List<Widget> children,
    required String submitLabel,
    required VoidCallback onSubmit,
  }) {
    _submit = onSubmit;
    Widget saveButton(String label) => FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      onPressed: saving ? null : onSubmit,
      child: saving
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Flexible(child: Text(zh ? '保存中…' : 'Saving…')),
              ],
            )
          : Text(label),
    );
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: Navigator.canPop(context)
              ? IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: saving ? null : () => Navigator.maybePop(context),
                  icon: const BackButtonIcon(),
                )
              : null,
        ),
        body: Column(
          children: [
            Expanded(
              child: Form(
                key: form,
                child: LayoutBuilder(
                  builder: (context, size) {
                    final extra = _inset > 0 ? size.maxHeight / 2 : 0.0;
                    return SizedBox(
                      key: _viewport,
                      child: FocusTraversalGroup(
                        policy: ReadingOrderTraversalPolicy(),
                        child: SingleChildScrollView(
                          controller: scroll,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                            math.max(16, (size.maxWidth - 720) / 2),
                            12 + extra,
                            math.max(16, (size.maxWidth - 720) / 2),
                            math.max(
                                  24,
                                  MediaQuery.viewPaddingOf(context).bottom,
                                ) +
                                extra,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final child in children) ...[
                                child,
                                const SizedBox(height: 12),
                              ],
                              if (error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Surface(
                                      padding: const EdgeInsets.all(12),
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.errorContainer,
                                      child: Text(
                                        error!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onErrorContainer,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (_slow)
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    zh
                                        ? '仍在保存，请稍候；无需重复提交。'
                                        : 'Still saving. Please wait; no need to submit again.',
                                  ),
                                ),
                              saveButton(submitLabel),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_inset > 0)
              Material(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          icon: const Icon(Icons.keyboard_hide),
                          label: Text(zh ? '收起键盘' : 'Hide keyboard'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(child: saveButton(zh ? '完成' : 'Done')),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _positionGeneration++;
    _slowTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    for (final input in _inputs.values) {
      input.focus.dispose();
    }
    scroll.dispose();
    super.dispose();
  }
}
