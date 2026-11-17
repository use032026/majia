import 'dart:async';

import 'package:almanac/src/stmini_startup.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stmini_flutter/stmini_flutter.dart';

StminiEvent _ready({
  String name = 'foundation_initialized',
  bool initialized = true,
}) => StminiEvent.fromMap({
  'name': name,
  'payload': {
    'stage': 'foundation',
    'initialized': initialized,
    'packageName': 'com.almanac.lite',
    'miniLoadingAvailable': false,
    'webLoadingAvailable': false,
  },
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'service consumes only verified current foundation events into immutable diagnostics',
    () async {
      final events = StreamController<StminiEvent>.broadcast(sync: true);
      final startup = StminiStartup(
        initialize: (_) async {},
        events: events.stream,
      );
      addTearDown(events.close);
      addTearDown(startup.dispose);
      await startup.initializeOnce();
      events.add(_ready(name: 'unrelated'));
      events.add(_ready(initialized: false));
      expect(startup.diagnostics['foundationState'], isNull);
      expect(startup.diagnostics['lastIssue'], 'invalid_foundation_event');
      events.add(_ready());
      final snapshot = startup.diagnostics;
      expect(snapshot['eventCount'], 1);
      expect((snapshot['foundationState'] as Map)['initialized'], isTrue);
      expect(() => snapshot['eventCount'] = 20, throwsUnsupportedError);
      expect(
        () => (snapshot['foundationState'] as Map)['initialized'] = false,
        throwsUnsupportedError,
      );
      events.add(_ready());
      expect(startup.diagnostics['eventCount'], 2);
      expect(snapshot['eventCount'], 1);
    },
  );

  test(
    'stream errors and done preserve the initialization terminal result and last real snapshot',
    () async {
      final events = StreamController<StminiEvent>.broadcast(sync: true);
      var initializations = 0;
      final startup = StminiStartup(
        initialize: (_) async {
          initializations += 1;
        },
        events: events.stream,
      );
      addTearDown(startup.dispose);
      final initialized = startup.initializeOnce();
      await initialized;
      events.add(_ready());
      events.addError(StateError('fake native stream failure'));
      expect(startup.diagnostics['lastIssue'], 'event_stream_failed');
      await events.close();
      expect(startup.diagnostics['eventsDone'], isTrue);
      expect(startup.diagnostics['eventCount'], 1);
      expect(startup.initializeOnce(), same(initialized));
      expect(initializations, 1);
    },
  );

  test(
    'creator disposal isolates pending initialization and a recreated service',
    () async {
      final events = StreamController<StminiEvent>.broadcast(sync: true);
      final pending = Completer<void>();
      var initializations = 0;
      final old = StminiStartup(
        initialize: (_) {
          initializations += 1;
          return pending.future;
        },
        events: events.stream,
      );
      final oldResult = old.initializeOnce();
      await old.dispose();
      final afterDisposal = old.diagnostics;
      final fresh = StminiStartup(
        initialize: (_) async {
          initializations += 1;
        },
        events: events.stream,
      );
      addTearDown(events.close);
      addTearDown(fresh.dispose);
      await fresh.initializeOnce();
      events.add(_ready());
      pending.completeError(StateError('fake old initialization failure'));
      await oldResult;
      expect(old.diagnostics, afterDisposal);
      expect(fresh.diagnostics['eventCount'], 1);
      expect(initializations, 2);
      await expectLater(old.initializeOnce(), throwsStateError);
    },
  );

  testWidgets(
    'one service subscription survives Host unmount and remount while initialization is pending',
    (tester) async {
      var listens = 0;
      var cancels = 0;
      var initializations = 0;
      final events = StreamController<StminiEvent>.broadcast(
        sync: true,
        onListen: () => listens += 1,
        onCancel: () => cancels += 1,
      );
      final pending = Completer<void>();
      final startup = StminiStartup(
        initialize: (_) {
          initializations += 1;
          return pending.future;
        },
        events: events.stream,
      );
      Widget host() =>
          StminiStartupHost(startup: startup, child: const SizedBox.shrink());
      try {
        await tester.pumpWidget(host());
        await tester.pumpWidget(const SizedBox.shrink());
        events.add(_ready());
        expect(startup.diagnostics['eventCount'], 1);
        await tester.pumpWidget(host());
        expect(listens, 1);
        expect(cancels, 0);
        expect(initializations, 1);
        pending.complete();
        await tester.pump();
      } finally {
        // Stream cancellation may return a root-zone SDK Future.
        if (!pending.isCompleted) {
          pending.complete();
        }
        await tester.runAsync(() async {
          await startup.dispose();
          await events.close();
        });
      }
      expect(cancels, 1);
    },
  );

  test(
    'SDK late-listen fixture replays already initialized native state without cross-channel FIFO',
    () async {
      // This models native replay on the real binary channel wire. It does not
      // claim the OS replay path has executed; the platform harness covers that.
      final binding = TestDefaultBinaryMessengerBinding.instance;
      final messenger = binding.defaultBinaryMessenger;
      const methods = MethodChannel('stmini_flutter/methods');
      const eventsChannel = MethodChannel('stmini_flutter/events');
      const codec = StandardMethodCodec();
      var nativeInitialized = false;
      var initializeCalls = 0;
      final wireMethods = <String>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        expect(call.method, 'initialize');
        initializeCalls += 1;
        nativeInitialized = true;
        return null;
      });
      messenger.setMockMethodCallHandler(eventsChannel, (call) async {
        wireMethods.add(call.method);
        if (call.method == 'listen' && nativeInitialized) {
          final ready = _ready();
          binding.channelBuffers.push(
            eventsChannel.name,
            codec.encodeSuccessEnvelope({
              'name': ready.name,
              'payload': ready.payload,
            }),
            (_) {},
          );
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(methods, null));
      addTearDown(
        () => messenger.setMockMethodCallHandler(eventsChannel, null),
      );
      await StminiFlutter.initialize(
        bridgeContext: {'packageName': 'com.almanac.lite'},
      );
      final startup = StminiStartup(
        initialize: (_) async {},
        events: StminiFlutter.events,
      );
      await startup.initializeOnce();
      await Future<void>.delayed(Duration.zero);
      expect(initializeCalls, 1);
      expect(startup.diagnostics['eventCount'], 1);
      expect(
        (startup.diagnostics['foundationState'] as Map)['initialized'],
        isTrue,
      );
      await startup.dispose();
      expect(wireMethods, ['listen', 'cancel']);
    },
  );

  test(
    'production SDK control failures remain in service diagnostics',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('stmini_flutter/events');
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'cancel') {
          throw PlatformException(code: 'fake_cancel');
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final startup = StminiStartup(initialize: (_) async {});
      await startup.initializeOnce();
      await Future<void>.delayed(Duration.zero);
      await startup.dispose();
      expect(startup.diagnostics['lastIssue'], 'event_cancel_failed');

      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'fake_activation');
      });
      final fresh = StminiStartup(initialize: (_) async {});
      await fresh.initializeOnce();
      await Future<void>.delayed(Duration.zero);
      expect(fresh.diagnostics['lastIssue'], 'event_stream_failed');
      expect(fresh.diagnostics['eventsDone'], isTrue);
      await fresh.dispose();
    },
  );
}
