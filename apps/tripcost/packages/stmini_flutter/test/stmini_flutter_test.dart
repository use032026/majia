import 'package:flutter_test/flutter_test.dart';
import 'package:stmini_flutter/stmini_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:async';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('stmini_flutter/methods');

  test('declares the Web-only runtime at compile time', () {
    expect(StminiFlutter.runtimeMode, StminiRuntimeMode.web);
  });

  test('openWeb forwards the ordinary Web presentation contract', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return null;
        });
    await StminiFlutter.openWeb('https://example.test/help', title: 'Help');
    expect(received?.method, 'openWeb');
    expect((received?.arguments as Map)['url'], 'https://example.test/help');
    expect((received?.arguments as Map)['title'], 'Help');
  });

  test('initialize forwards the Web bridge context only', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return null;
        });

    await StminiFlutter.initialize(
      bridgeContext: {
        'webSecurity': {'allowInsecureHTTP': true},
      },
    );

    expect(received?.method, 'initialize');
    expect((received?.arguments as Map)['bridgeContext'], {
        'webSecurity': {'allowInsecureHTTP': true},
    });
  });

  test('closeWeb invokes the standalone online-Web owner', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return null;
        });
    await StminiFlutter.closeWeb();
    expect(received?.method, 'closeWeb');
  });

  test(
    'authorized native web request forwards its native-derived origin only',
    () async {
      WebBridgeRequest? received;
      StminiFlutter.setWebBridgeHandler((request) {
        received = request;
        return {
          'code': '1',
          'data': {'accepted': true},
          // Native must ignore extra response fields such as origin.
          'origin': 'https://forged.example',
        };
      });
      final reply = Completer<ByteData?>();
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(
              const MethodCall('webBridgeRequest', {
                'method': 'hostAction',
                'params': {'id': '42'},
                'origin': 'https://help.example:8443',
              }),
            ),
            reply.complete,
          );
      final value = channel.codec.decodeEnvelope((await reply.future)!) as Map;

      expect(received?.method, 'hostAction');
      expect(received?.params, {'id': '42'});
      expect(received?.origin, 'https://help.example:8443');
      expect((value['data'] as Map)['accepted'], true);
    },
  );

  test(
    'native web request without an opt-in handler returns data msg',
    () async {
      StminiFlutter.setWebBridgeHandler(null);
      final reply = Completer<ByteData?>();
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(
              const MethodCall('webBridgeRequest', {
                'method': 'hostAction',
                'params': {},
                'origin': 'https://help.example',
              }),
            ),
            reply.complete,
          );
      final value = channel.codec.decodeEnvelope((await reply.future)!) as Map;

      expect(value['code'], '0');
      expect((value['data'] as Map)['msg'], isNotEmpty);
    },
  );
}
