import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Hidden title gesture, cancelled by any second pointer or app interruption.
class FiveSecondHold extends StatefulWidget {
  const FiveSecondHold({super.key, required this.child, required this.onHold});
  final Widget child;
  final VoidCallback onHold;
  static const duration = Duration(seconds: 5);

  @override
  State<FiveSecondHold> createState() => _FiveSecondHoldState();
}

class _FiveSecondHoldState extends State<FiveSecondHold>
    with WidgetsBindingObserver {
  final _pointers = <int>{};
  Timer? _timer;
  int? _active;
  Offset? _start;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_globalPointer);
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
    _active = null;
    _start = null;
  }

  void _globalPointer(PointerEvent event) {
    if (event is PointerDownEvent) {
      _pointers.add(event.pointer);
      if (_pointers.length > 1) _cancel();
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointers.remove(event.pointer);
      if (_active == event.pointer) _cancel();
    }
  }

  void _down(PointerDownEvent event) {
    _pointers.add(event.pointer);
    if (_pointers.length != 1 || event.buttons != kPrimaryButton) {
      _cancel();
      return;
    }
    _cancel();
    _active = event.pointer;
    _start = event.position;
    _timer = Timer(FiveSecondHold.duration, () {
      if (!mounted || _active == null || _pointers.length != 1) return;
      _cancel();
      widget.onHold();
    });
  }

  void _move(PointerMoveEvent event) {
    if (_active != event.pointer) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    final local = renderBox?.globalToLocal(event.position);
    if (renderBox == null ||
        local == null ||
        !(Offset.zero & renderBox.size).contains(local) ||
        (event.position - _start!).distance > kTouchSlop) {
      _cancel();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _cancel();
      _pointers.clear();
    }
  }

  @override
  void dispose() {
    _cancel();
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_globalPointer);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: (_) => _cancel(),
    onPointerCancel: (_) => _cancel(),
    child: widget.child,
  );
}
