import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stmini_flutter/stmini_flutter.dart';

Map<String, Object?> _state(String phase, {bool back = false, String? error}) =>
    {'phase': phase, 'canGoBack': back, 'errorCode': error};

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  final creates = <Map<Object?, Object?>>[];
  final platformCalls = <MethodCall>[];
  final calls = <int, List<MethodCall>>{};
  final states = <int, Object?>{};
  Future<Object?> Function(int, MethodCall)? overrideCall;
  const codec = StandardMethodCodec();

  // Flutter verifies foundation debug flags before package:test tearDown runs.
  // Restore inside the widget-test callback, including assertion failures.
  void localWidgetTest(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  MethodChannel channel(int id) =>
      MethodChannel('stmini_flutter/local_view/$id');
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }

  Widget host(Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(width: 300, height: 300, child: child),
  );
  Future<Object?> event(
    int id,
    Object? state, {
    String method = 'stateChanged',
  }) {
    final result = Completer<Object?>();
    binding.channelBuffers.push(
      channel(id).name,
      codec.encodeMethodCall(MethodCall(method, state)),
      (bytes) {
        try {
          result.complete(bytes == null ? null : codec.decodeEnvelope(bytes));
        } catch (error, stack) {
          result.completeError(error, stack);
        }
      },
    );
    return result.future;
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    creates.clear();
    platformCalls.clear();
    calls.clear();
    states.clear();
    overrideCall = null;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      platformCalls.add(call);
      if (call.method == 'create') {
        final args = Map<Object?, Object?>.from(call.arguments as Map);
        creates.add(args);
        final id = args['id'] as int;
        states[id] = _state('loading');
        calls[id] = [];
        messenger.setMockMethodCallHandler(channel(id), (call) async {
          calls[id]!.add(call);
          if (overrideCall != null) return overrideCall!(id, call);
          return switch (call.method) {
            'state' => states[id],
            'goBack' => false,
            _ => null,
          };
        });
      }
      return null;
    });
  });
  tearDown(() {
    for (final id in calls.keys) {
      messenger.setMockMethodCallHandler(channel(id), null);
    }
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'strict state schema rejects every envelope or capability expansion',
    () {
      for (final value in [
        null,
        [],
        {},
        {'phase': 'ready'},
        {..._state('ready'), 'path': '/private'},
        _state('unknown'),
        {..._state('ready'), 'canGoBack': 1},
        _state('failed', error: 'arbitrary'),
        {..._state('ready'), 'errorCode': false},
      ]) {
        expect(() => StminiLocalState.fromMap(value), throwsFormatException);
      }
      for (final phase in ['loading', 'ready', 'failed', 'closed']) {
        expect(StminiLocalState.fromMap(_state(phase)).phase.name, phase);
      }
      expect(
        StminiLocalState.fromMap(
          _state('failed', error: 'render_timeout'),
        ).errorCode,
        'render_timeout',
      );
    },
  );

  test(
    'identity validation rejects URI paths case and unsupported versions',
    () {
      for (final id in ['', 'Upper', '../x', '_x', 'a\n', 'a' * 65]) {
        expect(
          () => StminiLocalView(miniId: id, version: '1.0'),
          throwsArgumentError,
        );
      }
      for (final version in [
        '',
        '1.',
        '1-beta',
        '-1',
        '1\n',
        '1234567890',
        List.filled(9, '1').join('.'),
      ]) {
        expect(
          () => StminiLocalView(miniId: 'alpha', version: version),
          throwsArgumentError,
        );
      }
      expect(
        StminiLocalView(
          miniId: 'a' * 64,
          version: List.filled(8, '123456789').join('.'),
        ),
        isA<StminiLocalView>(),
      );
    },
  );

  test(
    'controller rejects commands before binding and after unused dispose',
    () async {
      final controller = StminiLocalController();
      await expectLater(controller.getState(), throwsStateError);
      await expectLater(controller.reload(), throwsStateError);
      await expectLater(controller.goBack(), throwsStateError);
      await expectLater(controller.close(), throwsStateError);
      controller.dispose();
      controller.dispose();
      await expectLater(controller.close(), throwsStateError);
    },
  );

  // Keep this as the first widget test. PlatformViewsService installs its
  // singleton incoming focus handler in its first caller's zone; registering
  // it in an earlier, completed widget fake zone would strand this receipt.
  localWidgetTest(
    'Android uses hybrid surface and preserves creation focus and layout wiring',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final controller = StminiLocalController();
      Widget view(TextDirection direction) => Directionality(
        textDirection: direction,
        child: SizedBox(
          width: 300,
          height: 300,
          child: StminiLocalView(
            miniId: 'alpha',
            version: '1.2',
            controller: controller,
          ),
        ),
      );
      await tester.pumpWidget(view(TextDirection.rtl));
      await settle(tester);
      expect(find.byType(AndroidView), findsNothing);
      expect(find.byType(PlatformViewLink), findsOneWidget);
      final surface = tester.widget<AndroidViewSurface>(
        find.byType(AndroidViewSurface),
      );
      expect(surface.controller, isA<ExpensiveAndroidViewController>());
      expect(surface.controller.requiresViewComposition, isTrue);
      expect(surface.hitTestBehavior, PlatformViewHitTestBehavior.opaque);
      expect(surface.gestureRecognizers, isEmpty);
      final create = creates.single;
      expect(create['hybrid'], isTrue);
      expect(create['direction'], 1);
      expect(create['viewType'], StminiLocalView.viewType);
      final parameters = const StandardMessageCodec().decodeMessage(
        ByteData.sublistView(create['params'] as Uint8List),
      );
      expect(parameters, {'miniId': 'alpha', 'version': '1.2'});
      final id = create['id'] as int;
      // This state read proves owner._attach ran; the rendered surface proves
      // PlatformViewLink's own created callback also ran.
      expect(controller.isAttached, isTrue);
      expect(calls[id]!.first.method, 'state');
      await event(id, _state('ready'));
      expect(controller.state?.phase, StminiLocalPhase.ready);
      final focused = Completer<void>();
      Object? focusError;
      binding.channelBuffers.push(
        SystemChannels.platform_views.name,
        codec.encodeMethodCall(MethodCall('viewFocused', id)),
        (bytes) {
          try {
            if (bytes != null) codec.decodeEnvelope(bytes);
          } catch (error) {
            focusError = error;
          }
          focused.complete();
        },
      );
      // Pump this test's fake zone rather than awaiting an unpumped message.
      // A missing receipt now fails here instead of hanging the whole suite.
      await settle(tester);
      expect(focused.isCompleted, isTrue);
      expect(focusError, isNull);
      expect(
        Focus.of(tester.element(find.byType(AndroidViewSurface))).hasFocus,
        isTrue,
      );
      expect(
        platformCalls.where((call) => call.method == 'create'),
        hasLength(1),
      );
      await tester.pumpWidget(view(TextDirection.ltr));
      await settle(tester);
      expect(
        platformCalls.where(
          (call) =>
              call.method == 'setDirection' &&
              (call.arguments as Map)['id'] == id &&
              (call.arguments as Map)['direction'] == 0,
        ),
        hasLength(1),
      );
      expect(creates, hasLength(1));
      await tester.pumpWidget(host(const SizedBox.shrink()));
      await settle(tester);
      expect(calls[id]!.where((call) => call.method == 'close'), hasLength(1));
      expect(
        platformCalls.where(
          (call) =>
              call.method == 'dispose' && (call.arguments as Map)['id'] == id,
        ),
        hasLength(1),
      );
      controller.dispose();
    },
  );

  localWidgetTest(
    'real widget creation wire is only identity and current state recovers early events',
    (tester) async {
      final controller = StminiLocalController();
      final observed = <StminiLocalState>[];
      await tester.pumpWidget(
        host(
          StminiLocalView(
            miniId: 'alpha',
            version: '1.2',
            controller: controller,
            onStateChanged: observed.add,
          ),
        ),
      );
      await settle(tester);
      final create = creates.single;
      expect(create['viewType'], StminiLocalView.viewType);
      final params = const StandardMessageCodec().decodeMessage(
        ByteData.sublistView(create['params'] as Uint8List),
      );
      expect(params, {'miniId': 'alpha', 'version': '1.2'});
      final id = create['id'] as int;
      expect(controller.isAttached, isTrue);
      expect(controller.state?.phase, StminiLocalPhase.loading);
      expect(calls[id]!.first.method, 'state');
      await event(id, _state('ready', back: true));
      expect(controller.state?.phase, StminiLocalPhase.ready);
      expect(controller.state?.canGoBack, isTrue);
      expect(await controller.goBack(), isFalse);
      await controller.reload();
      await event(id, _state('failed', error: 'render_timeout'));
      expect(controller.state?.errorCode, 'render_timeout');
      expect(calls[id]!.every((call) => call.arguments == null), isTrue);
      final close = controller.close();
      expect(controller.close(), same(close));
      await close;
      expect(controller.state?.phase, StminiLocalPhase.closed);
      expect(calls[id]!.where((call) => call.method == 'close'), hasLength(1));
      await expectLater(controller.reload(), throwsStateError);
      await tester.pumpWidget(host(const SizedBox.shrink()));
      await settle(tester);
      controller.dispose();
      expect(
        observed.map((state) => state.phase),
        contains(StminiLocalPhase.ready),
      );
    },
  );

  localWidgetTest(
    'late initial state response cannot overwrite newer native event',
    (tester) async {
      final pending = Completer<Object?>();
      overrideCall = (_, call) async =>
          call.method == 'state' ? pending.future : null;
      final controller = StminiLocalController();
      await tester.pumpWidget(
        host(
          StminiLocalView(
            miniId: 'alpha',
            version: '1',
            controller: controller,
          ),
        ),
      );
      await settle(tester);
      final id = creates.single['id'] as int;
      await event(id, _state('ready'));
      pending.complete(_state('loading'));
      await settle(tester);
      expect(controller.state?.phase, StminiLocalPhase.ready);
      await tester.pumpWidget(host(const SizedBox.shrink()));
      await settle(tester);
      controller.dispose();
    },
  );

  for (final invalid in [false, true]) {
    localWidgetTest(
      'invalid ${invalid ? 'event' : 'state response'} fails closed',
      (tester) async {
        if (!invalid) {
          overrideCall = (_, call) async =>
              call.method == 'state' ? {'phase': 'ready'} : null;
        }
        final controller = StminiLocalController();
        await tester.pumpWidget(
          host(
            StminiLocalView(
              miniId: 'alpha',
              version: '1',
              controller: controller,
            ),
          ),
        );
        await settle(tester);
        final id = creates.single['id'] as int;
        if (invalid) {
          await expectLater(
            event(id, {..._state('ready'), 'url': 'forbidden'}),
            throwsA(isA<PlatformException>()),
          );
          await settle(tester);
        }
        expect(controller.hasProtocolError, isTrue);
        expect(controller.state, isNull);
        expect(controller.isAttached, isFalse);
        expect(
          calls[id]!.where((call) => call.method == 'close'),
          hasLength(1),
        );
        await tester.pumpWidget(host(const SizedBox.shrink()));
        await settle(tester);
        controller.dispose();
      },
    );
  }

  localWidgetTest('wrong goBack return type cannot become truthy success', (
    tester,
  ) async {
    overrideCall = (_, call) async => call.method == 'state'
        ? _state('ready')
        : call.method == 'goBack'
        ? 1
        : null;
    final controller = StminiLocalController();
    await tester.pumpWidget(
      host(
        StminiLocalView(miniId: 'alpha', version: '1', controller: controller),
      ),
    );
    await settle(tester);
    await expectLater(controller.goBack(), throwsFormatException);
    await settle(tester);
    expect(controller.hasProtocolError, isTrue);
    await tester.pumpWidget(host(const SizedBox.shrink()));
    await settle(tester);
    controller.dispose();
  });

  localWidgetTest(
    'identity and controller update closes old before creating a new view',
    (tester) async {
      final old = StminiLocalController();
      final fresh = StminiLocalController();
      await tester.pumpWidget(
        host(StminiLocalView(miniId: 'alpha', version: '1', controller: old)),
      );
      await settle(tester);
      final oldId = creates.single['id'] as int;
      final lateState = Completer<Object?>();
      overrideCall = (id, call) async {
        if (call.method == 'state' && id == oldId) return lateState.future;
        if (call.method == 'state') return _state('ready');
        return null;
      };
      final pending = old.getState();
      final pendingAssertion = expectLater(pending, throwsStateError);
      await tester.pumpWidget(
        host(StminiLocalView(miniId: 'beta', version: '2', controller: fresh)),
      );
      await settle(tester);
      lateState.complete(_state('failed', error: 'render_timeout'));
      await settle(tester);
      await pendingAssertion;
      expect(creates, hasLength(2));
      expect(
        calls[oldId]!.where((call) => call.method == 'close'),
        hasLength(1),
      );
      expect(old.state?.phase, StminiLocalPhase.closed);
      expect(fresh.state?.phase, StminiLocalPhase.ready);
      await tester.pumpWidget(host(const SizedBox.shrink()));
      await settle(tester);
      old.dispose();
      fresh.dispose();
    },
  );

  localWidgetTest(
    'identity change with used external controller is rejected after closing old view',
    (tester) async {
      final controller = StminiLocalController();
      await tester.pumpWidget(
        host(
          StminiLocalView(
            miniId: 'alpha',
            version: '1',
            controller: controller,
          ),
        ),
      );
      await settle(tester);
      final oldId = creates.single['id'] as int;
      await tester.pumpWidget(
        host(
          StminiLocalView(
            miniId: 'alpha',
            version: '2',
            controller: controller,
          ),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isA<StateError>());
      expect(creates, hasLength(1));
      expect(
        calls[oldId]!.where((call) => call.method == 'close'),
        hasLength(1),
      );
      await tester.pumpWidget(host(const SizedBox.shrink()));
      await settle(tester);
      controller.dispose();
    },
  );

  localWidgetTest('omitted controller is recreated on identity update', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(StminiLocalView(miniId: 'alpha', version: '1')),
    );
    await settle(tester);
    await tester.pumpWidget(
      host(StminiLocalView(miniId: 'beta', version: '2')),
    );
    await settle(tester);
    expect(creates, hasLength(2));
    await tester.pumpWidget(host(const SizedBox.shrink()));
    await settle(tester);
  });

  localWidgetTest(
    'Android hybrid identity replacement closes and disposes the old platform view',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final old = StminiLocalController();
      final fresh = StminiLocalController();
      await tester.pumpWidget(
        host(StminiLocalView(miniId: 'alpha', version: '1', controller: old)),
      );
      await settle(tester);
      final oldId = creates.single['id'] as int;
      final pending = Completer<Object?>();
      overrideCall = (id, call) async {
        if (call.method == 'state' && id == oldId) return pending.future;
        if (call.method == 'state') return _state('ready');
        return null;
      };
      final obsolete = expectLater(old.getState(), throwsStateError);
      await tester.pumpWidget(
        host(StminiLocalView(miniId: 'beta', version: '2', controller: fresh)),
      );
      await settle(tester);
      pending.complete(_state('failed', error: 'render_timeout'));
      await settle(tester);
      await obsolete;
      expect(creates, hasLength(2));
      expect(creates.every((create) => create['hybrid'] == true), isTrue);
      expect(
        calls[oldId]!.where((call) => call.method == 'close'),
        hasLength(1),
      );
      expect(
        platformCalls.where(
          (call) =>
              call.method == 'dispose' &&
              (call.arguments as Map)['id'] == oldId,
        ),
        hasLength(1),
      );
      expect(old.state?.phase, StminiLocalPhase.closed);
      expect(fresh.state?.phase, StminiLocalPhase.ready);
      expect(
        tester
            .widget<AndroidViewSurface>(find.byType(AndroidViewSurface))
            .controller
            .viewId,
        creates.last['id'],
      );
      await tester.pumpWidget(host(const SizedBox.shrink()));
      await settle(tester);
      old.dispose();
      fresh.dispose();
    },
  );

  localWidgetTest('unsupported desktop platform cannot create a native view', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await tester.pumpWidget(
      host(StminiLocalView(miniId: 'alpha', version: '1')),
    );
    expect(tester.takeException(), isA<UnsupportedError>());
    expect(creates, isEmpty);
    await tester.pumpWidget(host(const SizedBox.shrink()));
  });
}
