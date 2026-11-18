import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/widgets.dart';

/// A verified main-document commit, rather than DOM or visual completeness.
enum StminiLocalPhase { loading, ready, failed, closed }

@immutable
final class StminiLocalState {
  const StminiLocalState._(this.phase, this.canGoBack, this.errorCode);

  factory StminiLocalState.fromMap(Object? value) {
    const keys = {'phase', 'canGoBack', 'errorCode'};
    if (value is! Map ||
        value.length != 3 ||
        value.keys.any((key) => !keys.contains(key)) ||
        value['phase'] is! String ||
        value['canGoBack'] is! bool) {
      throw const FormatException('Invalid local renderer state.');
    }
    final phase = switch (value['phase']) {
      'loading' => StminiLocalPhase.loading,
      'ready' => StminiLocalPhase.ready,
      'failed' => StminiLocalPhase.failed,
      'closed' => StminiLocalPhase.closed,
      _ => throw const FormatException('Invalid local renderer phase.'),
    };
    final error = value['errorCode'];
    if (error != null && (error is! String || !_errorCodes.contains(error))) {
      throw const FormatException('Invalid local renderer error.');
    }
    return StminiLocalState._(
      phase,
      value['canGoBack'] as bool,
      error as String?,
    );
  }

  static const _errorCodes = {
    'invalid_parameters',
    'not_initialized',
    'package_unavailable',
    'resource_unavailable',
    'navigation_rejected',
    'render_timeout',
    'renderer_terminated',
    'disposed',
  };
  final StminiLocalPhase phase;
  final bool canGoBack;
  final String? errorCode;
}

/// Owns exactly one native view lifetime. Supply a new controller when changing
/// identity or re-adding a removed view. No URL, file or JavaScript API exists.
final class StminiLocalController extends ChangeNotifier {
  MethodChannel? _channel;
  Object? _lease;
  bool _everBound = false;
  bool _reserved = false;
  bool _disposed = false;
  bool _closing = false;
  int _revision = 0;
  int _stateRequest = 0;
  StminiLocalState? _state;
  bool _protocolFailed = false;
  Future<void>? _closeFuture;

  StminiLocalState? get state => _state;
  bool get hasProtocolError => _protocolFailed;
  bool get isAttached => _lease != null && !_closing && !_disposed;

