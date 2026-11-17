import 'dart:async';

import 'package:flutter/services.dart';

import 'stmini_event.dart';

/// EventChannel-compatible transport with local, awaitable control errors.
///
/// Flutter's EventChannel reports listen/cancel failures globally. This derived
/// transport sends the same wire methods, but delivers activation failures to
/// listeners and cancellation failures to the last subscription's cancel Future.
/// Controls are serialized across generations; old completions never clear a
/// new handler. Native owns the corresponding event-production lease.
class SafeStminiEventStream extends Stream<StminiEvent> {
  SafeStminiEventStream({BinaryMessenger? messenger}) : _messenger = messenger;

  static const channelName = 'stmini_flutter/events';
  static const _codec = StandardMethodCodec();
  final BinaryMessenger? _messenger;
  BinaryMessenger get _binaryMessenger =>
      _messenger ?? ServicesBinding.instance.defaultBinaryMessenger;

  _EventGeneration? _current;
  Future<void> _controls = Future<void>.value();

  @override
  bool get isBroadcast => true;

  @override
  StreamSubscription<StminiEvent> listen(
    void Function(StminiEvent)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final generation = _current ??= _EventGeneration();
    final controller = StreamController<StminiEvent>(sync: true);
    late _EventSubscription subscription;
    final delegate = controller.stream.listen(
      onData,
      onError: (Object error, StackTrace stack) =>
          subscription.forwardError(error, stack),
      onDone: onDone,
      // Cancellation must pass through the wrapper to release its lease.
      cancelOnError: false,
    );
    subscription = _EventSubscription(
      delegate,
      () => _remove(generation, controller),
      onError,
      cancelOnError ?? false,
      Zone.current,
    );
    generation.listeners.add(controller);
    if (generation.listeners.length == 1) _activate(generation);
    return subscription;
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _controls.then((_) => operation());
    _controls = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  void _activate(_EventGeneration generation) {
    try {
      _binaryMessenger.setMessageHandler(channelName, (ByteData? data) async {
        if (!identical(_current, generation) ||
            !generation.active ||
            !generation.listenSent) {
          return null;
        }
        if (data == null) {
          _finish(generation);
          return null;
        }
        try {
          final value = _codec.decodeEnvelope(data);
          if (value is! Map) {
            throw const FormatException('Invalid STMini event envelope.');
          }
          final event = StminiEvent.fromMap(Map<String, dynamic>.from(value));
          for (final listener in generation.listeners.toList()) {
            if (generation.listeners.contains(listener) && !listener.isClosed) {
              listener.add(event);
            }
          }
        } catch (error, stack) {
          _report(generation, error, stack);
        }
        return null;
      });
    } catch (error, stack) {
      // Defer errors until listen() has returned its subscription.
      scheduleMicrotask(() {
        _report(generation, error, stack);
        _finish(generation);
      });
      return;
    }
    unawaited(
      _enqueue(() async {
        if (!identical(_current, generation) || !generation.active) return;
        generation.listenSent = true;
        await MethodChannel(
          channelName,
          _codec,
          _binaryMessenger,
        ).invokeMethod<void>('listen');
      }).catchError((Object error, StackTrace stack) {
        _report(generation, error, stack);
        _finish(generation);
      }),
    );
  }

  void _report(_EventGeneration generation, Object error, StackTrace stack) {
    if (!identical(_current, generation) || !generation.active) return;
    for (final listener in generation.listeners.toList()) {
      if (!listener.isClosed) listener.addError(error, stack);
    }
  }

  void _finish(_EventGeneration generation) {
    if (!identical(_current, generation)) return;
    _current = null;
    generation.active = false;
    try {
      _binaryMessenger.setMessageHandler(channelName, null);
    } catch (error, stack) {
      for (final listener in generation.listeners.toList()) {
        if (!listener.isClosed) listener.addError(error, stack);
      }
    }
    for (final listener in generation.listeners) {
      scheduleMicrotask(() => unawaited(listener.close()));
    }
    generation.listeners.clear();
  }

  Future<void> _remove(
    _EventGeneration generation,
    StreamController<StminiEvent> listener,
  ) {
    generation.listeners.remove(listener);
    scheduleMicrotask(() => unawaited(listener.close()));
    if (!identical(_current, generation) || generation.listeners.isNotEmpty) {
      return Future<void>.value();
    }
    _current = null;
    generation.active = false;
    Object? cleanupError;
    StackTrace? cleanupStack;
    try {
      _binaryMessenger.setMessageHandler(channelName, null);
    } catch (error, stack) {
      cleanupError = error;
      cleanupStack = stack;
    }
    return _enqueue(() async {
      if (generation.listenSent) {
        await MethodChannel(
          channelName,
          _codec,
          _binaryMessenger,
        ).invokeMethod<void>('cancel');
      }
      if (cleanupError != null) {
        Error.throwWithStackTrace(cleanupError, cleanupStack!);
      }
    });
  }
}

class _EventGeneration {
  final listeners = <StreamController<StminiEvent>>{};
  bool active = true;
  bool listenSent = false;
}

class _EventSubscription implements StreamSubscription<StminiEvent> {
  _EventSubscription(
    this._delegate,
    this._remove,
    this._errorHandler,
    this._cancelOnError,
    this._zone,
  );
  final StreamSubscription<StminiEvent> _delegate;
  final Future<void> Function() _remove;
  Function? _errorHandler;
  bool _cancelOnError;
  final Zone _zone;
  Future<void>? _cancellation;

  @override
  Future<void> cancel() => _cancellation ??= _cancel();

  Future<void> _cancel() async {
    await Future.wait<void>([_remove(), _delegate.cancel()]);
  }

  void forwardError(Object error, StackTrace stack) {
    try {
      final handler = _errorHandler;
      if (handler is void Function(Object, StackTrace)) {
        handler(error, stack);
      } else if (handler is void Function(Object)) {
        handler(error);
      } else {
        _zone.handleUncaughtError(error, stack);
      }
    } finally {
      if (_cancelOnError) {
        unawaited(cancel().catchError((Object _) {}));
      }
    }
  }

  @override
  void onData(void Function(StminiEvent)? handleData) =>
      _delegate.onData(handleData);
  @override
  void onError(Function? handleError) => _errorHandler = handleError;
  @override
  void onDone(void Function()? handleDone) => _delegate.onDone(handleDone);
  @override
  void pause([Future<void>? resumeSignal]) => _delegate.pause(resumeSignal);
  @override
  void resume() => _delegate.resume();
  @override
  bool get isPaused => _delegate.isPaused;
  @override
  Future<E> asFuture<E>([E? futureValue]) {
    final value = futureValue as E;
    final completion = Completer<E>();
    onDone(() => completion.complete(value));
    _cancelOnError = true;
    onError((Object error, StackTrace stack) {
      completion.completeError(error, stack);
    });
    return completion.future;
  }
}
