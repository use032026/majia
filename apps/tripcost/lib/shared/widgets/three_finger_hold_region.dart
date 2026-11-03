import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

class ThreeFingerHoldRegion extends StatefulWidget {
  const ThreeFingerHoldRegion({
    required this.child,
    required this.onActivated,
    this.enabled = true,
    this.onError,
    super.key,
  });

  final Widget child;
  final FutureOr<void> Function() onActivated;
  final bool enabled;
  final void Function(Object error, StackTrace stackTrace)? onError;

  @override
  ThreeFingerHoldRegionState createState() => ThreeFingerHoldRegionState();
}

class ThreeFingerHoldRegionState extends State<ThreeFingerHoldRegion>
    with WidgetsBindingObserver {
  final _origins = <int, Offset>{};
  final _screenPointers = <int>{};
  Timer? _timer;
  bool _requiresAllUp = false;
  bool _activating = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_trackScreenPointer);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_canActivate) cancel();
  }

  @override
  void didUpdateWidget(ThreeFingerHoldRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) cancel();
  }

  @override
  void deactivate() {
    cancel();
    super.deactivate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    GestureBinding.instance.pointerRouter.removeGlobalRoute(
      _trackScreenPointer,
    );
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Disarm an in-progress hold before opening another route.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _requiresAllUp = _origins.isNotEmpty || _screenPointers.isNotEmpty;
  }

  bool get _canActivate =>
      mounted &&
      widget.enabled &&
      _foreground &&
      TickerMode.of(context) &&
      _routesAreCurrent;

  bool get _routesAreCurrent {
    BuildContext? routeContext = context;
    final visited = <NavigatorState>{};
    while (routeContext != null) {
      if (ModalRoute.of(routeContext)?.isCurrent == false) return false;
      final navigator = Navigator.maybeOf(routeContext);
      if (navigator == null || !visited.add(navigator)) break;
      // A nested branch route can remain current while a root route covers it.
      // Continue outside that Navigator to check each enclosing modal route.
      BuildContext? parent;
      navigator.context.visitAncestorElements((element) {
        parent = element;
        return false;
      });
      routeContext = parent;
    }
    return true;
  }

  void _pointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    // Listener and global routes can see the same event in either order.
    // Idempotent updates make the all-screen count correct before arming.
    _screenPointers.add(event.pointer);
    _origins[event.pointer] = event.position;
    if (!_canActivate) {
      cancel();
      return;
    }
    if (_requiresAllUp || _activating) return;
    if (_origins.length > 3 || _screenPointers.length > 3) {
      cancel();
    } else if (_origins.length == 3 && _screenPointers.length == 3) {
      _timer = Timer(const Duration(seconds: 5), _holdCompleted);
    }
  }

  void _trackScreenPointer(PointerEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    if (event is PointerDownEvent) {
      _screenPointers.add(event.pointer);
      // The Settings page excludes the app's bottom navigation. An extra
      // contact there still disqualifies an exactly-three-finger hold.
      if (_screenPointers.length > 3) cancel();
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      final wasOnScreen = _screenPointers.remove(event.pointer);
      final wasInRegion = _origins.remove(event.pointer) != null;
      if (wasOnScreen || wasInRegion) cancel();
    }
  }

  void _pointerMove(PointerMoveEvent event) {
    final origin = _origins[event.pointer];
    if (origin != null && (event.position - origin).distance > kTouchSlop) {
      cancel();
    }
  }

  void _pointerEnded(PointerEvent event) {
    if (_origins.remove(event.pointer) == null) return;
    _screenPointers.remove(event.pointer);
    cancel();
  }

  void _holdCompleted() {
    _timer = null;
    if (!_canActivate ||
        _requiresAllUp ||
        _origins.length != 3 ||
        _screenPointers.length != 3 ||
        _activating) {
      cancel();
      return;
    }
    _requiresAllUp = true;
    _activating = true;
    unawaited(_activate());
  }

  Future<void> _activate() async {
    try {
      await widget.onActivated();
    } on Object catch (error, stackTrace) {
      try {
        final handler = widget.onError;
        if (handler != null) {
          handler(error, stackTrace);
        } else {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'three finger hold',
            ),
          );
        }
      } on Object catch (handlerError, handlerStack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: handlerError,
            stack: handlerStack,
            library: 'three finger hold error handler',
          ),
        );
      }
    } finally {
      _activating = false;
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _pointerDown,
    onPointerMove: _pointerMove,
    onPointerUp: _pointerEnded,
    onPointerCancel: _pointerEnded,
    child: widget.child,
  );
}
