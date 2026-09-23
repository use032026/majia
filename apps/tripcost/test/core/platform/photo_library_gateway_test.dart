import 'dart:typed_data';

import 'package:flutter/services.dart'
    show MethodCall, MethodChannel, PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_cost/core/platform/photo_library_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('trip_cost/photos_test');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('sends PNG bytes through the dedicated save channel', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return null;
        });

    final bytes = Uint8List.fromList(<int>[137, 80, 78, 71]);
    await const MethodChannelPhotoLibraryGateway(
      channel: channel,
    ).savePng(bytes);

    expect(received?.method, 'savePng');
    expect(received?.arguments, bytes);
  });

  test('maps native permission denial to a domain exception', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'photo-permission-denied');
        });

    expect(
      () => const MethodChannelPhotoLibraryGateway(
        channel: channel,
      ).savePng(Uint8List.fromList(<int>[1])),
      throwsA(
        isA<PhotoLibrarySaveException>().having(
          (error) => error.code,
          'code',
          PhotoLibrarySaveException.permissionDenied,
        ),
      ),
    );
  });

  test('rejects an empty image before calling the platform', () async {
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls += 1;
          return null;
        });

    expect(
      () => const MethodChannelPhotoLibraryGateway(
        channel: channel,
      ).savePng(Uint8List(0)),
      throwsA(isA<PhotoLibrarySaveException>()),
    );
    expect(calls, 0);
  });
}
