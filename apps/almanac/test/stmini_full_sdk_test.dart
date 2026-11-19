import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stmini_flutter/stmini_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('stmini_flutter/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() async {
    StminiFlutter.setWebBridgeHandler(null);
    messenger.setMockMethodCallHandler(channel, null);
  });

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
    'local-only SDK advertises no package mutation and propagates rejection',
    () async {
      expect(StminiFlutter.miniPackageMode, 'local_only');
      expect(StminiFlutter.miniPackageDownloadAvailable, isFalse);
      expect(StminiFlutter.miniPackageInstallAvailable, isFalse);
      expect(StminiFlutter.miniPackageUpdateAvailable, isFalse);
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'openMini') {
          throw PlatformException(
            code: 'unsupported',
            message: 'Local packages only',
          );
        }
        return null;
      });
      await expectLater(
        StminiFlutter.openMini(
          'mini://fixture?downloadUrl=https://fixture.invalid/x.zip',
        ),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'unsupported',
          ),
        ),
      );
    },
  );
}