  Future<void> _attach(int viewId) async {
    if (_disposed || _everBound) throw StateError('Controller already used.');
    _everBound = true;
    final lease = Object();
    _lease = lease;
    final channel = MethodChannel('stmini_flutter/local_view/$viewId');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (!_current(lease) || _closing) return null;
      if (call.method != 'stateChanged') {
        _failProtocol(lease);
        throw const FormatException('Invalid local renderer event.');
      }
      try {
        final state = StminiLocalState.fromMap(call.arguments);
        _revision += 1;
        _accept(state, lease);
      } on FormatException {
        _failProtocol(lease);
        rethrow;
      }
      return null;
    });
    // A view may emit before Dart installs its handler. Recover current truth,
    // but never let this older response overwrite a newer stateChanged event.
    try {
      await getState();
    } catch (_) {
      if (_current(lease) && !_closing) _failProtocol(lease);
    }
  }

  bool _current(Object lease) => !_disposed && identical(_lease, lease);

  Object _requireLease() {
    final lease = _lease;
    if (lease == null || _disposed || _closing || _protocolFailed) {
      throw StateError('Local renderer controller is not active.');
    }
    return lease;
  }

  void _accept(StminiLocalState state, Object lease) {
    if (!_current(lease) || _closing) return;
    _state = state;
    if (state.phase == StminiLocalPhase.closed) {
      _closing = true;
      _channel?.setMethodCallHandler(null);
    }
    notifyListeners();
  }

  void _failProtocol(Object lease) {
    if (!_current(lease) || _protocolFailed) return;
    _protocolFailed = true;
    _state = null;
    _revision += 1;
    _channel?.setMethodCallHandler(null);
    notifyListeners();
    unawaited(close().catchError((Object _) {}));
  }

  /// Fetches the same strict state schema used by stateChanged notifications.
  Future<StminiLocalState> getState() async {
    final lease = _requireLease();
    final revision = _revision;
    final request = ++_stateRequest;
    final raw = await _channel!.invokeMethod<Object?>('state');
    if (!_current(lease) || _closing) throw StateError('Local view closed.');
    try {
      final value = StminiLocalState.fromMap(raw);
      if (_revision == revision && request == _stateRequest) {
        _accept(value, lease);
      }
      return value;
    } on FormatException {
      _failProtocol(lease);
      rethrow;
    }
  }

  Future<void> reload() async {
    final lease = _requireLease();
    final raw = await _channel!.invokeMethod<Object?>('reload');
    if (!_current(lease) || _closing) throw StateError('Local view closed.');
    if (raw != null) {
      _failProtocol(lease);
      throw const FormatException('Invalid local renderer response.');
    }
  }

  Future<bool> goBack() async {
    final lease = _requireLease();
    final raw = await _channel!.invokeMethod<Object?>('goBack');
    if (!_current(lease) || _closing) throw StateError('Local view closed.');
    if (raw is! bool) {
      _failProtocol(lease);
      throw const FormatException('Invalid local renderer response.');
    }
    return raw;
  }

  /// Closes once and revokes notifications immediately. Native close is
  /// idempotent; the same Future is returned for every subsequent close call.
  Future<void> close() {
    if (_closeFuture != null) return _closeFuture!;
    if (_lease == null || _disposed) {
      return Future<void>.error(StateError('Controller is not attached.'));
    }
    return _startClose();
  }

  Future<void> _startClose() {
    _closing = true;
    _revision += 1;
    final lease = _lease!;
    final channel = _channel!;
    channel.setMethodCallHandler(null);
    final completion = Completer<void>();
    _closeFuture = completion.future;
    unawaited(() async {
      try {
        final value = await channel.invokeMethod<Object?>('close');
        if (value != null) {
          if (_current(lease)) {
            _protocolFailed = true;
            _state = null;
            notifyListeners();
          }
          throw const FormatException('Invalid local renderer close response.');
        }
        if (_current(lease) && !_protocolFailed) {
          _state = const StminiLocalState._(
            StminiLocalPhase.closed,
            false,
            null,
          );
          notifyListeners();
        }
        completion.complete();
      } catch (error, stack) {
        completion.completeError(error, stack);
      }
    }());
    return completion.future;
  }

  Future<void> _release() {
    _channel?.setMethodCallHandler(null);
    if (_lease != null && !_disposed) return close();
    return Future<void>.value();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _channel?.setMethodCallHandler(null);
    if (_lease != null && _closeFuture == null) {
      unawaited(_startClose().catchError((Object _) {}));
    }
    _disposed = true;
    _lease = null;
    super.dispose();
  }
}

/// Embeds only a verified local package. Creation parameters are exactly
/// miniId/version; the native host independently verifies both and its files.
/// The original app startup does not instantiate this widget automatically.
class StminiLocalView extends StatefulWidget {
  StminiLocalView({
    super.key,
    required this.miniId,
    required this.version,
    this.controller,
    this.onStateChanged,
  }) {
    bool full(RegExp pattern, String text) =>
        pattern.matchAsPrefix(text)?.end == text.length;
    if (miniId.length > 64 ||
        !full(RegExp(r'[a-z0-9][a-z0-9_-]{0,63}'), miniId) ||
        version.length > 79 ||
        !full(RegExp(r'[0-9]{1,9}(\.[0-9]{1,9}){0,7}'), version)) {
      throw ArgumentError('Invalid local package identity.');
    }
  }

  final String miniId;
  final String version;

  /// A controller is bound to one view lifetime. Identity changes require a
  /// new external controller; omitted controllers are replaced automatically.
  final StminiLocalController? controller;
  final ValueChanged<StminiLocalState>? onStateChanged;
  static const viewType = 'stmini_flutter/local_view';

  @override
  State<StminiLocalView> createState() => _StminiLocalViewState();
}

class _StminiLocalViewState extends State<StminiLocalView> {
  late StminiLocalController _controller;
  late bool _ownsController;
  Object _generation = Object();
  bool _bindingRejected = false;
  bool _replacing = false;
  AndroidViewController? _androidController;
  Object? _androidGeneration;
  TextDirection? _androidLayoutDirection;

