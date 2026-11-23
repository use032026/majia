import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stmini_flutter/stmini_flutter.dart';
import 'package:trip_delta/domain.dart';
import 'package:trip_delta/main.dart';
import 'package:trip_delta/screens.dart';
import 'package:trip_delta/stmini_web_host.dart';
import 'package:trip_delta/store.dart';
import 'package:trip_delta/web_launch_splash.dart';

WebBridgeRequest request(
  String method, [
  Map<String, dynamic> params = const {},
  String origin = 'https://first.example',
]) => WebBridgeRequest(method: method, params: params, origin: origin);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeRuntime runtime;
  late TripDeltaWebHost host;
  setUp(() {
    runtime = FakeRuntime();
    host = TripDeltaWebHost(
      homeUrl: 'https://first.example/app/#/',
      runtime: runtime,
    );
  });
  tearDown(() => host.dispose());

  test('initialization is single flight and does not open a page', () async {
    runtime.initialization = Completer<void>();
    final first = host.initialize();
    final second = host.initialize();
    expect(identical(first, second), isTrue);
    expect(runtime.initializeCount, 1);
    expect(runtime.context?['webSecurity'], {
      'allowInsecureHTTP': false,
      'bridgeOrigins': ['https://first.example'],
    });
    expect(runtime.context!.containsKey('authStorageKey'), isFalse);
    expect(runtime.context!.containsKey('bridgeUserInfoStorage'), isFalse);
    runtime.initialization!.complete();
    await first;
    await host.initialize();
    expect(runtime.initializeCount, 1);
    expect(runtime.opens, isEmpty);
  });

  test('initialization failure is retryable', () async {
    runtime.failInitialize = true;
    await expectLater(host.initialize(), throwsStateError);
    runtime.failInitialize = false;
    await host.openHome();
    expect(runtime.initializeCount, 2);
    expect(runtime.opens.single['url'], host.homeUri.toString());
  });

  test('identical explicit web opens each reach native navigation', () async {
    for (var i = 0; i < 2; i++) {
      expect(
        (await host.handleBridge(
          request('open', {
            'router': '/web',
            'link': 'https://third.example/a',
            'isNeedNavigationBar': '1',
            'title': 'Details',
          }),
        ))['code'],
        '1',
      );
    }
    expect(runtime.opens.length, 2);
    expect(runtime.opens.first['showNavigationBar'], isTrue);
  });

  test('bad external links and parameter types fail without opening', () async {
    for (final link in [
      'http://first.example',
      'javascript:alert(1)',
      'mini://x',
      'https://user:secret@first.example',
      '//first.example',
      ' https://first.example',
      'https://first.example/\npath',
      5,
    ]) {
      expect(
        (await host.handleBridge(
          request('open', {'router': '/web', 'link': link}),
        ))['code'],
        '0',
      );
    }
    expect(
      (await host.handleBridge(
        request('open', {
          'router': '/web',
          'link': 'https://first.example',
          'title': 5,
        }),
      ))['code'],
      '0',
    );
    expect(runtime.opens, isEmpty);
  });

  test(
    'internal login route preserves home and sets return parameter',
    () async {
      expect(
        (await host.handleBridge(
          request('open', {
            'router': '/login',
            'methodId': 'ignored',
            'language': 'en',
          }),
        ))['code'],
        '1',
      );
      final uri = Uri.parse(runtime.opens.single['url'] as String);
      expect(uri.origin, 'https://first.example');
      expect(uri.path, '/app/');
      final fragment = Uri.parse(uri.fragment);
      expect(fragment.queryParameters['__mini_route_child'], '1');
      final encoded = fragment.queryParameters['__mini_open_route']!;
      final params = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(encoded))),
      );
      expect(params, {'router': '/login', 'language': 'en', 'isBack': '1'});
      expect(runtime.opens.single['showNavigationBar'], isFalse);
    },
  );

  test('third party cannot request app internal routes', () async {
    expect(
      (await host.handleBridge(
        request('open', {'router': '/login'}, 'https://third.example'),
      ))['code'],
      '0',
    );
    for (final router in ['//evil.example', '/\\evil.example', '', 5]) {
      expect(
        (await host.handleBridge(request('open', {'router': router})))['code'],
        '0',
      );
    }
    expect(runtime.opens, isEmpty);
  });

  test(
    'unknown methods and native failures use CMS failure envelope',
    () async {
      final unknown = await host.handleBridge(request('arbitraryHostAction'));
      expect(unknown['code'], '0');
      expect((unknown['data'] as Map)['msg'], isNotEmpty);
      runtime.failOpen = true;
      expect(
        (await host.handleBridge(
          request('open', {'router': '/web', 'link': 'https://first.example'}),
        ))['code'],
        '0',
      );
    },
  );

  test('close and credential-free session events are forwarded', () async {
    expect((await host.handleBridge(request('close')))['code'], '1');
    expect(runtime.closes, 1);
    expect(
      await host.handleBridge(
        request('web_notifySessionChanged', {'reason': 'logout'}),
      ),
      {
        'code': '1',
        'data': {'notified': 2},
      },
    );
    expect(runtime.reasons, ['logout']);
    expect(
      (await host.handleBridge(
        request('web_notifySessionChanged', {'reason': 7}),
      ))['code'],
      '0',
    );
    expect(
      (await host.handleBridge(
        request('applog', {'msg': 'not logged'}),
      ))['code'],
      '1',
    );
  });

  test(
    'dispose removes handler and blocks pending initialization/open',
    () async {
      runtime.initialization = Completer<void>();
      final pending = host.openHome();
      host.dispose();
      runtime.initialization!.complete();
      await expectLater(pending, throwsStateError);
      expect(runtime.handler, isNull);
      expect(runtime.opens, isEmpty);
      expect((await host.handleBridge(request('close')))['code'], '0');
    },
  );

  test(
    'production adapter opens configured default only when called',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const methods = MethodChannel('stmini_flutter/methods');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methods, (call) async {
            calls.add(call);
            return call.method == 'notifyWebSessionChanged' ? 1 : null;
          });
      final actual = TripDeltaWebHost();
      addTearDown(() {
        actual.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(methods, null);
      });
      await actual.initialize();
      expect(calls.map((call) => call.method), ['initialize']);
      expect(calls.single.arguments, {
        'bridgeContext': {
          'packageName': 'com.globalsmartchoose.app',
          'authStorageKey': 'futrenapp:auth-storage:v1',
          'bridgeUserInfoStorage': {
            'storageKey': 'futrenapp:cache-storage:v1',
            'valueKey': 'user',
            'nestedKey': 'userInfo',
          },
          'webSecurity': {
            'allowInsecureHTTP': false,
            'bridgeOrigins': [Uri.parse(TripDeltaWebHost.defaultHomeUrl).origin],
          },
          'webLoading': {
            'readyEvent': 'futrenapp:startup-complete',
            'failureEvent': 'futrenapp:startup-failed',
            'launchImages': webLaunchImages,
            'languageStorage': {
              'valueKey': 'language',
              'manualKey': 'language_user_set',
            },
          },
        },
      });
      await actual.openHome(showNavigationBar: false);
      expect(calls.last.method, 'openWeb');
      expect(calls.last.arguments, {
        'url': TripDeltaWebHost.defaultHomeUrl,
        'showNavigationBar': false,
      });
      expect((await actual.handleBridge(request('close')))['code'], '1');
      expect(calls.last.method, 'closeWeb');
    },
  );

  test('Android production runtime never calls a native Web method', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const methods = MethodChannel('stmini_flutter/methods');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, (call) async {
          calls.add(call);
          return null;
        });
    final actual = TripDeltaWebHost();
    addTearDown(() {
      actual.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methods, null);
    });
    await actual.initialize();
    await expectLater(actual.openHome(), throwsUnsupportedError);
    for (final method in ['open', 'close', 'web_notifySessionChanged']) {
      expect((await actual.handleBridge(request(method)))['code'], '0');
    }
    expect(calls, isEmpty);
  });

  test('unsupported runtime never registers a bridge handler', () async {
    runtime.isSupported = false;
    await host.initialize();
    expect(runtime.handler, isNull);
    expect(runtime.initializeCount, 0);
    await expectLater(host.openHome(), throwsUnsupportedError);
    expect((await host.handleBridge(request('close')))['code'], '0');
    host.dispose();
    expect(runtime.handlerRegistrations, 0);
    expect(runtime.opens, isEmpty);
  });

  for (final fail in [false, true]) {
    testWidgets(
      'trip home survives Web preparation fail=$fail without opening',
      (tester) async {
        runtime.failInitialize = fail;
        final store = MemoryTripStore();
        await tester.pumpWidget(TripDeltaApp(store: store, webHost: host));
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(runtime.initializeCount, 1);
        expect(runtime.opens, isEmpty);
        await tester.pumpWidget(TripDeltaApp(store: store, webHost: host));
        await tester.pumpAndSettle();
        expect(runtime.initializeCount, 1);
        await tester.pumpWidget(const SizedBox());
        expect(runtime.handler, isNull);
      },
    );
  }
}

