import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stmini_flutter/src/safe_event_stream.dart';
import 'package:stmini_flutter/stmini_flutter.dart';

const _codec = StandardMethodCodec();
const _state = <String, dynamic>{
  'stage': 'mini',
  'runtimeMode': 'mini',
  'initialized': true,
  'packageName': 'com.almanac.lite',
};

Map<String, dynamic> _event() => <String, dynamic>{
  'name': 'runtime_initialized',
  'payload': _state,
};

Future<void> _settle() => Future<void>.delayed(Duration.zero);

/// Binary wire fixture, not an Android/iOS event-loop execution claim.
class _Messenger extends BinaryMessenger {
  final calls = <MethodCall>[];
  MessageHandler? handler;
  Future<ByteData?>? Function(MethodCall)? control;

  @override
  Future<ByteData?>? send(String channel, ByteData? message) {
    expect(channel, SafeStminiEventStream.channelName);
    final call = _codec.decodeMethodCall(message!);
    calls.add(call);
    return control?.call(call) ??
        Future<ByteData?>.value(_codec.encodeSuccessEnvelope(null));
  }

  @override
  void setMessageHandler(String channel, MessageHandler? callback) {
    expect(channel, SafeStminiEventStream.channelName);
    handler = callback;
  }

  Future<void> emit(dynamic value) async {
    await handler?.call(_codec.encodeSuccessEnvelope(value));
  }