  @override
  void initState() {
    super.initState();
    _newController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final direction = Directionality.maybeOf(context);
    final controller = _androidController;
    if (direction != null &&
        controller != null &&
        identical(_androidGeneration, _generation) &&
        direction != _androidLayoutDirection) {
      _androidLayoutDirection = direction;
      unawaited(controller.setLayoutDirection(direction));
    }
  }

  void _newController() {
    _controller = widget.controller ?? StminiLocalController();
    _ownsController = widget.controller == null;
    _bindingRejected =
        _controller._reserved ||
        _controller._everBound ||
        _controller._disposed;
    if (!_bindingRejected) {
      _controller._reserved = true;
      _controller.addListener(_changed);
    }
  }

  void _changed() {
    final state = _controller.state;
    if (mounted && state != null) widget.onStateChanged?.call(state);
  }

  Future<void> _release() {
    if (_bindingRejected) return Future<void>.value();
    _controller.removeListener(_changed);
    final closing = _controller._release();
    if (_ownsController) _controller.dispose();
    return closing;
  }

  @override
  void didUpdateWidget(covariant StminiLocalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.miniId != widget.miniId ||
        oldWidget.version != widget.version ||
        !identical(oldWidget.controller, widget.controller)) {
      final closing = _release();
      _androidController = null;
      _androidGeneration = null;
      _androidLayoutDirection = null;
      _generation = Object();
      final generation = _generation;
      _newController();
      _replacing = true;
      unawaited(() async {
        var failed = false;
        try {
          await closing;
        } catch (_) {
          failed = true;
        }
        if (mounted && identical(_generation, generation)) {
          setState(() {
            _replacing = false;
            _bindingRejected |= failed;
          });
        }
      }());
    }
  }

  Future<void> _created(
    int id,
    Object generation,
    StminiLocalController owner,
  ) async {
    if (!mounted || !identical(_generation, generation)) {
      await _closeOrphan(id);
      return;
    }
    try {
      await owner._attach(id);
    } catch (_) {
      await _closeOrphan(id);
      if (mounted && identical(_generation, generation)) {
        owner.removeListener(_changed);
        setState(() {
          _bindingRejected = true;
        });
      }
    }
  }

  Future<void> _closeOrphan(int id) async {
    try {
      await MethodChannel(
        'stmini_flutter/local_view/$id',
      ).invokeMethod<Object?>('close');
    } catch (_) {
      /* The platform may already have destroyed the obsolete view. */
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_replacing) return const SizedBox.shrink();
    if (_bindingRejected) {
      throw StateError('A local view needs a new controller.');
    }
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw UnsupportedError('Local Mini views require iOS or Android.');
    }
    final generation = _generation;
    final owner = _controller;
    final parameters = <String, String>{
      'miniId': widget.miniId,
      'version': widget.version,
    };
    void created(int id) {
      unawaited(_created(id, generation, owner));
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Native navigation replaces the child WebView. Compose the platform
      // view in Android's view hierarchy so those children remain visible;
      // DOM/commit success alone does not prove texture composition painted.
      return PlatformViewLink(
        key: ValueKey(generation),
        viewType: StminiLocalView.viewType,
        surfaceFactory: (context, controller) => AndroidViewSurface(
          controller: controller as AndroidViewController,
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        ),
        onCreatePlatformView: (params) {
          final direction = Directionality.of(context);
          final controller = PlatformViewsService.initExpensiveAndroidView(
            id: params.id,
            viewType: params.viewType,
            layoutDirection: direction,
            creationParams: parameters,
            creationParamsCodec: const StandardMessageCodec(),
            onFocus: () => params.onFocusChanged(true),
          );
          _androidController = controller;
          _androidGeneration = generation;
          _androidLayoutDirection = direction;
          // The link must reveal its surface, and the SDK must bind its
          // independent control channel. Both observe this same creation.
          controller.addOnPlatformViewCreatedListener(
            params.onPlatformViewCreated,
          );
          controller.addOnPlatformViewCreatedListener(created);
          unawaited(controller.create());
          return controller;
        },
      );
    }
    return UiKitView(
      key: ValueKey(generation),
      viewType: StminiLocalView.viewType,
      creationParams: parameters,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: created,
    );
  }

  @override
  void dispose() {
    _generation = Object();
    unawaited(_release().catchError((Object _) {}));
    super.dispose();
  }
}