class MemoryTripStore implements TripStore {
  AppData value = const AppData(language: 'en', onboardingComplete: true);
  @override
  Future<AppData> load() async => value;
  @override
  Future<void> save(AppData data) async => value = data;
}

class FakeRuntime implements TripWebRuntime {
  @override
  bool isSupported = true;
  int handlerRegistrations = 0;
  int initializeCount = 0;
  int closes = 0;
  bool failInitialize = false;
  bool failOpen = false;
  Map<String, dynamic>? context;
  Completer<void>? initialization;
  WebBridgeHandler? handler;
  final opens = <Map<String, dynamic>>[];
  final reasons = <String>[];
  @override
  Future<void> initialize(Map<String, dynamic> context) async {
    initializeCount++;
    this.context = context;
    if (failInitialize) throw StateError('unavailable');
    await initialization?.future;
  }

  @override
  void setBridgeHandler(WebBridgeHandler? handler) {
    handlerRegistrations++;
    this.handler = handler;
  }

  @override
  Future<void> open(
    String url, {
    String? title,
    required bool showNavigationBar,
  }) async {
    if (failOpen) throw StateError('unavailable');
    opens.add({
      'url': url,
      'title': title,
      'showNavigationBar': showNavigationBar,
    });
  }

  @override
  Future<void> close() async => closes++;
  @override
  Future<int> notifySessionChanged(String reason) async {
    reasons.add(reason);
    return 2;
  }
}
