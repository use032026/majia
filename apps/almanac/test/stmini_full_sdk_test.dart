import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stmini_flutter/stmini_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('stmini_flutter/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = StandardMethodCodec();
  Future<Object?> reverseRequest() async {
    final reply = Completer<Object?>();
    var replies = 0;
    await messenger.handlePlatformMessage(
      channel.name,
      codec.encodeMethodCall(
        const MethodCall('webBridgeRequest', {
          'method': 'fixture_business_provider_not_installed',
          'params': {'methodId': 'synthetic-default-provider'},
          'origin': 'https://example.invalid',
        }),
      ),
      (data) {
        replies += 1;
        expect(replies, 1);
        reply.complete(data == null ? null : codec.decodeEnvelope(data));
      },
    );
    return reply.future;
  }

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    StminiFlutter.setWebBridgeHandler(null);
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'iOS initialize installs default reverse reply before native dispatch',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      // Reproduce a fresh Engine with no explicit setWebBridgeHandler call.
      channel.setMethodCallHandler(null);
      Object? duringInitialize;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'initialize');
        duringInitialize = await reverseRequest();
        return null;
      });
      await StminiFlutter.initialize(
        bridgeContext: const {'packageName': 'com.almanac.lite'},
      );
      expect(duringInitialize, {
        'code': '0',
        'data': {'msg': 'Host did not handle the web request.'},
      });
      expect(await reverseRequest(), duringInitialize);
    },
  );

  test(
    'iOS repeated initialization preserves an explicit reverse provider',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var providerCalls = 0;
      StminiFlutter.setWebBridgeHandler((request) {
        providerCalls += 1;
        expect(request.origin, 'https://example.invalid');
        expect(request.params['methodId'], 'synthetic-default-provider');
        return {
          'code': '1',
          'data': {'synthetic': true},
        };
      });
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      await StminiFlutter.initialize();
      await StminiFlutter.initialize();
      expect(await reverseRequest(), {
        'code': '1',
        'data': {'synthetic': true},
      });
      expect(providerCalls, 1);
      StminiFlutter.setWebBridgeHandler(null);
      await StminiFlutter.initialize();
      expect((await reverseRequest() as Map)['code'], '0');
      expect(providerCalls, 1);
    },
  );

  test(
    'Android initialize leaves an unconfigured reverse channel unchanged',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      channel.setMethodCallHandler(null);
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      await StminiFlutter.initialize();
      // The test messenger returns no envelope for an absent receiver.
      // An unintended iOS-style default on Android would instead return code0.
      expect(await reverseRequest(), isNull);
      expect(StminiFlutter.runtimeStage, 'foundation');
      expect(StminiFlutter.miniPackageDownloadAvailable, isFalse);
    },
  );

  test(
    'complete SDK entry methods preserve native dispatch and parameters',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'isAvailable') return true;
        if (call.method == 'notifyWebSessionChanged') return 2;
        return null;
      });
      await StminiFlutter.initialize(
        bridgeContext: const {'packageName': 'com.almanac.lite'},
      );
      await StminiFlutter.openMini('mini://synthetic_fixture');
      await StminiFlutter.openWeb(
        'https://example.invalid/fixture',
        title: 'Synthetic',
        showNavigationBar: false,
      );
      await StminiFlutter.closeWeb();
      await StminiFlutter.closeMini();
      expect(await StminiFlutter.isAvailable, isTrue);
      expect(
        await StminiFlutter.notifyWebSessionChanged('synthetic-session'),
        2,
      );
      expect(calls.map((call) => call.method), [
        'initialize',
        'openMini',
        'openWeb',
        'closeWeb',
        'closeMini',
        'isAvailable',
        'notifyWebSessionChanged',
      ]);
      expect(calls[1].arguments, {'link': 'mini://synthetic_fixture'});
      expect(calls[2].arguments, {
        'url': 'https://example.invalid/fixture',
        'title': 'Synthetic',
        'showNavigationBar': false,
      });
      expect(StminiFlutter.runtimeMode, StminiRuntimeMode.mini);
    },
  );

  test(
    'unsupported native Web and Android full Mini errors propagate',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'unsupported_capability');
      });
      for (final operation in <Future<void> Function()>[
        () => StminiFlutter.openMini('mini://synthetic_fixture'),
        () => StminiFlutter.openWeb('https://fixture.invalid'),
        () => StminiFlutter.closeWeb(),
      ]) {
        await expectLater(
          operation(),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'unsupported_capability',
            ),
          ),
        );
      }
    },
  );

  test('null notification reply is not invented successful zero', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    await expectLater(
      StminiFlutter.notifyWebSessionChanged('synthetic'),
      throwsFormatException,
    );
  });

  test(
    'reverse bridge request model validates and freezes native origin metadata',
    () async {
      StminiFlutter.setWebBridgeHandler(null);
      // The immutable request model is independent from mocked method dispatch.
      final request = WebBridgeRequest.fromMap({
        'method': 'synthetic',
        'params': <String, dynamic>{},
        'origin': 'https://example.invalid',
      });
      expect(request.origin, 'https://example.invalid');
      expect(() => request.params['host'] = true, throwsUnsupportedError);
      for (final origin in [
        'http://example.invalid',
        'https://user@example.invalid',
        'https://example.invalid/private',
        'https://example.invalid?token=synthetic',
      ]) {
        expect(
          () => WebBridgeRequest.fromMap({
            'method': 'synthetic',
            'params': {},
            'origin': origin,
          }),
          throwsFormatException,
        );
      }
      // Do not send a real host request; method-codec transport is covered by
      // the controlled native Engine target separately.
    },
  );
  test(
    'platform capabilities preserve Android and explicit iOS package dispatch',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(StminiFlutter.miniPackageMode, 'local_only');
      expect(StminiFlutter.miniPackageDownloadAvailable, isFalse);
      expect(StminiFlutter.miniPackageInstallAvailable, isFalse);
      expect(StminiFlutter.miniPackageUpdateAvailable, isFalse);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(StminiFlutter.miniPackageMode, 'download_install_update');
      expect(StminiFlutter.miniPackageDownloadAvailable, isTrue);
      expect(StminiFlutter.miniPackageInstallAvailable, isTrue);
      expect(StminiFlutter.miniPackageUpdateAvailable, isTrue);
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'openMini') {
          throw PlatformException(
            code: 'invalid_download_url',
            message: 'HTTPS required',
          );
        }
        return null;
      });
      await expectLater(
        StminiFlutter.openMini(
          'mini://fixture?downloadUrl=http://fixture.invalid/x.zip',
        ),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'invalid_download_url',
          ),
        ),
      );
    },
  );
}