  @override
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    PlatformMessageResponseCallback? callback,
  ) async {
    callback?.call(await handler?.call(data));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'SDK shares one broadcast and native subscription until last cancel',
    () async {
      expect(StminiFlutter.events, same(StminiFlutter.events));
      expect(StminiFlutter.events.isBroadcast, isTrue);
      final messenger = _Messenger();
      final stream = SafeStminiEventStream(messenger: messenger);
      final firstEvents = <StminiEvent>[];
      final secondEvents = <StminiEvent>[];
      final first = stream.listen(firstEvents.add);
      final second = stream.listen(secondEvents.add);
      await _settle();
      expect(messenger.calls.map((call) => call.method), ['listen']);
      expect(messenger.calls.single.arguments, isNull);
      await messenger.emit(_event());
      expect(firstEvents.single.name, 'runtime_initialized');
      expect(secondEvents.single.payload, _state);
      expect(
        () => secondEvents.single.payload['initialized'] = false,
        throwsUnsupportedError,
      );
      await first.cancel();
      expect(messenger.calls, hasLength(1));
      await messenger.emit(_event());
      expect(firstEvents, hasLength(1));
      expect(secondEvents, hasLength(2));
      await second.cancel();
      expect(messenger.calls.map((call) => call.method), ['listen', 'cancel']);
      expect(messenger.handler, isNull);
      await second.cancel();
      expect(messenger.calls, hasLength(2));
    },
  );

  test(
    'bad envelopes and malformed models fail locally without readiness',
    () async {
      final messenger = _Messenger();
      final stream = SafeStminiEventStream(messenger: messenger);
      final events = <StminiEvent>[];
      final errors = <Object>[];
      final subscription = stream.listen(events.add, onError: errors.add);
      await _settle();
      for (final value in <dynamic>[
        'not a map',
        {'name': 7, 'payload': _state},
        {'name': '', 'payload': _state},
        {'name': 'runtime_initialized', 'payload': false},
        {
          'name': 'runtime_initialized',
          'payload': {7: 'invalid key'},
        },
      ]) {
        await messenger.emit(value);
      }
      await messenger.handler!(
        _codec.encodeErrorEnvelope(code: 'native_error'),
      );
      await messenger.handler!(ByteData(1));
      expect(errors, hasLength(7));
      expect(events, isEmpty);
      await messenger.emit(_event());
      expect(events.single.payload, _state);
      await subscription.cancel();
    },
  );

  for (final synchronous in [true, false]) {
    test(
      '${synchronous ? 'sync' : 'async'} activation failure is a local stream error and done',
      () async {
        final globalHandler = FlutterError.onError;
        final messenger = _Messenger();
        messenger.control = (_) {
          if (synchronous) throw StateError('fake control activation');
          return Future<ByteData?>.error(StateError('fake control activation'));
        };
        final stream = SafeStminiEventStream(messenger: messenger);
        final errors = <Object>[];
        var done = false;
        final subscription = stream.listen(
          (_) => fail('unexpected event'),
          onError: errors.add,
          onDone: () => done = true,
        );
        await _settle();
        expect(errors.single, isA<StateError>());
        expect(done, isTrue);
        expect(messenger.handler, isNull);
        expect(FlutterError.onError, same(globalHandler));
        await subscription.cancel();
      },
    );

    test(
      '${synchronous ? 'sync' : 'async'} cancellation failure is awaitable and a fresh listener works',
      () async {
        final messenger = _Messenger();
        messenger.control = (call) {
          if (call.method == 'cancel') {
            if (synchronous) throw StateError('fake control cancellation');
            return Future<ByteData?>.error(
              StateError('fake control cancellation'),
            );
          }
          return Future<ByteData?>.value(_codec.encodeSuccessEnvelope(null));
        };
        final stream = SafeStminiEventStream(messenger: messenger);
        final first = stream.listen((_) {});
        await _settle();
        await expectLater(first.cancel(), throwsA(isA<StateError>()));
        messenger.control = null;
        final events = <StminiEvent>[];
        final next = stream.listen(events.add);
        await _settle();
        await messenger.emit(_event());
        expect(events, hasLength(1));
        await next.cancel();
      },
    );
  }

  for (final failListen in [false, true]) {
    test(
      'old ${failListen ? 'failed' : 'successful'} activation and delayed cancellation cannot close a new generation',
      () async {
        final messenger = _Messenger();
        final activation = Completer<ByteData?>();
        final cancellation = Completer<ByteData?>();
        var listens = 0;
        messenger.control = (call) {
          if (call.method == 'listen' && listens++ == 0) {
            return activation.future;
          }
          if (call.method == 'cancel') return cancellation.future;
          return Future<ByteData?>.value(_codec.encodeSuccessEnvelope(null));
        };
        final stream = SafeStminiEventStream(messenger: messenger);
        final old = stream.listen((_) => fail('old queued event delivered'));
        await _settle();
        final oldHandler = messenger.handler!;
        final canceled = old.cancel();
        final freshEvents = <StminiEvent>[];
        final fresh = stream.listen(freshEvents.add);
        final freshHandler = messenger.handler;
        await oldHandler(_codec.encodeSuccessEnvelope(_event()));
        if (failListen) {
          activation.completeError(StateError('late activation failure'));
        } else {
          activation.complete(_codec.encodeSuccessEnvelope(null));
        }
        await _settle();
        expect(messenger.handler, same(freshHandler));
        expect(messenger.calls.map((call) => call.method), [
          'listen',
          'cancel',
        ]);
        // Native listen for the next generation cannot overtake old cancellation.
        await messenger.emit(_event());
        expect(freshEvents, isEmpty);
        cancellation.complete(_codec.encodeSuccessEnvelope(null));
        await canceled;
        await _settle();
        expect(messenger.calls.map((call) => call.method), [
          'listen',
          'cancel',
          'listen',
        ]);
        expect(messenger.handler, same(freshHandler));
        await oldHandler(_codec.encodeSuccessEnvelope(_event()));
        expect(freshEvents, isEmpty);
        await messenger.emit(_event());
        expect(freshEvents, hasLength(1));
        await fresh.cancel();
      },
    );
  }

  test(
    'late failing cancellation cannot erase a replacement handler',
    () async {
      final messenger = _Messenger();
      final cancellation = Completer<ByteData?>();
      messenger.control = (call) => call.method == 'cancel'
          ? cancellation.future
          : Future<ByteData?>.value(_codec.encodeSuccessEnvelope(null));
      final stream = SafeStminiEventStream(messenger: messenger);
      final old = stream.listen((_) {});
      await _settle();
      final canceled = old.cancel();
      final failure = expectLater(canceled, throwsA(isA<StateError>()));
      final events = <StminiEvent>[];
      final fresh = stream.listen(events.add);
      final handler = messenger.handler;
      cancellation.completeError(StateError('late cancel failure'));
      await failure;
      await _settle();
      expect(messenger.handler, same(handler));
      await messenger.emit(_event());
      expect(events, hasLength(1));
      messenger.control = null;
      await fresh.cancel();
    },
  );

  test(
    'native done closes current listeners and a later listen gets a fresh generation',
    () async {
      final messenger = _Messenger();
      final stream = SafeStminiEventStream(messenger: messenger);
      var done = false;
      final first = stream.listen((_) {}, onDone: () => done = true);
      await _settle();
      await messenger.handler!(null);
      await _settle();
      expect(done, isTrue);
      final events = <StminiEvent>[];
      final fresh = stream.listen(events.add);
      await _settle();
      await first.cancel();
      expect(messenger.handler, isNotNull);
      await messenger.emit(_event());
      expect(events, hasLength(1));
      await fresh.cancel();
    },
  );

  test(
    'cancelOnError and asFuture release their native subscriptions',
    () async {
      final messenger = _Messenger();
      final stream = SafeStminiEventStream(messenger: messenger);
      final errors = <Object>[];
      stream.listen((_) {}, onError: errors.add, cancelOnError: true);
      await _settle();
      await messenger.emit('malformed');
      await _settle();
      expect(errors, hasLength(1));
      expect(messenger.handler, isNull);
      final subscription = stream.listen((_) {});
      final completion = subscription.asFuture<void>();
      final failed = expectLater(completion, throwsA(isA<FormatException>()));
      await _settle();
      await messenger.emit(false);
      await failed;
      await _settle();
      expect(messenger.handler, isNull);
    },
  );
}
