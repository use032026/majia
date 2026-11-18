import 'dart:async';

import 'package:almanac/src/almanac_app.dart';
import 'package:almanac/src/app_controller.dart';
import 'package:almanac/src/domain/almanac_models.dart';
import 'package:almanac/src/stmini_startup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stmini_flutter/stmini_flutter.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'test_support.dart';

class _FakePolicyLauncher extends UrlLauncherPlatform {
  final urls = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    urls.add(url);
    return false;
  }
}

Future<AppController> _controller(MemoryStateStore store) async {
  final controller = AppController(
    store: store,
    seedFactory: () => 'stmini-startup-seed',
    clock: () => DateTime(2026, 10, 10, 9),
  );
  await controller.load();
  await controller.completeOnboarding();
  await controller.setLocaleMode(AppLocaleMode.en);
  await controller.setThemeMode(AppThemeMode.dark);
  final leaf = controller.todayLeaf;
  await controller.sealToday(
    suitableId: leaf.suitablePromptIds.first,
    avoidId: leaf.avoidPromptIds.first,
    intention: 'Keep this local record',
  );
  return controller;
}

StminiStartup _testStartup({
  required StminiInitializer initialize,
  Stream<StminiEvent> events = const Stream<StminiEvent>.empty(),
}) {
  final startup = StminiStartup(
    initialize: initialize,
    events: events,
    loadInstalledPackages: () async => const <StminiPackage>[],
  );
  addTearDown(startup.dispose);
  return startup;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'concurrent and completed calls initialize once with only Deynu ID',
    () async {
      final pending = Completer<void>();
      final contexts = <Map<String, dynamic>>[];
      final startup = _testStartup(
        initialize: (context) {
          contexts.add(context);
          return pending.future;
        },
      );

      final first = startup.initializeOnce();
      expect(startup.initializeOnce(), same(first));
      expect(contexts, <Map<String, dynamic>>[
        <String, dynamic>{'packageName': 'com.almanac.lite'},
      ]);
      pending.complete();
      await first;
      expect(startup.initializeOnce(), same(first));
      expect(contexts, hasLength(1));
    },
  );

  for (final synchronous in <bool>[true, false]) {
    test(
      '${synchronous ? 'A synchronous' : 'An asynchronous'} failure is contained without retry',
      () async {
        var calls = 0;
        final startup = _testStartup(
          initialize: (_) {
            calls += 1;
            if (synchronous) throw StateError('fake initialization failure');
            return Future<void>.error(
              PlatformException(code: 'fake_initialization_failure'),
            );
          },
        );

        final first = startup.initializeOnce();
        await first;
        await startup.initializeOnce();
        expect(startup.initializeOnce(), same(first));
        expect(calls, 1);
      },
    );
  }

  for (final fails in <bool>[false, true]) {
    testWidgets(
      'first frame, pending and ${fails ? 'failed' : 'successful'} initialization preserve the original app',
      (tester) async {
        final store = MemoryStateStore();
        final controller = await _controller(store);
        addTearDown(controller.dispose);
        final saved = store.value;
        final writes = store.writeCount;
        final data = controller.data!.toJson();
        final pending = Completer<void>();
        var calls = 0;
        final startup = _testStartup(
          initialize: (context) {
            calls += 1;
            expect(
              tester.binding.schedulerPhase,
              SchedulerPhase.postFrameCallbacks,
            );
            expect(find.byKey(const Key('daily_leaf_scroll')), findsOneWidget);
            expect(context, <String, dynamic>{
              'packageName': 'com.almanac.lite',
            });
            return pending.future;
          },
        );
        final originalLauncher = UrlLauncherPlatform.instance;
        final launcher = _FakePolicyLauncher();
        UrlLauncherPlatform.instance = launcher;
        addTearDown(() => UrlLauncherPlatform.instance = originalLauncher);

        Widget app() => StminiStartupHost(
          startup: startup,
          child: AlmanacApp(controller: controller),
        );

        expect(calls, 0);
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(find.byKey(const Key('daily_leaf_scroll')), findsOneWidget);
        expect(launcher.urls, isEmpty);
        expect(store.value, saved);
        expect(store.writeCount, writes);

        // A root rebuild and theme/locale notifications do not reinitialize.
        await tester.pumpWidget(app());
        await controller.setLocaleMode(AppLocaleMode.zhHans);
        await controller.setThemeMode(AppThemeMode.light);
        await tester.pumpAndSettle();
        await controller.setLocaleMode(AppLocaleMode.en);
        await controller.setThemeMode(AppThemeMode.dark);
        await tester.pumpAndSettle();
        expect(calls, 1);

        if (fails) {
          pending.completeError(PlatformException(code: 'fake_unavailable'));
        } else {
          pending.complete();
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('daily_leaf_scroll')), findsOneWidget);
        expect(controller.data!.toJson(), data);
        expect(store.value, saved);
        expect(controller.todayLeaf.intention, 'Keep this local record');
        expect(
          Theme.of(tester.element(find.byType(Scaffold).last)).brightness,
          Brightness.dark,
        );
        expect(launcher.urls, isEmpty);

        await tester.tap(find.byKey(const Key('settings_button')));
        await tester.pumpAndSettle();
        expect(find.text('Language'), findsOneWidget);
        final privacy = find.byKey(const Key('privacy_button'));
        await tester.ensureVisible(privacy);
        await tester.tap(privacy);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('privacy_screen')), findsOneWidget);
        expect(find.text('Local records'), findsOneWidget);
        expect(launcher.urls, <String>[
          'https://www.almanac1.com/privacy.html?lang=en',
        ]);
        expect(controller.data!.toJson(), data);

        // Remounting with the process initializer also keeps its terminal result.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(find.byKey(const Key('daily_leaf_scroll')), findsOneWidget);
      },
    );
  }

  testWidgets('disposal before the first frame skips initialization', (
    tester,
  ) async {
    var calls = 0;
    final startup = _testStartup(
      initialize: (_) async {
        calls += 1;
      },
    );
    final binding = tester.binding;

    // Build and dispose before advancing a frame, leaving the registered
    // post-frame callback pending until the host has already been unmounted.
    binding.attachRootWidget(
      binding.wrapWithDefaultView(
        StminiStartupHost(startup: startup, child: const SizedBox.shrink()),
      ),
    );
    binding.buildOwner!.buildScope(binding.rootElement!);
    expect(find.byType(StminiStartupHost), findsOneWidget);
    binding.attachRootWidget(
      binding.wrapWithDefaultView(const SizedBox.shrink()),
    );
    binding.buildOwner!.buildScope(binding.rootElement!);
    binding.buildOwner!.finalizeTree();
    expect(find.byType(StminiStartupHost), findsNothing);

    await tester.pump();
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late initialization failure after disposal is contained', (
    tester,
  ) async {
    final pending = Completer<void>();
    final startup = _testStartup(initialize: (_) => pending.future);
    await tester.pumpWidget(
      StminiStartupHost(startup: startup, child: const SizedBox.shrink()),
    );
    await tester.pumpWidget(const SizedBox.shrink());

    pending.completeError(StateError('fake late failure'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await startup.initializeOnce();
  });

  testWidgets(
    'production foundation adapter sends initialize and decodes state fixture',
    (tester) async {
      const channel = MethodChannel('stmini_flutter/methods');
      final calls = <MethodCall>[];
      final nativeState = <String, dynamic>{
        'stage': 'foundation',
        'initialized': true,
        'packageName': 'com.almanac.lite',
      };
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'foundationState') return nativeState;
        if (call.method == 'installedPackages') return <Object?>[];
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      const eventsChannel = MethodChannel('stmini_flutter/events');
      messenger.setMockMethodCallHandler(eventsChannel, (_) async => null);
      addTearDown(
        () => messenger.setMockMethodCallHandler(eventsChannel, null),
      );
      final startup = StminiStartup();
      try {
        await tester.pumpWidget(
          StminiStartupHost(startup: startup, child: const SizedBox.shrink()),
        );
        await tester.pump();
        await startup.initializeOnce();

        expect(StminiFlutter.runtimeStage, 'foundation');
        expect(calls.map((call) => call.method), <String>[
          'initialize',
          'installedPackages',
        ]);
        expect(calls.first.arguments, <String, dynamic>{
          'bridgeContext': <String, dynamic>{'packageName': 'com.almanac.lite'},
        });

        // Verify the production Dart getter and payload decoding. Native state
        // persistence is covered by native tests rather than this channel fake.
        expect(await StminiFlutter.foundationState, nativeState);
        expect(calls.map((call) => call.method), <String>[
          'initialize',
          'installedPackages',
          'foundationState',
        ]);
        expect(calls.last.arguments, isNull);
      } finally {
        // Stream cancellation may return a root-zone SDK Future.
        await tester.runAsync(startup.dispose);
      }
    },
  );
}
